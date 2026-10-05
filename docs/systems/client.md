# The client

**What it does.** Draws the world the server sends, predicts the player's own steps, follows them with the camera
and turns input into actions. Controls: WASD, the arrows or tap to move; left click or Space to attack; F to
interact; Tab for standing; Esc to close a window.

**Key modules** (all in `StarterPlayerScripts.Client`)
- `Client.client.lua` is the LocalScript. It wires the remotes, input and prediction, and builds `promptFor`.
- `Viewport.lua` is the tile window. It is a ring buffer of ImageLabels per layer, so repaints happen off screen.
- `Hud.lua` covers hearts, coin, inventory, prompt, notices, dialogue, trade, standing and the death overlay.

**Tunables:** `COLS`, `MAX_COLS`, `ROWS`, `VIEW_DX`, `VIEW_DY` and `BANNER_SECONDS` in Config.

**Gotchas**
- None of this runs outside Studio. Test it with the Studio MCP locally, or ask Danzo to Play.
- All three files sit within 1–3 lines of their `test/structure.test.js` ceilings. Adding a line means removing
  one, or splitting the file (proposed for rung 3 part 5).
- The client sets `Predicted*` attributes on the Player so they can be compared with the server's `TileX/TileY`.

## Expansion: deficits at scale

Notes for the map/village/NPC expansion (2026-10-05). Nothing here is decided.

- **The line ceilings are already hit**, `test/structure.test.js:22-24`. Hard limit: `Client.client.lua` is at
  660/660, `Viewport.lua` at 430/430, `Hud.lua` at 1023/1025. Any feature the expansion needs on screen (a map,
  more NPC kinds, more standing rows) fails `npm test` first. Probably: the rung 3 part 5 client split, before it.
- **WorldInit sends the whole map**, `server/Server.server.lua:90`, `shared/WorldGen.lua:851`. Two bytes per tile
  (ground + object) in one remote: 18 KB at 96x96 today, ~0.5 MB at 512x512. Soft limit: a large first remote
  stalls the join on a slow phone (a guess on where it hurts). Probably: send chunks around the player and
  stream the rest, or send the seed and regenerate on the client.
- **The client keeps every tile as a Lua number**, `client/Client.client.lua:362`. `WorldGen.decode` unpacks both
  layers into tables: ~0.5 M entries at 512x512 (memory guess: several MB on mobile). Probably: keep the packed
  strings and read bytes on demand, or keep only loaded chunks.
- **One byte per tile id**, `shared/WorldGen.lua:821`. Hard limit: id + 48 must fit a byte (~207 kinds per layer);
  past id 79 the strings stop being plain ASCII (whether remotes mind is a guess).
- **EntityState is one remote call per entity event**, `server/State.lua:66-69`, `server/Sim.lua:981-995`.
  Each `move` is its own `FireClient` to every player who knows the entity, and interest is rechecked every
  0.25 s as players × all entities. With many NPCs in view, calls per second per client grow with the crowd.
  Probably: batch a tick's moves into one packet per player, and a spatial index for interest.
- **Per-frame work over every entity, three times**, `Client.client.lua:611` (idle frames), `Viewport.lua:179`
  (`step`) and `:216` (`refresh`, which writes `Position` and `ZIndex` on every entity, moving or not).
  Bounded by `VIEW_DX`/`VIEW_DY` (Config `:44-45`), so cheap until a crowd stands in view. Probably: touch only
  what moved. The tile ring (`Viewport.lua:203`) is sized by the window, not the map, so it already scales.
- **Two more linear scans per frame**: `promptFor` over all entities (`Client.client.lua:172`) and `villageAt` over
  all villages (`:650-652`, `WorldGen.lua:811`). Fine today. Probably: look up by tile (the client already builds
  an occupancy table, `:152`) and by region or chunk.
- **Standing is three tribe types**, `Hud.lua:989`, `Client.client.lua:105, 364`, fed by `server/Standing.lua:72`.
  Hard limit: the wire is `{ farmer, hunter, plunderer }`, and `tribeNames` is keyed by tribe type, so several
  villages per tribe overwrite each other. Probably: send standing per village holder and list the known ones.
- **No map or minimap**, nothing in `client/`. A bigger world with many villages will need one, and it has no line
  room (above). It would also need the map data that WorldInit may stop sending in full.

Measure first: WorldInit bytes and join time at the target map size; EntityState calls per second to one client in
the busiest village; client frame time with the expected crowd in view.
