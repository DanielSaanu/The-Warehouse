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
