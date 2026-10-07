# World generation and the map

**What it does.** Grows one 256×256 tile world from a seed: noise for elevation and moisture with a lean per quarter
(fields south-west, forest east, hills north), then the river, lakes and marsh, then sixteen villages stamped from
ASCII layouts (three tiers per tribe, multi-tile halls and barns), fords, a road TREE between neighbours, the places
between villages (shrine, burnt village, ruined watchtower, abandoned camp, battlefield), caves, signs. The server
keeps one map per server and sends every joining client an encoded copy. Plan: `docs/plans/world-expansion.md`.

**Key modules** (all pure Luau; `WorldGen` re-exports every query under its old name, so callers never changed)
- `shared/WorldGen.lua` is the hub: the generation ORDER, `encode`/`decode` (one printable byte per tile, offset
  `WorldGen.OFFSET` = 33), `compass`, the flood overlay, `ascii`. `GEN_VERSION` = 2.
- `shared/Grid.lua` the tile grid: `walkable`, `nearestWalkable`, `villageAt`, `flood`, `reachable`, regions, and
  `Grid.place` (a multi-tile object by its ANCHOR, the bottom-left tile; the rest of the footprint is `part`).
- `shared/WorldLand.lua` noise, river, lakes, marsh, hills, forest; later the fords, caves and the wadeable river.
- `shared/WorldPlans.lua` pure data: the nine village layouts, the five place stamps, the legend, and `check`
  (a test proves every `=` belongs to exactly one footprint). Read this to see what a village looks like.
- `shared/WorldVillages.lua` placement (Danzo's sketch positions scaled to the map, nudged onto dry ground clear of
  other villages) and stamping. `villages[1..3]` are the farmers' town, the hunters' great lodge, the stronghold.
- `shared/WorldRoads.lua` A* with a search box, the road tree (Prim plus a few loops), a road out of every gate,
  `route` for everything that walks, the signs.
- `shared/WorldPlaces.lua` the places between villages, 2–5 tiles off a road, 30 tiles apart.
- `shared/TileTypes.lua` defines the ground and object tiles. Ids are small integers (under 94), so a map is one byte
  per tile. `foot` is a multi-tile object's footprint; its sprite may be taller than its footprint.
- `shared/Rng.lua` is a seeded xorshift32 and the only randomness source. `shared/Names.lua` makes people and place names.
- `server/Map.lua` holds the one `WorldGen.World` and `Map.encoded`. `Map.village(id)` looks up a village by id.
- `client/Viewport.lua` draws a sprite wider or taller than a tile with its bottom-left on the anchor tile and
  `ZIndex = ty`, so a hall's roof hangs over the row behind and the south draws over the north. `part` draws nothing.

**Tunables** (`shared/Config.lua`): `WORLD_SEED` (0 = random each server), `WORLD_WIDTH`, `WORLD_HEIGHT` (256),
`REGION` (region size in tiles). The village list and positions are `WorldPlans.PLANS`.

**Previews**: `npm run test:luau` writes `exports/world_1.txt` (an `IDS w h sx sy` line plus the two encoded layers),
`npm run preview:world [file] [scale] [x0 y0 x1 y1]` paints it (a window of tiles for a close look),
`npm run preview:view [file] [x] [y] [scale] [night]` shows the player's viewport. `tools/mapfile.js` is the shared
reader; it parses the offset and the id→sprite table out of the Lua, so a new tile needs no tool change.

**Gotchas**
- The map is **derived, never saved** (ARCHITECTURE R4): a save stores the seed. Changing the generator means
  bumping `WorldGen.GEN_VERSION`, and that discards the saved world on load. Never bump it for anything else
  (→ learnings P3).
- `Map.village` throws before `Map.init` has run (→ T3).
- After touching WorldGen or tiles, run `npm run preview:world` and `npm run preview:view`, and LOOK at the PNGs.
- Camp and bag tiles on the object layer are written only by `server/Tiles.lua` ([talk-and-trade.md](talk-and-trade.md)).
- A village layout is drawn north row first; a footprint's `=` tiles sit above and to the right of its anchor.
- The server still rosters every village with the old three-village roster (`Sim.initTribes`): 16 tribes, same
  guards and villagers each. Rostering by tier, and a tribe that holds several villages, is step 3 of the plan.

