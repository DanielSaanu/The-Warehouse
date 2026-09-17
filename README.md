# The Warehouse

A place to quickly piece together game assets, and the pipeline that ships them into a Roblox game.

This repo is for Claude and a human to work on art together. The human works in a browser UI, Claude works
from the terminal, and both edit the same small files. First target: a 2D, top-down, pixel-art Roblox game.

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

**Just want to press Play?** Download [`exports/roblox/TheWarehouse.rbxmx`](exports/roblox/TheWarehouse.rbxmx),
right-click **Workspace** in Studio's Explorer > **Insert from File**, press Play. No Rojo, no API key: the model carries the
code and the sprite pixels. Full pipeline (Rojo live sync, API key, uploads): **[docs/ROBLOX_SETUP.md](docs/ROBLOX_SETUP.md)**.

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
- **No-upload dev path** (`SheetData.lua` + `src/rbxmx.js`): the sheet's pixels are embedded in a Lua module and
  rebuilt at runtime with EditableImage; every build also emits a `.rbxmx` model (insert into any place) and a
  `.rbxlx` place, generated straight from the Rojo project without needing Rojo.
- **Rojo project** (`roblox/`): `Grid.lua` (a screen-filling tile grid that keeps pixels crisp), a first
  playable client (walled room, WASD/tap movement, rain overlay) and a server world clock.

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
npx warehouse roblox build [--upload]       # sheet + Sprites.lua + SheetData.lua + TheWarehouse.rbxmx (+ upload with .env)
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
