# QA summary: Rung 2 part 1 (generated world, scrolling viewport, validated movement)

Goals file: `docs/qa/rung2-part1.md`. Verbatim round reports: `docs/qa/archive/rung2-part1-round{1,2}.md`.
This was the first run of the loop, under the original rules (three Opus reviewers per round: A average player,
B game feel and readability, C integration and technical quality). Danzo ended the loop during round 2, so round 2's
feedback was not acted on and no round 3 ran. Target (every reviewer >= 8.0) not reached.

## Scores

| Round | A player | B feel | C technical | Average | Main finding |
|---|---|---|---|---|---|
| 1 | 7 | 6 | 7 | 6.67 | Night tint drew under players (Global ZIndex); a frozen frame every tile; moves could desync after a snap; palisade was one wall with a gate to nowhere; one river ford per world. |
| 2 | 7 | 7 | stopped | 7.0 | Round 1 fixes confirmed in Studio (sync, smooth walking, layering). Remaining: no controls hint, uneven scroll steps at non-16-multiple tile sizes, small play area on phones, tap-to-move stuck behind obstacles, hunter and plunderer villages look alike. |

All reviewers ran Studio Play Solo through the Roblox_Studio MCP and saw a clean Output (only the `[World]` and
`[Sprites]` lines). In round 2 both reviewers confirmed the server's `TileX/TileY` always equalled the client's
`PredictedX/PredictedY` with `MoveEpoch` 0, and per-frame traces showed no frozen frames.

## What was fixed (after round 1, commit `4ed0999`)

Layering and HUD
- `ScreenGui.ZIndexBehavior = Sibling`, so the night tint covers players and name labels; the HUD sits in an
  Overlay frame above the tint, inside the play area.
- A second full-screen `Backdrop` ScreenGui (IgnoreGuiInset) removed the grey strip above the play area.
- Two-line village banner (name / farmers|hunters|plunderers) that fades in and out; enters at margin 1, resets
  at margin 5, so it no longer flickers along a wall. Opening banner: "<village> / farmers - the morning after".
- Clock and banner have minimum pixel sizes; remote name labels clamp text to 10-20 px.

Movement
- `Viewport:step(now)` advances slides, the camera is set from this frame's position, then `refresh()` lays out.
  A held key starts the next slide exactly when the previous one ended. No frozen frame per tile, no camera lag.
- New `shared/Movement.lua`: `Move(epoch, targetX, targetY, facing)`. The server validates the target against
  its own position; any rejection snaps and bumps the epoch; in-flight moves with an old epoch are dropped; the
  client ignores snaps it already has. Snaps slide over 0.1 s instead of teleporting.
- Pace budget replaced the 0.65 tolerance (which allowed 1.54x speed forever): credit capped at 0.35 s, a step
  spends 0.85 x its step time. Tested: honest walker with 120 ms jitter never rejected; 2x speed hack gains ~18%.
- Tap sets a target tile; the walk stops on arrival or when blocked; dragging re-aims; a key cancels it.
- `WindowFocusReleased` clears held keys (no walking on after alt-tab).
- Remote players return to the idle frame after two step-times and slide at the destination tile's speed; turns
  broadcast only on a real facing change and are not echoed to the mover.
- Player attributes `TileX`, `TileY`, `MoveEpoch` (server) and `PredictedX`, `PredictedY` (client) for QA.

Rendering
- Tiles drawn at whole screen pixels (a whole multiple of 16 when that keeps >= 85% of the space); camera and
  entities quantized to art pixels and rounded from the same screen coordinate, so the player never wobbles.

World generation
- Farmer village walled on all four sides with north and east gates and a SW breach; 3 of 4 huts burnt. Roads
  leave through the gate facing their destination, never cut through a walled village; every gate gets a road.
- Three natural fords carved before the roads (20+ rows apart); road reuse cost 0.5 -> 0.85 so each village pair
  gets its own road. All 7 tested seeds have 3-4 crossings.
- Caves placed after roads, only where reachable from spawn (seed 7 had an unreachable one).
- Village names re-rolled when they share a first-3 or last-4 letter run.

Day cycle
- New `shared/DayCycle.lua`: equal 36 s dusk and dawn fades, interpolated per frame between server ticks; phases
  morning / afternoon / dusk / night / dawn.

Art and tooling
- Bed redrawn (wood frame, pillow, red blanket); sheet re-uploaded (decal 125789431816942).
- `test/luau/run.js` normalises CRLF: on Windows it never rewrote `exports/world_1.txt`, so map previews were stale.
- New `test/luau/movement.test.luau`; worldgen tests now assert gate roads, cave reachability, >= 2 crossings and
  distinct names on 7 seeds. `npm run lint:luau` is clean.
- Server ignores WorldInit from players already leaving, and answers it at most once a second per player.

## What was preserved (confirmed by reviewers in both rounds)

- The opening beat: spawning on the road among burnt huts with the "morning after" banner.
- The loading screen that explains what to check after 5 s.
- The client asking the server for the world and retrying (no Play Solo race).
- Pure-Luau shared modules with tests and PNG previews.
- The recycled tile pool that repaints only when the camera crosses a tile.
- Most-recent-key-wins input; turning when walking into solids; identical per-tile speed on client and server.
- The art style and the readable sprite set.

## Deferred, and why

- Tall grass visually hiding the player: belongs with the hiding mechanic (DESIGN.md §11), next PR.
- Water shore edge tiles and blocky river diagonals: an art pass of ~8 tiles, not in this PR's goals.
- Filling the empty middle and NE meadows: wildlife, camps and NPCs (next PR) are the intended fill.
- Distance-based replication filtering: matters once NPCs exist; moves already go only to other players.
- Mobile default thumbstick without a character: not testable in Play Solo.

## Fixed after the loop (Danzo's own play test: "a hitch per tile")

- Scrolling snaps to whole screen pixels when the tile size is not a multiple of 16 (whole art pixels when it
  is), so every frame's step is the same size. Measured at 60 fps: 5, 5, 5, 5 px per frame.
- The play area sits on a whole pixel (floored offset instead of a 0.5 anchor).
- The tile layer is a ring buffer: images keep fixed world positions inside a frame that scrolls continuously;
  when the camera crosses a tile only the edge images (2 tiles off screen) are re-parked and repainted. Before,
  every tile crossing repainted all 252 images and re-anchored the frame by a tile in the same frame, which showed
  as a hitch once per tile. Danzo confirmed it is smooth.

## Open items from round 2 (not acted on; the loop was ended)

FIX
- No controls hint on first spawn ("WASD / arrows to move" or "tap to walk", cleared on the first step).
- Small play area on landscape phones (29 px tiles, 45% black bars): let COLS grow with the aspect ratio.
- Tap-to-move gets stuck behind walls and trees: short BFS to the tapped tile, plus a target marker.
- Hunter and plunderer villages look the same: per-tribe hut variant and a landmark tile.

CONSIDER
- Props in empty meadows; a light radius around the player at night; tighten MOVE_SLACK once latency data exists;
  DESIGN.md says a 20x16 tile pool but the code uses 18x14; trim unused template road stubs; day-progress bar
  under the clock; banner contrast and placement; clock box covering top-left tiles; remote name labels dimmed
  at night; softer tall-grass texture.
