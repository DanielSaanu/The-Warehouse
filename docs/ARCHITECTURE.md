# Architecture: where the data lives

**Status: Track A is built (2026-09-18, branch `track-a`); Track B is not.** `roblox/src/server/README.md` has the
check-list, and §10 lists where the build departed from this plan and why. Written 2026-09-18 before rung 3 part 2 (save and catch-up), because the shape
of the data decides whether saving is a morning's work or a rewrite. Reviewed for five rounds (7 → 9.0, summary in
`docs/qa/architecture-summary.md`), then re-read end to end and revised by a different model, which changed six
decisions — listed in §9 so nobody re-litigates them by accident. This document states decisions; the history of
how they were reached lives in the summary, not here.

Danzo's brief: *"set it up in a way where the data flows instead of congesting… a village has x amount of people,
those people are split into groups, those groups are split into individuals. Data that affects the group is
applied at the top level, data that applies to a family is at the group level, and so on… the data is in one
place, or several, whatever works, and the systems that rely on it are not directly moving it."*

---

## 1. What is actually wrong today

Measured, not asserted.

- **The creature record is a bag of ~47 fields.** `newEntity` (`Sim.lua:150`) sets 31; another 16 are bolted on
  later. Identity, body, position, pathfinding scratch, an AI mind and a combat memory in one table that every
  system reaches into. **That is the congestion.**
- **Nothing owns anything.** `S.tribes` is touched from four files and written from two (Sim, and
  `Interact.lua:167,293,305`). There is no module you can point at and say "this is the only thing that changes a
  tribe's stock".
- **`Sim.lua` is 1,617 lines** (~20k tokens). It and `Hud.lua` are `--!nonstrict`, so the type checker is barely
  looking. Twelve full entity sweeps, twenty `pairs(S.players)` sweeps.
- **Nothing durable is separable from the transient**, and the durable parts are stamped with a clock
  (`os.clock`) that resets to zero on every new server.

---

## 2. The shape: one tree, by tier

One **World Record**: plain data. No functions, no Instances, no cycles, no object references — ids only.

```
world
├─ meta        version, genVersion, seed, gameSeconds, savedAt, rngState,
│              nextBagId, lastDailyTick, headlines[]
├─ calendar    calamity { kind, active, day, warnedDay }
├─ regions[]   per 16x16: grass, deer, boar, wolf                 36 rows, fixed
├─ tribes[]    type, villageId, stock{}, population, walled, surnames, news
├─ villages[]  id, tribeId                (rung 3 part 3 adds memory; nothing else is stored in v1)
├─ groups{}    id, kind, tribe, from, to, pos, dir, acc, speed, pauses, fullSize,
│              lateTarget, carry{}, members[], pauseUntil, replenishAt, retreatUntil
├─ people      nextId, rows: the full Families.Person minus `entity`
├─ camps{}     owner, x, y, litUntil, out
├─ bags{}      id, x, y, owner, slots, droppedAt, public
└─ players     a SEPARATE DataStore key per player (DESIGN §14):
               version, pos, inv, coin, rep{}, grudges{}, rest, goalStage, flags, lastSeenDay, lastGroupId
```

**What is deliberately *not* in the tree** — each of these is in memory today, and saving any of them is a bug:

| Not stored | Why | Rebuilt from |
| --- | --- | --- |
| the map (`ground`, `object`) | derived (R4) | `meta.seed` via `WorldGen.generate` |
| camp and bag tiles on the map | derived: every runtime `world.object` write (`Sim.lua:842, 1283, 1287, 1302, 1317, 1340, 1366`) is a stamp of a camp or bag row | re-stamped from `camps`/`bags` on load |
| flood tiles, `floodBackup`, `calamity.flood`, `regions[].tide` | an overlay derived from `calamity.kind` | `Calamity.applyOverlay` (§6 boot order) |
| `groups[].route` | derived from `from`/`to` | `WorldGen.route` on load, `pos` clamped |
| `regions[].live` | the count of *materialised* animals (`Sim.lua:180, 602, 619, 1551`); persisted, `r.live[sp] < want` is false forever and nothing ever spawns again | zeroed on boot |
| `regions[].forest/open/col/row/village`, village name/bounds/spawn | derived from the map | the map |
| every entity id: `person.entity`, `g.entities`, `g.leader`, `g.target`, `t.guard`, `t.merchant`, `t.survivor` | the `"e"..n` counter restarts, so a stale id **collides** with a new object rather than dangling | `restore` re-points them (A4) |
| `day`, `dayFraction` | derived from `gameSeconds` | `DayCycle` |
| a family | derived index over `father/mother/spouse/children` | `Families` |
| `sizeTier`, `chiefId`, village `bank` | no writer exists; rung 4 | — |

