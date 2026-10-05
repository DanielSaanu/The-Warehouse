# Movement and combat

**What it does.** Tile-by-tile movement that the client predicts and the server validates. Fights are melee
swings with cooldowns and knockback, and NPCs telegraph their swings before they land. Onlookers take sides by
one rule: help the side you dislike less, if the gap is worth a fight.

**Key modules**
- `shared/Movement.lua` holds the step protocol and the pace budget. A step is charged the step time of the tile
  being LEFT.
- `shared/Combat.lua` holds damage, facing, knockback and loot, shared by the server (authority) and client (feel).
- `shared/Stats.lua` gives players, people and animals the same stat block.
- `shared/Witness.lua` holds the pure side-taking rule. `server/Sides.lua` applies it to the simulation.

**Tunables:** `MOVE_STEP`, `MOVE_SLACK`, `MOVE_BURST`, `ATTACK_COOLDOWN`, `HIT_INVULN`, `TELEGRAPH` and
`RESPAWN_SECONDS` in Config. Tile speed multipliers are in `TileTypes`.

**Gotchas**
- A rejected move snaps the player back and bumps `epoch`, so moves already in flight are dropped.
- `Sides`, `Debug` and `Restore` never `require` Sim: Sim binds itself into them in `init`. This avoids a require
  cycle and keeps Sim inside Luau's type-inference budget.
- Being killed costs no reputation. Reputation records conduct, not luck (DESIGN §7).

## Expansion: deficits at scale

Notes from 2026-10-05, for rung 4 (more map, more villages, many more NPCs). Not decisions.

- **Every hit sweeps every entity.** `server/Sides.lua:202` (`Sides.witnessed`), called per landed blow
  (`Sim.lua:513`, `Sim.lua:622`). Soft limit: a brawl of k fighters costs k x entities per swing window, so
  big fights in a crowded map go O(n²). Probably a nearby-only query around (x, y): region buckets or the
  occupancy grid.
- **Witnesses join first-come, not nearest.** `Sides.lua:213`: the first `WITNESS_JOIN` (3) in `pairs()` order
  within `WITNESS_RANGE` (8) act. Tuning numbers; in a dense village the three who pile in are arbitrary, not the
  closest. Guess that it will read wrong to a player; probably sort by distance once the sweep is local.
- **Target picking is O(n²).** `pickNpcTarget` (`Sim.lua:814`) does two full entity scans per armed NPC think,
  and chasers think every 0.15 s (`Sim.lua:1211`). Soft. `nearestArmedKin` (`Sides.lua:114`) is one more full
  scan per alarm. Probably the same local query.
- **Interest and broadcasts scale with players x entities.** `tickInterest` (`Sim.lua:981`) is players x
  entities every 0.25 s; `hit` and `die` go to every player on the server (`Sim.lua:593`, `Sim.lua:628`), not
  just those in view. Soft: bandwidth grows with players times fights.
- **Path budgets are fixed node counts.** `pathTo` default 400 (`Sim.lua:159`); 120 / 200 / 250 / 300 / 500 at
  `Sim.lua:673, 678, 780, 867, 902, 926` and `Sides.lua:290`; `Tick.LEADER_BUDGET` 200 / `LOST_BUDGET` 800
  (`Tick.lua:122`). Tuning numbers that do not grow with distance, and the 0.5-weighted heuristic
  (`WorldGen.lua:285`) expands more than the straight line. On a bigger map a scattered fighter's walk home (500)
  or a lost leader (800) fails more often and falls back to wander or collapse. Probably a budget tied to distance,
  or a coarse road graph for long trips.
- **Re-path churn.** Chasers re-path every 1 s (`Sim.lua:770, 858, 900`), and each A* allocates fresh
  `gScore` / `cameFrom` / `closed` tables (`WorldGen.lua:250`). Soft: GC pressure with many fighters (a guess;
  not measured).
- **Unbounded searches.** `WorldGen.route` without `maxNodes` (`Tick.lua:95`, `Bands.lua:40`) and the
  `WorldGen.reachable` flood (`WorldGen.lua:676`) cover the whole map. Soft: cost grows with the square of the
  map side.
- **One body per tile on one-tile roads.** The side-step in `followPath` (`Sim.lua:173`) handles one blocker. More
  traffic means more stand-offs on roads and at gates. Guess.
- **Feelings by tribe type, kin by tribe index.** `Witness.lua:20` (`TRIBE_FEELING`) and `Party` / `Seer`
  (`Witness.lua:40`) carry no village. Two farmer tribes like each other at 45; whether a second village of the
  same tribe is kin is unstated. A design question, not a bug yet.
- **`WorldGen.villageAt` is a linear scan.** `WorldGen.lua:811`, used by `Sides.sheltered` and animal spawns. Fine
  to dozens of villages.
- **Line ceilings.** `pathTo`, `followPath` and `pickNpcTarget` live in `Sim.lua` (1254 / 1255,
  `test/structure.test.js:20`); `Sides.lua` is 293 / 400. Any growth here waits on Track B.

Measure first: `Sides.witnessed` ms per call and 10 Hz loop ms at ~200 entities in one brawl; how often `pathTo`
returns false (and nodes expanded) on the bigger map.
