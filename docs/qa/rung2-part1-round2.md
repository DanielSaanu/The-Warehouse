# QA round 2: Rung 2 part 1

Scores: A (average player) 7, B (game feel and readability) 7, C (integration and technical quality) not scored.
**Average of completed reviews: 7.0.** Target (every reviewer >= 8.0) not met.

Danzo ended the loop during round 2: reviewer C was stopped mid-review, and no round 2 fixes or round 3 were run.
Both completed reviewers tested in Studio Play Solo through the Roblox_Studio MCP (one at a time), plus `npm test`,
`test/luau/run.js` and the preview PNGs. Neither found a game error in Output; both saw the server's tile always equal
the client's prediction (epoch 0) and no frozen frames while walking.

---

## Reviewer A: the average player

SCORE: 7/10

I tested in Studio Play Solo. The Output window showed only `[World] seed 1, 96x96, villages: Glenworth (farmer), Kenstow (hunter), Wild's Rest (plunderer) (43 ms)` and `[Sprites] sheet 1: decal 125789431816942 -> image 81987139412456`. The two other error lines came from my own probe commands, not the game. `npm test` passed 11/11 and `node test/luau/run.js` passed (movement and worldgen on 7 seeds). No tracked files were changed. `bin/warehouse.js` was already modified before I started.

What a player sees, from the Studio run:
- **Spawn:** you appear at (29,70) on the path inside the palisade. The clock reads "Day 1, morning" and the banner reads "Glenworth / farmers - the morning after", then fades after 3 s. Three burnt huts with glowing embers, one intact hut, a stall, a bed and two farms tell the story without words.
- **Controls hint:** there is none. Nothing on screen mentions WASD or arrows.
- **Walking:** holding D moved me 29→36 in 1.0 s on the road (about 6.8 tiles/s). Server TileX matched PredictedX every time and MoveEpoch stayed 0.
- **Blocked moves:** walking into water at x=53 and into the wall above the gate stopped me cleanly with no snap. Holding S and then A walked left, so the most recent key wins.
- **Banner on return:** walking back through the east gate showed "Glenworth / farmers".
- **Night:** I forced the tint to 0.45. It covered the player, and the clock stayed on top of it.

GOALS:
- Generated 96x96 world: met. `exports/world_1.png` has forest, tall grass, a lake, a river with 3 fords, 3 caves and roads. The north-east and centre are large empty meadows, and there is a stray 1x3 water sliver beside the road near (38,53-56).
- Three villages, plundered start: met. The palisade has north and east gates plus a SW breach, and 3 of 4 huts are burnt (`view_29_70@5x.png`). The raiders' village (Wild's Rest) is a straight road north of your gate, which is good for the story.
- Scrolling 16x12 viewport, keeps aspect: met. In a 1291x606 window the PlayArea was 720x540 (45 px per tile) with black bars and no grey strip. The player stayed centred in the per-frame log (sprite position change 0 while walking).
- Tile-step movement, prediction, validation: met. The frame log over 10 steps had no frozen frames. The client led the server by about 0.05 s, with no snaps. I could not fire remotes from the command bar (sandbox capability error), so I could not test snapping in Studio. `movement.test.luau` shows 354 hacked steps accepted in 51 s against 300 for an honest walker.
- Day/night, HUD clock, banner: met. I saw the HUD and banner live. The tint layering holds (`ScreenCapture_3`, `view_29_70_night@5x.png`), and the 36 s fades are covered by tests.
- 22 sprites, one palette: met. `preview_tiles@4x.png` is cohesive and readable. The burnt hut, stall and bed read at a glance.

PRESERVE (done well, must survive future iterations):
- Order of the per-frame update in `Client.client.lua:421-425` (advance slides, then camera, then layout) and continuous-walk chaining in `Viewport.lua:220-233`: my frame log shows smooth, unbroken walking.
- The start village as a silent story (embers, breach, one surviving hut): it is the strongest first-minute moment.
- Epoch-based snap protocol (`Server.server.lua:388-406`) and PredictedX/TileX attributes: they made desync checkable in 1 line.
- The banner's enter at +1 / leave at +5 rule (`Client.client.lua:199-211`): no flicker walking along walls.
- Loading screen that explains itself after 5 s (`Client.client.lua:64-72`).

