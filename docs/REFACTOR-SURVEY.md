# Refactor survey: AI-friendly docs (branch `refactor/ai-friendly`)

**Created:** 2026-09-27 · Read-only survey taken before the refactor on branch `refactor/ai-friendly`. Nothing in
it changed code. Rerun the commands at the bottom to refresh it.

## Scope, as agreed with Danzo ("go adapted", 2026-09-27)

The directive was a generic template (parkour, PvP, rounds). It was adapted to this repo:

- **Keep and extend** `CLAUDE.md`, `docs/learnings.md` and `docs/ARCHITECTURE.md`. Don't replace them. A new
  `docs/architecture.md` would be the same file as `ARCHITECTURE.md` on Windows, so the overview lives in
  `docs/systems/README.md` instead.
- **Keep the learnings IDs** A/S/P/T/G/Q. `R1`–`R5` already mean the five architecture rules in ARCHITECTURE §3.
- **Move no Luau file.** The Rojo tree is identical by construction, and the sourcemap diff proves it.
- **Don't split docs over 300 lines** (`ARCHITECTURE.md`, `DESIGN.md`, `RUNG3.md`) in this pass. Splitting
  them is escalation trigger 1, so they're listed as proposals in the PR.
- **Header comments** only where the file has headroom under `test/structure.test.js`'s line ceilings. `Sim`,
  `WorldGen`, `Hud`, `Viewport` and `Client` sit 1–3 lines under a ceiling that may only shrink, so their
  "required by / returns" line lives in the folder README instead. `Sprites.lua` is generated: never hand-edit it.

## Toolchain

- Rojo 7.7.0 (`rokit.toml`; a `rojo.exe` in the repo root is gitignored). Project: `roblox/default.project.json`,
  place name `Lowlands`.
- `luau` / `luau-analyze` in `tools/luau/` (gitignored): `npm run lint:luau`, `npm run test:luau`.
- `npm test` = node tests (including `test/structure.test.js`, the line ceilings and one-clock rule) + Luau tests.
- selene and StyLua aren't used in this repo.

## Remotes (all RemoteEvents, in `ReplicatedStorage.Remotes`, declared in `default.project.json`)

| Name | Direction | Payload | Fired / handled in |
|---|---|---|---|
| `WorldInit` | C→S then S→C | C→S: nothing (rate-limited request). S→C: `encodedMap, me{x,y,facing,epoch}, others, clock{day,frac}, sheetIds, calamity, welcome` | `Client.client.lua:358,529`, `Server.server.lua:90,123` |
| `Move` | C→S | `epoch, tx, ty, facing` (the tile being stepped onto; protocol in `shared/Movement.lua`) | `Client.client.lua:198,234`, `Server.server.lua:141` |
| `Action` | C→S | `kind, a, b, c`, where kind is `attack`, `interact`, `topic`, `trade` (`op, good, n`), `select` (slot) or `close` | `Client.client.lua:295-371`, `Server.server.lua:168` |
| `EntityState` | S→C | `kind, id, ...`, where kind is `spawn`, `move`, `leave`, `die`, `hit`, `attack`, `telegraph`, `object` or `snap` | `Server.server.lua:58,75`, `State.lua:53`, `Client.client.lua:400` |
| `Notice` | S→C | `kind, data`, where kind is `hud`, `text`, `dialogue`, `trade`, `calamity`, `flood`, `welcome` or `died` | `State.lua:57`, `Client.client.lua:482` |
| `Clock` | S→C (all) | `day, frac` | `Server.server.lua:192`, `Client.client.lua:534` |

## Other names code looks up at runtime (never rename)

- `ReplicatedStorage.Shared`, `ReplicatedStorage.Remotes` (`WaitForChild`), and every module name via
  `Shared:WaitForChild("<Name>")`, `script.Parent:WaitForChild("<Name>")` or `script.Parent.<Name>`.
- `ServerStorage.Debug` (a BindableFunction made at runtime by `Server.server.lua:207`); the Workspace attributes
  `Debug` / `DebugResult`.
