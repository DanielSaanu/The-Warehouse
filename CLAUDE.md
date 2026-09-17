# CLAUDE.md

The Warehouse is an asset pipeline for a 2D pixel-art Roblox game, built to be operated by a human in the
browser UI and by Claude from the terminal at the same time. **The files are the shared brain.** Nothing in
the UI is hidden state: every action writes a file under `scenes/`, `sprites/`, `ideas/`, `library/`.

## Start of every session

1. Read `ideas/INBOX.md`. That is the to-do list the human writes in the UI. Work through it.
2. `node bin/warehouse.js scenes` to see what exists. Open the scene JSONs you will touch.
3. When you change art, render it and LOOK at it: `node bin/warehouse.js render <scene> --scale 8` then Read
   the PNG in `exports/`. For a text view, `node bin/warehouse.js ascii <scene>`.

## The loop

- **Draw** small sprites as pixel-text in `sprites/<name>.txt` (format in `src/pixels.js`). 16x16 is the game's
  tile size. One character per pixel, `.` is transparent. Keep palettes small (5 to 8 colors).
- **Compose** in `scenes/<name>.json` (format in `src/scene.js`): layers of images, pixel grids, text, shapes,
  or other scenes. Effects: outline, recolor, tint, hue, flip, opacity. A scene's file name is its sprite name
  in Roblox.
- **Borrow** with `search`/`fetch` (Kenney CC0 packs, OpenGameArt, game-icons, LoSpec palettes). The license
  lands in `library/index.json`; keep CC-BY attributions when shipping.
- **Ship** with `node bin/warehouse.js roblox build` (add `--upload` only if the human has set up `.env`).
  This regenerates `roblox/src/shared/Sprites.lua`. Never hand-edit that file.
- **Game code** lives in `roblox/src/`, synced to Studio by Rojo. `Grid.lua` is the tile renderer,
  `Client.client.lua` the first playable, `Server.server.lua` the world clock.

## Conventions

- Scenes that are only for eyeballing (mockups) get `"export": false` and a `preview_` prefix.
- Animation frames: separate scenes named `<thing>_<n>` (e.g. `slug_walk_0`, `slug_walk_1`), or one scene with a
  `frames` map. Both pack into the sheet as separate sprites.
- Renderer is `src/render.js` and runs unchanged in the browser and node. If you change it, run `npm test`
  and re-check the UI with `npm start`.
- The UI polls the scene file on disk every 2.5 s. When you edit a scene JSON, the human sees it live.
- Commit `sprites/`, `scenes/`, `ideas/`, `library/index.json` and small library images. Do not commit
  `cache/`, `.env`, or `exports/*.png`.
- `roblox/assets.lock.json` (sheet hash -> Roblox asset id) and the generated `Sprites.lua` ARE committed, so the
  uploaded asset id travels with the repo. Only the human can upload (needs `.env`); after they run
  `roblox build --upload` they commit both files. When Claude changes sprites, `roblox build` keeps the old id and
  prints CHANGED; the human re-uploads.

## Testing the Roblox side

- **Luau without Studio**: download the `luau` release zip from https://github.com/luau-lang/luau/releases and put
  `luau` + `luau-analyze` in `tools/luau/` (gitignored). Then `npm run lint:luau` (syntax/type check with the
  Roblox-only noise filtered) and `npm run test:luau` (runs `test/luau/*.test.luau` against the shared modules).
  Everything in `roblox/src/shared/` except `Sprites.lua` must stay pure Luau so this keeps working.
  `npm run preview:world` paints the generated map into `exports/world_1.png` and `npm run preview:view` renders
  what the player sees around the spawn. LOOK at them after touching WorldGen or sprites.
- **The viewport, client and server Lua cannot run outside Studio.** A cloud session re-reads them adversarially
  before pushing and asks the human to Play. A **local session on Danzo's PC has the Roblox Studio MCP server**
  (`Roblox_Studio`, user scope) and can test for real: check `/mcp`, keep `rojo serve roblox/default.project.json`
  running and connected in Studio, then use the MCP tools to run Luau inside Studio (smoke-test the shared
  modules, build the GUI, start and stop Play) and read the Output window. Fix from real Output text, never guess.
- **Generated files**: any sprite or scene change means `node bin/warehouse.js roblox build`, then the human runs
  `--upload` and commits `roblox/src/shared/Sprites.lua` + `roblox/assets.lock.json`. On the PC, if those two are
  locally modified, `git checkout -- roblox/src/shared/Sprites.lua roblox/assets.lock.json` before `git pull`.

## QA loop

`/qa-loop docs/qa/<goals>.md` (skill in `.claude/skills/qa-loop/`) runs Danzo's review experiment: up to three
rounds of one Opus reviewer, fixes between rounds, a `docs/qa/<goals>-summary.md` at the end. Each PR gets a goals
file in `docs/qa/` written by the builder before the loop starts. Do not read `docs/qa/archive/` (the verbatim
round reports) unless asked: they are stale once summarised and would leak old reviews into a build session.
