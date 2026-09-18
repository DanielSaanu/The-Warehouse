# server/ — one line per module (docs/ARCHITECTURE.md H6)

Read this first. Update it in the same commit as any move. Sizes are line counts, rounded.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | remotes, player join/leave, the movement handler | 190 |
| `Map.lua` | the generated map and `Map.encoded` (what joining clients are sent). Was `World.lua` | 40 |
| `Calendar.lua` | `meta.gameSeconds`, the ONE clock: `now()`, `clock()`, `setDay()`, `skipTo()`, `advance()` | 60 |
| `Sim.lua` | everything else, for now: entities, AI, fighting, groups, camps, calamities, the tick loops | 1620 |
| `Sides.lua` | who takes whose side in a fight | 280 |
| `Interact.lua` | the F key: talk, trade, rest, gifts | 340 |
| `Debug.lua` | the test console (Workspace attribute `Debug`) | 215 |

## Track A progress (the plan's save-critical steps)

- [x] **A0** guard rails: `test/structure.test.js` (400-line ceiling, `os.clock` allow-list), this file, `World`→`Map`
- [x] **A1** one clock: every sim timer is `Calendar.now()` game seconds; Debug `night`/`day`/`jump` only move forward
- [ ] **A2** pure ticks in `shared/Tick.lua`
- [ ] **A3** records and references (`villageId`, `ps.save`, calamity overlay split)
- [ ] **A4** `shared/Save.lua` + generate/restore
- [ ] **A5** `Persistence.lua` (rung 3 part 2)
