# Art sources for the world expansion

Which free 16×16 packs can fill the bigger world, and what still has to be drawn by hand. The research was done
on 2026-10-05 in a regular Claude chat with web access: every licence was read on the pack's own page. Later the
same day a session on Danzo's PC **fetched all 15 packs and looked at every sheet**: see "Verified contents" below.
The cloud sessions cannot reach `kenney.nl` or `opengameart.org` (network policy), so fetching happens on Danzo's
PC. `fetch kenney` and `fetch opengameart <url>` work; the itch.io packs were pulled with itch's free-download
endpoint into `library/local/<code>/` (no browser needed) and indexed by hand with licence, author, url and credit.

The plan these feed: a 256 × 256 map with 16 villages (farmers 6, hunters 5, plunderers 5) in three sizes, and
the asset list in nine groups. That plan lives on the design board "World Expansion Plan" (claude.ai artifact,
private to Danzo); nothing in it is decided yet. Board 3 marks each NEW asset HAVE / BORROW / CHECK / DRAW using
the codes below: 27 have, 25 borrow, 13 check, 60 draw. **After looking (2026-10-05): 27 have, 61 borrow, 6 check,
31 draw.** The board itself still shows the old marks; this doc is the current list.

## Rules

- **CC0** is best. **CC-BY** and **OGA-BY** are fine with the credit line copied exactly into `docs/PUBLISH.md`.
- **Never** CC-BY-SA, GPL-only, non-commercial, "personal use", or an unclear licence.
- ⚠ "No redistribution" packs are risky on Roblox: anyone can pull an uploaded image back out. Avoid them.
- Borrowed art is recoloured to `library/palettes/lowlands.json` and tidied by hand so it matches the drawn sprites.
- `fetch` records every borrowed file in `library/index.json`. Re-check it before publishing.

## The packs (code as used on board 3)