- Player attributes: `TileX`, `TileY`, `MoveEpoch`, `Hp` (server) and `PredictedX/Y/Facing/Epoch`, `InputBlocked` (client).
- DataStore `Lowlands_v1`, keys `world` and `player_<userId>` (`server/Persistence.lua:27`).

## Secrets check

Every tracked file and the full git history were searched for Open Cloud keys, `.ROBLOSECURITY`, `x-api-key`
values, private place/universe ids and `sk-` tokens. **None were found.** `.env` is gitignored and has never been
committed. `.env.example` holds empty placeholders only, and `docs/ROBLOX_SETUP.md:81` shows `paste-the-key-here`.

## Plan: old → new mapping

No file moves, renames or re-nests. Everything below is an **addition**, except `CLAUDE.md`, `docs/learnings.md`
and `roblox/src/server/README.md`, which are extended.

| Old | New | Change |
|---|---|---|
| every `roblox/src/**/*.lua` | same path | none, apart from a 1-line header comment where there is headroom |
| `roblox/default.project.json` | same | none |
| — | `INDEX.md` | new: one line per doc and source folder |
| `CLAUDE.md` | same | extended: "Reading and editing" rules, the Rojo rules, the worklog and verification steps |
| — | `docs/systems/README.md` + one file per system | new: how the game fits together, per system |
| — | `docs/worklog.md` | new |
| `docs/learnings.md` | same | extended: G and T rules taken from existing docs and comments |
| — | `roblox/src/README.md`, `roblox/src/client/README.md`, `roblox/src/shared/README.md` | new hubs |
| `roblox/src/server/README.md` | same | a service line added at the top |
| — | `docs/REFACTOR-SURVEY.md` | this file |

## Baseline (before any change)

`rojo sourcemap roblox/default.project.json` and `rojo build` both succeeded (scratchpad `before.json`,
`before.rbxlx`). The tree:

### Instance tree

```
Lowlands (DataModel)
  ReplicatedStorage (ReplicatedStorage)
    Shared (Folder)
      Calamity (ModuleScript)
      Combat (ModuleScript)
      Config (ModuleScript)
      DayCycle (ModuleScript)
      Ecology (ModuleScript)
      Families (ModuleScript)
      Farms (ModuleScript)
      Gossip (ModuleScript)
      Headlines (ModuleScript)
      Items (ModuleScript)
      Movement (ModuleScript)
      Names (ModuleScript)
      Reputation (ModuleScript)
      Rng (ModuleScript)
      Save (ModuleScript)
      Sprites (ModuleScript)
      Stats (ModuleScript)
      Talk (ModuleScript)
      Tick (ModuleScript)
      TileTypes (ModuleScript)
      Trade (ModuleScript)
      Witness (ModuleScript)
      WorldGen (ModuleScript)
  ServerScriptService (ServerScriptService)
    Server (Folder)
      Bands (ModuleScript)
      Calendar (ModuleScript)
      Debug (ModuleScript)
      Goals (ModuleScript)
      Interact (ModuleScript)
      Map (ModuleScript)
      Persistence (ModuleScript)
      Restore (ModuleScript)
      Server (Script)
      Sides (ModuleScript)
      Sim (ModuleScript)
      Standing (ModuleScript)
      State (ModuleScript)
      Tiles (ModuleScript)
      Villagers (ModuleScript)
  StarterPlayer (StarterPlayer)
    StarterPlayerScripts (StarterPlayerScripts)
      Client (Folder)
        Client (LocalScript)
        Hud (ModuleScript)
        Viewport (ModuleScript)
```

### Files, line counts, requires

