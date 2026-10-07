# QA summary: world expansion, step 2 (the bigger map, sixteen villages, big buildings)

Goals: [`world-expansion-p2.md`](world-expansion-p2.md). Branch `world-expansion` (built on the session branch
`claude/blissful-bardeen-fpjfxl`, PR DanielSaanu/The-Warehouse#16). Reviewer: one Opus subagent per round, no Studio
(cloud session: everything below is from code, tests and the painted previews; Danzo's Play is the real check).
Danzo played between rounds and added asks; they are folded into the rounds they landed in. Verbatim reports:
`archive/world-expansion-p2-round{1,2,3}.md`.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | The town's breach was a dead end, layouts had sealed pockets, the river had one road crossing and ford signs said nothing, a saved tile was reused on a new world. |
| 2 | 7/10 | Fords counted with a road on one bank (and roads widened into the river made fake fords), exit signs named villages by compass not by road, solid rock still came in blocks, roofs overhung houses, the minimap could sit over a panel. |
| 3 | **8/10** | Target met. Left: a crag-thinning hash that kept whole rows, exit signs that walked round their own village, a spare gate road looping round its wall. All taken anyway. |

## Fixed, by round

**Round 1** — the breach opens (tested from outside to inside); `WorldPlans.check` floods every layout from its spawn
(five pockets found); `WorldRoads.fordRoads` joins both banks of every ford to the road network; ford signs name the
banks; `Save.applyPlayer` drops a saved tile from another world (tested); pool margin 3; places clear only named
wild things; duplicate signs within six tiles are one; signs moved to `shared/WorldSigns.lua`.
*Danzo's asks:* `forest_floor` and `rocky` ground tiles with trees on a spaced lattice and sparse boulders; crag
cave mounds; roads two tiles wide; the capitals redrawn with double gates, two-tile streets, a plaza and corner
towers; `client/Minimap.lua` (M or a tap).

**Round 2** — `carveRoad` never widens onto water; a crossing counts only with road on both banks (test); exit signs
name the first village the road reaches (BFS); rock blocks over 12 tiles thinned; `WorldPlans.OVERHANG` and `check`
refuse a roof over a building or a wall; the minimap hides while a panel is open; the capitals are always joined by
road ("the king's roads"); places 24 apart; no diagonal tree chains; "East bank: X (dir)" ford wording; caves
approached from the south; no sign on a cave's doorstep.
*Danzo's asks:* houses are the Kenney Tiny Town houses as drawn (48 x 48, footprint 3 x 2, roof row overhanging):
farmers orange roof and wood, hunters grey roof and wood, plunderers grey roof and stone, a charred shell for the
burnt ones; the town hall is a stone gatehouse (64 x 48, 4 x 3); every layout redrawn; no roof over a wall.

**Round 3** — the crag hash mixes x and y and runs twice (test: no rock block over 12 tiles away from the border);
an exit's road walk may only step outward near its village and a gate's sign stands outside the wall; spare gates
search the half-plane they face; open layouts carry a clear top row; minimap dot 5 px minimum; ascii glyphs unshared.

## Preserved (confirmed across rounds)

- `WorldPlans`: the ASCII layouts plus `check` (footprints, sealed pockets, the roof rule) — readable data a test proves.
- The anchor-plus-`part` footprint model: walking, A*, `villageAt`, `Farms.scan` and the save needed no special case.
- `WorldGen` as a thin hub re-exporting every old name: no caller changed (B4 done).
- `villages[1..3]` = town, great lodge, stronghold: Bands, Goals, Interact, Gossip, State and Restore unchanged.
- The worldgen test's single flood fill, seven-seed sweep and footprint integrity check.
- `tools/mapfile.js` reading `OFFSET` and the id→sprite table from the Lua sources, so previews cannot drift.
- The town as the first screen: a plaza at the crossing, the gatehouse north-west, the market west, the windmill east.
- The forest lattice (no tree beside or diagonal to another) and roads that never widen into water.

## Deferred, one line each

- Entity/object y-sort (a player north of a tree or hall draws over its crown or roof): a renderer layer change, later.
- Farm plot count vs `Farms` tuning, and the old roster on 16 villages: step 3 (rostering by tier).
- Unreachable-route and `floodTiles` cost at 256², the whole map to every joiner: step 4.
- Line-ceiling squeezing in `Client.client.lua` (655/660) and `Viewport.lua` (427/430): the client split (rung 3 part 5).
- Houses sharing an edge with a wall: `check` forbids overlap and roofs over walls; a lane along the inside of every
  wall is Danzo's call.
- Bigger art for the windmill (32 x 48), longhouse and war hall (48 x 32): a drawing job for Danzo.
- `preview_tiles` is stale (a mockup scene, not shipped).

## Open from the last round

None: round 3's FIX and CONSIDER items were all taken in the `qa round 3` commit, except the two deliberately
deferred above (houses flush with walls; the big-art drawing job).

## For Danzo's Play (DevMode on)

1. Output starts with `[Map] seed 1, 256x256, villages:` and sixteen names, under a second.
2. You stand on the plaza: the stone gatehouse north-west, orange houses, the market awnings, the well, the windmill.
3. Walk out of the east double gate: a sign names the village that road reaches. Follow a two-tile road to a ford:
   its sign names a village on each bank, and the road continues on the far bank.
4. Walk into a forest: a darker floor, trees you weave between, never a wall of them. Walk into the hills: stony
   ground, scattered boulders, a few small crags, a cave mouth in one of them that you can walk up to.
5. Press M: the minimap fills the screen with sixteen markers (yellow farmers, green hunters, red raiders) and your
   white dot; press M again; open the bag and the minimap hides.
6. Step 3 is the next build: tribes that hold several villages, rosters by tier, the save format bump.