**The tier rule, which is Danzo's rule made precise:**

> A fact lives at the **highest tier where it is still true of everything below it** — and if it is *derived*
> from anything else, it is not stored at all (R4).

- True of a tribe → tribe row: stock, surnames, which village is theirs (by id).
- True of a village → village row: from part 3, **what happened here**.
- True of a party → group row: where it is going, load, who is in it.
- True of one person → person row, small fixed fields only.
- True of a player's relationship with a tribe → **that player's own key**, never the tribe's, never a villager's.

**A family is not a group.** It is a derived index over person fields. **Groups are only things with a route, a
position and members.**

### Ids stay numbers. The *serialised* form has no id-keyed maps.

DataStore serialises to JSON, and JSON object keys are strings: a sparse `{ [7] = person }` comes back
`{ ["7"] = person }` and `reg.people[p.father]` silently returns nil. Three nodes are id-keyed in memory:
`people.people` (`Families.lua:30`), `camps` (by `UserId`) and `bags` (already string ids — fine).

The fix lives **entirely inside `Save.encode`/`Save.decode`**: id-keyed maps are written as **arrays of rows that
carry their own id** (`Person.id`, `camp.owner` — both fields exist today), and `decode` rebuilds the in-memory
index. JSON number *values* round-trip as numbers, so `father = 7` needs no change. Nothing outside `Save.lua`
knows. *(An earlier revision turned every id into a string instead; that was a type change across `--!strict`
`Families.lua`, silently changed the sort order that decides pairing and succession — `"p10" < "p2"` — and
touched five camp read sites in a `--!nonstrict` file. It is reverted: §9.)*

---

## 3. The five rules

**R1. Live objects are projections; the durable half is a named sub-table.** An entity is a view of a person
record plus scratch. **The live player record is a projection too** — `Sim.lua:1515` puts a `Player` Instance, a
function, `budget` and `-math.huge` in the same flat table as `inv` and `rep`. Its durable half moves to
`ps.save`, and the save writes only that. *Save records, never live objects.*

**R2. One writer per slice.** Ownership is by **field path**, so two systems can own different fields of one row.

| Slice | Only writer |
| --- | --- |
| `meta.gameSeconds`, `.lastDailyTick`, `calendar.calamity` | `Calendar` |
| `meta.version`, `.genVersion`, `.seed`, `.savedAt`, `.rngState` | `Save` (stamped at encode; `rngState` is a snapshot of the one `Rng`) |
| `meta.nextBagId`, `camps`, `bags`, their tiles on the map | `Tiles` |
| `meta.headlines`, `tribes[].news`, `.population`, `.surnames`, `people` | `Population` |
| `tribes[].type`, `.walled`, `.villageId`, `villages[]` | written once by `generate` (A4), never after |
| `tribes[].stock`, player `inv`, `coin` | `Economy` |
| `regions[]` counts | `Ecology` (exists, pure) |
| `groups{}` | `Bands` |
| memory on villages and groups (part 3), player `rep`, `grudges`, `goalStage`, `flags`, `lastSeenDay` | `Standing` |
| entities, occupancy, player `pos`, `rest` | `Bodies` |

**`Bands` must never recreate a group row wholesale** once part 3 hangs `memory` on it. Grow and shrink rows.

**R3. Systems ask, they do not reach.** `Economy.deposit(tribe, goods)`, not `t.stock.hide += n`. The call is the
contract, and the place for a log line, a test, or a save-dirty flag. Deliberately **not** an ECS or a message
bus: the failure mode here is unclear ownership, not too little indirection.

