# How the game fits together

**Created:** 2026-09-27. This is the short overview. The full reasoning, and the rules R1–R5 it cites, are in
[`../ARCHITECTURE.md`](../ARCHITECTURE.md). What the game is meant to *be* is in [`../DESIGN.md`](../DESIGN.md).

## Server vs client

- **The server owns the world** (`roblox/src/server`, which syncs to `ServerScriptService.Server`). It generates the
  map from a seed, ticks the World Record (`State.state`: tribes, people, groups, regions, calamity, players),
  validates every move and action, and saves.
- **The client draws what it is told** (`roblox/src/client`, which syncs to `StarterPlayerScripts.Client`). It
  predicts its own steps with the same rules the server checks (`shared/Movement.lua`), paints a scrolling tile
  window and runs the HUD. It holds nothing durable.
- **`shared/` is pure Luau** (`ReplicatedStorage.Shared`): rules over records, with no Instances and no Roblox
  APIs. That's why `npm run test:luau` can run it outside Studio. The one exception is the generated `Sprites.lua`.
- **The world is numbers; the grid is a window** (DESIGN §4). People, groups and wildlife live as records.
  Within `MATERIALISE_RANGE` of a player they become entities with bodies, and past `COLLAPSE_RANGE` they fold
  back into records. The same pure ticks (`shared/Tick.lua`) run live and during catch-up after the server slept.

## Remotes

All six are RemoteEvents in `ReplicatedStorage.Remotes`, declared in `roblox/default.project.json`. Never rename
them: both sides look them up with `WaitForChild`.

| Name | Direction | Payload | Used by |
|---|---|---|---|
| `WorldInit` | C→S, then S→C | C→S: nothing. S→C: `encodedMap, me, others, clock, sheetIds, calamity, welcome` | `Client.client.lua`, `Server.server.lua` |
| `Move` | C→S | `epoch, tx, ty, facing` | `Client.client.lua`, `Server.server.lua` |
| `Action` | C→S | `kind, a, b, c`, where kind is `attack`, `interact`, `topic`, `trade`, `select` or `close` | `Client.client.lua`, `Server.server.lua` → `Interact.lua` / `Sim.lua` |
| `EntityState` | S→C | `kind, id, ...`, where kind is `spawn`, `move`, `leave`, `die`, `hit`, `attack`, `telegraph`, `object` or `snap` | `Server.server.lua`, `State.lua`, `Client.client.lua` |
| `Notice` | S→C | `kind, data`, where kind is `hud`, `text`, `dialogue`, `trade`, `calamity`, `flood`, `welcome` or `died` | `State.lua`, `Client.client.lua` |
| `Clock` | S→all | `day, frac` | `Server.server.lua`, `Client.client.lua` |

File and line references for each are in [`../REFACTOR-SURVEY.md`](../REFACTOR-SURVEY.md).

## Systems

One file each. Read only the one your task touches.

| System | File | Main modules |
|---|---|---|
| World generation and the map | [world-and-map.md](world-and-map.md) | `WorldGen`, `Map`, `TileTypes`, `Rng`, `Names` |
| Time, the tick and calamities | [time-and-calamities.md](time-and-calamities.md) | `Calendar`, `DayCycle`, `Tick`, `Calamity`, `Sim` |
| People, villages, farms, wildlife | [population.md](population.md) | `Families`, `Farms`, `Villagers`, `Ecology`, `Bands` |
| Movement and combat | [movement-and-combat.md](movement-and-combat.md) | `Movement`, `Combat`, `Stats`, `Sides`, `Witness` |
| Reputation, gossip, grudges | [reputation-and-gossip.md](reputation-and-gossip.md) | `Reputation`, `Gossip`, `Standing` |
| Talking, trade, the F key | [talk-and-trade.md](talk-and-trade.md) | `Interact`, `Talk`, `Trade`, `Items`, `Goals`, `Tiles` |
| Saving and catch-up | [saving.md](saving.md) | `Save`, `Restore`, `Persistence`, `Headlines` |
| The client | [client.md](client.md) | `Client`, `Viewport`, `Hud` |
| The art pipeline (node) | [art-pipeline.md](art-pipeline.md) | `bin/warehouse.js`, `src/*.js`, `Sprites.lua` |

The per-module "who owns what" table is [`roblox/src/server/README.md`](../../roblox/src/server/README.md).
