# The Warehouse — and Lowlands, the game it builds

**Lowlands** is a 2D top-down pixel-art Roblox game: a living world of farmers, hunters and raiders who remember
what you do. Design: **[docs/DESIGN.md](docs/DESIGN.md)**. What is being built next:
**[docs/RUNG3.md](docs/RUNG3.md)**. Getting it in front of people: **[docs/PUBLISH.md](docs/PUBLISH.md)**.

**The Warehouse** is the asset pipeline underneath it: a place to quickly piece together game assets and ship them
into that game.

This repo is for Claude and a human to work on art together. The human works in a browser UI, Claude works
from the terminal, and both edit the same small files.

```
 free asset sources ──┐
 (Kenney, OpenGameArt,│      scenes/*.json        exports/roblox/sheet_0.png
  game-icons, LoSpec) ├──►   sprites/*.txt   ──►  roblox/src/shared/Sprites.lua  ──► Roblox Studio (via Rojo)
 hand-drawn pixels ───┘      ideas/INBOX.md                 ▲
                                    ▲                       │ Open Cloud upload
              browser UI ───────────┤                       │
              Claude (CLI) ─────────┘
```

## Quick start

```bash
npm install
npm start                      # UI at http://localhost:4242
npx warehouse help             # every CLI command
```

Roblox side (Rojo, API key, upload): see **[docs/ROBLOX_SETUP.md](docs/ROBLOX_SETUP.md)**.
Publishing Lowlands and the credits it owes: see **[docs/PUBLISH.md](docs/PUBLISH.md)**.

## What is in the box

- **Sources** (`src/sources/`): Kenney CC0 packs, OpenGameArt, game-icons.net, LoSpec palettes, curated free
  fonts, and your own drops. Everything fetched lands in `library/` with its license in `library/index.json`.
- **Scenes** (`scenes/*.json`): a small JSON that says "16x16 canvas, this sprite here, flipped, recolored,
  outlined, this text on top". One file per sprite. Nest scenes inside scenes.
- **Pixel-text sprites** (`sprites/*.txt`): draw sprites as characters, one per pixel. Human-readable,
  diff-able, and something Claude can draw and read.
- **Renderer** (`src/render.js`): one Canvas 2D renderer that runs identically in the browser and in node.
  Effects: crop (slice sprite sheets), scale, rotate, flip, opacity, tint, hue/sat/brightness, recolor map,
  pixel outline, shadow, blend modes, text with real fonts, shapes with gradients.
- **UI** (`ui/`): search sources, drag layers on a zoomable pixel canvas, pixel editor, palette snapping, and an
  **ideas pad** that is literally `ideas/INBOX.md`. The UI reloads a scene when its file changes on disk, so when
  Claude edits a scene you see it.
- **Sprite sheets + Lua** (`src/sheet.js`): packs every scene into 1024-max sheets and generates
  `Sprites.lua` with `ImageRectOffset/Size` for each sprite, plus `Sprites.New` / `Sprites.Apply` helpers.
- **Roblox upload** (`src/roblox.js`): Open Cloud Assets API, with a lock file so unchanged sheets are never re-uploaded.
- **Rojo project** (`roblox/`): a seeded 96x96 world generator (river, lake, forest, caves, three villages,
  roads by A*), a scrolling pixel viewport, server-validated movement with client prediction, day/night clock.
  The design lives in `docs/DESIGN.md`.

## CLI cheat sheet

```bash
npx warehouse search kenney tiny            # find packs
npx warehouse fetch kenney tiny-dungeon     # download a CC0 pack into library/kenney/tiny-dungeon/
npx warehouse search gameicons potion       # icons
npx warehouse search lospec dungeon         # palettes
npx warehouse new slug_walk_0 16 16         # empty scene
npx warehouse render slug_idle --scale 8    # -> exports/slug_idle@8x.png
npx warehouse ascii slug_idle               # print the sprite as pixel-text
npx warehouse totxt library/x.png -o sprites/x.txt   # turn a small PNG into an editable pixel-text sprite
npx warehouse roblox build [--upload]       # sheet + Sprites.lua (+ upload with .env configured)
npm test                                    # renderer/packer tests + Luau tests (needs tools/luau/, see CLAUDE.md)
npm run preview:world                       # paint the generated world into exports/world_1.png
```

## Layout

```
bin/warehouse.js      CLI entry
src/                  renderer, scene format, sources, packer, roblox, server
ui/                   browser UI (no build step)
scenes/               composed sprites (the sprite name = file name)
sprites/              hand-drawn pixel-text sprites
ideas/                the shared scratchpad (INBOX.md)
library/              fetched assets + index.json with licenses
exports/              rendered PNGs and the Roblox sheet (ignored by git)
roblox/               Rojo project: default.project.json + src/{shared,client,server}
docs/                 setup guides
```

## Licenses of borrowed things

CC0 (Kenney) needs nothing. CC-BY (game-icons.net, many OpenGameArt entries) needs a credit line in your
game's description. `library/index.json` remembers who to credit. Fonts are OFL/Apache and fine to bake into images.

Code in this repo: MIT.
