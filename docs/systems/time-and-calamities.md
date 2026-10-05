# Time, the tick and calamities

**What it does.** One game clock drives everything. One in-game day is `DAY_SECONDS` real seconds, and the last
`NIGHT_FRACTION` of it is night. Once a week there's a calamity (flood or beast tide), warned about the day before.
The world's daily and weekly work runs as pure functions, so the same code covers live play and catch-up.

**Key modules**
- `server/Calendar.lua` owns `meta.gameSeconds`, **the one clock** (ARCHITECTURE R5). `now()` folds wall time in 1:1.
- `shared/DayCycle.lua` holds the calendar and night maths shared by the server clock and the client tint.
- `shared/Tick.lua` holds the pure ticks: `daily`, `families`, `groups`, `catchUp`. They return events, and the
  server turns those into bodies, prints and notices.
- `shared/Calamity.lua` holds the weekly clock and `applyOverlay` (what a load re-lays).
- `server/Sim.lua` runs the tick loops, entities and AI. At 1274 lines it is the biggest file, and Track B carves it up.

**Tunables:** `DAY_SECONDS`, `NIGHT_FRACTION`, `NIGHT_RAMP`, `NIGHT_ALPHA`, `WEEK_DAYS` and `CALAMITY_START` in
Config. `Tick.CATCHUP_CAP` is four in-game weeks.

**Gotchas**
- Never stamp anything the world remembers with `os.clock()`: it restarts near zero on every server.
  `test/structure.test.js` enforces an allow-list.
- Anything that decays over longer than the catch-up cap must be a closed form over a day count (→ P2).
- Server `Debug` commands `night`, `day` and `jump` only move time forward.
