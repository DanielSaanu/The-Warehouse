# QA round 1: Rung 2 part 1

Scores: A (average player) 7, B (game feel and readability) 6, C (integration and technical quality) 7.
**Average: 6.67.** Target (every reviewer >= 8.0) not met; fixes below go into round 2.

All three reviewers ran Studio Play Solo through the Roblox_Studio MCP (sequentially), plus `npm test`,
`test/luau/run.js` and the preview PNGs.

---

## Reviewer A: the average player

I ran it in Studio and it works. The world loads, the art is good, and walking is responsive with no server corrections. The main problems: walking stutters slightly on every tile, the server can drift out of sync with the client, the start village's gate leads nowhere, and the river has only one crossing on every seed I tested.

**What I ran**
- `npm test`: 11 of 11 passed.
- `node test/luau/run.js`: passed on seeds 1, 7, 42 and 2026. Every seed shows exactly `ford 2`, and seed 2026 has `cave 2`.
- Looked at `world_1.png`, `view_28_73@5x.png`, `view_28_73_night@5x.png`, `view_54_71@5x.png` and `preview_tiles@4x.png`.
- Studio Play: the Output window was clean, just `[World] seed 1, 96x96, villages: Eldercaster (farmer), Oakcaster (hunter), Thorn Crag (plunderer) (41 ms)` and `[Sprites] sheet 1: decal 73171207654960 -> image 87231116874201`. The later errors in Output came from my own test snippets, not the game.
- I simulated keyboard walks and logged every Move event on the server and every frame on the client. Then I stopped Play; Studio is back in Edit.

SCORE: 7/10
GOALS:
- 96x96 generated world: partial - meadow, tall grass, forest, lake, 3 caves and a rock border all show in world_1.png, but every seed has exactly one 2-tile ford (roads reuse each other, water costs 9 in `WorldGen.lua:186`), so "fords" is really one ford.
- Three villages from templates, plundered start: partial - named and placed; start has 2 burnt huts, stall, bed and farms. The palisade is one wall line (`WorldGen.lua:85`) you can walk around, and its gate leads only to open grass; the road leaves by the east side instead.
- Scrolling 16x12 viewport, aspect kept: met with one flaw - Studio shows the play area at 730x548 inside a 1291x606 window, letterboxed. Because `IgnoreGuiInset=false` (`Client.client.lua:28`), a grey strip of the 3D void shows above the black bars.
- Tile-step movement, facings, 2-frame walk, server authority: met in Studio - 22 Moves received on the server at 0.183 s apart, 0 snaps, and walking into a tree only sent a turn (`0,0,down`). Other players and name labels: not tested.
- Day/night clock, tint, HUD, banner: met - HUD showed "Day 1, morning"; night PNG reads well; the banner fired on re-entry with "Eldercaster  (the Eldercaster tribe)".
- 22+ sprites in one palette: met - preview_tiles@4x.png is cohesive and readable. Burnt hut, ford stepping stones and palisade are standouts; the bed reads as a blue box.

PRESERVE (done well, must survive future iterations):
- Opening beat (`Client.client.lua:175`): you spawn on the crossroads looking at burnt huts, with "Eldercaster. The morning after." That is a good hook for the survivor coming in the next PR.
- Loading fallback (`Client.client.lua:45-53`): after 5 s it tells you what to check instead of showing a blank screen.
- Client asks for the world and the server answers (`Client.client.lua:205`, `Server.server.lua:82`): Play Solo loaded reliably with it.
- Pure-Luau WorldGen with tests and PNG previews: fast to iterate on, and the reachability tests are real.
- Recycled tile-image pool (252 per layer) that only repaints when the camera crosses a tile.
- Art style and scale: 16x12 tiles at this size looks like Stardew or Zelda.

