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
  walking the route. Collapsed, only `pos` advances (`Tick.groups`).

**Tunables:** `MATERIALISE_RANGE`, `COLLAPSE_RANGE`, `SQUAD_LOAD`, `FED_SECONDS`, `FED_HUNTER`, `BAND_RETREAT`,
`GRACE_DAYS` and `CAMPFIRE_RADIUS` in Config. Size tiers are in DESIGN §5.

**Gotchas**
- A world is built by exactly ONE of `Sim.init` (new) or `Restore.apply` (loaded). Running both duplicates every
  villager.
- Records must finish their work whether or not anyone is watching: a birth raises the population even if the
  mother has no body right now.
- `homeTile` and `workTile` are scratch on the entity, never saved.
