# server/ — one line per module (docs/ARCHITECTURE.md H6)

Read this first. Update it in the same commit as any move. Sizes are line counts, rounded.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | remotes, player join/leave, the movement handler | 190 |
| `State.lua` | the ground everything stands on: `State.state` (the World Record), tile occupancy, the two remotes, and the client-facing helpers (`notice`, `text`, `hud`, `broadcastEntity/Object`, `restText`) | 90 |
| `Tiles.lua` | camps and bags, and every runtime write to the map's object layer: `placeCamp`, `dropBag`, `takeBag`, `tick`, `stampAll`/`unstampAll` | 145 |
| `Map.lua` | the generated map and `Map.encoded` (what joining clients are sent). Was `World.lua` | 40 |
| `Persistence.lua` | the ONLY DataStore code: `loadWorld`, `saveWorld`, player keys, autosave, the policy (never write a key you failed to read; one server holds the lease) | 170 |
| `Goals.lua` | the goal line under the clock: `set`, `clear`, `rebuild`, `tick` (carved verbatim out of Sim when it hit its ceiling) | 65 |
| `Calendar.lua` | `meta.gameSeconds`, the ONE clock: `now()`, `clock()`, `setDay()`, `skipTo()` (catch-up adds its lump to `meta.gameSeconds` directly, in `Tick.catchUp`) | 60 |
| `Restore.lua` | `Sim.state` <-> a save: `snapshot()`, and `apply(data, slept)` = the RESTORE constructor (bodies, routes, stamped tiles, overlay, `Map.reencode`) | 150 |
| `Sim.lua` | everything else, for now: entities, AI, fighting, groups, calamities, the tick loops | 1417 |
| `Sides.lua` | who takes whose side in a fight | 280 |
| `Villagers.lua` | a villager's day: out to a plot in the morning, home to a hut door at night, home at a run from wolves and strange bandits; scans huts and plots off the map. What the farms YIELD is `shared/Farms.lua` (pure, in `Tick.daily`, saved as `tribes[].plots`) | 130 |
| `Interact.lua` | the F key: talk, trade, rest, gifts | 340 |
| `Debug.lua` | the test console (Workspace attribute `Debug`) | 215 |

## Track A progress (the plan's save-critical steps)

- [x] **A0** guard rails: `test/structure.test.js` (400-line ceiling, `os.clock` allow-list), this file, `World`→`Map`
- [x] **A1** one clock: every sim timer is `Calendar.now()` game seconds; Debug `night`/`day`/`jump` only move forward
- [x] **A2** pure ticks: `shared/Tick.lua` (`daily`, `families`, `groups`, `catchUp`); Sim turns their events into bodies and prints
- [x] **A3** records and references: `t.villageId` + `Map.village(id)` (no live village tables), `Person.village` is an id,
      `Calamity.applyOverlay` (what a load re-lays) split from `startCalamity` (the one-time half), `Ecology.wolfSurge` /
      `setTide`, bags have their own saved counter (`meta.nextBagId`)
- [x] **A4** `shared/Save.lua` (encode / decode / check / gravestones / players) + `Restore.lua` (snapshot, apply).
      Debug `reload [seconds]` saves through real JSON and restores in place, sleeping that long first
- [x] **A5** `Persistence.lua` + the boot order in `Server.server.lua`. Debug `savetest [seconds]` runs save -> lease ->
      load -> restore against a store in memory. **The real DataStore needs Studio's Game Settings -> Security ->
      "Enable Studio Access to API Services"**; without it the server says so and runs NO-SAVE, by design

## After Track A

- [x] **Headlines**: `shared/Headlines.lua`, a 64-entry ring in `meta.headlines` (births from `Tick.families` - so catch-up writes
      them - deaths and calamities from Sim). A returning player gets "Welcome back / You were gone N days" plus up to three
      lines, from tribes that would tell them. Debug `welcome <days>` shows it on demand.

## After Track A, continued

- [x] **A villager's day and farms that grow** (2026-09-21): ported from the unpushed `world-up-close` branch, which built it
      before Track A existed, onto this layout: the rule is pure (`shared/Farms.lua`, counts living villagers, so catch-up farms
      too), the walk is a projection (`Villagers.lua`), plot growth is saved, plot positions are derived. Debug `farms` reports.
      Smoke-tested in Studio (work by day, home at night, a harvest, a flood); **no QA reviewer has looked at it.**

## Track B (carving Sim.lua) — started, then parked

- [x] **B1 (part)** `State.lua` and `Tiles.lua` carved out verbatim; `Sim.lua` 1570 → 1410, its ceiling 1580 → 1420.
      `State.lua` is the seam the rest of Track B needs: new modules `require` it instead of being handed a `ctx`
      through `bind()`, and it can never form a cycle because it requires only `Map` and `shared/`.
- [ ] **B1 (rest)** `Bands` (groups: materialise / collapse / members), the calamity half of `Calendar`.
- [ ] **B2** `Bodies`, `Brains`, `Fighting`. **B3** name the owners (R2/R3). **B4** split `WorldGen.lua`.

**Parked on purpose (Danzo, 2026-09-18): do not continue Track B without asking.** What is carved so far is tested
and smoke-tested in Studio but **no QA reviewer has looked at it** — run `/qa-loop` on it before building on it.