## Expansion: deficits at scale

Notes for rung 4 (bigger map, several villages per tribe). **Step 2 of `docs/plans/world-expansion.md` (2026-10-07)
closed the generator items**: villages come from a list with a spacing rule, roads are a tree, the map is 256², the
save strands by design (development mode), the WorldGen ceiling is gone (six modules under 400), the tests follow the
map. Still open, for steps 3–4: `villages[1..3]` by index, one village per tribe, A* without a budget, `villageAt` as
a linear scan, the whole map to every joiner (131 KB at 256²), `Config.REGION` doing nothing.

- **Three villages, placed by hand.** `shared/WorldGen.lua:528-534`. Hard limit. One village per tribe type at fixed
  fractions of the map. Any other count needs a new placement pass. Probably a list of villages with a spacing rule.
- **Roads join a fixed list of pairs.** `shared/WorldGen.lua:604`. Hard limit. Three pairs, all to all. At N villages,
  all to all is N² unbounded A* runs. Probably nearest neighbours or a spanning tree.
- **A village's index is its meaning.** `server/Bands.lua:84`, `server/Goals.lua:23`, `server/Interact.lua:65-67`,
  `client/Client.client.lua:396`, `server/Sim.lua:564` and `server/State.lua:122` (`or 1`). Hard limit. 1 = farmers,
  2 = hunters, 3 = plunderers. A fourth village or a new order breaks the quest, the bands and the dialogue.
  Probably look villages up by type or role.
- **One tribe per village, same index.** `server/Sim.lua:277-285`, `shared/Save.lua:141`, rep keys `v1..v3`
  (`docs/architecture/as-built.md:39`). Hard limit for "several villages per tribe". Probably a tribe holds a list
  of village ids (a save-format change, so trigger 3).
- **A* has no budget by default.** `shared/WorldGen.lua:249`. `Tick.rebuildRoute` (`shared/Tick.lua:95`) and
  `server/Bands.lua:40` pass none, and a load rebuilds every group's route (`server/Restore.lua:170-173`). Soft
  limit. Cost is about map area per call, and each node allocates (`WorldGen.lua:270`). Probably cached routes
  between villages.
- **Whole-map scans in generation.** `shared/WorldGen.lua:613-620` (every spare gate scans all W×H tiles) and
  `floodTiles` (`:757-770`, W×H×25). Soft limit. Both grow with area times villages. Probably fine as one-off cost; measure.
- **`villageAt` is a linear scan.** `shared/WorldGen.lua:811-816`. Soft limit. Called per tile in those scans and
  on every client step (`Client.client.lua:650`). Probably a village-id grid or a per-region lookup.
- **The whole map goes to every joiner.** `shared/WorldGen.lua:852`, `server/Server.server.lua:90`. Soft limit.
  2 bytes a tile: 18 KB today, 131 KB at 256², 524 KB at 512². Guess: join time and remote size limits bite
  past 256². Probably send by region.
- **`Config.REGION` does nothing.** `shared/Config.lua:16` vs the hard-coded `WorldGen.REGION = 16`
  (`shared/WorldGen.lua:731`). Tuning trap: editing Config changes nothing.
- **Fixed feature counts.** One river (`shared/WorldGen.lua:482`), three caves (`:652`), one template per tribe type
  (`:89`). Tuning numbers. A bigger map gets the same river and three caves. Probably scale with area.
- **Growing the map strands the save.** `shared/WorldGen.lua:13`. Hard limit. The save stores only the seed, so a new
  generator means `GEN_VERSION` bump and a discarded world (→ P3). Needs a plan before rung 4 (trigger 3).
- **Line ceiling.** `shared/WorldGen.lua` is 879 lines against an 880 allow-list (`test/structure.test.js:21`). Hard
  limit. One more line fails `npm test`. Track B4's split has to come first.
- **Tests pin today's numbers.** `test/luau/worldgen.test.luau:46-48, 61, 64, 67` (96×96, 3 villages) and the Track B
  gate "three villages" (`docs/architecture/tracks.md:91`). These fail on purpose when the map grows; update them with it.

Measure first: `WorldGen.generate` ms at 256² (`Map.init` prints it); the `WorldInit` payload size and join time;
the A* nodes expanded per group route at load.
