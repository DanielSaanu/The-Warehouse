# Architecture: where the data lives

**Status: a plan, not the code, and the review is still running.** Written 2026-09-18, before rung 3 part 2
(save and catch-up), because the shape of the data decides whether saving is a morning's work or a rewrite.

> **Review loop: rounds 1, 2 and 3 scored 7, 8.5 and 8.5. Round 4 is next.** Danzo raised the bar to **9.5**
> (from 8.0) and capped the loop at **5 rounds**, on 2026-09-18: *"points shouldnt be given for free, i want to
> make sure we have this right before we start coding."* Verbatim reports:
> `docs/qa/architecture-round1.md`, `-round2.md`, `-round3.md`.
>
> **Nothing here is built yet, and nothing should be built until the loop closes** — including rung 3 part 2,
> which depends on step 1. Between them the three rounds have found **five save blockers** that were invisible
> from reading the code — and round 3 found that one of them was *introduced* by round 2's own fix. That is the
> whole argument for finishing the review first.

Danzo's brief: *"set it up in a way where the data flows instead of congesting… a village has x amount of people,
those people are split into groups, those groups are split into individuals. Data that affects the group is
applied at the top level, data that applies to a family is at the group level, and so on… the data is in one
place, or several, whatever works, and the systems that rely on it are not directly moving it."*

---

## 1. What is actually wrong today

Measured, not asserted.

**The creature record is a bag of ~47 fields.** `newEntity` (`Sim.lua:150`) sets 31; another 16 are bolted on
later (`npcTarget, threat, alarm, attacked, provokedBy, beatenBy, mercyGiven, escapeGiven, broken, nextHeal,
blockedCount, nextWitnessAt, aggroUntil, person, first, last`). Six unrelated concerns — identity, body, position,
pathfinding scratch, an AI mind, a combat memory — in one table that every system reaches into. **That is the
congestion.**

**Nothing owns anything.** `S.tribes` is *touched* from four files (Sim 18 sites, Interact 8, Sides 5, Debug 4)
and **written from two**: Sim, and `Interact.lua:167,293,305` (`t.stock`). Sides and Debug only read. The smaller
number is the honest one and it is still the problem — there is no module you can point at and say "this is the
only thing that changes a tribe's stock", so no change can be reasoned about locally.

**Twelve full sweeps over every entity** on the server (eight in `Sim.lua`, two in `Sides.lua`, two in
`Debug.lua`), plus twenty `pairs(S.players)` sweeps in `Sim.lua` alone.

**`Sim.lua` is 1,617 lines.** It did break Luau's type inference once, at roughly 1,800 lines, and the fix was
splitting out `Sides.lua` and `Debug.lua`. Today it lints clean — **but both it and `Hud.lua` are `--!nonstrict`,
so the type checker is barely looking.** The inference budget is a tripwire we already hit, not a guard. The real
reason to split is §4b: a person and a model both have to read this.

**Nothing durable is separable from the transient** — and worse, per R5, the durable parts are timestamped with a
clock that resets to zero on every new server.

---

## 2. The shape: one tree, by tier

One serialisable **World Record**. No functions, no Roblox Instances, no cycles, and **no object references —
ids only**. If it cannot be JSON, it does not belong.

```
world
├─ meta        version, seed, gameSeconds, savedAt, rngState, nextBagId,
│              nextPersonId, lastDailyTick, headlines[]    (never os.clock; see R5)
│              (day and dayFraction are DERIVED from gameSeconds — not stored)
├─ mapDiff     sparse { "tileIndex" -> id } of every runtime tile change, byte-packed
│              EXCEPT calamity tiles, which are an overlay (see the load order, §6)
│              (the map itself is regenerated from the seed — it is derived, R4)
├─ calendar    calamity { kind, active, day, warnedDay }   (no tile list: recompute on load)
├─ regions[]   per 16x16: grass, deer, boar, wolf, tide     36 rows, fixed
│              (forest/open/col/row are derived from the map — not stored)
├─ tribes[]    type, sizeTier, stock{}, population, walled, surnames, news, chiefId
│              (guard/merchant/survivor are ENTITY ids — cleared on save, R5)
├─ villages[]  id, tribeId, roster, bank, memory{}
│              (name, bounds, spawn/bed/stall come from the seed — not stored)
├─ groups{}    caravan / squad / band / (rung 4: hire, warband)
│              from, to, pos, dir, acc, carry{}, morale, memory{},
│              members[]: person ids, or { player = userId } — never anonymous specs
│              (route[] is DERIVED: recomputed from from/to on load, pos clamped)
├─ people{}    "id" -> { id, first, last, sex, tribe, village, role, stage, born,
│                        alive, died, cause, killer, father, mother, spouse,
│                        children[], widowed, due, grown }   — the full Families.Person
│                        minus `entity`, which is transient. `village` is a village ID.
├─ camps{}, bags{}                                        (game-time timers, R5)
└─ players{}   a SEPARATE DataStore key per player (DESIGN §14):
               pos, inv, coin, rep{}, grudges{}, rest, goalStage, flags, lastSeenDay
```

