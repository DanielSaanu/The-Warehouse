# People, villages, farms, wildlife

**What it does.** Three tribes (farmers, hunter-gatherers, plunderers; DESIGN §5) live in villages. Every person
is a record with parents, a birth day and a death. Couples conceive about once a week, and villages refill by
births only. Farms feed a village by counting its living adults. Groups (a caravan, a hunting squad, a bandit band)
walk routes between villages. Wildlife is counts per region: grass, deer, boar and wolf.

**Key modules**
- `shared/Families.lua` handles couples, conception, births, growing up, death and successors.
- `shared/Farms.lua` holds the farm rule over records. Plot growth is saved; plot positions come from the map.
- `server/Villagers.lua` holds a villager's day: out to a plot, home at night, home at a run from wolves. This is
  what you watch, not a rule, so it changes no number.
- `shared/Ecology.lua` holds the daily herbivore/predator tick, drift between regions, and the edges "breathing".
- `server/Bands.lua` handles groups as records with a route. Near a player (materialised) they're entities
  walking the route. Collapsed, only `pos` advances (`Tick.groups`). Materialised, the leader's route rule is
  `Tick.leaderStep` (pure, tested): `pos` moves only when the bodies do, and a leader that cannot get back to the
  road is reported "lost" and the group collapses (H6).
- `server/Ride.lua` + `shared/Belong.lua` (rung 3 part 4): a player rides with a group as SCRATCH (`g.riders`,
  `ps.ride`), never as a `members` row and never saved (learnings S7, ARCHITECTURE §13). The leader waits up to
  `Belong.WAIT` s a leg for a rider more than `Belong.LAG` tiles behind; a rider's kill goods go into `g.carry`.

**Tunables:** `MATERIALISE_RANGE`, `COLLAPSE_RANGE`, `SQUAD_LOAD`, `FED_SECONDS`, `FED_HUNTER`, `BAND_RETREAT`,
`GRACE_DAYS` and `CAMPFIRE_RADIUS` in Config. Size tiers are in DESIGN §5.

**Gotchas**
- A world is built by exactly ONE of `Sim.init` (new) or `Restore.apply` (loaded). Running both duplicates every
  villager.
- Records must finish their work whether or not anyone is watching: a birth raises the population even if the
  mother has no body right now.
- `homeTile` and `workTile` are scratch on the entity, never saved.
- Anything new that joins a group: check every reader of `g.members` first (materialise, the daily refill, the
  band's break all count it as people) (→ S7).

## Expansion: deficits at scale

Notes from 2026-10-05, for rung 4 (more map, several villages per tribe, many more NPCs). Not decisions.

- **Villages are always materialised.** `server/Sim.lua:276` (`initTribes`) gives every living villager a body,
  and the 10 Hz loop (`Sim.lua:1208`) thinks for every entity. Soft limit: the entity budget is ~100
  (`docs/architecture/decisions.md:25`), and no code enforces it or DESIGN §4's 60 NPC / 40 animal / 40 group
  caps. Nine villages of ~18 is ~160 bodies before any group or animal. Probably villages materialise and collapse
  near players the way groups do.
- **A tribe is one village.** `Families.lua:20` caps per tribe type, `Families.villagers` (`:74`) and
  `Farms.workers` (`Farms.lua:62`) filter by tribe, `Villagers.site(i)` (`Villagers.lua:33`) and
  `Gossip.villageKey(tribeIdx)` (`Gossip.lua:42`) key by tribe index, and `Sim.lua:285` sets `S.tribes[i]` and
  `S.villages[i]` from the same `i`. Hard limit: a second village per tribe shares one cap, one farm site and one
  gossip key. decisions.md:23 already says the cap must become per village; probably everything here keys by
  village id.
- **Fixed group ids.** `Bands.lua:83-104` makes exactly `"caravan"`, `"squad"`, `"band"` from `villages[1..3]`;
  `Interact.lua:43` reads `S.groups.band`, `Debug.lua:188` defaults to it, `Tick.lua:51` (`fullCrew`) hard-codes
  3 / 4 crew by kind. Hard limit: one group of each kind in the world. Probably ids built from village + kind + n,
  and crew size from the tier table (DESIGN §5).
- **Full registry scans.** `Families.lua:76, 136, 149, 186` and `Farms.lua:64` walk every person ever born,
  dead included, and `Tick.families` (`Tick.lua:30`) runs them per tribe per day. Soft limit: cost is tribes x
  registry, the registry never shrinks (the pruned dead stay), and catch-up repeats it 28 times. Probably a
  living-by-village index.
- **The 4 MB key.** `docs/architecture/modules-and-limits.md:65`: ~15,300 records, ~106 real days at one death a
  day. Hard limit, and deaths scale with the living: ten times the people is roughly a tenth of the runway (a guess
  at linear). Probably `people` lifted into its own key (decision 1 already allows it).
- **Population ceiling of 60.** `Tick.lua:76` (`math.min(60, ...)`) and the per-type `ROSTER` (`Sim.lua:270`).
  Tuning numbers, but hard-coded: DESIGN §5's large tier is 100+. Probably from the tier.
- **Villager danger check scans every entity.** `Villagers.lua:72` per villager think (~every 0.8 s). Soft:
  villagers x entities. Probably a nearby-only query (regions or the occupancy grid).
- **Six beds per hut door.** `Villagers.lua:52` (`DOOR_SPREAD`). Tuning: more people than 6 x huts stack on the
  same tiles and re-path all night (a guess from the comment there).
- **One-off scans at world build.** `forestTarget` (`Bands.lua:48`) runs a full-map `WorldGen.reachable` flood
  and an unbounded route per region; `Tick.rebuildRoute` (`Tick.lua:94`) runs an unbounded A* per group on
  create and on every restore. Soft: regions x tiles grows with the square of the map side.
- **Catch-up is per second x every group.** `Tick.lua:230`. Measured 3 ms at 3 groups (`as-built.md:27`); 40
  groups plus the registry scans could reach the ~50 ms slicing line (`modules-and-limits.md:89`). Guess: linear.
- **Line ceilings and pinned tests.** `Sim.lua` is 1254 lines against its 1255 ceiling (`test/structure.test.js:20`),
  so any population code added there fails H1 until Track B carves it. `test/luau/worldgen.test.luau:48` pins
  `#world.villages == 3`.

Measure first: live entity count and 10 Hz loop ms with several villages materialised; catch-up ms at the cap with
~40 groups and a year-old registry; save-key bytes per in-game day at the new population.