FIX (done poorly; why it matters; concretely how to fix):
- No controls hint: a new player sees a character and a clock with no verb. DESIGN §12 defers the teaching to the survivor NPC, but until that exists the first seconds are a guess -> add "WASD / arrows to move" (or "tap to walk" on touch) as a third banner line on first spawn, removed on the first step.
- Scrolling judder at non-16-multiple sizes: at 45 px per tile, one art pixel is 2.81 screen px, and the world moved in uneven 2/3/5/6 px steps per frame at 60 fps (my log). That reads as a slight stutter during the most common activity, walking. -> When the tile size is not a multiple of 16, snap camera and entities to whole screen pixels instead of art pixels (`Viewport.lua:182-186`). Or lower the 85% threshold (`Viewport.lua:112`) so more screens get a clean multiple.
- Half-pixel play area: AbsolutePosition X was 285.5 because of AnchorPoint 0.5 on an odd-width screen, so the pixel art is sampled off-grid -> in `fit()` set the position to an offset of `math.floor((size - t*cols)/2)` with AnchorPoint 0.

CONSIDER (fine but could change; why; how):
- Empty stretches (the NE quadrant and the centre meadow are about 30x40 tiles of grass): at 6 tiles/s that is about 15 s of nothing, and caves are solid dead ends -> scatter cheap props (flowers, stumps, lone rocks) now; wildlife later.
- Player at night: the red shirt goes muddy at 0.55 -> leave a small soft light radius around the local player; that also sets up campfire radius.
- Pace slack lets a cheater walk about 18% faster (354 vs 300) -> acceptable now; tighten MOVE_SLACK once real latency data exists.
- DESIGN.md line 69 says a 2-tile margin (20x16); the code uses 1 tile (18x14) -> align the doc.
- The road stub east of Wild's Rest dead-ends at the template edge -> trim template road ends that no road uses.

UNCERTAIN (could not verify):
- Server snap and anti-speed behaviour live (sandbox blocks FireServer), other players' names and remote slides (single client only), tap-to-move on a real touch device, whether Roblox's default touch thumbstick overlays the play area with no character, and a full natural dusk/dawn transition (I forced the tint rather than waiting 7 minutes).

---

## Reviewer B: game feel and readability

Review lens: game feel and readability. I ran it in Studio (MCP, two Play sessions, now stopped), ran `npm test` (11/11 pass) and `node test/luau/run.js` (movement and worldgen OK on 7 seeds), and looked at world_1.png, view_29_70@5x.png, view_29_70_night@5x.png and preview_tiles@4x.png.

What I saw in Studio: the Output had only `[World] seed 1, 96x96, villages: Glenworth (farmer), Kenstow (hunter), Wild's Rest (plunderer) (42 ms)` and `[Sprites] sheet 1: decal 125789431816942 -> image 81987139412456`, with no warnings or errors. The window was 1291x606, the PlayArea 720x540 at x=285.5 and tiles 45 px. The opening banner "Glenworth / farmers - the morning after" showed. Holding D for 1.5 s moved the player from 29,70 to 40,70 through the east gate. Holding A stopped cleanly at the wall (24,69). Tapping W moved one tile and returned to the idle back-facing frame. Server TileX/Y always equalled PredictedX/Y and MoveEpoch stayed 0, so no snaps. A frame-by-frame record (3 s on RenderStepped) showed the player's AbsolutePosition locked at 623.5 while the world scrolled, walk frames switching once per tile, and no frozen frames between chained steps.

SCORE: 7/10
GOALS:
- 96x96 generated world: met - world_1.png has forest, tall grass, a river with 3 crossings, a lake, 3 caves, roads.
- Three villages, start village plundered: partial - Glenworth reads well (walls, 2 gates, SW breach, 3 burnt huts, farms, stall, bed). But Kenstow and Wild's Rest look the same (same huts, stall and bed on a cross road; world_1.png).
- 16x12 smooth scrolling viewport: met - player locked at x=623.5 while the World frame offset ran -68 to -45, then wrapped with a repaint, with no seam.
- Tile-step movement, prediction, remote players: met for local play (the server always matched the prediction, epoch 0, walls block). Remote players and names not verified.
- Day/night, HUD clock, banner: met - "Day 1, morning" clock and the fading two-line banner seen in Studio. Night tint only checked in the preview PNG, where it stays readable.
- 22 sprites in one palette: met - preview_tiles@4x.png. The burnt hut with its ember, the stall and the cave read at a glance.

PRESERVE (done well, must survive future iterations):
- Update order (Client.client.lua:421-425: step, then camera, then refresh) plus art-pixel quantizing: the player never wobbles against the world.
- Step chaining (`startAt = nextStepAt`, Client:244; Viewport:223): holding a key walks steadily with no stop at each tile.
- Night tint under the HUD (Viewport.lua:82-96, ZIndexBehavior Sibling at Client:48): tinted world, bright HUD.
- The loading text that explains itself (Client:64-72) and the black full-screen backdrop: never a blank or grey screen.
- The opening beat: waking on a road next to burnt huts, with the "the morning after" banner, tells the story without a word.

