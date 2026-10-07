# QA round 1: world expansion step 2 — SCORE 7/10

Reviewer: Opus subagent, 2026-10-07, no Studio (cloud session). Goals: `docs/qa/world-expansion-p2.md`.

## Report (verbatim)

I scored this step 7/10. It is a big, clean piece of work: tests and lint are green, all sixteen villages are drawn, the big buildings render and the modules are well split. Three problems hold the score down: the road network crosses the river only once on seed 1 and most fords have no road, the town's breach is a dead end, and an old saved player position is reused on the new map. Studio was not available, so nothing below comes from a real Play.

What I ran: `npm test` (13/13 node tests, 14/14 Luau tests), `npm run lint:luau` (clean), the worldgen test on 7 seeds, the full map and close-up previews (looked at), the spawn and night views, a view of the ford at 160,30, and my own scripts in the scratchpad (road connectivity, ford coverage, place counts, sealed pockets, route timings).

SCORE: 7/10
GOALS:
- 1 256² map, server runs on it: met (Studio untested) - `Config.lua` and `WorldGen.DEFAULT_*` are 256. The encoded map is 131,072 B. `OFFSET` is 33 and the encode/decode round-trip passes. Generation takes 306–416 ms in the standalone `luau` interpreter. `Shared` maps a whole folder (`src/shared`), so the 5 new ModuleScripts appear without a project change.
- 2 Sixteen villages: met - the test prints 16 names per seed with the right tribe and tier mix. `villages[1..3]` are the town, the great lodge and the stronghold, and the test checks the gate counts (3/0/2) and the spacing.
- 3 Layouts as data: met - `WorldPlans.lua` has the legend at the top and `check` passes on all 9 layouts and 5 places. Every tier building in the goals is present.
- 4 Multi-tile objects whole: met - `Grid.place`; the hole and orphan scan in `worldgen.test.luau:142-166` passes on 7 seeds.
- 5 Renderer: met (Studio untested) - `Viewport.lua:165-177` sizes each sprite W/16 × H/16, hangs it up from the anchor and sets `ZIndex = ty`. `view_59_185@5x.png` shows the hall's 48×48 roof, the windmill, the knights post and the awnings drawn correctly. The file is 427 lines (ceiling 430).
- 6 Roads and signs: partial
  - Every village is on the network and no gate is off it.
  - Fords do not spread the roads: 3 of 4 ford crossings on seed 1 (and 3–4 roadless on every seed) have no road.
  - On seed 1 the only road across the river is far north, about row 65. Oakham to Glenworth by road is 438 tiles against a Manhattan distance of 190.
  - The `preferRoads` route for the town→great-lodge caravan passes through Rock Camp, a plunderer hideout.
  - Ford signs read "Ford. Wolves at night. Stay on the road." They name no place, and 3 of the 4 stand where there is no road.
- 7 Places between villages: met - 16 on every seed (4 shrines, 3 towers, 3 camps, 3 burnt villages, 3 battlefields). There are 5 caves (max(3, area/13000)).
- 8 Three countries: partial - rock covers 26% of the north against 12–16% elsewhere, and forest is 15% in the east against 9–10% elsewhere. In `world_1.png` the boulder grids are everywhere, the south-west does not read as fields, and the great lodge (window 190,124 to 222,156) sits in solid boulder fields, not pines.
- 9 Save path: partial - `GEN_VERSION` 2 and `Save.decode` refuse the old save cleanly, and `VERSION`/`PLAYER_VERSION` are unchanged. But a returning player keeps their saved x, y from the 96² map: `Restore.lua:53-56` → `Sim.lua:1032-1035` puts them at stale coordinates on the new map, for example inside a rock field.
- 10 No regressions: met - all tests pass, `WorldGen.lua` is 205 lines and its allow-list entry is gone. The test changes scale with the world; the gossip `owed` budget is 32 B per holder against about 25 B measured.