**Every map key in the tree is a string.** DataStore serialises to JSON, and JSON has no integer keys: a
`{ [number]: Person }` written today comes back `{ ["7"]: Person }`, so `reg.people[p.father]` — a number —
silently returns nil and **the family tree detaches on the first load**. Three nodes are numeric-keyed in the code
right now: `Families.Registry.people` (`Families.lua:30`), `S.camps` (keyed by `UserId`, `Sim.lua:1286`) and
`mapDiff`. Either the key is a string everywhere, or the node is an array of rows carrying their own `id` field.
This is not a byte-budget question — §8 Q9 noticed the string keys and drew only the budgeting conclusion — it is
a correctness question, and R1's test is what catches it.

**The tier rule, which is Danzo's rule made precise:**

> A fact lives at the **highest tier where it is still true of everything below it** — and if it is *derived*
> from a lower tier, it is not stored at all (R4).

- True of a tribe → tribe row: stock, size tier, surnames.
- True of a village → village row: roster, knowledge bank, **what happened here**.
- True of a party → group row: where it is going, load, morale, what they saw (the route itself is derived).
- True of one person → person row, small fixed fields only.
- True of a player's relationship with a tribe → **that player's own key**, never the tribe's, never a villager's.

**A family is not a group.** It is a derived index over `Person.father/mother/spouse/children`
(`Population.familyOf(id)`). Storing it as a group row would be storing derived data (R4), and the entity model
refuses it anyway: `newEntity` gives an entity exactly one `group` field, while a hunter in a squad is also
somebody's son. **Groups are only things with a route, a position and morale.**

---

## 3. The five rules

**R1. Live objects are projections; the durable half is a named sub-table.** An entity is a view of a person
record plus transient scratch, rebuilt when a player comes near and thrown away when they leave. **The live
player record is a projection too** — `Sim.lua:1515` puts a `Player` Instance, the `snap` function, `budget` and
`known` in the same flat table as `inv`, `rep` and `goalStage`, and `SetAsync` on that throws. So the durable
half of both lives in a named sub-table (`ps.save`), the save writes only that, and a test **round-trips** the
tree — `decode(encode(t))` deep-equals `t` — rather than merely walking it. A walk catches a function, an
Instance, a cycle, `inf` and `NaN` (`Sim.lua:1517-1518` puts `-math.huge` in the live player record); only a
round trip catches a key or a value that changes type in transit, which is how the numeric-key blocker above
hides. *Save records, never live objects.*

**R2. One writer per slice — and every node in §2 has one.** Ownership is by **field path**, not by table, so
two systems can own different fields of the same row without fighting.

| Slice | Only writer |
| --- | --- |
| `meta` (all of it except `gameSeconds`) | `Save` |
| `regions[]` counts | `Ecology` |
| `tribes[].stock` | `Economy` |
| `tribes[].population`, `.news`, `.surnames`, `.chiefId` | `Population` |
| `tribes[].type`, `.sizeTier`, `.walled` | `Save` (written once at generate, never after) |
| `people`, roles, succession | `Population` |
| `villages[].roster`, `.bank` | `Population` |
| `groups[]` from/to, pos, carry, morale, members | `Bands` |
| `groups[].memory`, `villages[].memory`, player `rep`, grudges | `Standing` |
| player `inv`, `coin` | `Economy` (the inventory slice; not its own module) |
| player `pos`, `rest` | `Bodies` |
| player `goalStage`, `flags`, `lastSeenDay` | `Progress` (a slice of `Standing`; not its own module) |
| `mapDiff`, tile mutations | `Tiles` |
| `camps`, `bags` | `Tiles` |
| entities, positions, occupancy | `Bodies` |
| `calamity`, `meta.gameSeconds` | `Calendar` |