| File | Lines | Requires |
|---|---|---|
| `server/Bands.lua` | 199 | shared/Config, shared/WorldGen, shared/Names, shared/Tick, Map, State, Calendar |
| `server/Calendar.lua` | 57 | shared/DayCycle |
| `server/Debug.lua` | 318 | shared/Config, shared/Items, shared/Stats, shared/WorldGen, shared/Ecology, shared/Families, shared/Save, shared/Headlines, shared/Gossip, Calendar, Restore, Persistence, Map, Villagers, Standing |
| `server/Goals.lua` | 64 | shared/Config, shared/WorldGen, shared/Talk, Map |
| `server/Interact.lua` | 349 | shared/WorldGen, shared/TileTypes, shared/Items, shared/Combat, shared/Reputation, shared/Trade, shared/Ecology, shared/Calamity, shared/Talk, shared/Rng, shared/Gossip, Sim, Map, State, Standing |
| `server/Map.lua` | 50 | shared/Config, shared/WorldGen |
| `server/Persistence.lua` | 175 | shared/Config, shared/Save, State |
| `server/Restore.lua` | 203 | shared/Rng, shared/WorldGen, shared/Ecology, shared/Calamity, shared/Tick, shared/Save, shared/Reputation, shared/Headlines, Map, Calendar, Tiles, Villagers, Standing |
| `server/Server.server.lua` | 219 | shared/Movement, shared/Sprites, Map, Sim, Interact, Persistence, Restore |
| `server/Sides.lua` | 294 | shared/Config, shared/WorldGen, shared/Witness, shared/Combat, shared/Gossip, Calendar, Map, Standing |
| `server/Sim.lua` | 1275 | shared/Config, shared/WorldGen, shared/TileTypes, shared/Movement, shared/Rng, shared/Names, shared/Stats, shared/Items, shared/Combat, shared/Reputation, shared/Trade, shared/Ecology, shared/Calamity, shared/DayCycle, shared/Families, shared/Tick, shared/Headlines, Standing, Sides, Debug, Restore, Goals, Map, State, Tiles, Villagers, Bands, Calendar |
| `server/Standing.lua` | 196 | shared/Reputation, shared/Gossip, Map |
| `server/State.lua` | 125 | shared/WorldGen, shared/Items, Map |
| `server/Tiles.lua` | 145 | shared/Config, shared/WorldGen, shared/TileTypes, shared/Items, Map, State, Calendar |
| `server/Villagers.lua` | 153 | shared/WorldGen, shared/TileTypes, shared/Farms, Map, State |
| `shared/Calamity.lua` | 85 | Config, Rng, WorldGen, Ecology |
| `shared/Combat.lua` | 69 | Config, Rng |
| `shared/Config.lua` | 78 | — |
| `shared/DayCycle.lua` | 49 | Config |
| `shared/Ecology.lua` | 178 | Rng, WorldGen, TileTypes |
| `shared/Families.lua` | 199 | Rng, Names |
| `shared/Farms.lua` | 120 | WorldGen, TileTypes |
| `shared/Gossip.lua` | 381 | Config, Reputation |
| `shared/Headlines.lua` | 89 | — |
| `shared/Items.lua` | 124 | — |
| `shared/Movement.lua` | 56 | Config, TileTypes, WorldGen |
| `shared/Names.lua` | 61 | Rng |
| `shared/Reputation.lua` | 114 | Config |
| `shared/Rng.lua` | 48 | — |
| `shared/Save.lua` | 307 | Config, WorldGen |
| `shared/Sprites.lua` | 190 | — |
| `shared/Stats.lua` | 42 | — |
| `shared/Talk.lua` | 178 | Rng |
| `shared/Tick.lua` | 196 | Config, WorldGen, DayCycle, Ecology, Families, Trade, Farms, Headlines, Gossip |
| `shared/TileTypes.lua` | 61 | — |
| `shared/Trade.lua` | 84 | Items |
| `shared/Witness.lua` | 104 | Reputation |
| `shared/WorldGen.lua` | 880 | Rng, Names, TileTypes |
| `client/Client.client.lua` | 660 | shared/Config, shared/WorldGen, shared/TileTypes, shared/Movement, shared/DayCycle, shared/Combat, shared/Items, shared/Sprites, Viewport, Hud |
| `client/Hud.lua` | 1023 | shared/Sprites, shared/Items, shared/Reputation |
| `client/Viewport.lua` | 430 | shared/Sprites, shared/TileTypes, shared/WorldGen, shared/Config |

## Refresh

```
./rojo.exe sourcemap roblox/default.project.json -o <tmp>/sourcemap.json
wc -l roblox/src/*/*.lua
grep -n "require(" roblox/src/*/*.lua
grep -nE "Remotes:WaitForChild|:Fire(Server|Client|AllClients)|OnServerEvent|OnClientEvent" roblox/src/*/*.lua
```