FIX (done poorly; why it matters; concretely how to fix):
- Walking stutters on every tile: I logged the world frame's position each frame at 60 fps and got `mmmmmmmm.mmmmmmmm.…`, one frozen frame every 9. That frame is the first one of each new step, because the slide starts from zero (`Client.client.lua:139-143`, `Viewport.lua:125`). The whole screen scrolls, so an 11% judder is exactly what makes moving feel cheap. -> While a key is held, set `me.lastStep += stepTime` instead of `= now`, start the slide at that time (`moveEntity(..., me.lastStep)`), and allow the next step when less than one frame of the current slide is left.
- Server can drift out of sync (reasoned from code, not seen at Studio's zero lag): Move sends only a direction, and a snap only resets the client. Moves already in flight are applied on top of the server's position after the snap. The client ignores move events for its own player (`Client.client.lua:186`), so the offset stays until some later step is rejected. Real-world lag bunches packets under the 0.11 s tolerance (`Config.lua:170`), which would cause rubber-banding and sudden forward jumps. -> Send the target x,y plus a step number; the server confirms the last step it accepted; the client ignores snaps older than its newest step and replays any unconfirmed steps.
- Gate to nowhere and a fence with open sides: players will try the gate first and find nothing. -> Either wrap the palisade around three sides with the gate on the road that leads to the hunters, or put the gate row on the east-west road and remove the dead north path.
- One river crossing per world: half the map is behind one 2-tile chokepoint, and the goal promises fords. -> Carve 2-3 extra fords at random river rows, or add a small A* penalty for reusing road tiles so each pair of villages gets its own route.
- Grey strip above the letterbox: looks broken on first frame. -> Set `IgnoreGuiInset=true` on the backdrop and offset the HUD by `GuiService:GetGuiInset()`.

CONSIDER (fine but could change; why; how):
- Banner repeats the name ("Eldercaster (the Eldercaster tribe)") and flickers if you step back and forth on the margin edge. -> Show "Eldercaster - farmers", and only re-show after the player has been away 5+ tiles.
- Village names come out samey: Eldercaster and Oakcaster in seed 1, Pencaster and Bramcaster in seed 42. -> Pick again when a suffix repeats.
- The middle of the map is flat, empty meadow (world_1.png, between the north road and the river). -> Scatter flowers, bushes and rocks, and use the unused grass_2 more; wildlife will help later.
- Tall grass has no visual effect on you, though DESIGN.md section 11 says it hides you. -> Draw the grass tips over the player's lower half.
- Other players slide at a fixed 0.17 s per tile (`Client.client.lua:191`) whatever the terrain, so they will stop-start on fords. -> Include the step time in the "move" broadcast.
- Water has no shore edges (DESIGN.md section 17 lists "water edge") and rivers step in blocky diagonals. -> Add edge tiles in the next sprite pass.
- Touch: holding a finger keeps walking past the tapped tile. -> Stop when the player reaches the tapped tile.

UNCERTAIN (could not verify):
- Other players and their name labels (Studio Play Solo has only one player).
- Snap corrections under real lag or packet bunching; I could only reason from code.
- A held key after alt-tab: I found no handler for losing window focus, but did not confirm whether Roblox fires InputEnded in that case.
- The live night tint and clock rollover: the server ticks every second and overwrote my test values; the tint is checked from the preview PNG and code only.
- Touch input and whether the mobile thumbstick or jump button appear without a character.

---

## Reviewer B: game feel and readability

SCORE: 6/10

I ran it in Studio. Play started cleanly: the Output showed only `[World] seed 1, 96x96, villages: Eldercaster (farmer), Oakcaster (hunter), Thorn Crag (plunderer) (41 ms)` and `[Sprites] sheet 1: decal 73171207654960 -> image 87231116874201`, with no game errors. Any other errors in the Output came from my own probe snippets. I stopped Play at the end. `npm test` passed 11/11 and `test/luau/run.js` passed. Movement was checked with real key presses and a per-frame position trace.

GOALS:
- 96x96 generated world: met - world_1.png has meadow, tall grass, forest, river, lake and 3 caves (each reachable through one gap). There is only one ford crossing (2 tiles) and the river runs the full height of the map, so the whole east side hangs on that single crossing, in all 4 test seeds.
- Three villages, plundered start: partial - the names and layouts are there and the burnt huts, stall, bed and farms read well (view_28_73@5x.png). The "palisade" is one straight wall on the north side (world_1.txt line 68), so it looks like a fence, not an enclosure.
- 16x12 scrolling viewport: met, with a defect - PlayArea measured 730.7x548 on a 1291x606 screen, so the 4:3 shape holds. The camera lags one frame behind the player (see FIX).
- Tile-step movement: met in Play Solo - the server log shows steps every 0.18-0.20 s on grass with no snaps. Holding Up then pressing Left turned left, and releasing Left went back to Up. A burnt hut blocked a step and a turn was sent. Other players' names draw correctly (checked with a mock label).
- Day/night, HUD, banner: partial - clock label "Day 1, morning" is fine. In Studio the night tint does NOT cover players (see FIX). The banner appears and hides after 3 s.
- 22 sprites, one palette: met - preview_tiles@4x.png is cohesive and the player's red shirt stands out on green. The bed is the weak sprite: it looks like a blue box or ice block.

PRESERVE (done well, must survive future iterations):
- Most-recent-key-wins input stack (Client.client.lua:109, 237-238, 267): it feels like Stardew, with no diagonal fighting.
- Speed per tile type used the same way on client and server (Client:138, Server:106): roads feel faster and fords slower, and prediction matches the server.
- Walking into a solid tile still turns you, throttled to 0.2 s (Client:127-136): the upcoming F interact and attack can rely on it.
- The sprite set and the spawn composition: the scene reads as "burnt village" within a second.
- A loading screen with a diagnostic message (Client:32-53) and the client asking the server for the world: startup can't fail silently.

FIX (done poorly; why it matters; concretely how to fix):
- **Night tint does not cover entities.** `Instance.new("ScreenGui")` defaults to `ZIndexBehavior.Global`, which I confirmed at runtime. The Night frame has z=10 and entities have `3+floor(py)`, which was 78 at spawn. At night every player below row 7 glows at full brightness on a dark world. Name labels (z=200) and entities with py≥48 also draw over the HUD banner (z=51). The preview tool tints everything, so view_28_73_night@5x.png does not match the game. -> Set `gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling` (Client:26), or keep entity ZIndex below Night's.
- **Camera lags one frame, so the player shakes.** `setCamera(e.px…)` runs before `refresh()` updates `px` (Client:273-275). Measured: the player sits 4.5 px off-centre while walking (≈1.6 art pixels at this scale). It pops back to 251.2 at the start of every step, and the world stops for one frame each step (5.5 times a second). -> Split `refresh` into moving entities, then setting the camera, then laying out, or compute px/py before `setCamera`.
- **Prediction can drift out of sync with the server.** The server applies dx/dy to its own position (Server:103). If one step is rejected on timing, the snap comes back after later steps were already accepted. The client ends up one tile off the server, and own-id "move" events are ignored (Client:186), so it never corrects. Other players then see you in the wrong tile, and the next PR's interact and attack will aim at the wrong tile. The 0.65 tolerance (about 110 ms) makes this likely on a real network with lag spikes. -> Add a sequence number or target tile to Move, have the server echo the last accepted seq and position, and have the client replay unacknowledged steps after a snap.
- **Grey strip at the top of the screen.** `IgnoreGuiInset=false` (Client:28) leaves the 58 px Roblox top-bar area uncovered by the backdrop. The capture shows the empty 3D sky there. -> Put Backdrop and PlayArea in a ScreenGui with `IgnoreGuiInset=true`, and offset only the HUD by `GuiService:GetGuiInset()`.
- **Touch overshoots.** The direction is set once on InputBegan and cleared only when the finger lifts (Client:240-259). Holding a tap keeps walking past the tapped tile, and dragging doesn't steer. -> Store the target tile, recompute the direction each frame, stop on arrival, and handle `InputChanged`.

CONSIDER (fine but could change; why; how):
- **Non-integer pixel scale:** 45.67 px per tile is 2.85 times the art size, so pixels come out uneven and may shimmer while scrolling. -> Snap the tile size to a whole multiple of 16 and round the world offset to whole art pixels.
- **Phone readability:** the clock is 22% of screen width with TextScaled. In portrait (390 px wide) that is 86 px for "Day 2, afternoon", about 5 px glyphs. Name labels are 0.35 of a tile, about 8 px tall on a phone. -> Set the HUD size from PlayArea height with a minimum pixel size, and add a UITextSizeConstraint.
- **Other players' slide time:** it is fixed at `Config.MOVE_STEP` (Client:191) and ignores tile speed and network timing, so remote players stop and start on fords and roads. -> Slide for the time since that player's last update, capped at stepTime/speed.
- **Dusk vs dawn:** dusk ramps over 72 s but dawn over 14 s, and the clock only updates once a second (Client:218-226), so dawn brightens in visible jumps. -> Interpolate the tint on the client between clock updates and make the two ramps match.
- **Banner and snap feel:** the banner pops on and off with no fade, and a snap teleports the camera instantly. -> Tween the banner's transparency, and slide snaps over about 0.1 s.
- **Starting banner:** "Eldercaster. The morning after." replaces the tribe banner on the same frame (Client:173-175), so the tribe name never shows at spawn. -> Include the tribe name.

UNCERTAIN (could not verify):
- Snap and rubber-banding under real network lag. Play Solo has no latency; the drift described above comes from reading the code.
- Whether the default mobile thumbstick or jump buttons appear when there is no character, and whether tap-to-move feels right on an actual phone.
- How the scaled pixel art shimmers during scrolling on real phone screens (I only saw the 1291x606 Studio window).
- Night tint on a two-client test (I used a mock label and forced the tint alpha because the command bar isn't allowed to fire Clock).
- Whether the other two villages' banners appear correctly on entry. I didn't walk there; this is judged from the code.

---

## Reviewer C: integration and technical quality

SCORE: 7/10

**How I tested:** `npm test` passed (11 JS tests plus the worldgen Luau test on seeds 1, 7, 42 and 2026, about 40 ms each). `lint:luau` has 3 type warnings and no errors (Viewport.lua:97, Server.server.lua:80, World.lua:24). I looked at world_1.png, view_28_73@5x.png, view_28_73_night@5x.png and preview_tiles@4x.png.

In Studio Play Solo, the only Output lines were `[World] seed 1, 96x96, villages: Eldercaster (farmer), Oakcaster (hunter), Thorn Crag (plunderer) (41 ms)` and `[Sprites] sheet 1: decal 73171207654960 -> image 87231116874201`, with no errors from the game's own scripts. I walked with W/A/S/D for about 10 s using real key input and logged every EntityState event: 40 moves, 0 snaps. The server's last position (33,57) matched the client sprite. I took two screenshots and Play is stopped.

GOALS:
- 96x96 generated world: met. The test output shows a river, a lake, 3 caves (2 on seed 2026), forest and tall grass; world_1.png is readable, and every village is reachable from spawn in all 4 seeds.
- Three named villages, plundered farmer start: partial. The names and templates work (screenshot: huts, 2 burnt huts, stall, bed, farms). But the "palisade" is one north wall (WorldGen.lua:85), so the gate leads nowhere and the east, west and south sides are open.
- 16x12 scrolling viewport keeping aspect: met. In Studio the PlayArea is 730.67x548 (4:3) with letterbox bars; scrolling is smooth with no tile seams.
- Tile-step movement, prediction, snap, other players: partial. Solo play works (4 facings, 2 walk frames, blocked turns). But the reconciliation has a desync bug (see FIX). I could not test two players.
- Day/night, HUD clock, village banner: partial. The clock shows "Day 1, morning" and the banner "Eldercaster. The morning after." appears and hides after 3 s. But in the forced-night screenshot (ScreenCapture_2) the player sprite stays full brightness above the tint.
- 22 sprites, one palette, one sheet: met. preview_tiles@4x.png looks coherent, and the uploaded sheet id resolves on the server.

PRESERVE (done well, must survive future iterations):
- The client asks for the world (WorldInit) and retries every 1.5 s (Client.client.lua:205), and the server answers each request. This removes the Play Solo race where the world arrived before the client was listening.
- Pure-Luau shared modules (WorldGen, Rng, Names, TileTypes) with tests for same-seed determinism, reachability and encode/decode round-trips, plus the preview tools. This is what makes cloud sessions able to check anything.
- The map is sent as printable byte strings (offset 48), 9216 bytes per layer: small, NUL-safe, and round-trip tested.
- Client and server both time a step from the destination tile's speed, so the client's prediction matches the server's rule.
- The loading screen appears before anything yields, and after 5 s it says what to check (Client.client.lua:26-53). No silent blank screens.
- Viewport recycles 18x14 images per layer and repaints only when the camera crosses a tile, so cost stays fixed however big the world gets.

FIX (done poorly; why it matters; concretely how to fix):
- **ScreenGui draws in Global layering mode (confirmed at runtime: `ZIndexBehavior Enum.ZIndexBehavior.Global`).** Player sprites get ZIndex 3+py (the spawn sprite measured z=75), which beats the night tint (10) and the HUD (51). Name labels get 200. Result: players never darken at night (ScreenCapture_2), and sprites and name labels draw over the banner, which sits inside the play area at y 33-71. -> Set `gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling` in Client.client.lua:26. Players are still sorted by row inside the Entities layer.
- **After a snap, client and server can silently end up a tile apart.**
  - Moves are sent as offsets (dx, dy). When the server rejects step N and snaps, step N+1 is already on its way and gets accepted from the snapped position.
  - The client ignores the server's "move" events about itself (Client.client.lua:186), so it never learns the real position. Other players then see you one tile off until you next bump into something.
  - Rejections will happen on real networks: a step is only accepted if it arrives at least 65% of the step time after the last one, about 0.11 s. Network jitter over roughly 70 ms, or low frame rates on mobile, will trigger it.
  - -> Send the target tile (nx, ny) plus a sequence number. The server rejects any step that doesn't start from its own position, and the snap echoes the sequence number so the client drops predictions older than it.
- **The speed check allows 1.54x speed for ever.** Each step only needs 65% of the expected interval (Server.server.lua:107), so a cheater can keep that pace indefinitely. -> Replace it with an allowance: add real time elapsed, subtract each step's cost, cap it at about one step, and reject when it goes negative.
- **Other players freeze mid-stride.** A remote player's walk frame flips on every move (Client.client.lua:192) and never goes back to frame 0 when they stop. -> In `refresh`, reset any entity idle for more than 0.35 s to frame 0, as the local player already does (line 269).
- **Keys can get stuck down.** If the window loses focus while a key is held, the release event may never arrive and `held` is never cleared, so the player keeps walking. -> Clear `held` and `touchDir` on `UserInputService.WindowFocusReleased`.
- **Palisade.** The goal says the starting village has a palisade with a gate. -> Wall all four sides of the farmer template, with gates where the roads leave, or reword the goal.

CONSIDER (fine but could change; why; how):
- Move the step rules (walkable check, step time, tolerance) into a pure `shared/Movement.lua`. Today the logic is copied in the client and server and has no tests. -> Share it and add a Luau test that feeds it timed steps.
- The server re-sends a turn to all clients every 0.2 s while a player pushes into a wall, and does not rate-limit turn events or WorldInit requests. Every move goes to every client (FireAllClients). -> Rate-limit per player now; add distance-based filtering before NPCs arrive (DESIGN.md §4 caps).
- A tap moves one step per tap, and holding keeps the direction from the first touch (TouchMoved is ignored). -> Re-aim on TouchMoved and stop at the tapped tile.
- Tiles are drawn at a non-integer 45.67 px, so art pixels come out uneven sizes. -> Round the play area to a whole multiple of 16 px.
- Every road crosses the river at the same 2-tile ford (ford=2 on all seeds), and the NE quadrant has no road at all. -> Make shared road tiles cost more in A*, or place a second ford.
- `WorldInit.OnServerEvent` calls `addPlayer`, so a late request from a player who is leaving could re-add a ghost. -> Guard with `player.Parent == Players`.
- The game only covers the screen below Roblox's top bar, so the 3D sky shows as a grey strip across the top (ScreenCapture_1). -> Add a full-screen black backdrop in a second ScreenGui with IgnoreGuiInset on.
- The Luau tests don't check that caves are reachable. -> Add a reachability assert for caves.

UNCERTAIN (could not verify):
- Two-player behaviour and leaving mid-move. Studio's MCP can only run Play Solo, and the MCP blocks scripts from firing remotes, so I also could not inject jittered moves to reproduce the snap desync. That bug comes from reading the code.
- How often snaps happen under real latency and jitter.
- Whether Roblox's default touch controls show up with no character, and how tap-to-move feels on a phone.
- Night tint across a full 10-minute cycle: I forced the tint directly rather than waiting 7 minutes.

---

## Builder decisions after round 1

Verified by the builder in Studio Play Solo before round 2: clean Output (`[World] seed 1, 96x96, villages: Glenworth
(farmer), Kenstow (hunter), Wild's Rest (plunderer)`, `[Sprites] sheet 1: decal 125789431816942 -> image
81987139412456`). After walking with held keys and turns, the server's `TileX/TileY` equalled the client's
`PredictedX/PredictedY` at epoch 0 (no snaps). A 210-frame RenderStepped trace while walking showed no frozen frames
and the player on one fixed screen pixel (Y 252.0, X 623.5) throughout. `ZIndexBehavior.Sibling`; PlayArea 720x540
inside a 1291x548 area.

### PRESERVE (checked against the diff, all kept)
Opening-beat banner (now "<village> / farmers - the morning after"), loading fallback text, client-pulls-world
handshake, pure-Luau shared modules + tests + previews, recycled tile pool repainting only on tile crossings,
most-recent-key input stack, identical per-tile speed on client and server (now literally one shared function), turning
when walking into solids, printable map encoding, the art style and spawn composition.

### FIX (done)
- **Night tint does not cover entities; labels over HUD** (B, C): `gui.ZIndexBehavior = Sibling`. HUD moved inside the
  play area into an Overlay frame above the Night frame.
- **Walk hitch every tile** (A) and **camera one frame late** (B): `Viewport:step(now)` advances slides, the camera is
  set from this frame's position, then `Viewport:refresh()` lays out. A held key starts the next slide exactly when the
  previous one ended (`moveEntity(..., startAt)` continues from the previous tile); the step gate uses the current
  slide's end instead of the next tile's step time.
- **Prediction desync after a snap** (A, B, C): new `shared/Movement.lua`. Move is `(epoch, targetX, targetY, facing)`.
  The server requires the target to be adjacent to *its* position; any rejection snaps and bumps the epoch; moves with an
  old epoch (in flight before the client heard the snap) are dropped silently; the client ignores snaps it already has.
  Chose an epoch over seq + replay: remotes are reliable and ordered, so it gives the same guarantee without replay code.
- **Speed check allows 1.54x forever** (C): pace budget (`Movement.spend`): elapsed time earns credit capped at
  `MOVE_BURST` 0.35 s, a step spends `MOVE_SLACK` 0.85 x its step time. Tested: an honest walker with 120 ms jitter is
  never rejected over 2000 steps; bunched packets pass; a 2x speed hack gets 354 steps where an honest walker gets 300.
- **Grey strip above the play area** (A, B): a second ScreenGui (`Backdrop`, IgnoreGuiInset) paints the whole screen
  black; the game gui keeps the inset so Roblox's buttons never cover the play area and touch coordinates line up.
- **Touch overshoot** (B; A and C as CONSIDER): a tap sets a target tile; each frame walks toward it one axis at a time,
  stopping on arrival or when both axes are blocked; dragging re-aims (InputChanged); any key cancels it.
- **Other players freeze mid-stride** (C): per-remote walk frame resets to 0 after two step-times idle. Remote turns
  no longer cut a slide short.
- **Stuck keys after alt-tab** (C): `WindowFocusReleased` clears held keys and the touch target.
- **Palisade / gate to nowhere** (A, B, C): farmer template walled on all four sides, gates north and east, a breach in
  the south-west corner. Roads leave through the gate facing their destination, never cut through a walled village, and
  a gate no road chose gets its own road to the network. Test: every gate exit is road and reaches every village.
- **One river crossing** (A; B, C as CONSIDER): three natural fords carved before the roads (20+ rows apart, river
  <= 3 wide, banks cleared); road-reuse cost raised 0.5 -> 0.85 so each village pair gets its own road. Seeds 1, 7, 42,
  2026, 3, 99, 123456 have 3-4 crossings; the test asserts >= 2.

### CONSIDER (done: cheap, or raised by two reviewers)
- Non-integer pixel scale (B, C): tiles are whole screen pixels, a whole multiple of 16 when that keeps >= 85% of the
  space; camera and entities are quantized to art pixels and rounded from the same screen coordinate (no wobble).
- Other players' slide time (A, B): the destination tile's step time.
- Banner repeats the name and flickers (A); start banner hides the tribe (B): two-line banner, title = village,
  subtitle = farmers / hunters / plunderers (start: "farmers - the morning after"); shows on entering (margin 1), resets
  only 5 tiles out; fades in and out (B).
- Dusk and dawn asymmetric and stepping (B): new `shared/DayCycle.lua`, equal 36 s ramps, tint interpolated every frame
  between server ticks; phases morning / afternoon / dusk / night / dawn. Tested for smoothness.
- Snap teleports the camera (B): snaps slide over 0.1 s.
- Phone readability (B): clock and banner have minimum pixel sizes; name labels clamp text to 10-20 px.
- Samey village names (A): names sharing the first 3 or last 4 letters are re-rolled.
- Bed reads as a blue box (A, B): redrawn (wood frame, pillow, folded sheet, red blanket). Sheet re-uploaded (decal
  125789431816942); `Sprites.lua` and `assets.lock.json` committed.
- Step rules duplicated and untested (C): `shared/Movement.lua` + `test/luau/movement.test.luau`.
- Turn spam / WorldInit spam (C): turns broadcast only on a real facing change; moves and turns are not echoed to the
  mover; WorldInit answered at most once a second per player.
- Ghost re-add from a late WorldInit (C): `addPlayer` ignores players no longer parented to Players.
- Caves not reachability-tested (C): caves are placed after the roads, only where the tile south of the mouth is
  reachable from spawn; tested on 7 seeds (this found an unreachable cave on seed 7 before the change).
- Lint warnings (C): all cleared; `npm run lint:luau` is clean.

### Also fixed (found while fixing)
- `test/luau/run.js` never rewrote `exports/world_1.txt` on Windows (luau prints CRLF; the MAPFILE regex wanted LF), so
  on this PC the ASCII map and world PNG were stale. Line endings are normalised now.
- Player attributes `TileX`, `TileY`, `MoveEpoch` (server) and `PredictedX`, `PredictedY` (client) so QA can compare
  authority with prediction from the MCP.

### Deferred
- Tall grass visually hiding the player (A): belongs with the hiding mechanic (DESIGN.md §11), which arrives with
  wildlife and NPCs next PR; drawing it now promises a mechanic that does nothing.
- Water shore edges and blocky river diagonals (A): an art pass of about 8 edge tiles; not in this PR's goals.
- Empty middle meadow (A): wildlife, camps and NPCs next PR are the intended fill; decoration now is placeholder work.
- Distance-based replication filtering (C): matters once NPCs exist; moves already go only to other players.
- Default mobile thumbstick/jump without a character (A, B, C uncertain): not testable in Play Solo; tap-to-move covers
  touch for now.