FIX (done poorly; why it matters; concretely how to fix):
- Phone play area is tiny: on a landscape phone (about 844x354 usable) `fit()` (Viewport.lua:109-112) gives 29 px tiles in a 464x348 box, and about 45% of the width is black bars. Most Roblox players are on phones, and remote name labels bottom out at 10 px (Viewport:208). -> Keep ROWS at 12 but let COLS grow with the aspect ratio (e.g. `cols = clamp(floor(W/t), 16, 22)`), rebuilding the pool on resize. Or take whole-pixel tiles from the height only.
- Tap-to-move gets stuck (Client:257-278): it tries one axis, then the other, then gives up. Tapping past the palisade or a tree walks into it and stops, there is no marker on the target tile, and taps on the black bars do nothing. On touch this is the only control. -> Add a short BFS (WorldGen has flood/findPath) to the tapped tile, capped at about 24 steps. Show a 1-tile target outline in the Entities layer and clear it on arrival.
- Villages look alike: a player entering Wild's Rest (plunderers) sees the same thatched huts as Kenstow. The banner is the only thing that tells them apart. -> Give each tribe a variant hut (hide tent for hunters, spiked or dark hut for plunderers) and one landmark tile (drying rack, totem or skull post) in the templates.

CONSIDER (fine but could change; why; how):
- Half-pixel centring: PlayArea sits at x=285.5 (AnchorPoint 0.5 on an odd-width screen), so every sprite lands on a .5 pixel. With Pixelated resampling that can double or drop a column. -> Set the root Position to `fromOffset(floor((W - t*cols)/2), floor((H - t*rows)/2))`.
- Uneven scrolling: recorded per-frame deltas of 2, 3, 5 and 6 px, because road steps move 1.8 art px per frame at 60 Hz, quantized to 1 or 2 art px. That is a faint shimmer. -> Pick step times that give whole art px per frame (0.133 s = 2 px per frame), or quantize to screen pixels when the scale is 16 px per art pixel or more.
- Non-integer pixel scale: 45 px tiles (2.81x) on Studio's window and 59 px on 1366x768 give uneven art-pixel widths. The 85% rule is a sound trade. Just re-check it once the width grows as suggested above.
- The clock gives no sense of time running out: "Day 1, morning" does not say how close night is. -> Add a small sun/moon progress bar under the text. It will matter once the calamity clock arrives.
- Banner subtitle contrast: gold text (207,169,85) on a 35%-transparent dark band over grass is low contrast. The band also covers the burnt hut and the live hut behind it. -> Raise the band's opacity to about 0.2 transparency, or give the subtitle a stroke. Move the banner lower or make it shorter.
- The HUD clock box covers the top-left tiles (trees were hidden under it in capture 3). -> Make it more transparent or shrink it to the text bounds.
- Remote players' names sit inside World, so the night tint dims them. -> Accept that, or move labels to the overlay later.
- Tall grass reads as a barcode of dark vertical stripes, close to the palisade texture. -> Soften it with 2-3 green shades before the hiding mechanic ships.

UNCERTAIN (could not verify):
- Remote players' slide smoothness under real latency, and name label layout, with only one client.
- Touch input (tap, drag, lift), and whether Roblox shows any default touch thumbstick with no character.
- The night tint and dusk/dawn fade in Studio (not reached; preview PNG only).
- The village-entry banner for Kenstow and Wild's Rest (too far to walk in the time I had; the opening banner works).
- Whether Roblox rounds the .5 PlayArea position when rendering.

---

## Reviewer C: integration and technical quality

Stopped mid-review when the loop was ended; no report.

---

## Open items for a next round (not acted on)

FIX raised in round 2:
- Controls hint on first spawn: "WASD / arrows to move" or "tap to walk", cleared on the first step (A).
- Uneven per-frame scroll steps (2/3/5/6 px) when tiles are not a multiple of 16: quantize to screen pixels at
  those sizes (A FIX, B CONSIDER).
- Half-pixel PlayArea position (x=285.5): place it at a floored offset with AnchorPoint 0 (A FIX, B CONSIDER).
- Small play area on landscape phones: let COLS grow with the aspect ratio (B).
- Tap-to-move stuck behind walls and trees: short BFS path to the tapped tile plus a target marker (B).
- Hunter and plunderer villages look alike: per-tribe hut variant and a landmark tile (B).

CONSIDER raised in round 2: scatter props in empty meadows (A, and A in round 1), a light radius around the player at
night (A), tighten MOVE_SLACK once latency data exists (A), DESIGN.md margin text says 20x16 but the pool is 18x14 (A),
trim unused template road stubs (A), day-progress bar under the clock (B), banner contrast and placement (B), clock box
covering top-left tiles (B), remote name labels dimmed at night (B), softer tall-grass texture (B).