**`Bands` must never recreate a group row wholesale.** `makeGroup` does today, so a replenish after losses would
wipe `memory` that `Standing` owns. Grow and shrink rows; never replace them.

**R3. Systems ask, they do not reach.** `Economy.deposit(tribe, goods)`, not `t.stock.hide += n`. The call is the
contract, and the place for a log line, a test, or a save-dirty flag. Deliberately **not** an ECS or a message
bus: the failure mode here is unclear ownership, not too little indirection.

**R4. Derived data is never stored.** The map comes from the seed. A family comes from person fields. "What this
tribe thinks of you" is `Witness.feel(...)` over stored numbers, not a cached matrix.

**R5. Stored time is game time; stored links are ids.** Two save-blockers, both live in the code today:

- **`os.clock()` restarts near zero on a new server.** `S.dayStart` (`Sim.lua:1548`), `camps.litUntil` (`:1286`),
  `bags.droppedAt` (`:841`), `groups.pauseUntil` (`:416`), `replenishAt` and `retreatUntil` are all `os.clock`
  based and all sit in tables the tree must persist. Loaded fresh they are garbage: every campfire out, every bag
  an hour old, every group paused forever. **Every persisted instant is an in-game day plus fraction; every
  persisted duration is remaining seconds, rehydrated on load.**
- **The clock itself must stop reading wall time.** `Sim.clock()` (`Sim.lua:73`) *derives* the day from
  `os.clock() - S.dayStart`, so catch-up cannot advance the calendar at all: there is no wall time to point at.
  It becomes an accumulator — `meta.gameSeconds += dt` each tick, and catch-up adds a lump.
- **The tree holds ids, never references**, and every id read is nil-checked. `removeEntity` (`Sim.lua:168`) does
  not clear other entities' `npcTarget`, `threat` or `alarm.to` — survivable while entities are transient, fatal
  the moment an id is durable.
- **Durable id counters live in `meta` and are restored.** `nextId` is a file local starting at 0
  (`Sim.lua:42`) and issues both entity ids (`"e"..n`) and bag ids (`"b"..n`). Bags are persisted, and durable
  records hold entity ids: `person.entity = e.id` (`:317`) sits on a saved registry row, and `g.leader` holds one
  on a saved group row. After a restart the counter restarts, so a stale `"e7"` does not dangle — **it collides
  with a different new object**, which a nil-check cannot catch. Entity ids are therefore never persisted at all,
  and bag ids get their own counter in `meta`. The **full clear-list on save** is `person.entity`, `g.entities`,
  `g.leader`, `g.target`, and — the three round 2 missed — **`t.guard`, `t.merchant`, `t.survivor`**, which
  `initTribes` writes onto the durable tribe row from `spawnPerson`'s return (`Sim.lua:369, 380, 391`), and
  which `Interact.lua:52, 221` reads back to find the survivor to talk to and the merchant to trade with. They are
  re-pointed by step 1b's `restore`, not loaded. `Families.Registry.nextId` already persists with the registry;
  it is listed in `meta` as `nextPersonId` only so every counter is in one place.
- **The RNG is state.** `rng` is a file local seeded from the world seed (`Sim.lua:1547`) and `Rng` is one
  number. Without `meta.rngState`, every restart replays the same stream: the same names, the same conceptions.
- **`os.time` is the one permitted wall-clock read, and only at load.** Banning wall time outright leaves catch-up
  with nothing to measure the gap against: the world has to know how long it was down. `meta.savedAt = os.time()`
  (UNIX epoch, stable across servers and restarts, unlike `os.clock`) is written on every save; on load,
  `os.time() - meta.savedAt` is the elapsed real seconds that becomes `gameSeconds`. Nothing else in the codebase
  reads a wall clock into anything durable — `Movement.newBudget(os.clock())` stays, because a per-tick movement
  budget is transient by definition.

---

## 4. The module map after

Shared stays as it is — 18 files, median 80 lines, mostly pure Luau — **except `WorldGen.lua` at 877 lines**,
which is split into generate / query / encode before part 2, because `encode` *is* the save format.

