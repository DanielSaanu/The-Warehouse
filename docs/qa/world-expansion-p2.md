# QA goals: world expansion, step 2 (the bigger map, sixteen villages, big buildings)

Branch: `world-expansion`. Plan: [`docs/plans/world-expansion.md`](../plans/world-expansion.md) "Build order" 2 and
"Build notes for step 2", approved by Danzo 2026-10-07 (256 x 256, 16 villages as drawn, interiors later). Handoff
H13. Review the step 2 commits' diff, with the new files as they stand: `shared/Grid.lua`, `shared/WorldLand.lua`,
`shared/WorldPlans.lua`, `shared/WorldVillages.lua`, `shared/WorldRoads.lua`, `shared/WorldPlaces.lua`, the new
`shared/WorldGen.lua`, `client/Viewport.lua` (`assign`), `tools/mapfile.js`, `test/luau/worldgen.test.luau`.

The question for this loop: **does the world now feel like a country worth walking: sixteen different villages in
three kinds of land, joined by roads with things to find between them, drawn with buildings bigger than a tile,
while every caller of the old WorldGen and the whole save path keep working unchanged?**

## Goals

1. **The map is 256 x 256 and the server runs on it** (`Config.WORLD_*`, `WorldGen.DEFAULT_*`). `Map.init` prints
   the time; generation stays well under a second in Studio. The `WorldInit` payload (two 65 536-byte strings plus the
   village list) reaches the client and the client decodes it with the same `OFFSET` (33). No remote, no `require`
   target, no instance name changed; the Rojo tree is the same shape plus five new ModuleScripts under `Shared`.
2. **Sixteen villages from one list** (`WorldPlans.PLANS`, `WorldVillages.build`): farmers 1 walled town, 2 villages,
   3 hamlets in the south-west; hunters 1 great lodge, 2 lodges, 2 camps in the east; plunderers 1 stronghold, 1
   camp, 3 hideouts in the north. Positions are Danzo's sketch scaled and nudged onto dry ground, at least 4 tiles
   clear of each other. `villages[1]` is the town (the start, three gates, plundered: two burnt huts and a breach),
   `[2]` the great lodge, `[3]` the stronghold, so `Bands`, `Interact`, `Goals`, `Gossip` and `State` work unchanged.
3. **Layouts are data a reader can see** (`WorldPlans.VILLAGES`, one character per tile, legend at the top of the
   file). Every layout passes `WorldPlans.check`: one spawn, one bed, one stall; every multi-tile footprint is its
   anchor plus `=` tiles, every `=` owned by exactly one anchor. The board's three large layouts are the shape of the
   tiers; the tier table's buildings are present (hall, granary, storehouse, windmill, knights post, market row; longhouse,
   trophy hall, tannery, muster ring, lookout tree, hiring board; war hall, tents, cages, loot, towers at the corners).
4. **Multi-tile objects are whole** (`Grid.place`, `TileTypes.foot`): the anchor is the bottom-left tile, the rest of
   the footprint is `part` (solid) or `part_open` (the muster ring is stood on). Walking, A*, `nearestWalkable` and
   `villageAt` need no special case. A test over seven seeds finds no hole and no orphan part.
5. **The renderer draws them** (`Viewport.assign`): a sprite with `W`/`H` over 16 is `W/16 x H/16` cells with its
   bottom-left on the anchor tile, `ZIndex = ty` so the south draws over the north, `part` hides the slot. The town
   hall's roof hangs over the row behind it. `Viewport.lua` stays under its 430 ceiling (427).
6. **Roads are a tree, not a web** (`WorldRoads.edges`: Prim over village centres plus floor(n/6) short loops):
   every village is joined, no gate opens onto nothing, roads leave walled villages through the gate facing where
   they go and never cut through a third village. A sign stands at every village exit and every ford, naming the
   next place and its direction. Fords are placed before the roads so the roads spread across them.
