# Architecture §6: Track A (A0–A5) and Track B (B1–B4)

Part of [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), which maps every § and rule ID to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of ARCHITECTURE.md, wherever it now lives.

## 6. How we get there without stopping the game

Two tracks. **Track A is what save needs and is not optional. Track B is what the reader needs and is.** The
earlier draft interleaved them and then called half of it optional, which hid three blocker fixes inside
"optional" steps; every save blocker is now mapped to a Track A step, and the table at the end proves it.

Each step is its own commit series, leaves the game playable, and names its gate: `npm test` can only run
`shared/`; lint covers everything; some behaviour needs Play in Studio.

### The mechanics of moving code, already proven here (Track B lives by these)

- **Move text verbatim first, rename after.** Mixing a move with a rewrite turns a refactor into a bug hunt.
- **Watch for bare calls to moved locals.** `local function canFight` that becomes `Sides.canFight` leaves
  callers saying `canFight(...)` — nil at runtime, **silent** until that branch runs. After every move:
  `/usr/bin/grep -n "[^.a-zA-Z_]name(" roblox/src/server/*.lua`, then Play and read the Output.
- **Definition order is load-bearing.** A helper used at line 400 and defined at 900 is a nil global.
- **One module per commit**, so a bisect lands on one move.

### Track A — save-critical

**A0 — guard rails.** The 400-line check with its allow-list; `server/README.md`; rename `World.lua` → `Map.lua`;
the `os.clock` lint rule, landing with an allow-list of today's sites that A1 empties.
**Gate:** test + lint.