```
server/
  Map.lua          the generated map: init, get, walkable, encoded  (exists as World.lua, 37)
  Save.lua         the tree: load, save, migrate, catch-up. Owns `meta`.    ~200
  Calendar.lua     day, clock, calamities                                  ~120
  Bodies.lua       entities: spawn, move, occupancy, replication, wildlife  ~300
  Brains.lua       the think dispatcher, the AI states, targeting          ~250
  Fighting.lua     damage, death, loot, break points                       ~250
  Bands.lua        groups: routes, materialise/collapse, carry, members    ~200
  Tiles.lua        runtime tile changes, the map diff, camps and bags      ~150
  Population.lua   people, families, roles, succession                     ~150
  Economy.lua      stock, prices, deposits, the player inventory slice      ~80
  Standing.lua     reputation events; later gossip and grudges             ~150
  Sides.lua        who takes whose side                          (exists, 278)
  Interact.lua     the F key                                      (exists, 341)
  Debug.lua        the test console                               (exists, 214)
  Sim.lua          the tick loops and nothing else                         ~150
```

**The name `World.lua` is already taken, so the new module is `Save.lua`.** `server/World.lua` exists today (37
lines: `World.init/get/walkable/encoded`, holding the generated map, required by `Server.server.lua:11` and
`Sim.lua:27`). Two modules called "world" — one holding the map, one holding the World Record — breaks H3 before
a line is written, so **step 0 renames the existing file to `Map.lua`** (two require sites) and the tree lives in
`Save.lua`.

Budgeted so headers and boilerplate do not push a module through the 400 ceiling. Two earlier entries are gone:
`Wildlife` (80 lines) folded into `Bodies`, because a module that is 20% header is not worth the hop, and
`Targeting` folded into `Brains`. `Brains` is budgeted at **250, not 350** — the earlier pair of numbers said
"split when it passes 250" about a module estimated at 350, which is an instruction to split it on day one. 250
is the target; if the real carve lands over it, `Targeting` comes back out, and that is a measurement, not a
guess.

---

## 4b. The codebase has a second reader, and it has a context window

Claude writes most of this (Danzo, 2026-09-18: *"your coding this and your context matters"*). A 1,617-line file
costs ~20k tokens; a session that opens three has spent its budget before changing anything.

**H1. A hard ceiling of 400 lines, target 250** — a check that fails `npm test`, not a guideline. Generated files
exempt. Line count is a proxy; if it ever disagrees with real cost, add "and no file over ~6k tokens". **Every
allow-list entry names the step that deletes it**, so the list cannot become permanent:

| Violator | Lines | Cleared by |
| --- | --- | --- |
| `Sim.lua` | 1617 | steps 2-4 |
| `WorldGen.lua` | 877 | step 5 |
| `Hud.lua` | 1021 | **rung 3 part 5** (the client split; the trade window is already its own screen) |
| `Client.client.lua` | 653 | **rung 3 part 5** |
| `Viewport.lua` | 429 | **rung 4**, or never — it is 29 lines over and one job |

The client three are deferred on purpose: this plan is about the server tree, and touching the client mid-refactor
doubles the QA surface for no save benefit. But they are dated, not exempt.

**H2. The first fifteen lines say what the file owns** — its job, its slice, what it deliberately does not do.

**H3. One job per file, and the filename is the job**, so a task maps to a file before anything is read.

**H4. Plain `require` by default; `bind(ctx)` only for a genuine cycle.** `bind` was invented to break a cycle
with a god object and it costs real safety: `Sides.bind` takes an untyped `ctx` into a row of `any` locals in a
`--!nonstrict` file, so there is no go-to-definition and `luau-analyze` cannot see a typo. Once `Sim` is only the
tick loops, siblings require each other directly. Keep `bind` for the one mutual pair (`Brains` ↔ `Fighting`).

**H5. Tests are the cheap way to read a rule.** `witness.test.luau` states every side-taking case in assertions;
reading it is faster and less ambiguous than reading thresholds, and it cannot drift.

**H6. `roblox/src/server/README.md`: one line per module** — what it owns, how big — updated in the same commit
as any move. Read first, every session.

**H7. Greppable, stable names.** `Economy.deposit`, not `handle`/`process`/`update`.
`/usr/bin/grep -rn "Economy\."` should list a module's whole public surface without opening it.

**H8. One worked example per module header.** A two-line "the call that matters looks like this" is worth more
than a dependency list, because it shows the shape of correct use.

**H9. New logic goes in `shared/` as pure Luau unless it touches a Roblox API; `server/` modules are thin
adapters.** This is the rule that lets the model check its own work without Studio — `npm test` can only bundle
`shared/` (`test/luau/run.js:12`). `CLAUDE.md` already requires it of `shared/`; the plan's `Population`,
`Economy` and `Standing` all sit on pure cores that already exist (`Families`, `Trade`, `Reputation`, `Witness`).

