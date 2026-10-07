# QA round 3: world expansion step 2 — SCORE 8/10

Reviewer: Opus subagent, 2026-10-07, no Studio (cloud session). Reviewed HEAD ea153ed. Goals: `docs/qa/world-expansion-p2.md`.

## Report (verbatim)

I reviewed HEAD ea153ed (`git diff 97d7cc1..HEAD`). **Studio was not available, so nothing here was seen running in Roblox.** I changed no tracked files.

**What I ran:**
- `npm test`: 13/13 node tests pass and every Luau test is green. `lint:luau` is clean.
- Rojo build succeeds. No `roblox/` file was added since round 2, so the tree is the shape round 2 verified.
- Generation takes 573–711 ms per seed in the luau CLI.
- My own Luau probes over seeds 1, 7, 42, 2026, 3, 99 and 123456 (scratchpad).

**Player view:**
- The spawn is a strong first screen (`view_60_186@5x.png`): a plaza, a stone gatehouse hall, orange Kenney houses, the market, the windmill.
- The night tint keeps everything readable (`view_60_186_night@5x.png`).
- The town has a corner tower at every unbreached corner, double gates, three exit signs, and a breach you can read (`world_1_40_168_80_200@3x.png`).
- The great lodge (`world_1_194_128_218_152@3x.png`) and the stronghold (`world_1_98_12_120_34@3x.png`) each look like their tribe.
- The town-to-lodge road is now 189 tiles against 189 tiles walking straight (it was 449).
- Seen whole, `world_1.png` reads as three countries.

**What hurts:**
- **Straight walls of identical boulders across the hills** (`world_1_164_26_196_44@3x.png`: rows y=28, 35, 42). Rock components over 12 tiles still exist on every seed: 18 tiles in a line at 171–188,35 on seed 1, and 34 tiles at 212–245,7 on seed 42.
- **Signs that contradict the road.** Glenmouth's east-side sign at 109,163 says "Ulfmere, west", but the road there runs east to the ford and the great lodge. No sign anywhere near the start names the great lodge, which is the first goal's destination.

SCORE: 8/10

GOALS:
- 256x256, server runs on it: met - `Config.lua:14-15`, `WorldGen.DEFAULT_*`, OFFSET 33, `Map.lua:21-29` prints the ms; Studio timing and the 131 KB WorldInit are unverified.
- Sixteen villages from one list: met - the `PLANS` order and tier counts are asserted, and villages [1..3] have 6, 0 and 4 gates (`worldgen.test.luau:116-118`).
- Layouts as data + check: met - `WorldPlans.check` covers footprints, the sealed-pocket flood and the roof rule (`OVERHANG`/`BEHIND_OK`); all 9 layouts and 5 place stamps pass.
- Multi-tile objects whole: met - the seven-seed test finds no hole and no orphan part (`worldgen.test.luau:155-178`).
- Renderer draws them: met (from the code) - `Viewport.lua:154-180` sizes by W/H, puts the bottom-left on the anchor, sets ZIndex=ty and hides `part` tiles; 427/430 lines.
- Roads a tree, two wide, signs: partial - the tree, the capitals' roads and fords with road on both banks hold; but exit signs can name the wrong way, and the stronghold's unused north gate loops back south.
- Places between villages: met - 14–16 per seed, at least 3 of every kind except battlefields (2–3), grass only, shrine one tile off the road, 5 caves on every seed.
- Three countries, all walkable: partial - forests are perfect (0 trees side by side, 0 diagonal; 15–78 unreachable tiles out of ~57k), but the crag thinning makes long rows of rock.
- Save path: met - `Save.lua:272-274` returns nil for a tile saved in another world; `GEN_VERSION` 2; `Save.VERSION` unchanged.
- Nothing regresses: met - green and lint-clean; WorldGen is 207 lines and its allow-list entry is gone.
- Minimap: met (from the code) - 32x32 cells, tribe markers with a 5 px minimum, M or a tap toggles, hidden while a panel is open (`Client.client.lua:624`).
- Capitals grand: met - double gates, two-tile streets, a plaza, corner towers on both walled capitals.
- Houses real houses: partial - 48x48 Kenney houses in the right colours, a 3x2 burnt shell, a 64x48 castle, nothing stretched. But houses sit flush against walls: town `h==W` in rows 3, 7 and 11, the stronghold's east side, and both sides of the stockade camp. Read literally, "no house touches a wall" is not met.

