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
