# server/ — one line per module (docs/ARCHITECTURE.md H6)

Read this first. Update it in the same commit as any move. Sizes are line counts, rounded.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | remotes, player join/leave, the movement handler | 190 |
| `Map.lua` | the generated map and `Map.encoded` (what joining clients are sent). Was `World.lua` | 40 |
| `Calendar.lua` | `meta.gameSeconds`, the ONE clock: `now()`, `clock()`, `setDay()`, `skipTo()`, `advance()` | 60 |
| `Sim.lua` | everything else, for now: entities, AI, fighting, groups, camps, calamities, the tick loops | 1570 |
| `Sides.lua` | who takes whose side in a fight | 280 |
| `Interact.lua` | the F key: talk, trade, rest, gifts | 340 |
| `Debug.lua` | the test console (Workspace attribute `Debug`) | 215 |

## Track A progress (the plan's save-critical steps)

- [x] **A0** guard rails: `test/structure.test.js` (400-line ceiling, `os.clock` allow-list), this file, `World`→`Map`
- [x] **A1** one clock: every sim timer is `Calendar.now()` game seconds; Debug `night`/`day`/`jump` only move forward
- [x] **A2** pure ticks: `shared/Tick.lua` (`daily`, `families`, `groups`, `catchUp`); Sim turns their events into bodies and prints
- [x] **A3** records and references: `t.villageId` + `Map.village(id)` (no live village tables), `Person.village` is an id,
      `Calamity.applyOverlay` (what a load re-lays) split from `startCalamity` (the one-time half), `Ecology.wolfSurge` /
      `setTide`, bags have their own saved counter (`meta.nextBagId`)
- [ ] **A4** `shared/Save.lua` + generate/restore
- [ ] **A5** `Persistence.lua` (rung 3 part 2)