PRESERVE (done well, must survive future iterations):
- `WorldPlans` layouts plus `check`: anyone can read a village, and a bad footprint fails a test.
- The thin `WorldGen` hub that re-exports under the old names: no caller changed.
- The anchor-plus-`part` model: walking, A*, `villageAt` and `Farms.scan` needed no special case.
- The worldgen test's single flood fill, 7-seed sweep and footprint integrity check.
- The town as drawn (`view_59_185@5x.png`): a crossing at spawn, the hall north-west, the windmill south-east, the market west. It reads at a glance.
- The stronghold close-up: corner towers, two gates, tents, cages and loot all read well.

FIX (done poorly; why it matters; concretely how to fix):
- **The breach is a dead end.** The goals promise "plundered … and a breach", but you cannot get into the town through it. My flood fill shows the breach tiles (53,193)→(53,192) are sealed: the woodpile `v` (layout row 14, column 2) is north, rubble west, the burnt hut east. -> Change that `v` to `.` (or move the woodpile) so the breach opens into the town. Add a test that floods from outside the town and reaches the inner breach tile.
- **Sealed pockets in layouts.**
  - Stronghold (103,28 and 103,29): `Pxx`/`P.b`/`P.S` in columns 2–3.
  - Plunderer camp: 6 tiles at (192,37/38), (199,37/38) and (192,42/43).
  - Town: (65,181), beside the bed.
  - Why it matters: the stronghold merchant spawns at `stall.y+1`, which is the palisade. `nearestFree` probably then picks the sealed pocket tile (2,13), so nobody can stand next to the merchant to talk (the stall itself still trades).
  - -> Fill the pockets with `x`, `.`→`R`, or open them. Extend `WorldPlans.check`, or the test, so every walkable tile in a layout must connect to `@`.
- **One river crossing; fords don't carry roads.**
  - Why it matters: a player in the town who wants the great lodge faces a 438-tile road via the far north. Caravans and rides take the same route, through a raider hideout.
  - -> After the MST, add an edge for each ford: A* from the nearest village on each bank to the ford. Or make the river cost high in `stepCost` everywhere except fords, so the tree's cross-river edge uses one, and allow one extra edge per uncrossed ford.
  - -> Test: every ford cluster touches a path tile, and road distance between capitals is ≤ 1.6× Manhattan.
- **Ford signs say nothing useful.** -> At a ford, use `signpostTarget` toward the far bank: "Ford. Glenworth, east." Only put "stay on the road" where there is a road.
- **Stale player position after a world reset.** -> In `Restore.player`, use the saved x, y only when `saved.metWorld == S.meta.worldId`; otherwise use the rest point or `world.spawn`. This touches the save path (trigger 3), so it goes through the heavy agent; it is a small, testable change.

CONSIDER (fine but could change; why; how):
- Tall art against entities: with thousands of 16×32 pines and autumn trees, a player standing north of any tree draws over its crown, not only behind halls. -> Next step: draw entities into the Objects layer with ZIndex = ty (an entity on the same row draws above).
- Pool margin: `MARGIN = 2` rows below the window. When the camera sits between tiles, the top third of a 48-tall sprite (hall, windmill, lookout tree, `dead_tree_tall`) at the bottom edge pops in. -> Extend the pool down by `maxH − 1` rows.
- `WorldPlaces.fits` treats any id `>= O.pine.id` as clearable nature. A future building id above 55 would be stamped over. -> Add a `nature` flag in `TileTypes`.
- Duplicate signs: Glenworth has two "Wenham, south" signs 5 tiles apart. -> Skip a sign when the same text is within 6 tiles.
- `e > 0.70` rock is 18% of the map and draws as an identical boulder grid. Already noted as art work, but it is the map's biggest visual weakness. -> Thin it with `rocks_grey`/`boulder` mixes or a lower density.
- The town has 24 farm plots, but `Farms` is tuned to 8. That is step 3, but it shifts food once a save is made.

