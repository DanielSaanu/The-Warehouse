# QA round 2: world expansion step 2 — SCORE 7/10

Reviewer: Opus subagent, 2026-10-07, no Studio (cloud session). Reviewed HEAD 1119540 (the round 1 commit); the
house resize was in the working tree and was not reviewed. Goals: `docs/qa/world-expansion-p2.md`.

## Report (verbatim)

I reviewed HEAD 1119540 (`git diff 97d7cc1..HEAD`). **Studio was not available, so nothing here was seen running in Roblox.** Another session changed the working tree while I was reviewing (from 17:25: `TileTypes.lua`, `WorldPlans.lua`, `worldgen.test.luau`, and new `scenes/house*.json` and `castle.json`, none committed). I threw away the results from that window: `view_200_128` and `view_205_136` showed hunter huts drawn as `house_hunter`, and one route-timing run was affected. Everything below is from HEAD.

**What I ran on HEAD:** `npm test` passed (13/13 node, all Luau). `lint:luau` is clean. The Rojo sourcemap compared with 97d7cc1 lost nothing and gained exactly `WorldPlaces`, `WorldPlans`, `WorldSigns`, `WorldVillages` and `Client/Minimap` as ModuleScripts, and the Rojo build succeeds. Generation takes 382–442 ms per seed in the luau CLI. I also wrote my own Luau checks over seeds 1, 7, 42 and 2026.

**Player view:** You spawn on a real plaza with a two-tile street, a hall whose roof hangs over the row behind, and a windmill and fields (`view_58_188@5x.png`). The town has towers, double gates and a readable breach (`world_1_40_170_80_210@3x.png`). The great lodge and the stronghold look like their tribes. Seen whole, the map (`world_1.png`) reads as three countries joined by brown roads.

What hurts:
- **Clutter on the first screen.** The windmill's sails cover a hut, and the knights post's roof covers another hut. Both come from the town layout: the `5` and `k` sit directly under `hh`.
- **Rock blocks.** Solid rock appears as big grids of identical dark boulders (`view_200_128`; the rock in it is unaffected by the mid-review change).
- **Long walks.** The road between the town and the great lodge is 449 tiles on seed 1, against 193 tiles walking straight. That is the walk the first goal asks for.
- **Signs that lead elsewhere.** Many exit signs name a village the road does not go to.