**R4. Derived data is never stored.** See the table in §2. The test for any new field: *can I recompute this from
something else in the tree plus the seed?* Then it is not in the tree.

**R5. One clock, and it is game time.**

- `os.clock()` restarts near zero on a new server, and today it stamps `S.dayStart` (`Sim.lua:1548`),
  `camps.litUntil` (`:1286`), `bags.droppedAt` (`:841`), `groups.pauseUntil` (`:416`, `groupTurn`),
  `replenishAt`, `retreatUntil` — all in tables the tree persists — and `Sim.clock()` (`:72`) derives the day
  from it, so catch-up has no calendar to advance.
- **`Calendar.now()` returns `meta.gameSeconds`**, an accumulator (`+= dt` per tick; catch-up adds a lump).
  **Every sim timer, durable or not, is an absolute `gameSeconds` value.** One unit, no "day plus fraction", no
  "remaining seconds rehydrated on load" — a timer that is already in game time needs nothing done to it on
  load, and it expires correctly across a catch-up for free.
- `os.clock` survives in exactly two places: `Movement.newBudget` (a per-tick budget) and profiling prints. A lint
  rule in `tools/luau-check.js` fails any other use in `server/` (allow-list by file:function).
- `os.time()` is read in exactly one place: `meta.savedAt` at save, and `os.time() - savedAt` at load, which is
  how the world knows how long it slept.
- **Known consequence:** `Debug jump` moves `gameSeconds`, so campfires burn out and bags expire across a jump.
  That is correct — time passed — and it is a behaviour change QA should expect.

---

## 4. The module map after

```
shared/  (pure Luau — the only code `npm test` can run; `test/luau/run.js:12`)
  Save.lua         encode / decode / migrate / shape-check the tree            ~200   NEW (A4)
  Tick.lua         Tick.daily, Tick.groups, Tick.catchUp — pure over the tree   ~200   NEW (A2)
  Calamity.lua     + applyOverlay / the one-time half as data                 (exists)
  DayCycle.lua     + day/fraction from gameSeconds                            (exists)
  WorldGen.lua     877 → generate / query / encode                              (B4)

server/
  Map.lua          the generated map: init, get, walkable, encoded   (exists as World.lua, 37)
  Persistence.lua  DataStore adapter: load, save, autosave, failure policy      ~150   NEW (A5)
  Calendar.lua     gameSeconds, now(), setDay(), calamity begin/end             ~120   NEW (A1)
  Bodies.lua       entities: spawn, move, occupancy, replication, wildlife      ~300
  Brains.lua       the think dispatcher, the AI states, targeting               ~250
  Fighting.lua     damage, death, loot, break points                            ~250
  Bands.lua        groups: materialise/collapse, members; adapter for Tick.groups ~200
  Tiles.lua        camps and bags, and their stamps on the map                  ~150
  Population.lua   adapter for Families + Tick.daily events → bodies            ~150
  Economy.lua      stock, prices, deposits, the player inventory slice           ~80
  Standing.lua     reputation events; later gossip and grudges                  ~150
  Sides.lua / Interact.lua / Debug.lua                          (exist: 278 / 341 / 214)
  Sim.lua          the tick loops and nothing else                              ~150
```

`server/World.lua` already exists and holds the *map*; it is renamed `Map.lua` (two require sites:
`Server.server.lua:11`, `Sim.lua:27`) so nothing called "world" sits next to the World Record.

**`Save.encode` returns a JSON-safe table, not a string** — pure Luau has no JSON encoder and DataStore takes
tables. "JSON-safe" is checkable without JSON: every table is either a dense array or string-keyed; every number
is finite; no functions, userdata or cycles. `Save.check(t)` asserts exactly that, which is what makes
`decode(encode(tree))` deep-equal `tree` a *meaningful* test in `npm test`: under that shape, real JSON is the
identity. `Persistence` measures the real byte size with `HttpService:JSONEncode` and logs it on every save.

---

## 4b. The codebase has a second reader, and it has a context window