---

## 5. Not blowing up the machine

### The 4 MB key

The first draft warned about the wrong table. `Families.MAX_PEOPLE = 9` caps the **living per tribe** —
`weeklyConceive` filters by tribe, not village, which is identical today at one village per tribe and wrong the
moment §8 Q4's answer lands — so the registry grows at the *death* rate, not the birth rate. A full person record is ~274 B of JSON, pruned ~71 B:

- 4 MiB ÷ 274 B ≈ **15,300 full records**; pruned, ≈ **59,000**.
- At roughly one death per in-game day (600 s), 15,300 days ≈ **106 real days** of continuous simulation.

**People are not the thing to watch. Memory per holder, per player, is.** Rung 3 part 3 puts gossip memory on
villages and groups: 3 villages + up to 40 groups ≈ 43 holders. At 5 entries × ~60 B that is **~13 KB per player
ever seen**, and 300 lifetime players ≈ 3.9 MB. The key dies of gossip, not of the dead.

What prevents it:
- **A holder's memory is capped per player, not globally.** A flat "N most recent" forgets a quiet player the
  moment a busy one turns up, which guts the feature. Instead: up to ~3 entries per (holder, player), with an LRU
  over at most ~32 remembered players per holder. 43 holders × 32 players × 3 entries × ~60 B ≈ **242 KB** —
  bounded, and it still remembers you.
- **Per-player standing and grudges live in that player's own key** (DESIGN §14 already saves player state
  separately). The world key holds what *places and parties* remember; the player key holds what the player
  carries.
- `people` is a versioned sub-table, so it can be lifted into its own chunked key later without touching the rest.

### CPU

The first draft over-claimed a spatial index. DESIGN §4 caps materialised entities at 60 NPC + 40 animal, so
`Sides.witnessed` sweeping ≤100 cheap `cheb` comparisons per blow is microseconds. Of the eight `Sim.lua` sweeps
only four are radius queries; the fold-back sweep, the flood sweep and **the 10 Hz think loop — the actual
dominant cost — must touch every entity anyway**, and an index does not help them.

So **the index is demand-driven**: built when a measurement says a query is hot, not on faith. The design is
sound when wanted — a 3×3 block of 16-tile regions covers any radius ≤ 16, which is what `nearestArmedKin` (16)
and `witnessed` (8) need.

Rung 4's real answer is the tiering DESIGN §4 already describes: distant groups stay abstract and never
materialise, and a far village ticks once a day. That, not an index, is what buys hundreds of NPCs.

---

## 6. How we get there without stopping the game

A strangler, not a rewrite. Each step is its own PR and leaves the game playable. **Every step names its gate**,
because they are not the same gate: `npm test` can only bundle `shared/` (H9), `lint` covers every file, and
some behaviour can only be checked by pressing Play — which a cloud session cannot do (CLAUDE.md), so a
Studio-gated step is one a local session on Danzo's PC has to finish.

### The mechanics of moving code, already proven here

Splitting `Sides.lua` and `Debug.lua` out of `Sim.lua` worked, and it worked a particular way:

- **Move text verbatim first, rename after.** Mixing a move with a rewrite turns a refactor into a bug hunt.
- **Watch for bare calls to moved locals.** A `local function canFight` that becomes `Sides.canFight` leaves
  callers saying `canFight(...)` — `nil` at runtime and **silent** until that branch runs. The linter flags the
  unused definition, not the broken call. After every move:
  `/usr/bin/grep -n "[^.a-zA-Z_]name(" roblox/src/server/*.lua`, then start Play and read the Output.
- **Definition order is load-bearing.** A helper used at line 400 and defined at line 900 is a nil global;
  `luau-analyze` calls it `LocalShadow`, which reads as harmless and is not.
- **One module per PR**, so a bisect lands on one move.

### The steps, in dependency order

**Step 0 — the ceiling, the index file, and the rename.** `npm test` gains a check failing any non-generated
`.lua` over 400 lines, landing with the H1 allow-list that later steps delete entries from — a refactor with a
progress bar. Rename `server/World.lua` to `server/Map.lua` (two require sites: `Server.server.lua:11`,
`Sim.lua:27`) so `Save.lua` can have the name. Write `roblox/src/server/README.md`.
**Gate:** `npm test` + lint.