UNCERTAIN (could not verify):
- The Studio Output line `[Map] seed 1, 256x256, villages: …`, the real generation time, and whether `WorldInit` (131 KB plus 16 village records) arrives without throttling.
- Whether `Viewport.assign` sizes and positions look right live, and the overhang behaviour in play.
- Tick cost and fights with 16 rostered tribes, including whether caravan guards clash with Rock Camp's bandits on the new route.
- Whether `nearestFree` really puts the stronghold merchant in the sealed pocket; this is reasoned from the ring order, not run.
- Rojo sourcemap and build: `rojo.exe` is not available on Linux here.

## Builder decisions

Danzo played the build between the report and the fixes and added three asks of his own (forests that do not wall
the player in, a rocky "skin" instead of plugs of rock, a minimap, wider roads and gates with grandeur for the
capitals); they are folded in here and listed under "Danzo's asks".

**FIX, done**
- The breach: the woodpile that sealed it moved; the town is redrawn (below) and the worldgen test now walks the
  breach from outside to inside on every seed.
- Sealed pockets: `WorldPlans.check` floods every layout from its spawn and fails on any walkable tile it cannot
  reach; five pockets across the town, the stronghold, the camp and the hideout were opened by that check.
- One river crossing: `WorldRoads.fordRoads` joins both banks of every ford to the nearest road on that side
  (`WorldRoads.fords` finds the crossings and says whether a road touches each); the test asserts every ford has
  a road. Seed 1 went from 1 crossing with a road to 12.
- Ford signs name the nearest village on each bank with its direction ("Ford. Brambury east, north-east. Ulfmere
  west, south-west. Wolves at night."). Signs moved to `shared/WorldSigns.lua` (WorldRoads had passed 400 lines).
- Stale player position: `Save.applyPlayer` returns no tile when the key's `metWorld` is another world (a key from
  before worlds had ids keeps its tile); Restore then uses the rest point. Tested in `save.test.luau`. Trigger 3:
  done in this session because Danzo put H13 on Fable directly; `PLAYER_VERSION` unchanged.

**CONSIDER, taken**
- Pool margin 2 → 3 rows, so a 48-tall sprite anchored just below the window does not pop in.
- `WorldPlaces.fits` clears only a named list of wild things (and decor), not "any id above 55".
- Duplicate signs: the same words within six tiles are one sign.
- Rock: the `e > 0.70` boulder fields are gone (see Danzo's asks); solid rock is only crags above 0.84.

**CONSIDER, deferred**
- Entities drawn above tree crowns: a renderer y-sort between entities and objects; a later step (Viewport is at
  its ceiling and the fix is a layer change, not a line).
- 24 farm plots against `Farms` tuned to 8: step 3, with the roster by tier.
- A road-distance-to-Manhattan ratio test: with a road at every ford the ratio is no longer the problem; not pinned.

**Danzo's asks (2026-10-07, after playing)**
- Forests: a `forest_floor` ground tile says "forest"; trees stand on a spaced lattice ((x + 2y) % 3 == 0), so no
  two are side by side and a forest is always walkable. Tree count halves, forest area is unchanged.
- Hills: a `rocky` ground tile with sparse boulders, loose rocks and dead trees; solid rock only above 0.84, and the
  cave mouths are small 3 x 2 crags placed on the stony ground, open to the south.
- Roads two tiles wide (`carveRoad` lays the tile beside each step too, never through a wall or into a village).
- The capitals: double gates, two-tile streets, a plaza at the town's crossing with a well and lanterns, towers at
  the wall corners (town 18 x 18, great lodge 18 x 17, stronghold 14 x 16). `villages[1]` has six gates now.
- A minimap: `client/Minimap.lua`, one cell per 8 x 8 tiles coloured by what is there, village markers in tribe
  colours (capitals bigger), a white dot for the player, M or a tap swaps corner and full size. The client
  script paid for its five hook lines by one-lining three trivial functions.
- Two new sprites (`forest_floor`, `rocky`): `roblox build` run, Danzo re-uploads.