7. **The places between villages** (`WorldPlaces.build`): max(5, villages) of them, cycling shrine, burnt village,
   ruined watchtower, abandoned camp, battlefield, 2–5 tiles off a road (the shrine 1), 30 tiles apart, never on water,
   road or a village's approach. At least one of each kind on every seed. Caves stay in `WorldLand` and scale with area.
8. **Land that looks like three countries** (`WorldLand.build`): the elevation leans up to the north (hills: broken
   ground, boulders, dead trees), moisture leans east (forest: pines and autumn trees), the south-west is low and dry
   (fields). Marsh (pools and reeds) at the wet lowlands. The river splits the map with several fords and is wadeable.
9. **The save path is untouched except by design**: `GEN_VERSION` 2 discards the old world (development mode: fine,
   recorded in the plan). `Save.VERSION` and `PLAYER_VERSION` unchanged. The gossip `owed` budget test scales with
   holders (16 villages); the whole world record stays a small fraction of the 4 MB key.
10. **Nothing regresses**: `npm test`, `npm run lint:luau` clean; `WorldGen.lua` is 205 lines and its allow-list entry
    is gone (B4 done); every previously green Luau test is green with its numbers scaled to the world, not loosened
    further than the world needed. `npm run preview:world` and `preview:view` paint the real tiles (the IDS format),
    and the PNGs were looked at: the town, the great lodge, the stronghold, the breach corner.

## Studio play-through (DevMode on, nothing saves)

1. Play. The Output shows `[Map] seed 1, 256x256, villages:` sixteen names and a time. No warnings from `Sprites`
   (after Danzo's upload; before it, every new sprite warns `unknown sprite` and the old sheet shows the old tiles).
2. You stand in the town centre on a path crossing; the town hall is north-west with its roof over the fields' row,
   the windmill south-east, the market awnings west. Walk to the south-west corner: the breach is walkable, the rubble is not.
3. Leave by the east gate: a sign names the next village and its direction. Follow the road to a hamlet (three or
   four huts, a field, a well, no walls) and on to the river: a ford with a sign, the river wadeable beside it.
4. Find one place between villages: walk round it, nothing inside it blocks the road, a 32-tall shrine or watchtower
   draws over the tile behind it, and the player draws over it when standing south of it.
5. Open Debug and `tp` to the great lodge and the stronghold (or walk). The great lodge is open, pines around it, the
   longhouse 3 wide; the stronghold has towers at the corners and gates north and south, both with roads.
6. Walk behind a hall (north of it) and in front (south): the body is solid on its footprint only; the roof overhang
   row is walkable and the player appears OVER the roof there (known limit, goal 5).

## Out of scope (do not penalise absence)

Step 3 (a tribe holds many villages; rostering by tier; save format change), step 4 (sending the map by region,
cached routes, a village-id grid, tick cost at 16 villages). Interiors. Tax, processions, hiring boards and hunting
parties doing anything. The H12 first-week and toys work. Behaviour of any new building.

## Known limitations going in

- **The server rosters every village with the old roster** (`Sim.initTribes`): 16 tribes, each with the same guards,
  merchant and villagers as the old three. Population and tick cost are 5x; measured in Studio, not tuned. Step 3.
- **A spare gate's road can run along the outside of a palisade** to reach the network (the stronghold's north gate on
  seed 1): correct, a little odd to look at.
- **Entities draw above roof overhangs** (no entity/object y-sort yet): a player standing on the row behind a hall
  appears over its roof.
- **The map still goes to every joiner whole**: 131 KB of strings at 256². Fine for now; step 4 if it is not.
- **Hills are boulder fields at `e > 0.70`** as before (the old `rock` tile); the north is rockier than the board drew
  it. A hills tileset is art work, not this step.
- **Danzo uploads the sheet**: `roblox build` printed CHANGED; until `--upload` and the commit of `Sprites.lua` +
  `assets.lock.json`, Studio shows the old image with the new rects (wrong tiles, no crash).
