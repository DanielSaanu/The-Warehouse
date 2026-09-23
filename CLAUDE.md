# CLAUDE.md

The Warehouse is an asset pipeline for a 2D pixel-art Roblox game, built to be operated by a human in the
browser UI and by Claude from the terminal at the same time. **The files are the shared brain.** Nothing in
the UI is hidden state: every action writes a file under `scenes/`, `sprites/`, `ideas/`, `library/`.

## Start of every session

0. **Read `docs/ARCHITECTURE.md` before writing any server code.** It is the plan for where the data lives, and
   it is being built: **Track A** (save-critical: one game clock, pure ticks in `shared/`, records instead of
   live references, `Save.lua`, then `Persistence.lua` = rung 3 part 2) and **Track B** (optional: carving
   `Sim.lua` up for the reader). It was reviewed for five Opus rounds (7 → 9.0, `docs/qa/architecture-summary.md`)
   and then revised by Fable on 2026-09-18 — §9 lists the six decisions that changed, so do not undo them by
   accident. **Track A is merged (2026-09-18): the world and its players save**, confirmed by Danzo against the real
   DataStore. Studio needs Game Settings → Security → "Enable Studio Access to API Services", or the server runs
   NO-SAVE and says so. `roblox/src/server/README.md` says which steps have landed.
1. Read `docs/handoffs.md` (is anything OPEN?), then `ideas/INBOX.md`. The inbox is the to-do list the
   human writes in the UI. Work through it.
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

## Model policy and escalation

Following Anthropic's guidance — *for most workloads, start with Opus; use Fable only when Opus at higher
effort still falls short.*

- **Routine work runs on Opus, default effort.** Every session is a ROUTINE session unless Danzo opens it by
  saying **"heavy"**.
- **Escalated work runs on an Opus subagent at HIGH effort** — the `heavy` agent in `.claude/agents/heavy.md`.
- **Fable is a last resort and is never spawned automatically.** Only after the heavy agent at high effort has
  made a full attempt and either (a) came back without a confident answer, or (b) the same handoff has bounced
  back twice, ask: *"Opus at high effort fell short on H`<n>` — use Fable?"* Proceed only on "use fable".
  (The Fable allowance is reserved for personal projects, and this is one — but it is still the last rung.)

A routine session must **not** attempt the work itself when an escalation trigger fires. Instead:

1. Append an entry to `docs/handoffs.md` using its template.
2. Tell Danzo in one line: `Escalate: <what> — spawning heavy agent`.
3. Spawn the `heavy` agent with the handoff entry **verbatim** as its brief.
4. Relay its report in a line or two and carry on with the routine work.
5. If it needs a decision, bring the question to Danzo and **resume the same agent** with the answer — do not
   re-spawn.

A session opened with "heavy" does the escalated work directly, on whatever model it is running.

### Escalation triggers

1. An architecture or design decision with more than one reasonable option — anything that would add to,
   reinterpret or undo `docs/ARCHITECTURE.md` (especially the six decisions in §9) or `docs/DESIGN.md`.
2. A change to a shared or core system: anything in `roblox/src/shared/`, `src/render.js`, or the sprite and
   scene file formats (`src/pixels.js`, `src/scene.js`) that other files already depend on.
3. **Anything touching save data** — the save format version, `Save.lua`, `Restore.lua`, `Persistence.lua`, or
   the DataStore. A format change strands the world Danzo is already playing.
4. A failing test, a `lint:luau` error, or a line in the Studio Output window that the routine session cannot
   explain after one honest attempt.
5. A toolchain or dependency change: Rojo, `rokit.toml`, the `luau` binaries, node deps, or the Studio MCP setup.
6. A performance or memory tradeoff in the tick loop, WorldGen, or the renderer.
7. Any hard-to-reverse action: force-push, history rewrite, deleting a branch, deleting sprites or scenes, or
   hand-editing `roblox/src/shared/Sprites.lua` / `roblox/assets.lock.json`.
8. Anything in `ideas/INBOX.md` that conflicts with what the docs say.

Uploading is not a trigger — it is simply not Claude's to do. Only Danzo runs `roblox build --upload`.

## The docs are the memory

Chats are disposable; the files are the source of truth. No session depends on another session's history —
if a later session needs it, it has to be written down. Four layers:

| Layer | File | Role |
|---|---|---|
| **Orientation** | `CLAUDE.md` | how to work here, the loop, this policy |
| **To-do** | `ideas/INBOX.md` | what Danzo wants next, and where things stand |
| **Rulebooks** | `docs/learnings.md` (how to build here) · `docs/PRINCIPLES.md` (what makes a good game) | generalised rules with stable IDs |
| **Detail** | `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `docs/RUNG3.md`, `docs/qa/*`, `roblox/src/server/README.md` | the full reasoning |

- Only rules that **generalise** earn a line in `docs/learnings.md`. Cite them by ID (e.g. "→ S2") from QA
  reports, handoffs and commit messages; the rule carries the date and branch that paid for it.
- Every resolved handoff should leave a doc richer — a recorded decision, a new rule — so the same case never
  escalates twice.
- `docs/handoffs.md` stays small: trim a resolved entry to its heading plus one line once the real doc holds
  the detail.

## How to talk to Danzo

- Short, plain, direct. No walls of text.
- Multi-item explanations → one small card per item with labelled lines (what, where, the problem, the fix,
  who does it, the ask).
- Commands he has to run himself → exact text to paste, one paste at a time.
- Flag uncertainty instead of guessing. Say when something is a guess.
- Never claim a render, a test or a Studio run passed without having actually looked at the output.
