# The art pipeline (The Warehouse, node)

**What it does.** Draw sprites as pixel text, compose them into scenes, pack a sheet, and ship it to Roblox as
`shared/Sprites.lua` plus an uploaded image. The browser UI (`npm start`) and the CLI edit the same files.

**Key files**
- `bin/warehouse.js` is the CLI (`scenes`, `render`, `ascii`, `search`, `fetch`, `roblox build`).
- `src/pixels.js` defines the sprite text format, `src/scene.js` the scene format, and `src/render.js` the
  renderer (the same code in the browser and in node).
- `src/sheet.js` and `src/roblox.js` pack and upload the sheet. `src/library.js` and `src/sources/` borrow CC0
  and CC-BY assets.
- `sprites/*.txt`, `scenes/*.json`, `library/index.json` hold the art itself and licences.

**Gotchas**
- `roblox/src/shared/Sprites.lua` and `roblox/assets.lock.json` are generated and committed. Never hand-edit them.
  Only Danzo uploads (`roblox build --upload`).
- After any art change, render it and LOOK at it (`render <scene> --scale 8`, then Read the PNG).
- Changing `render.js`, `pixels.js` or `scene.js` is escalation trigger 2.
- Full setup: [`docs/ROBLOX_SETUP.md`](../ROBLOX_SETUP.md). Publishing: [`docs/PUBLISH.md`](../PUBLISH.md).

## Expansion: deficits at scale

Notes for more tiles and NPC kinds (2026-10-05). Nothing here is decided.

- **The sheet is not capped at 256**, `src/sheet.js:8`, `src/build.js:49`. It grows by powers of two to 1024x1024,
  then spills into more sheets. Today ~115 sprites fill a 256 sheet that holds 225 (16 px + 1 px padding). Each
  NPC kind costs ~8 sprites (4 facings x 2 frames, more with variants), so about a dozen more kinds tips it to 512.
- **Any art change re-packs everything**, `src/sheet.js:9`. Sorting and shelf packing are global, so one new sprite
  can move every cell and change every sheet's hash: Danzo re-uploads them all. Until he does, `Sprites.lua` has
  the new cells over the old image (`src/build.js:86`). More sheets, more uploads. Probably: stable placement.
- **Tile ids are one byte on the wire**, `roblox/src/shared/WorldGen.lua:821` (see [client](client.md)).

Measure first: sprite count per new NPC kind and tile set, and the sheet size that gives.