| Code | Pack | Licence · credit | Covers |
|---|---|---|---|
| TT, TF | [Kenney Tiny Town](https://kenney.nl/assets/tiny-town) + [Tiny Farm](https://kenney.nl/assets/tiny-farm) | CC0 | farmer buildings, nature, props *(likely)* |
| RPG | [Kenney Roguelike/RPG pack](https://kenney.nl/assets/roguelike-rpg-pack) | CC0 | floors, walls, roofs, doors; beds, chairs, bookcases; trees, bushes; banners |
| KI, TD | [Kenney Roguelike Indoors](https://kenney.nl/assets/roguelike-indoors), [Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) | CC0 | furniture (some too modern); cellar, weapons, items |
| T16 | [Tiny 16: Basic](https://opengameart.org/content/tiny-16-basic) + [Buildings](https://opengameart.org/content/tiny-16-buildings) | CC-BY · Lanea Zimmerman; John Cheesman and Lanea Zimmerman | buildings, trees, `dead.png`, signs, items. DB16 palette, closest to our style |
| FW | [16x16 Fence and Well](https://opengameart.org/content/16x16-fence-and-well-tiny-16) | CC0 | well, fence in all positions |
| MW | [Mini World Sprites](https://merchant-shade.itch.io/16x16-mini-world-sprites) | CC0 | goblin hut, orc town hall, spike walls, tower, tombstones, dead trees, pines, rocks. **Map scale**: likely redraw bigger |
| OBJ | [Objects for 16x16 tilesets](https://opengameart.org/content/objects-for-16x16-tilesets) | CC-BY · "Art by MrBeast. Commissioned by OpenGameArt.org (http://opengameart.org)" | bones, rubble, burnt fire, bedroll, sheepskin, crate, stool, table |
| IND | [[16x16] Indoor RPG Tileset](https://opengameart.org/content/16x16-indoor-rpg-tileset) | CC-BY · armisius / tilation, link their page | walls, floors, doors, furniture, rugs (3/4 view) |
| PD | [16x16 Puny Dungeon](https://opengameart.org/content/16x16-puny-dungeon-tileset) | CC0 | cellar walls and floors, crates, animated torch |
| PW | [Puny World](https://merchant-shade.itch.io/16x16-puny-world) | CC0 | cliffs, rocks, rivers, overworld buildings |
| FOR | [16x16 Pixel Forest (free sample)](https://opengameart.org/content/free-sample-16x16-pixel-forest-tileset-%E2%80%93-top-down-rpg-style) | CC0 | terrain, trees, decorative tiles |
| ICO | [Shade Assorted RPG Icons](https://merchant-shade.itch.io/16x16-mixed-rpg-icons) + [Weapon Icons](https://merchant-shade.itch.io/free-16x16-weapon-rpg-icons) | CC0 | potions, food, spear, axes, knives, chests, camping sheet |
| ALX | [16x16 RPG Item Pack](https://alexs-assets.itch.io/16x16-rpg-item-pack) | CC0 | bows, scrolls, food, keys |

Also worth a look: [Ninja Adventure](https://pixel-boy.itch.io/ninja-adventure-asset-pack) (CC0, huge, Japanese
look so needs restyling), [DawnLike](https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181)
(CC-BY, credit DragonDePlatino and DawnBringer), [Sharm's 16x16 Forest Tiles](https://opengameart.org/content/16x16-forest-tiles)
(CC-BY, credit Sharm, surt, MrBeast), [Toen's Medieval Strategy pack](https://opengameart.org/content/toens-medieval-strategy-sprite-pack-v10-16x16)
(CC-BY 4.0, Andre Mari Coppola; ruins at map scale), [Ever Rogue](https://efilheim.itch.io/ever-rogue) (CC0).

Not fetched yet: Ninja Adventure and the "also worth a look" packs.

## Verified contents (looked at, 2026-10-05)

**Codes added:** TT is now Tiny Town alone; **TF** = Kenney Tiny Farm, **TD** = Kenney Tiny Dungeon, **KI** = Kenney
Roguelike Indoors. **Positions** are `(col,row)` from 0 on the 16 px grid; RPG and KI sheets have a 1 px gap (17 px
pitch). **View:** our own `hut.txt` is 3/4 (roof over a front wall), so 3/4 buildings fit; floors, terrain and
icons are top-down either way. "Map" = a whole building squeezed into 1 to 3 tiles.

| Code | Files in `library/` | What is really there | View |
|---|---|---|---|
| TT | `kenney/tiny-town/Tilemap__tilemap_packed.png` (+ one PNG per tile) | grass, dirt, trees (green, autumn), bush, mushrooms, wood fence set, sign, beehive, well, barrel, tools; roof, wall, door and window parts; castle wall and gate | 3/4 |
| TF | `kenney/tiny-farm/…packed.png` | tilled soil, crop stages, seed bags, crop crates, sacks, barrel, buckets, hay bales, troughs, barn walls + roof, dead branches, pine, farmers, sheep, cow, chicken | 3/4 |
| TD | `kenney/tiny-dungeon/…packed.png` | dungeon walls, doors, rubble, table, stool, **anvil**, shelf, chests, iron railing, barred crates, weapons, potions, heroes, monsters | 3/4 |
| RPG | `kenney/roguelike-rpg-pack/Spritesheet__roguelikeSheet_transparent.png` (57×31) | floors, paths, water, flower beds; walls and roofs in 4 materials; doors, windows; beds, tables, chairs, benches, counters with goods, market awnings, anvil, ovens, **fireplaces**, bookcases, **banners in orange/teal/green**, 2×2 tents, gold heaps, tombstones, statue, trees, **berry bushes**, mushrooms, dead tree, stumps, log, rocks, torches, mine carts | 3/4 |
| KI | `kenney/roguelike-indoors/…transparent.png` (27×18) | tables, chairs, beds, rugs, **washing line with clothes**, candles, wall torches, shields, ladder; some too modern (stoves, piano) | 3/4 |
| T16 | `opengameart/tiny-16-basic/basictiles_2.png`, `things_0.png`, `dead_1.png`; `tiny-16-buildings/buildings_10.png` | walls, floors, water, lava, well 1×2, bed, chest, pot, sign, braziers, pine, oak; doors, gates, levers, fireplaces. `dead_1` is **dead creatures and people**, not dead trees. Buildings = roof and wall parts only | 3/4 |
| FW | `opengameart/16x16-fence-and-well-tiny-16/` | fence posts and rails in all joins; the well is ~3×4 tiles, too big for one | 3/4 |
| OBJ | `opengameart/objects-for-16x16-tilesets/objects.png` (7×7) | campfire unlit, lit, burnt (0–2,0–2); sheepskin (3,0–1); bedroll (4,0); stool (3,2); table (4,2); barrels (0–1,3); rubble sticks (0–1,4); bones and skull (2–4,3–4); blood (5–6,*); crates (2,5), (0–1,6) | 3/4 |
| IND | `opengameart/16x16-indoor-rpg-tileset/all_in_one.png` | mostly big carpets; wood walls and floors, beds, shelf, chairs, tables, plants, barrels: thin | 3/4 |
| PD | `opengameart/16x16-puny-dungeon-tileset/punyworld-dungeon-tileset.png` (26×20) | stone walls and floors, **animated torch** (16–23,0), chests and crates (21–23,18–19), levers, gems, keys, traps | 3/4 |
| PW | `local/pw/PUNY_WORLD_v1__punyworld-overworld-tileset.png` (27×65) | grass and dirt autotiles, **raised cliffs** (0–3,4–6), cave mouths (19–20,4–5), pine forests, rivers, ponds, map-scale tents, huts, houses, castles, wells, signposts, docks | top-down / map |
| FOR | `opengameart/free-sample-…/Forest_Tileset_-_Free__*.png` | grass with flowers, grass-dirt and grass-water autotiles, two 4×4 trees, small bushes, rocks. Small sample | top-down |
| MW | `local/mw/` (207 files) | map-scale buildings in wood and 4 team colours; **SpearWall** (spiked stockade + gate), Tower, Barracks, **QuestBoard**, Well, Tombstones, Signs; DeadTrees (stumps + 2 dead trees), Pine, Trees, Rocks (grey, mossy, snow), Wheatfield, Objects (arrows, spear, axe). Units and animals. The orc town hall is only in a **preview image** (likely the paid pack): not borrowable | map, 3/4 |
| ICO | `local/ico/` | potions, books, chests, armour, mugs and jars (no real food); camping strip: tent, backpack, pot, bedroll, **herbs, rope**, compass; tavern strip: **meat** ×2, lute, coins, map; weapon sheets ×4 metals: swords, **spears** (cols 15–19, rows 0–9), axes, knives, sickles, bows | icon |
| ALX | `local/alx/16x16_RPG_Item_Pack__Sheet.png` (8×9, also one PNG each) | swords, spears, axes (row 1), **bows** (0–3,2), staves, shields, potions, **necklaces, rings** (0–3,4–5), scrolls, **map** (6,4), helmets, boots, armour, gloves, apple, cheese, egg, pie, keys, candle, goblet. **No arrows** | icon |

### The board's items, after looking

**BORROW, confirmed** (pack · file · position):

- **Farmer:** farmhouse 2×2: compose from TT roof (0–2,4–5) + wall/door (0–3,6–7), or T16 `buildings_10` roofs + walls ·
  well: T16 `basictiles` (7,3–4) or TT (8,7–8), 1×2 (FW's well is too big) · watchtower: MW `Wood__Tower` (1 wide,
  stackable) · fence: TT (8–11,3–6) (FW's posts are 2 tiles tall) · **barn: TF walls (6–8,7–10) + roof (9–11,6–10)** (was DRAW).
- **Hunter:** **hiring board: MW `Miscellaneous__QuestBoard`** (was DRAW).
- **Plunderer:** **tent: RPG 2×2 (46–49,10–11)**, map-scale 1×1 in PW (4–5,26) · **stockade wall, gate, spike barricade:
  MW `Enemy__SpearWall`** · **lookout tower: MW `Wood__Tower`** · **loot heap: RPG gold heaps (41–43,10–11)** (all were DRAW).
- **Rooms:** home, hall: RPG floors (5–9,0–5) + walls (13–56,12–24) · workshop, store room: IND wood floor/walls
  (0–5,18–21), thin · cellar: PD (0–7,0–8) · **trading room: RPG counters with goods (10–13,4–6) + awnings (10–11,0–3)**.
- **Furniture:** **hearth: RPG (54–55,6–10), T16 `things` (9–11,4–7)** · table: OBJ (4,2) · bench: RPG (18,4–5) · chest:
  PD (21–22,18), TD (5–8,7) · shelf: RPG bookcases (41–50,12–14) · barrels: TT (10,10), OBJ (0–1,3) · crates: OBJ
  (2,5) · **sacks: TF (2,6)** · **anvil: TD (2,6), RPG (15,0)** · **counter: RPG (10–13,4–6)** · banner: RPG (49–53,0–8) ·
  rug: IND carpets, KI (16–21,8–17) · hide rug: OBJ sheepskin (3,0–1).
- **Debris:** rubble: OBJ (0–1,4), TD (0,1–2) · bones: OBJ (2–4,3–4) · skull: OBJ (3,4) (T16 had none) · **fallen log:
  RPG (53,18), TT (10,8)** · **stump: RPG (53,19–20), MW `Nature__DeadTrees` (0–1,0)**.
- **Nature:** pine: RPG (16–18,9–11), TT (4,0–2) (MW's is tiny) · dead tree: MW `Nature__DeadTrees` (2–3,0), RPG
  (27,9–11) · bush: RPG (19,9) · **berry bush: RPG (23–24,9–11)** · flowers: RPG beds (0–4,6–14), TT (0,0) · **mushrooms:
  TT (5,2), RPG (48,2–7)** · boulder: MW `Nature__Rocks` · cliff edge: PW (0–3,4–6).
- **Props:** barrel: TT (10,10) · crate: OBJ (2,5) · **hay bale: TF (0–1,8)** · **washing line: KI (16–18,1–2)** · faction
  banners ×3: RPG orange, teal, green · **trough: TF (2–3,8–9)** · **beehive: TT (9,7)**.
- **Items:** bow: ALX (0–3,2) · **arrows: MW `Objects__ArrowShort`** (ALX has none) · spear: ICO weapons, ALX (0–2,1) ·
  **rope, herbs: ICO camping strip (5), (4)** · meat: ICO tavern strip (2–3) · **grain sack: TF (2,6)** · **trinket: ALX
  necklaces and rings (0–3,4–5)** · map scrap: ALX (6,4) · torch: PD (16–23,0).

**CHECK, still open** (a pack has something close; a look in context decides):

- palisade stake: MW SpearWall would make hunters and plunderers look alike.
- cage: TD barred crates (7–8,5) read as a cage only at a squint.
- ash pile: OBJ burnt campfire (0,0) may do.
- arrows in the ground: rotate MW's arrow and sink it?
- lily pad: RPG (28,10–11) look like floating leaves.
- lantern post: RPG torch posts (16–18,7–8), lanterns (51–52,16–17).

### Draw by hand (31)

- **Farmers:** town hall 3×3, granary, storehouse, knights post, windmill.
- **Hunters:** longhouse 3×2, trophy hall, tannery, drying rack, muster ring, smokehouse, lookout tree.
- **Plunderers:** war hall 3×2 (MW's orc hall is preview-only).
- **Rooms:** shrine (RPG statue and candles help), barracks; furniture: workbench, loom, weapon rack.
- **Debris:** broken wall, broken cart (only mine carts exist), broken fence, scorched ground, abandoned tent.
- **Nature:** reeds, chimney smoke, fireflies, crows.
- **Props:** cart, woodpile, scarecrow. **Items:** cloth.

## Rejected (so nobody re-checks them)

- **Non-commercial free tier:** Sprout Lands, Mystic Woods, Cozy Farm, Cozy Town, Tiny Wonder Farm, Cute Fantasy RPG,
  The Fan-tasy Tileset. **Paid for commercial use:** Top-Down Retro Interior.
- **CC-BY-SA or GPL only:** Jerom's and Eiyeron's 16x16 Fantasy tilesets, 16Pixel's packs, hilau's RPG tileset, Interior Tileset 16x16.
- **No or unclear licence:** Pixel Crawler, (FREE) Village Top Down, Tiny Village Pack, Terrible Campsite, Free Ruined Village Buildings.
- **Wrong size or style:** Shikashi's Fantasy Icons, Basic Camp, Stealthix RPG Nature, Cainos (32×32); Tiny Swords
  (64×64); Kenney Micro Roguelike (8×8); Kenney Medieval RTS (vector); Kenney Tiny Battle (modern); Hexany (1-bit).
- **⚠ No redistribution or unclear on modding:** Rogue Fantasy Catacombs, Top-Down Forest Tileset, Pixel Lands, Solaria.
  Serene Village (LimeZu) shows only a CC BY 4.0 badge with no written licence: ask before using.
