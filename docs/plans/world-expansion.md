# World expansion: the bigger map, more villages, big buildings

**Status:** approved to build 2026-10-07 (Danzo), branch `world-expansion` (cut from `rung3-part4-p2` at 65d3c1f).
**Step 2 built 2026-10-07 (Fable)**: the 256 x 256 map, sixteen villages from `WorldPlans`, the road tree, the places,
multi-tile buildings in the renderer, previews, tests (`docs/qa/world-expansion-p2.md` is the goals file). Steps 3–4 open.
Handoff H13. Copied from Danzo's private design board "World Expansion Plan" (claude.ai artifact, 2026-10-05) so
every session can read it; the board is now a picture of this doc, not the source.

**Why:** Danzo, 2026-10-07: pause the first-week and toys work (H12) and "focus on adding more elements that make
the world entertaining to be in … start with the map and buildings". The end goal is a **Pokemon-style open world**:
villages with real buildings, forests, places that look different (INBOX 2026-10-06). Interiors come later.

## Danzo's calls (2026-10-07)

| Question (board "Your calls before phase 2") | Answer |
|---|---|
| Map size | **256 × 256** (about 7x today's 96 x 96) |
| Village count | **16**: farmers 6, hunters 5, plunderers 5, in three sizes |
| Rooms / interiors | **Later.** This round is big outsides: multi-tile buildings and the bigger map |
| Names | Not asked; WorldGen already names villages, so real names (routine call) |

## The map (board 1)

- 256 x 256 tiles, 16 x 16 regions. The river splits the map north to south, with about three fords.
- **Farmers, 6**, south-west lowlands and farmland: 1 walled town (large), 2 villages (mid), 3 hamlets (small).
- **Hunters, 5**, eastern forests: 1 great lodge (large), 2 lodges (mid), 2 camps (small).
- **Plunderers, 5**, northern hills: 1 stronghold (large), 1 camp (mid), 3 hideouts near the roads (small).
- Sizes: large 14 tiles across, mid 9, small 5.
- Land: forest, hills, marsh, farmland, river with fords.
- Roads: a road **tree** between neighbouring villages, not all-to-all.
- **Places between villages** (the ruins and debris art lives here): a burnt village, a ruined watchtower, an
  abandoned camp, a cave, a roadside shrine, an old battlefield.
- The board's positions are a sketch to react to: WorldGen places villages from a list with a spacing rule.

Sketch positions (x, y on 256 x 256), for reference only:
F1 L 58,188 · F2 M 100,218 · F3 M 42,132 · F4 S 20,228 · F5 S 108,168 · F6 S 78,244 ·
H1 L 205,140 · H2 M 226,200 · H3 M 176,92 · H4 S 240,98 · H5 S 192,236 ·
P1 L 108,24 · P2 M 196,40 · P3 S 40,70 · P4 S 156,72 · P5 S 240,20.

## Village tiers (board 2)

| Faction | Small | Mid | Large |
|---|---|---|---|
| Farmers | **Hamlet** x3: 3–4 huts, one field, a well. No walls. Pays tax to the town. No caravans | **Village** x2: 6–8 huts, fields, a market stall, a store. The richest runs caravans | **Walled town** x1: walls and a gate, a hall, a market row, a knights post. Collects tax, sends processions |
| Hunters | **Camp** x2: 2–3 huts, a drying rack, a fire pit. One squad | **Lodge** x2: 5–6 huts, a tannery, a totem, a muster ground | **Great lodge** x1: a longhouse, a trophy hall, a hiring board. Sends hunting parties |
| Plunderers | **Hideout** x3: 2 tents, a skull post, a loot pile, near a road | **Camp** x1: 4–6 huts in a stockade, a lookout, stolen goods | **Stronghold** x1: a palisade with towers, a war hall, cages, loot heaps. Bands roam from here |

Tax, processions, hiring boards and hunting parties are **behaviour for later rungs**: this round places the
buildings that will hold them, and must not invent the behaviour.

Large-village layouts from the board (one character per 16 x 16 tile; `#` wall, `G` gate, `h` hut, `H` hall,
`k` store, `f` field, `s` stall, `n` knights post, `w` well, `p` path, `c` fire, `t` totem/skulls, `T` tree,
`r` rack/tent, `x` loot/debris, `o` lookout, `.` grass):

```
Farmer walled town   Hunter great lodge   Plunderer stronghold
################     TTT..TTTTTT..TTT     ..o##########o..
#ffff.hh.hh.fff#     T..hh......hh..T     ..#..rr..rr..#..
#ffff.hh.hh.fff#     T..hh.r..r.hh..T     ..#..rr..rr..#..
#.....pppp.....#     .......pp.......     ..#....pp....#..
#hh.kkpHHHp.hh.#     T.r...pppp...r.T     ..#.hh.pp.hh.#..
#hh.kkpHHHp.hh.#     T....HHHHHH....T     ..#.hh.pp.hh.#..
#pppppppppppppp#     TT...HHHHHH...TT     ..#..HHHHHH..#..
#.ss.ss.w.ss.hh#     T.hh..pccp..hh.T     ..#..HHHHHH..#..
#.....p.....hh.#     T.hh..pccp..hh.T     ..#t..pccp..t#..
#hh.n.p.hh.ffff#     ......pppp......     ..#xx.pccp.xx#..
#hh...p.hh.ffff#     T.r.t..pp..t.r.T     ..#xx..pp..xx#..
#.....p........#     T.....kkpp.....T     ..#.hh.pp.hh.#..
#ffff.p.hh.ffff#     T.hh..kkp...hh.T     ..#.hh.pp.hh.#..
#ffff.p.hh.ffff#     TT......p.....TT     ..o####GG####o..
#.....p........#     TTTTTT..p..TTTTT     .......pp...t...
######G#########                          .......pp.......
```

## The art (board 3 and `docs/art-sources.md`)

Drawn and borrowed on 2026-10-05 (commits 1d4098e, bc183f3): 31 hand-drawn assets (hunter buildings, farmer town
hall / granary / storehouse / knights post / windmill, plunderer war hall, furniture, debris, ambience animations,
cart, woodpile, scarecrow) and 89 crops from the CC0/CC-BY packs. **All are `export: false` today**, so none are
in the Roblox sheet. `scenes/preview_expansion_art.json` and `scenes/preview_borrowed.json` show them.
Halls are 2x2 to 3x3 tiles: **multi-tile sprites are new for the renderer** (INBOX 2026-10-06: "not everything
should be a 16x16 sprite"). CC-BY credit lines must reach `docs/PUBLISH.md`.

## Build order (board 4)

1. **Draw the assets.** Done 2026-10-05 (above). Left: choose which go in the sheet and flip `export`.
2. **Bigger map, list of villages.** WorldGen places villages from a list with a spacing rule, joins them with a
   road tree, adds the new land types and the places between villages. `shared/WorldGen.lua` (trigger 2).
3. **Many villages per tribe.** Today village 1 is always the farmers; a tribe holds a list of villages. Changes
   the save format, so the world resets (fine: development mode since 2026-10-05). `Save.lua`, `Sim.lua`,
   `Bands.lua` (trigger 3).
4. **Make it hold at scale.** Send the map region by region if needed, cache routes between villages, a lookup
   grid for which village a tile belongs to. The costs are listed per system in `docs/systems/*.md` "Expansion:
   deficits at scale" (trigger 6).

Plus, for the Pokemon feel this round: **multi-tile buildings** drawn and placed in the villages (renderer and
sprite/scene format: trigger 2), and the board's large-village layouts used as the shape of each tier.

## Not in this round

Interiors and floors (Danzo: later). The H12 first-week and toys work (paused). Tax, processions, hiring and
hunting-party behaviour. Rung 3 part 4 phases 3–4.

## Build notes for step 2 (Fable, 2026-10-07)

**Built as written below, same day, after the crash.** What differs from the notes: the sheet still fits one 256 x 512
image (177 sprites), not a second 1024; the places' margin ring may touch road (the shrine stands beside one; with a
strict ring nothing was ever placed and the cycle never advanced, which the "one of each kind" test caught); the
sim/tick/gossip tests that pinned 3 villages, 36 regions and 6 gossip holders now scale with the world. Generation is
~300–400 ms at 256² in the standalone interpreter. Known limits to carry into QA: the server rosters 16 villages with
the old roster; a spare gate's road may run along the outside of a palisade to reach the network; entities draw above
roof overhangs.

Decisions taken (and kept):

- **Modules**: `WorldPlans.lua` (pure data: the ASCII layouts and their legend), `WorldVillages.lua` (placement +
  stamping), `WorldPlaces.lua` (the places between villages). `WorldGen.lua` becomes a thin hub (< 400 lines, so its
  allow-list entry in `test/structure.test.js` goes): re-exports every Grid function under its old names (`index`,
  `inBounds`, `ground`, `object`, `walkable`, `nearestWalkable`, `villageAt`, `reachable`, `REGION`, `region*`),
  keeps `compass`, `floodTiles`/`setFlood`/`clearFlood`, `encode`/`decode`, `ascii`, and `route = WorldRoads.route`.
- **Generate order**: `WorldLand.build` → `WorldVillages.build` (rng fork 9) → `WorldLand.fords` (fork 10) →
  `WorldRoads.build` → `WorldPlaces.build` (fork 11) → `WorldLand.caves` (fork 8) → `WorldLand.finishRiver` →
  `WorldRoads.signs(world, WorldGen.compass)`. `GEN_VERSION = 2`, `DEFAULT_WIDTH/HEIGHT = 256`, `Config.WORLD_*` = 256.
- **Encoding**: `OFFSET` 48 → **33** (ids now reach 83; 83 + 48 is not ASCII and would not survive JSON). Save
  stores only the seed, so the version bump is the whole migration (development mode).
- **Village order rule (keeps the server running before step 3)**: `villages[1]` = the farmer walled town (the start,
  plundered: two burnt huts and a breach in the SW corner, gates N, E, S), `[2]` = the hunter great lodge, `[3]` =
  the plunderer stronghold, then the other 13 from the sketch list. `Sim.initTribes` will make 16 tribes with the
  old roster; rostering by tier is step 3.
- **Placement**: sketch positions scaled by w/256, h/256, nudged (jitter growing from ±4 to ±8, up to 60 tries) until
  the footprint + 2 has no water and is ≥ 4 tiles clear of every placed village. Names from `Names.place` with the
  `taken` list (21 x 15 combos, enough for 16).
- **Template legend** (one char per tile; multi-tile objects by their bottom-left ANCHOR, the rest `=`, placed with
  `Grid.place`): ground `.` grass `,` tall `p` path `@` spawn `F` farm `Z` scorched; `W` wall `G` gate `P` palisade
  `Q` palisade gate (a gate on the template edge exits outward); singles `h` hut (tribe's) `B` burnt hut `S` stall
  (exactly one) `b` bed (exactly one) `w` well `c` firepit `k` knights post `o` watchtower `s` smokehouse `d` drying
  rack `x` loot heap `g` cage `n` hiring board `l` lantern `y` hay `v` woodpile `e` scarecrow `i` beehive `m` awning
  `t` landmark (totem / skull post) `T` tree (tree / pine / dead tree) `R` boulder `D` rubble; anchors `A` hall
  (town_hall / longhouse / war_hall, 3x2) `1` granary `2` storehouse `3` tannery `4` trophy hall `5` windmill
  `7` lookout tree `8` tent `9` muster ring (all 2x2). A test must check every `=` is covered by exactly one footprint.
  Sizes: large 16x16 (farmer, hunter) and 12x14 (stronghold), mid 10x9, small 7x6.
- **Places**: scan road tiles ≥ 8 from any village, pick spots 2-5 tiles off the road (the shrine 1 tile off), no
  water or road in the stamp, ≥ 30 tiles between places; cycle shrine, burnt village, ruined watchtower, abandoned
  camp, battlefield; count = max(5, number of villages). Caves stay in WorldLand.
- **Renderer** (`client/Viewport.lua`, at its 430 ceiling): in `assign`, a sprite with `W`/`H` over 16 is sized
  `W/16 x H/16` cells, positioned with its bottom-left on the anchor tile, `ZIndex = ty` so the south draws over the
  north; `part` (sprite "") hides the slot. Pay for the ~7 lines by one-lining `getEntity`, `setMarker`,
  `repaintAll`, `setNight`. Known limit: entities draw above roof overhangs (no entity/object y-sort yet).
- **Previews**: the worldgen test prints `MAPFILE world_1` as `IDS w h sx sy` + the two encoded strings;
  `tools/preview-world.js` and `preview-view.js` decode with OFFSET parsed from WorldGen.lua, map ids to sprite names by
  parsing `TileTypes.lua`, and draw multi-tile sprites bottom-left anchored, north rows first.
- **Sheet**: remove `"export": false` from every scene a `TileTypes` sprite names, `roblox build` (a second 1024 sheet
  is expected), Danzo uploads and commits `Sprites.lua` + `assets.lock.json`.
- **Then**: tests (256 x 256, 16 villages, template validator, `WorldRoads.edges` connected), LOOK at the previews,
  Studio via the MCP, the goals file `docs/qa/world-expansion-p2.md`, the QA loop.