**Step 1 — make the tick pure over records, fix game time, and land the serialiser.** *The step part 2 cannot
start without, and the review found every half of it is broken today.*
- **Births only half-happen when nobody is watching.** `tickFamilies` (`Sim.lua:1451`) completes a birth only
  `if me` — if the mother is materialised. With no players, `Families.daily` adds the baby to the registry while
  `t.population`, `t.news` and the baby's body are skipped, and `weeklyConceive` mutates regardless. Catch-up
  would produce a registry that disagrees with the population it is meant to explain.
- **Every persisted timer moves to game time** (R5): `dayStart`, `litUntil`, `droppedAt`, `pauseUntil`,
  `replenishAt`, `retreatUntil`. **Including the three in `Debug.lua`** — `night`, `jump` and `day` each set
  `S.dayStart = os.clock() - …` (`Debug.lua:69, 75, 79`). They are the commands QA uses to reach a calamity, so
  breaking them silently costs a round; and `Debug` writing the clock at all violates R2, where `Calendar` owns
  `meta.gameSeconds`. They become `Calendar.setDay(day, frac)` calls.
- **Both ticks land in `shared/` as pure functions over the tree** — the daily tick *and* the 1 Hz abstract group
  advance (`tickGroups`, `Sim.lua:542`). Catch-up is specified as one step per in-game hour so that caravans
  arrive (DESIGN §14, RUNG3 part 2); if group movement stays in `server/`, step 6 can advance the calendar and
  still leave every caravan where it stood. So catch-up replays **hourly: groups; daily: ecology, families,
  economy**. This is also the only way the verification can run: `test/luau/run.js:12` bundles **only**
  `roblox/src/shared/`, so a tick left in `server/Sim.lua` cannot be covered by `npm test` at all and the plan's
  own "ends green" gate would be a fiction.
- **`shared/Save.lua` lands here, not in step 6** — `encode`/`decode` plus the R1 round-trip assertions — because
  steps 1 and 1b are *verified by a serialiser that would not exist yet*. "Two consecutive boots do not grow the
  registry" needs a save and a load. It is pure Luau over the tree, so it belongs in `shared/` (H9) and every
  later step can round-trip in `npm test` for free.
- **Verify:** run 28 simulated days with zero entities and assert registry, `t.population` and region counts
  match a run of the same 28 days with a player present; assert a 28-day run advances group `pos` identically
  whether it is replayed hourly or ticked live; assert two consecutive boots do not grow the registry; assert
  `decode(encode(tree))` deep-equals the tree, with no function, Instance, cycle, `inf`, `NaN` or numeric key.
  The "no persisted field came from `os.clock`" rule is **a lint check in `tools/luau-check.js`**, not a test
  assertion — a Luau test cannot see where a number came from, but a grep for `os.clock` outside an allow-list
  of transient call sites can.
**Gate:** `npm test` + lint. No Studio needed, which is the point of putting it in `shared/`.

**Step 1b — give `init` a restore path.** Today `initTribes` (`Sim.lua:349`) calls `Families.newAdult` for every
roster slot on **every boot**, and `initGroups` rebuilds `S.groups` from scratch. Bolt a load onto that and the
registry gains ~27 duplicate people per restart. Every constructor splits into `generate` (first boot, no save)
and `restore` (rehydrate bodies from records). `restore` is also what re-points `t.guard`, `t.merchant` and
`t.survivor` at the newly spawned entities, since R5 clears them on save. This is small, and part 2 is
meaningless without it.
**Gate:** `npm test` (the two-boots assertion) + Studio, to confirm the village still populates on a cold start.

**Step 2 — carve `Calendar`, `Tiles`, `Bands`.** Small, low-traffic, obvious seams, one PR each; proves the
pattern.
- **`Bands` also gives groups real members.** `g.members` is a list of anonymous specs (`{kind="hunter"}`) and
  `materialise` re-rolls names from `Names.person` every time, so the same squad is different people on every
  materialisation. Rung 3 part 3 ("four witnesses who will be home tonight") and part 4 (the player as a member)
  both need stable identity: members become person ids, plus `{ player = userId }` as the one other member kind,
  and `materialise` skips members who are offline.
- **Verify:** a squad completes a round trip and deposits; a calamity fires on schedule; wolves appear at night —
  behaviours parts 1 and 1b already proved — and a squad that collapses and re-materialises is the same four
  people.
