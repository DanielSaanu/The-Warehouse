# World generation and the map

**What it does.** Grows one 96×96 tile world from a seed: noise for elevation and moisture, then a river and
lakes, then rocks, caves, forest and tall grass, then three villages stamped from ASCII templates, then roads
between them by A*. The server keeps one map per server and sends every joining client an encoded copy.

**Key modules**
- `shared/WorldGen.lua` generates, queries (`walkable`, `regionOf`, `villageAt`, `route`, `nearestWalkable`),
  floods and encodes the map. It is pure Luau, 879 lines, and sits on an allow-list ceiling.
- `shared/TileTypes.lua` defines the ground and object tiles. Ids are small integers, so a map is one byte per tile.
- `shared/Rng.lua` is a seeded xorshift32 and the only randomness source. `shared/Names.lua` makes people and place names.
- `server/Map.lua` holds the one `WorldGen.World` and `Map.encoded`. `Map.village(id)` looks up a village by id.

**Tunables** (`shared/Config.lua`): `WORLD_SEED` (0 = random each server), `WORLD_WIDTH`, `WORLD_HEIGHT`, `REGION`
(region size in tiles).

**Gotchas**
- The map is **derived, never saved** (ARCHITECTURE R4): a save stores the seed. Changing the generator means
  bumping `WorldGen.GEN_VERSION`, and that discards the saved world on load. Never bump it for anything else
  (→ learnings P3).
- `Map.village` throws before `Map.init` has run (→ T3).
- After touching WorldGen or tiles, run `npm run preview:world` and `npm run preview:view`, and LOOK at the PNGs.
- Camp and bag tiles on the object layer are written only by `server/Tiles.lua` ([talk-and-trade.md](talk-and-trade.md)).
