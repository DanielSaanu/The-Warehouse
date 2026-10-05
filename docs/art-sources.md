# Art sources for the world expansion

Which free 16×16 packs can fill the bigger world, and what still has to be drawn by hand. The research was done
on 2026-10-05 in a regular Claude chat with web access: every licence was read on the pack's own page, but **no
preview image was looked at**, so contents marked *(likely)* or CHECK are unconfirmed until someone opens the pack.
The cloud sessions cannot reach `kenney.nl` or `opengameart.org` (network policy), so fetching happens on Danzo's
PC or after those hosts are allowed.

The plan these feed: a 256 × 256 map with 16 villages (farmers 6, hunters 5, plunderers 5) in three sizes, and
the asset list in nine groups. That plan lives on the design board "World Expansion Plan" (claude.ai artifact,
private to Danzo); nothing in it is decided yet. Board 3 marks each NEW asset HAVE / BORROW / CHECK / DRAW using
the codes below: 27 have, 25 borrow, 13 check, 60 draw.

## Rules

- **CC0** is best. **CC-BY** and **OGA-BY** are fine with the credit line copied exactly into `docs/PUBLISH.md`.
- **Never** CC-BY-SA, GPL-only, non-commercial, "personal use", or an unclear licence.
- ⚠ "No redistribution" packs are risky on Roblox: anyone can pull an uploaded image back out. Avoid them.
- Borrowed art is recoloured to `library/palettes/lowlands.json` and tidied by hand so it matches the drawn sprites.
- `fetch` records every borrowed file in `library/index.json`. Re-check it before publishing.

## The packs (code as used on board 3)

| Code | Pack | Licence · credit | Covers |
|---|---|---|---|
| TT | [Kenney Tiny Town](https://kenney.nl/assets/tiny-town) + [Tiny Farm](https://kenney.nl/assets/tiny-farm) | CC0 | farmer buildings, nature, props *(likely)* |
| RPG | [Kenney Roguelike/RPG pack](https://kenney.nl/assets/roguelike-rpg-pack) | CC0 | floors, walls, roofs, doors; beds, chairs, bookcases; trees, bushes; banners |
| — | [Kenney Roguelike Indoors](https://kenney.nl/assets/roguelike-indoors), [Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) | CC0 | furniture (some too modern); cellar, weapons, items |
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

**Download first:** TT (with Tiny Farm and Tiny Dungeon), Ninja Adventure, T16 + FW, MW, OBJ. Then RPG and ICO.

## Gaps: draw by hand

No pack names these. Look at the TT and Ninja Adventure previews before drawing, in case they turn up.

- **Hunters: all of it.** Longhouse, trophy hall, tannery, drying rack, hiring board, palisade, smokehouse, lookout tree.
- **Plunderers:** 16×16 tent, stockade wall and gate, lookout tower, cage, loot heap.
- **Farmers:** windmill, granary, storehouse, barn, knights post, town hall.
- **Rooms:** shrine, trading room, barracks; furniture: hearth, anvil, workbench, loom, counter, weapon rack, sacks.
- **Debris:** broken wall, cart and fence, scorched ground, ash, abandoned tent, fallen log, stump, arrows in the ground.
- **Nature and props:** berry bush, mushrooms, reeds, lily pad, smoke, fireflies, crows; hay bale, woodpile, lantern
  post, washing line, scarecrow, trough, beehive, cart.
- **Items:** rope, herbs, grain sack, cloth, trinket (Shikashi's pack has most of these, but at 32×32).

## Rejected (so nobody re-checks them)

- **Non-commercial free tier:** Sprout Lands, Mystic Woods, Cozy Farm, Cozy Town, Tiny Wonder Farm, Cute Fantasy RPG,
  The Fan-tasy Tileset. **Paid for commercial use:** Top-Down Retro Interior.
- **CC-BY-SA or GPL only:** Jerom's and Eiyeron's 16x16 Fantasy tilesets, 16Pixel's packs, hilau's RPG tileset, Interior Tileset 16x16.
- **No or unclear licence:** Pixel Crawler, (FREE) Village Top Down, Tiny Village Pack, Terrible Campsite, Free Ruined Village Buildings.
- **Wrong size or style:** Shikashi's Fantasy Icons, Basic Camp, Stealthix RPG Nature, Cainos (32×32); Tiny Swords
  (64×64); Kenney Micro Roguelike (8×8); Kenney Medieval RTS (vector); Kenney Tiny Battle (modern); Hexany (1-bit).
- **⚠ No redistribution or unclear on modding:** Rogue Fantasy Catacombs, Top-Down Forest Tileset, Pixel Lands, Solaria.
  Serene Village (LimeZu) shows only a CC BY 4.0 badge with no written licence: ask before using.
