# INDEX — read this first, then open only what the task needs

One line per doc and per source folder: what it is, and when to read it. For Roblox folders, the service they sync
to (`roblox/default.project.json`).

## Orientation and to-do

- [`CLAUDE.md`](CLAUDE.md): how to work here (the loop, reading and editing rules, Rojo rules, escalation). Every session.
- [`ideas/INBOX.md`](ideas/INBOX.md): Danzo's to-do list, written in the UI. Every session, after `docs/handoffs.md`.
- [`docs/handoffs.md`](docs/handoffs.md): routine → heavy escalations. Check for OPEN entries every session.
- [`docs/worklog.md`](docs/worklog.md): one dated line per block of work. Add to it at the end of each block.
- [`README.md`](README.md): what The Warehouse is, the quick start, the CLI cheat sheet. First time only.

## Rulebooks

- [`docs/learnings.md`](docs/learnings.md): how to build here, with ID'd rules (A/S/P/T/G/Q). Before a similar task; cite IDs.
- [`docs/PRINCIPLES.md`](docs/PRINCIPLES.md): what makes a good game. Before a design fork.

## Detail (read by section: the two hubs below map each § to a small file; RUNG3 by grep and line ranges)

- [`docs/systems/README.md`](docs/systems/README.md): how the game fits together, server vs client, the remotes list, one file per system. Before any game-code task.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): hub for where the data lives: maps §1–§11, R1–R5, H1–H9, A0–A5, B1–B4 to the files in [`docs/architecture/`](docs/architecture/data-model.md); names §9's six decisions. Before writing server code.
- [`docs/DESIGN.md`](docs/DESIGN.md): hub for what the game is: maps §1–§20 (pillars, tribes, reputation, calamities, rungs) to the files in [`docs/design/`](docs/design/pillars.md). Before gameplay changes.
- [`docs/RUNG3.md`](docs/RUNG3.md): the rung 3 build plan, parts 1–7 (part 3 = gossip spec). Before rung 3 work.
- [`docs/ROBLOX_SETUP.md`](docs/ROBLOX_SETUP.md): installing Rojo, connecting Studio, Open Cloud key, uploading. Setup or toolchain problems.
- [`docs/PUBLISH.md`](docs/PUBLISH.md): making the game public, credits owed, the post-sprite-change routine. Before publishing.
- [`docs/qa/`](docs/qa/): QA goals files and `*-summary.md` per PR. Read the summary for the area you touch; never `archive/`.
- [`docs/REFACTOR-SURVEY.md`](docs/REFACTOR-SURVEY.md): the 2026-09-27 survey: instance tree, requires, remote call sites, secrets check.

## Game code (Luau, synced by Rojo)

- [`roblox/src/`](roblox/src/README.md): the hub for the three folders below.
- [`roblox/src/shared/`](roblox/src/shared/README.md) → `ReplicatedStorage.Shared`: pure rules, tested by `npm run test:luau`.
- [`roblox/src/server/`](roblox/src/server/README.md) → `ServerScriptService.Server`: the world, tick, remotes, saving.
- [`roblox/src/client/`](roblox/src/client/README.md) → `StarterPlayer.StarterPlayerScripts.Client`: drawing, input, HUD.
- `roblox/default.project.json`: the Rojo tree, including the six RemoteEvents. Read before any file move.
- `roblox/sheet.json`: which scenes go in the sprite sheet (the input to `roblox build`). `roblox/assets.lock.json`: generated. Never hand-edit it.

## The Warehouse (node asset pipeline)

- `bin/warehouse.js`: the CLI entry point (`scenes`, `render`, `ascii`, `search`, `fetch`, `roblox build`).
- `src/`: pipeline code (`render.js`, `pixels.js`, `scene.js`, `sheet.js`, `roblox.js`, `server.js`, `sources/`). See [`docs/systems/art-pipeline.md`](docs/systems/art-pipeline.md).
- `ui/`: the browser UI (`npm start`). It polls scene files every 2.5 s.
- `sprites/`: pixel-text sprites (`.txt`, format in `src/pixels.js`). Drawing art.
- `scenes/`: scene JSON (format in `src/scene.js`). The file name is the Roblox sprite name.
- `library/`: borrowed assets and `index.json` licences. Keep CC-BY credits when shipping.
- `test/`: node tests (`core`, `structure` = line ceilings and the one-clock rule) and `test/luau/*.test.luau`.
- `tools/`: `luau-check.js` (lint), `preview-world.js`, `preview-view.js`. `tools/luau/` holds the gitignored binaries.
- `.claude/agents/heavy.md`, `.claude/skills/qa-loop/`: the heavy escalation agent and the QA loop skill.
- `exports/`, `cache/`: generated output. Not committed.
