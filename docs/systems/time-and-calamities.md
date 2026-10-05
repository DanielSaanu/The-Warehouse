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

## Expansion: deficits at scale

Notes for rung 4 (more villages, groups and people). Nothing here is decided.

- **Catch-up is seconds × groups.** `shared/Tick.lua:230-246`. Soft limit. It replays every one of 16,800 seconds
  (four weeks × 7 × 600) and walks every group each second. That is about 670k group steps at DESIGN §4's 40 groups,
  run in one go at load (`server/Restore.lua:174`) before anyone plays. Guess: fine at 40, slow at hundreds. Probably
  move a sleeping group by whole legs, or yield.
- **Catch-up keeps every event.** `shared/Tick.lua:245`. Soft limit. Four weeks of turns and deposits sit in one list
  just for the log. Probably count them instead.
- **The cap follows `DAY_SECONDS`.** `shared/Tick.lua:22`. Tuning number. A longer day makes catch-up dearer too.
- **Road meetings sort every group.** `shared/Gossip.lua:340-357`. Soft limit. Every 60 game seconds, live and in
  catch-up: all ids sorted, then pairs per 2×2 bucket. Probably fine; it grows with group count.
- **The daily tick touches every person.** `shared/Tick.lua:70-89`, `shared/Families.lua:134`. Soft limit. The
  registry only grows (DESIGN §4 data budget), the tick runs 28 times in a full catch-up, and live it runs inside one
  1 Hz frame (`server/Sim.lua:1235-1238`). Probably prune the dead first, or skip them.
- **Numbers buried in the tick.** `shared/Tick.lua:76` (population caps at 60) and `:51-54` (crews of 3 and 4).
  Tuning numbers. They ignore size tiers, so large tribes and big processions cannot exist. Probably move them to
  Config or the tier table.
- **`pairs()` over groups.** `shared/Tick.lua:79, 201`. Guess, unchecked: hash order can differ between runs, and
  `enlist` draws from the rng inside that loop. With more groups replenishing on the same day, live and catch-up
  could diverge. `Gossip.meet` already sorts for this reason.
- **One calamity for the whole world.** `S.calamity`, `shared/Calamity.lua:47-56`. Hard limit. A flood covers every
  river tile and a tide flags every region (`shared/Ecology.lua:149-150`). On a big map everyone floods at once.
  `startCalamity` walks every entity, player and tribe (`server/Sim.lua:1005-1040`), and the flood tile list goes
  to every client (`server/Server.server.lua:91`) and grows with the river. Probably regional calamities (a design question).
- **Fixed calamity flavour.** `shared/Calamity.lua:11` (two kinds), `:67, 74` ("from the north"). Tuning, but the
  north is only true of today's map.
- **Tide damage assumes one village per tribe.** `server/Sim.lua:1039` (`Map.village(t.villageId)`). Hard limit.
  A tribe with several villages is judged by one.
- **The 10 Hz loop thinks for every entity.** `server/Sim.lua:1205-1215`. Soft limit. Its cost follows the bodies,
  which DESIGN §4 caps at 60 NPCs and 40 animals. Check where those caps are enforced before adding more.
- **Line ceiling.** `server/Sim.lua` is 1254 lines against 1255 (`test/structure.test.js:20`). Hard limit. Its own
  startup print still says "3 groups" (`server/Sim.lua:1196`).

Measure first: `Tick.catchUp` ms for a full cap at the planned group count; one `Tick.daily` in ms with a registry
of a few thousand people; the flood tile count on the biggest planned map.