**Gate:** `npm test` + lint for the pure cores and the round trip; **Studio** for the behaviours, because a
squad's round trip cannot be observed outside Play. A cloud session can write this step but not close it.

**Step 3 — carve `Fighting`, `Brains`, `Bodies`.** The big ones, once the pattern is proven.
**Verify:** the part 1 QA script — welcome village defends, wary village watches, predation, band retreats at
half — written down as a regression script, because not breaking it is the whole claim.
**Gate:** `npm test` + lint, then **Studio** for the script. This is the step most likely to break something
silently (§6's bare-calls-to-moved-locals), so the Output window is not optional here.

**Step 4 — name the owners (R2/R3).** The only step that changes call sites rather than moving them. `Economy`
first (smallest surface, and rung 3 part 5 leans on it), then `Standing`, then `Population`. **The proof a slice
is owned:** grep for direct writes outside the owner, expect zero, and put that grep in the PR description.
**Gate:** `npm test` + lint + the grep. Studio for a smoke test only.

**Step 5 — split `WorldGen.lua`** into generate / query / encode, because `encode` is the save format and should
not be buried in an 877-line file. **Gate:** `npm test` + lint — `WorldGen` is pure and already covered.

**Step 6 — rung 3 part 2** writes and reads the tree; catch-up replays the now-pure ticks (hourly groups, daily
everything else) against the gap `os.time() - meta.savedAt` gives it. **Gate:** `npm test` + **Studio**, and the
Studio half is the real one: a save, a server restart and a rejoin.

**The load order is fixed, and it is not obvious.** Round 2's "`mapDiff` records EVERY runtime tile change"
collides with the calamity system, which is the fifth save blocker: `setFlood` (`WorldGen.lua:778`) stashes the
tiles it overwrites in `world.floodBackup`, an in-memory table that is not in the tree, and `endCalamity`
(`Sim.lua:1420`) restores from it. Persist flood tiles into `mapDiff` and the backup is gone; recompute the list
on load and you get a *different* list, because `floodTiles` skips tiles that are already flooded
(`WorldGen.lua:762`). Either way `clearFlood` cannot undo it and **the world stays flooded forever**. So:

1. Regenerate the map from `meta.seed`.
2. Apply `mapDiff` — which **excludes calamity tiles**; it is every *durable* runtime change (bags, campfires,
   pickups, player-caused edits).
3. Re-apply the active calamity from `calendar.calamity.kind` **last**, over the restored map, rebuilding
   `floodBackup` exactly as a live `startCalamity` would.

The overlay is derived (R4) and costs nothing to recompute; the backup never needs persisting because it is
always the layer directly under the overlay.

**The cross-key rule, which rung 3 part 4 needs.** A player who joins a caravan is a member of a group row in the
world key while the player lives in their own key, and the two are written on different schedules (world every
two minutes, player on leave) with no transaction — and a second server diverges by design (DESIGN §14). So:
**the world key is authoritative for membership.** The player key stores only `lastGroupId` as a hint, which is
revalidated against the world key on join and discarded on mismatch. Group ids are already stable strings
("caravan", "squad", "band"), so revalidation is a lookup, not a search.

**The index is not a step.** It is built when a measurement says a query is hot.

| Step | Size | Risk | Gate | Buys |
| --- | --- | --- | --- | --- |
| 0 ceiling, index file, `World`→`Map` | tiny | none | test + lint | a progress bar; the ceiling stops being optional |
| 1 pure ticks + game time + `Save.lua` | large | medium | test + lint | **part 2 becomes possible at all** |
| 1b restore path | small | low | test + Studio | a restart stops duplicating the village |
| 2 carve three | medium | low | test + Studio | the pattern proven, stable group members, Sim sheds ~400 lines |
| 3 carve three | large | medium | test + Studio | Sim becomes the tick loops |
| 4 owners | medium | medium | test + grep | "systems ask, they do not reach" becomes true |
| 5 split WorldGen | small | low | test + lint | the save format is readable |

**Escape hatch:** steps 0, 1, 1b and 5 are independently valuable and can ship even if 2–4 are judged not worth
the churn. **Steps 1 and 1b are the only ones that are not optional** — 1b was small enough to fold into 1 until
round 3 pointed out that both are verified by a serialiser, which is why step 1 now carries `Save.lua` and is the
largest single step in the plan. If it wants splitting, the seam is: 1a game time + the two pure ticks,
1b `Save.lua` + the restore path.

---

## 7. What this costs, and what could go wrong

- **A lot of moving with no new gameplay.** Mitigated by ordering: step 1 is a bug fix part 2 needs regardless.
- **Churn against a live QA history.** Every refactor PR runs the loop, because "nothing regressed" is the claim.
- **Over-abstraction.** The honest risk is building a framework for three villages. R3 is the lightest thing that
  fixes the real problem; if a rule is not paying, drop it.
- **The save format is a commitment.** Once there are saves, the tree's shape is load-bearing — which is exactly
  why this comes before part 2.

---

## 8. Open questions

Settled by review, recorded so they are not re-litigated:

1. **One tree or a separate people key?** One tree, with `people` versioned as its own sub-table so it can be
   lifted out later. Player state gets its own key from day one, per DESIGN §14.
2. **Named owners, or queued intents?** Owners are enough; contention is already handled by the
   `busy`/`nextWitnessAt` guards. What was missing was reference hygiene, now R5.
3. **Is a family a group?** No — a derived index over person fields.
4. **Villages under tribes, or their own tier?** Their own tier, keyed by id with `tribe` as a field. Rung 4 gives
   a tribe several villages, and a per-tribe `MAX_PEOPLE` would starve all but one.
5. **Entity budget?** ~100 by DESIGN §4's cap. What scales is players × entities and the 10 Hz think loop;
   rung 4's answer is §4's tiering, not an index.
6. **Does catch-up work on the tree?** Not today — step 1 is what makes it true.
7. **Is 400 the right ceiling, and does shared obey it?** Yes and yes; `WorldGen.lua` is step 5.

Answered in round 2:

8. **What must catch-up record?** A capped world-level headline ring, not a per-player diff — the latter is
   exactly the per-holder-per-player growth §5 warns about. `meta.headlines[]` of `{ day, kind, subjectId }`,
   64 entries ≈ 2.5 KB; the player key stores `lastSeenDay`; the "you were gone eleven days" line is built at
   join from headlines newer than that, filtered to tribes the player has standing with. `tribes[].news` is this
   idea already, un-generalised.
9. **Is DataStore denser than JSON?** No. The value is serialised to JSON and the 4 MB limit is measured after
   serialisation, so there is no free win — and a sparse numeric map becomes string keys (`"9216":12,` is 10 B,
   `"123":5,` is 8). Density has to come from our own packing: `WorldGen.encode`'s `packBytes` already gets tiles
   to ~1 B each, and the same trick on the diff gives ~4 B an entry. Budget in JSON bytes, as §5 does. **The
   correctness half of this fact is the bigger one and §2 now carries it: string keys are not a rounding detail,
   they silently detach the family tree.**
10. **The real death rate?** Below the assumption, so the arithmetic is safe. Only registered villagers enter the
    registry (group members and animals never do), refill is birth-only, and with a 0.5 conception chance per
    couple per weekly roll, ≤4 couples a village and 3 villages, that is ≤ ~0.9 births per in-game day sustained.
    ~15,300 records ÷ 0.9 ≈ 17,000 in-game days ≈ **118 real days**. A massacre is a burst, not a rate.

Answered in round 3:

11. **How does catch-up know how long it was down?** `meta.savedAt = os.time()`, and `os.time` is the single
    permitted wall-clock read, at load only (R5). Banning wall time outright left the gap unmeasurable.
12. **Is `groups[].route` stored?** No — derived (R4). `from`/`to` are stored, the route is recomputed by
    `WorldGen.route` on load, and `pos` is clamped to the new length. At 55-62 tiles and ~900 B a route, storing
    40 of them would be ~36 KB of the key for something the seed already determines. The risk this accepts: if
    `WorldGen.route` ever changes, a loading caravan teleports to the nearest point on its new road. That is a
    visible, harmless one-off; a stale stored route against a changed map is neither.
13. **Where does the player inventory live, and who owns it?** The player's own key, owned by `Economy` as a
    slice — there is no `Inventory` module. R2 named one for two rounds and §4 never listed it.
14. **Which of the five allow-listed big files does this plan actually fix?** `Sim.lua` (steps 2-4) and
    `WorldGen.lua` (step 5). `Hud.lua`, `Client.client.lua` and `Viewport.lua` are client files, dated to rung 3
    part 5 and rung 4 in H1, and deliberately untouched here: this plan is about the server tree, and opening the
    client mid-refactor doubles the QA surface for no save benefit.