PRESERVE:
- **ASCII layouts plus `WorldPlans.check`, now with the roof rule:** the layouts are data anyone can read, and a test can prove them right.
- **Anchor-plus-`part` footprints:** A*, walking, `villageAt` and the save need no special case.
- **`carveRoad` never widens onto water, and a ford counts only with road on both banks:** no fake crossings remain, and the test enforces it.
- **The forest lattice that refuses side-by-side and diagonal trees:** forests are dense to look at and always walkable.
- **The king's roads (`WorldRoads.lua:229-237`):** they made the first walk direct.
- **`tools/mapfile.js` reads OFFSET and sprites from the Lua sources:** the previews cannot drift from the game.

FIX:
- **Crag thinning keeps whole rows** (`WorldLand.lua:174`). `(cx * 7 + cy * 13) % 7 == 0` comes down to `cy % 7 == 0`, because `cx * 7` is always a multiple of 7. So every big block keeps every seventh row as a solid wall of up to 34 boulders, the "wall of identical boulders" the comment says it removes. -> Use a hash that mixes x and y, for example `(cx * 7 + cy * 13) % 11 == 0` or an Rng draw at ~10%. Then re-flood and cap any surviving component. Add a test that every non-border rock component is at most 12 tiles.
- **Exit signs walk around their own village** (`WorldSigns.lua:95-126`). The BFS only refuses tiles inside `v` (margin 0), so from an exit it follows the ring road around the village and names the nearest village in any direction. At Glenmouth on seed 1, three exits say "Ulfmere, west", including the east exit at 109,163. Thornwick's three north signs within 9 tiles (88/94/97,217) are the same pattern. -> Treat tiles within `villageAt(v, 2)` as closed except the exit's own continuation, so the walk must leave the village first. Then assert that each sign's target is reached through the exit it stands at.
- **The stronghold's north gate road loops around its own wall** on every seed. The gate faces the map edge, so the "nearest road tile" stub (`WorldRoads.lua:270-290`) runs west and then south outside the palisade to the south road. Its sign at 106,14 says "Salt Den, south-east". -> Search for the stub's target only in the half-plane the gate faces, or end the stub at a place/cave stamped beyond it, or drop the north gate from the layout.

CONSIDER:
- **Exit signs land inside walls.** The stronghold's south sign is always inside, at 105,30 (Storm Den 197,43 and others too), because `putSign`'s radius-2 ring reaches past the wall. -> Accept only spots on the gate's outer side.
- **Roads under roofs at village edges.** On seed 1, Thornwick's top house at 96,220 hangs its roof over the road on row 218, so the player walks over the roof. -> Have `carveRoad` treat overhang rows of village houses as costly, or pad layouts whose top row holds a house.
- **Houses flush with walls.** -> Confirm with Danzo whether "touch" means overlap (what `check` enforces) or sharing an edge; if it is the edge, add a one-tile margin to `check`.
- **The minimap player dot is ~2 px on a phone** (`Minimap.lua:113`, scale 0.02). -> Give it a 4–5 px minimum, as the markers have.
- **The debug ascii reuses letters.** `ascii` prints hay as 'H' (same as a house) and boulders as 'B' (same as a burnt house), which makes debugging ambiguous. -> Give them their own glyphs.

UNCERTAIN:
- Generation time, WorldInit delivery and client decode in real Studio.
- Minimap layering and its tap target against the Roblox topbar on a real phone.
- The Objects-layer y-sort for equal ZIndex, and tall sprites at the pool's edge (MARGIN 3), judged from the code only.
- Two players, or a player leaving mid-move, on the 256² map.
- How the not-yet-uploaded sheet looks with the new rects.

## Builder decisions

The target (8.0) was reached; the loop ends after this round. The FIX items were cheap and clearly right, so they
were taken anyway; the CONSIDER items that cost a line each too.

**FIX, done**
- Crag thinning uses a hash that mixes x and y with a product term, and runs twice so no component over 12 tiles
  survives; the worldgen test asserts every rock component away from the border is at most 12 tiles (cave mounds are 6).
- Exit signs: the road walk may only move outward (or sideways) while within three tiles of the village, so it must
  leave through its own exit before it can touch any other village; a sign spot for a village exit must be outside
  the village's footprint.
- Spare gates look for a road only in the half-plane they face; a gate facing nothing but hills keeps a one-tile
  stub and its sign names the nearest village in that half-plane (a direction across country, honestly).

**CONSIDER, taken**
- Open layouts whose top row held a house got a clear row above it, so no road passes under a roof at a village edge.
- The minimap's player dot has a 5 px minimum, like the markers.
- `ascii` prints unlisted solid objects as `*` and decor as `'`, so no letter is shared.

**CONSIDER, deferred / for Danzo**
- Houses flush with walls: `check` forbids a roof over a wall and any overlap; a house sharing an edge with the wall
  is how the walled layouts fit. If Danzo wants a one-tile lane along the inside of every wall, say so and the
  check gets a margin rule.