SCORE: 7/10
GOALS:
- 256x256, server runs on it: met - `Config.lua:14-15`, `WorldGen.DEFAULT_*`, OFFSET 33, tree identical plus new modules; Studio timing unverified.
- Sixteen villages from one list: met - `PLANS` order and tier counts asserted; villages [1..3] are town (6 gates), lodge (0), stronghold (4).
- Layouts as data + check: met - flood-from-spawn in `WorldPlans.check:286-310`; all tier buildings are present.
- Multi-tile objects whole: met - seven-seed hole/orphan test (`worldgen.test.luau:160-185`).
- Renderer draws them: met (by reading the code) - `Viewport.assign` size, offset and ZIndex = ty in the Objects layer; MARGIN 3 covers 48-tall sprites.
- Roads a tree, two wide, signs: partial - fords and signs don't hold up (FIX).
- Places between villages: partial - want 16, placed 13 (seed 1), 16, 14, 13; spacing and offset are not tested.
- Three countries, all walkable: partial - lattice forests work (only 70–153 walkable tiles per seed can't be reached); the rock crags are not small.
- Save path: met - `Save.applyPlayer:272-274` plus a test; `Restore.player` falls back to the rest point.
- Nothing regresses: met - green and lint-clean; WorldGen is 207 lines and its allow-list entry is gone. But Viewport is 427/430 and Client 655/660, reached by squashing functions onto one line.
- Minimap: met - `Minimap.lua`, M key and tap; it covers panels (FIX).
- Capitals grand: met - double gates, plaza, corner towers (`world_1_94_8_124_40@3x.png`).

PRESERVE:
- `WorldPlans` ASCII layouts plus `check`, including the sealed-pocket flood: readable data that a test can prove.
- Anchor-plus-`part` footprints: walking, A*, `villageAt` and the save need no special case.
- Capitals first in `world.villages`: Bands, Goals, Interact and Restore did not change.
- `tools/mapfile.js` reads OFFSET and sprites from the Lua sources, so the previews never drift from the game.
- Old WorldGen names kept as re-exports: no caller changed.

FIX:
- **Fords don't always have a road on both banks.** The test passes if a road touches either bank (`worldgen.test.luau:136`, `fords().road` checks any neighbour). Seed 42 has a real crossing at 135-137,55 with grass on the west bank and a road only on the east. It also has fake one-tile "fords" at 146,33 and 136,50: `carveRoad`'s second tile turns river into ford beside a road running along the bank, and each fake one gets a "Ford." sign. -> Only widen roads onto dry ground (skip water in `carveRoad:176-181`). Treat a crossing as joined only when it has a road on both bank tiles, and assert exactly that.
- **Exit signs name villages the road doesn't reach.** `signpostTarget` picks by the compass direction of the exit. On seeds 1/7/42/2026, 14, 23, 17 and 20 exit signs name a village you can't reach by road from that exit without going through another village. Example: Wenthorpe@82,243 says "Oakden, east", a hunter camp across the river, while its road goes north to farmer villages. -> Name the first village reached by following the roads from the exit (a breadth-first search over path and ford tiles).
- **Solid rock comes in blocks, not crags.** `e > 0.84` gives connected rock blocks of up to 340, 211, 614 and 254 tiles. Visually they are rows of identical boulders (`view_200_128`). -> Cap crag size (for example, flood-label the components and thin any over ~12 tiles), or seed small crags the way caves are seeded.
- **Tall sprites overhang solid huts in layouts.** The windmill `5` at town (15,13) and the knights post `k` at (3,12) both hang over `hh`. -> Add a sprite height to `ObjectDef`. Have `check` reject a tall object whose overhang row lands on a solid object, then fix the layouts.
- **Minimap ties with panels at ZIndex 30.** It is created after the HUD, so it probably draws on top. On a phone (~830x384 play area) the small map (x 724–824, y 37–137) covers the bag panel's close button (x 711–755, y 27–71). Its TextButton would then catch the tap. -> Use ZIndex 25, or hide the minimap while any panel is open.

CONSIDER:
- **Capital-to-capital road detour.** Town to lodge is 449 tiles by road against 193 walking straight. -> Always include the town–lodge edge, or pick the extra loops by how much they cut road distance compared with straight-line distance.
- **Place count.** `APART` 30 leaves 13–15 places. -> Lower it to ~24, or say in the goal that 16 is a ceiling.
- **Line-ceiling squeezing breaks the spirit of T1.** -> Move code out instead (Minimap could take the marker and legend helpers).
- **The forest lattice makes diagonal rows.** In the wettest forest the odds reach 1 and the rows become walls you can't cross. -> Jitter the lattice.
- **Unreachable targets search the whole map.** `route` to an unreachable walkable tile took 150 ms, and `floodTiles` takes 216 ms with 5193 tiles sent to every client. -> Step 4: cached routes and a node budget.
- **Ford sign wording.** "X east, south-west." reads oddly. -> "East bank: X (south-west)."
- **Small minimap markers on a phone.** Hamlet markers are about 2 px. -> Set a minimum pixel size.
- **`preview_tiles` is stale.** It doesn't show the new building sprites. -> Regenerate it.

UNCERTAIN:
- Generation time, `WorldInit` delivery of 131 KB, and client decode in real Studio.
- The draw order for equal ZIndex (minimap vs panels) and the Objects-layer y-sort, judged from the code only.
- Two players, or a player leaving mid-move, on the bigger map.
- How the not-yet-uploaded sheet looks with the new sprite rects.
- What the uncommitted working-tree changes (house_hunter 2x2, castle) will do. I did not review them.

## Builder decisions

**FIX, done**
- Fords: `carveRoad` never widens onto water (no fake one-tile fords); a crossing counts as joined only when BOTH bank
  tiles of its widest row are road, `fordRoads` makes it so, the test asserts it and rejects one-tile fords.
- Exit signs: `signpostTarget` walks the road from the exit (BFS over path and ford, never back through the village)
  and names the first village it touches; the compass pick is only the fallback for a road to nowhere.
- Crags: rock components over 12 tiles are thinned to scattered rock, boulders and loose stone on the stony ground
  (the cave mounds are seeded separately, after).
- Overhang: `WorldPlans.OVERHANG` (rows a sprite reaches above its footprint) and `check` refuses a layout where a
  roof lands on another building or on a wall (Danzo: walls never cut through houses; a corner tower in the wall is
  the one exception). Every layout was redrawn to pass.
- Minimap: hidden while any panel is open, so its button never sits over a close button (see the round 3 commit).

**CONSIDER, taken**
- The three capitals are always joined to each other ("the king's roads") whatever the tree did.
- Places 24 apart (was 30).
- The forest lattice refuses a tree diagonal to one above, so no line of trees walls the way, and the roof of a tree
  never meets a trunk.
- Ford signs read "Ford. East bank: X (direction). West bank: Y (direction). Wolves at night."
- Minimap markers get a minimum pixel size (round 3 commit).

**CONSIDER, deferred**
- Line-ceiling squeezing: Client 655/660 and Viewport 427/430 by one-lining trivial functions. The honest fix is
  the rung 3 part 5 client split, already on the allow-list's reasons. Not widened here.
- Unreachable routes searching the whole map, `floodTiles` cost: step 4.
- `preview_tiles` regeneration: a mockup scene, not shipped.

**Danzo's asks (2026-10-07, between the rounds)**
- Houses are the Kenney Tiny Town houses as drawn on their sheet (a 3-wide roof over a wall row, 48 x 48), footprint
  3 x 2 with the roof row hanging over the row behind: farmers orange roof and wood, hunters grey roof and wood,
  plunderers grey roof and stone; a charred shell for the burnt ones. No stretching, no forced square. The town
  hall is a stone gatehouse (Kenney castle wall and arch, 64 x 48, footprint 4 x 3). Every layout redrawn around
  them; the castle, windmill and houses never touch a wall.
- Still small: the windmill (32 x 48, hand-drawn) and the longhouse / war hall (48 x 32). Bigger art for those is a
  drawing job, listed for Danzo.