**H1. A hard ceiling of 400 lines, target 250** — a check in `npm test`. Generated files exempt. Every allow-list
entry names what deletes it: `Sim.lua` 1617 (B1–B3), `WorldGen.lua` 877 (B4), `Hud.lua` 1021 and
`Client.client.lua` 653 (rung 3 part 5, the client split), `Viewport.lua` 429 (rung 4, or never: one job, 29 over).
**H2.** The first fifteen lines say what the file owns, and what it deliberately does not do.
**H3.** One job per file, and the filename is the job.
**H4.** Plain `require` by default; `bind(ctx)` only for a genuine cycle (`Brains` ↔ `Fighting`). `bind` takes an
untyped `ctx` into `any` locals, so `luau-analyze` cannot see a typo.
**H5.** Tests are the cheap way to read a rule (`witness.test.luau`).
**H6.** `roblox/src/server/README.md`: one line per module, updated in the same commit as any move.
**H7.** Greppable, stable names: `Economy.deposit`, not `handle`/`process`/`update`.
**H8.** One worked example per module header.
**H9.** New logic goes in `shared/` as pure Luau unless it touches a Roblox API; `server/` modules are thin
adapters. This is the rule that lets the model check its own work without Studio. **Pure functions return events;
adapters print, notify and spawn.**

---

## 5. Not blowing up the machine

**The 4 MB key.** `Families.MAX_PEOPLE = 9` caps the *living per tribe*, so the registry grows at the death rate.
A full person record is ~274 B of JSON, pruned ~71 B: 4 MiB ÷ 274 ≈ 15,300 records ≈ 106 real days of continuous
simulation at one death per in-game day (the real rate is ≤ 0.9). **People are not the thing to watch. Memory per
holder, per player, is** (part 3): 43 holders × 5 entries × 60 B ≈ 13 KB per player ever seen; 300 players ≈
3.9 MB. So holder memory is capped per (holder, player) — ~3 entries, LRU over ~32 players per holder ≈ 242 KB —
and per-player standing lives in the player's own key.

**Pruning is a rule from the first save.** A person dead longer than `PRUNE_DAYS` keeps `id, first, last, died,
cause, killer` and loses the rest; never deleted, because the living point at them. A pure function in
`Save.lua`, run at encode, with its own test.

**CPU.** Entities are capped at ~100 (DESIGN §4), so a full sweep is microseconds; the 10 Hz think loop is the
dominant cost and an index does not help it. **The spatial index is demand-driven**: built when a measurement
says a query is hot. Rung 4's answer is DESIGN §4's tiering, not an index.

**Catch-up cost.** At the cap: 16,800 group steps × ≤40 groups of integer arithmetic + 28 daily ticks. Measure it
in A2's test; if it exceeds ~50 ms, `Persistence` runs it in slices with `task.wait()` *before* the door opens
(§6 boot order), which is free because nobody is in the server yet.

---

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

---

## 7. What this costs, and what could go wrong

- **A lot of moving with no new gameplay** — which is why Track A is ordered so part 2 arrives at its end, and
  Track B is optional.
- **Over-abstraction.** The honest risk is building a framework for three villages. R3 is the lightest thing that
  fixes the real problem; if a rule is not paying, drop it.
- **The save format is a commitment.** `meta.version` + `Save.migrate` exist from the first save, with a test per
  migration.
- **A2 changes behaviour on purpose** (births complete unobserved; `jump` expires timers). Those are the only two
  intended behaviour changes in Track A; anything else that changes is a bug.

---

## 8. Settled questions (do not re-litigate without new evidence)

1. One tree, `people` a versioned sub-table that can be lifted into its own key later; players in their own keys.
2. Named owners, not queued intents. 3. A family is a derived index, not a group.
4. Villages are their own tier keyed by id (rung 4 gives a tribe several; `MAX_PEOPLE` is per *tribe* today and
   must become per village then).
5. Entity budget ~100; the index is demand-driven.
6. Catch-up records a **world-level headline ring** (`meta.headlines[]` of `{day, kind, subjectId}`, 64 entries
   ≈ 2.5 KB), not per-player diffs; the join line is built from headlines newer than `lastSeenDay`.
7. DataStore is not denser than JSON; budget in JSON bytes.
8. "Capped at 4 weeks" is in-game weeks.
9. `groups[].route` is derived; the accepted risk is that a `WorldGen.route` change snaps a loading caravan to
   the nearest point on its new road — and `genVersion` now makes even that a non-event.