**A1 — one clock (R5).** New `server/Calendar.lua` owns `gameSeconds`; `Sim.clock()` reads it; every `os.clock`
timer in `Sim.lua`, `Sides.lua`, `Interact.lua` becomes `Calendar.now()`; `Debug`'s `night`/`jump`/`day`
(`Debug.lua:69, 75, 79`) become `Calendar.setDay(day, frac)`. Day maths goes in `shared/DayCycle.lua`.
**Gate:** test (DayCycle) + lint (the rule's allow-list is down to the two permitted sites) + Studio: day turns
to night, a campfire burns out, a squad pauses and resumes, `jump 7` reaches the calamity.

**A2 — pure ticks (`shared/Tick.lua`).**
- `Tick.daily(tree, rng) → events`: ecology, families, restock, population, group replenish. **Births complete
  whether or not anybody is watching** — today `tickFamilies` (`Sim.lua:1451`) only finishes a birth `if me`
  (the mother's entity exists), so an unobserved world gains registry babies that `population` and `news` never
  hear about. The pure tick always updates the records and returns `{born, grown, conceived}`; the server adapter
  turns events into bodies *if* the bodies exist.
- `Tick.groups(tree, world, routes, now)`: the abstract half of `tickGroups` (`Sim.lua:543`) — pause gate,
  `acc`/`speed`/`pos`, `groupTurn`, `depositCarry`, the `lateTarget` retarget. `materialise`/`collapse`/
  `anyPlayerWithin` stay in `server/`. **`g.to` is stored and rewritten on every retarget**: `makeGroup`
  (`:411`) takes `to` and keeps only `from`, and the retarget replaces `g.route` wholesale, so without `to` a
  reloaded band walks back to its day-one ambush.
- `Tick.catchUp(tree, world, routes, rng, seconds)`: **one granularity, stated once** — for each elapsed second
  `Tick.groups`; at each day boundary `Tick.daily`; calamities **expire** (`active → false` when `day > c.day`)
  but never **begin**; `warnedDay` is set to the final day. Nothing is "hourly": nothing in the code is, and an
  hourly lump moves a group one leg where live ticking moves it eleven.
- Online reputation fade stays daily in the adapter; **on join** a returning player fades once by
  `day - lastSeenDay` (`Reputation.fade(v, days)` already takes days), or an absent player never fades at all.
- **Verify, all in `npm test`:** after 28 days with no bodies, every registry birth is matched by a `population`
  increment and a `news` line; `catchUp(n)` equals `n` live steps of the same pure functions (this is the guard
  against someone "optimising" it into lumps); a group with a `lateTarget` retargets and survives
  `to`-based route rebuild; a calamity active at the start of a 28-day catch-up is inactive at the end and none
  began; the catch-up cost is printed.
**Gate:** test + lint, then Studio for the adapter: a birth with the mother on screen still morphs her.

**A3 — records and references.** The places where the live state is not yet a record:
- `tribes[].village` is a live `WorldGen.Village` table (`Sim.lua:352`) → `villageId`. **Twelve read sites:**
  `Interact.lua:38, 80, 94, 144`, `Sides.lua:63, 180, 206`, `Sim.lua:312, 477, 932, 952, 1406`, `Debug.lua:128`.
  Three are **pointer equality** and fail silently, not loudly: `Sides.lua:63` (who counts as home),
  `Interact.lua:80` (`tribeAt` — how the F key knows which village you are in) and `Debug.lua:128`. Compare ids.
- `Person.village` is the village *name* (`Sim.lua:312`) → the village id.
- `ps.save` sub-table (R1): `inv, coin, rep, grudges, rest, goalStage, flags, pos`; everything else in `ps` is
  transient.
- Bag ids get `meta.nextBagId`; entity ids keep the file-local counter **because they are never saved**.
- **`startCalamity` (`Sim.lua:1374`) splits.** It lays tiles, and *also* sets `c.day`, takes 30% of every tribe's
  food, runs `Ecology.beastTide`, shoves bodies, destroys camps and notifies. A load must re-lay the tiles and do
  none of the rest, so: `Calamity.applyOverlay(world, regions, kind) → floodTiles` is idempotent — `setFlood`
  (self-clearing, `WorldGen.lua:779`) or `r.tide = true`, **nothing else** — and the one-time half stays in
  `Calendar.beginCalamity`. **`Ecology.beastTide` (`Ecology.lua:131`) splits the same way**: it sets the tide flag
  *and* doubles wolves in one loop. The rule for anything a load calls: **ask what else that function does.**
**Gate:** test + lint + Studio: trade and guard talk still work in each village (the `tribeAt` path), an NPC at
home still defends it (the `Sides.lua:63` path), a flood starts, ends and lifts.

**A4 — `Save.lua` and the restore path.**
- `Save.encode/decode/check/prune/migrate` per §2 and §4. `meta.genVersion` is a constant in `WorldGen`; a
  mismatch on load means the seed no longer produces the map the records were made on, so **the world key is
  discarded and regenerated** (players keep their own keys; their `pos` is re-validated anyway). Pre-release,
  that is the honest policy; a generator change is a new world.
- Every constructor splits into **`generate`** (first boot) and **`restore`** (from records). Today `initTribes`
  (`Sim.lua:349`) calls `Families.newAdult` for every roster slot on every boot and `initGroups` (`:425`) rebuilds
  groups from scratch — bolt a load onto that and the registry gains ~27 duplicates per restart. `restore` spawns
  bodies for the living in the registry, re-points `t.guard/merchant/survivor`, and re-stamps camp and bag tiles.
- **Verify in `npm test`:** `Save.check(encode(tree))` passes; `decode(encode(tree))` deep-equals `tree`
  **including key types** (build the fixture with sparse numeric ids so the array-of-rows path is exercised —
  `reg.people` is dense today and would pass by luck); a pruned registry still resolves every `father`/`mother`;
  generate → encode → decode → restore → encode is stable (two boots do not grow the registry).
**Gate:** test + lint + Studio: a cold start still populates three villages.

**A5 — rung 3 part 2: `Persistence.lua` and the boot order.** The only file where saving touches Roblox.

*The boot order is fixed:*
1. `GetAsync`. **No key → `generate`. Key → continue. Error → retry with backoff; if it still fails, generate a
   world and run in NO-SAVE mode for the life of the server.** Never write to a key you failed to read: that is
   how a DataStore hiccup erases a world.
2. `Save.decode` + `migrate`; `genVersion` check.
3. Regenerate the map from `meta.seed`. Re-stamp `camps` and `bags`. Rebuild routes from `from`/`to`.
4. `Tick.catchUp` for `math.min(os.time() - savedAt, CATCHUP_CAP)` seconds. **The cap is 4 *in-game* weeks**
   (DESIGN §14; 28 × 600 s = 4.7 real hours of world time — the real-weeks reading is 2.4 million days of
   replay). Past the cap the world slept. Set `lastDailyTick` to the final day: the live driver
   (`Sim.lua:1598`) assigns rather than steps, so it would otherwise skip everything in between.
5. `Calamity.applyOverlay` if one is still active → assign the transient `c.flood`.
6. **Encode the map now, not before**: `Map.encoded = WorldGen.encode(world)`. Today it is built once inside
   `World.init` (`World.lua:21`) and shipped to every joiner (`Server.server.lua:78`), so restored camps would
   exist on the server and on nobody's screen. **If a field crosses to the client, a load rebuilds it as
   deliberately as it rebuilds the tree** — `Map.encoded` and `c.flood` (`Server.server.lua:79`,
   `Client.client.lua:384`) are the two today.
7. `restore` bodies. **Open the door**: `PlayerAdded` handlers wait on a `ready` signal — `GetAsync` yields for
   seconds, and today `World.init()` is synchronous so nothing had to wait.

*Saving:* autosave every 2 minutes and in `BindToClose`, via `UpdateAsync`. **One server owns the world key**: a
lease in the key (`meta.owner = JobId`, `leaseUntil`) — a second server that finds a live lease loads the world
and runs NO-SAVE, which is DESIGN §14's "the second diverges" without two timelines overwriting each other every
two minutes. Player keys save on leave and in `BindToClose`; on join, `pos` is re-validated with `nearestFree`
(the tile may now be a wall, a flood or a campfire). `lastGroupId` in the player key is a hint: **the world key is
authoritative for group membership**, revalidated on join, discarded on mismatch (rung 3 part 4).
**Gate:** test + **Studio, and the Studio half is the real one**: save, stop, start, rejoin — camps where they
were, the same named people, the calendar later than you left it, a caravan somewhere else.

### Track B — for the reader (optional, any order after A3, one module per commit)

**Status 2026-09-18: started and parked.** `State.lua` (the record, occupancy, the client-facing helpers) and
`Tiles.lua` (camps, bags, the map's object layer) are carved; `Sim.lua` is 1,410 lines. `State.lua` matters beyond
its own size: it is what lets the remaining carves `require` their shared ground instead of taking a `bind(ctx)`
(H4), and it cannot form a cycle. The rest of Track B is untouched and needs a QA loop of its own.

**B1 — carve the small three:** `Tiles`, `Bands`, the calamity half of `Calendar`. `Bands` also gives groups
**stable members** — `g.members` is anonymous specs (`{kind="hunter"}`) re-rolled into different named people on
every materialise; they become person ids, plus `{ player = userId }`. *Part 3 and part 4 need this; part 2 does
not*, which is why it is here and not in Track A. **Gate:** test + Studio (a squad's round trip; same four people
after collapse/materialise).
**B2 — carve the big three:** `Fighting`, `Brains`, `Bodies`. **Gate:** Studio, with the part 1 QA script written
down as a regression script — welcome village defends, wary village watches, predation, band retreats at half.
**B3 — name the owners (R2/R3).** `Economy`, then `Standing`, then `Population`. **Proof a slice is owned:** grep
for writes outside the owner, expect zero, put the grep in the commit. **Gate:** test + lint + grep.
**B4 — split `WorldGen.lua`** into generate / query / encode. **Gate:** test + lint.

### Every save blocker has a Track A home

| # | Blocker | Fixed in |
| --- | --- | --- |
| 1 | `os.clock()` stamps in durable tables | A1 |
| 2 | `Sim.clock()` derives the day from wall time | A1 |
| 3 | id counters restart → stale entity ids collide | A3 (bag counter), A4 (entity ids never encoded) |
| 4 | a flood cannot be lifted after a load | §2 (overlay is not stored) + A3 (`applyOverlay`) + A5 order |
| 5 | id-keyed maps come back string-keyed | A4 (`Save` arrays-of-rows) |
| 6 | re-applying a calamity re-runs its one-time half (incl. `beastTide`) | A3 |
| 7 | `Map.encoded` / `c.flood` stale after a load | A5 steps 5–6 |
| 8 | unobserved births half-happen; catch-up cannot move groups | A2 |
| 9 | live references (`t.village`), `ps` holds an Instance, `init` cannot restore | A3, A4 |
| 10 | a failed read followed by an autosave erases the world; two servers overwrite each other | A5 |
| 11 | a generator change silently moves the map under the records | A4 (`genVersion`) |