---

## 9. What the second reader changed (2026-09-18), and why

Five review rounds by one model family converged on a document that a different model, reading it cold, changed
in six places. Each is a decision reversed or a gap filled, not a rewording:

1. **Ids stay numeric; `Save` writes arrays of rows.** The round-4 fix (stringify every id) solved a
   serialisation problem by changing the in-memory model, and round 5 then found two silent bugs it caused. The
   problem is only at the JSON boundary, so the fix belongs only there.
2. **`mapDiff` is deleted.** All eight runtime map writes are stamps of `camps`/`bags` rows — the diff was stored
   derived data (R4) with two places to get out of sync. Rounds 2–4 spent three fixes on a node that should not
   exist. If rung 4 adds real terrain edits, that is when it earns a node.
3. **One clock.** "Instants are day-plus-fraction, durations are remaining-seconds-rehydrated" was two conventions
   and a load-time fix-up where one absolute `gameSeconds` needs neither.
4. **Tracks A and B.** The old escape hatch said steps 2–4 were optional while the calamity split and `g.to`
   lived in step 2, and `villageId`, `ps.save` and the bag counter had no step at all.
5. **Persistence has a failure policy and a boot order with a door.** Never write a key you failed to read; one
   server holds the lease; players wait for `ready`. None of the five rounds asked what happens when `GetAsync`
   fails or a player joins mid-load.
6. **`genVersion`.** Round 1 removed the stored map because a generator change would corrupt it; deriving the map
   from the seed has the mirror problem, and nothing guarded it.

Also: catch-up has one stated granularity (the draft said "hourly" in one place and "1 Hz" in two); the
`observed`-flag test, which tested a flag the pure tick does not have, is replaced by record invariants;
`regions[].tide` and `meta.nextPersonId` were each stored twice; `Persistence` no longer "owns" fields that
`generate` writes.

---

## 10. Where the build departed from the plan (Track A, 2026-09-18)

Written after building it, because a plan that is not corrected by its own implementation becomes fiction.

1. **R1's `ps.save` sub-table became a whitelist.** `inv`, `rep`, `goalStage` are read at ~100 sites across four
   `--!nonstrict` files; moving them under `ps.save` would have been a hundred chances at a silent nil. Instead
   `Save.encodePlayer` copies **named fields**, and `Save.encode` does the same for every node of the world — so
   nothing is saved by accident, and "what is durable" is one list per node in `shared/Save.lua`.
2. **`Calendar.now()` is continuous, not tick-fed.** It folds `os.clock()` deltas into `gameSeconds` on every call,
   so attack cooldowns keep their resolution and there is exactly one sim-side wall-clock read.
3. **The calendar only moves forward.** With absolute timers, a backwards `Debug day` would leave every NPC's next
   thought hours in the future. `setDay` refuses the past; `skipTo(frac)` means "the next time it is that hour".
4. **The `os.clock` rule and the line ceiling live in `test/structure.test.js`**, not in the Luau linter: `npm test`
   runs everywhere, the linter needs a gitignored binary. The ceiling is a ratchet — each allow-listed file has its
   own limit that may only shrink — and it stopped this build twice, which is what it is for.
5. **`server/Restore.lua` exists.** The restore constructor needs Sim's innards and Sim was at its ceiling, so it is
   a bound module like `Sides` and `Debug`. `Sim.init(saved, slept)` runs exactly one constructor.
6. **The lease contends instead of forbidding.** A server that finds a live lease plays without saving, and takes
   over when the lease runs out — so a crash costs at most `LEASE_SECONDS` of not saving, where the plan's version
   would have left a quick-restarted server NO-SAVE for its whole life.
7. **`children[]` is not saved** (derived from `father`/`mother`, R4) and is rebuilt by `decode`.
8. **Catch-up at the cap costs 3 ms**, measured in `tick.test.luau`. No slicing needed.
9. **`headlines[]` is carried by the format but nothing writes it yet** — the "you were gone eleven days" line is
   the visible half of part 2 and is the next thing to build.
