# QA round 1: Rung 2 part 2

SCORE: 8/10 (reviewer: one Opus agent, live in Studio through the Roblox_Studio MCP)

## Reviewer report (verbatim)

QA review — branch `rung2-part2` (1fd3ea8, 63ab7f6)

Tested live in Roblox Studio (Play started and stopped; Debug/DebugResult attribute channel on Workspace; keyboard + mouse driven through the MCP; GUI read from the Client datamodel). `npm test`, `node test/luau/run.js` and `npm run lint:luau` all pass (20/20 modules `ok`). Console over the whole session showed **zero game errors** — only my own AssistantCommand mistakes.

SCORE: 8/10

GOALS:
- 1. First five minutes: met - `player` returned `knifex1,waterskinx1,foodx2,camper_setx1`; F on "Lorwyn Saltby" (survivor) opened a 6-page script naming the player ("Stifffchoclate. You're alive."); the guard shares the surname (Brilo Saltby); Hint "WASD to walk · click to swing · F to talk, trade, rest" showed on spawn and cleared after the first step.
- 2. Attack with feel rules: met - swing took boar e62 hp 8→6 and knocked it 30,70→31,70 into `chase`; Output `[Sim] … hit by wolf (e64) for 3 -> hp 7 at 4317.43` / `… hp 4 at 4319.24` = 1.81 s apart (TELEGRAPH 0.5 + cooldown 1.0, Config.lua:37-39); hearts HUD present; `kill` dropped the whole inventory as a bag, respawn in ~3 s at Glenworth with a knife, rep unchanged 20/0/-20 (63ab7f6, Reputation.lua:71).
- 3. F, one prompt at a time: met - Prompt cycled "F: Talk"/"F: Camp" live; guard opened the four-choice window (road/tribes/prices/me) and "Ask about the road" answered with live state: the active flood, "the band was last seen north-east of here", and the region's wildlife.
- 4. Trade: met - verified live at the Glenworth stall: sold 2 hides → coin 80→86, stock 5→7, buy 5→4, sell 3→2; title "Glenworth (farmers, you are welcome here)"; camper-set row priced 14.
- 5. Rest and camp: met (code + prompt) - Sim.lua:911-978 and Interact.lua:161-236 are complete and coherent (new camp clears the old, fire→`camp_out`, wolves trample an out camp, flood destroys camps on flooded tiles, `restAt` refuses when standing < neutral). I saw "F: Camp" but never got a camp placed live (see UNCERTAIN).
- 6. Reputation per tribe: met - Standing screen read "the Glenworth tribe welcome / the Kenstow hunters neutral / the Wild's Rest band wary"; fade observed live across one in-game day (20 → 19.5432).
- 7. NPC groups with routes: met - `state`: caravan 3 members route 1/56, squad 4 route 37/109, band 4 route 33/35; `summon caravan` moved it 8 tiles and it materialised (merchant + 2 guard sprites on screen).
- 8. Wildlife from regional counts: met - deer 131→137, boar 47→48, wolf 15→16 over an in-game day; wolf aggroed 0.6 s after `night` and killed to 4 hp; boar only charged after being hit; Ecology 200-day test survives (deer 62 boar 42 wolf 8).
- 9. Weekly calamity + debug channel: met - `calamity flood` painted 106 `flood` ground tiles on the client, banner "Flood / The river has burst its banks…", and shoved the player off the flooded tile (epoch 4→5). ~15 debug commands all worked.
- 10. Villages look different: met - exports/view_65_57@5x.png (hide tents + totem), exports/view_58_33@5x.png (dark spiked huts + skull post) vs the thatch-and-palisade farmers in view_29_70@5x.png.
- 11. Part 1 leftovers: met - PlayArea 1298x708 on a 1.83 aspect = 22 columns (Config.MAX_COLS), no black bars (Viewport.lua:117); hint clears on first step; tap-to-move BFS covered by test/luau/sim.test.luau:147.
- 12. Art: met - 74 new scenes + 27 sprite files, one 128x256 sheet, 97 sprites, asset id 92588138876546 in both `Sprites.lua` and `assets.lock.json`, working tree clean.
- 13. State shaped for persistence: met - Sim.lua:37-50, everything in `Sim.state`, nothing in closures.

PRESERVE:
- The knowledge bank wired to live state (Interact.lua:35-70, Talk.lua): the guard telling me where the band actually is, that a flood is on, and what the region's wildlife is doing is the whole payoff of the simulation, in one screen of text.
- Prices that move with stock and standing (Trade.lua:31-43) — selling two hides visibly moved four numbers. That is the trade loop working.
- Server authority + epoch fencing (Server.server.lua:113-138): PredictedX/Y matched TileX/TileY at every check, including after knockback, flood displacement and respawn.
- The debug attribute channel (Sim.lua:1180-1300): it made this whole review possible. Keep it.
- Zero runtime errors and `pcall` around every think/tick (Sim.lua:1122-1160).

FIX:
- **Four empty grey buttons on every choice-less dialogue.** Hud.lua:442 `b.Visible = c ~= nil` — when `hasChoices` is false, `c` is `false`, and `false ~= nil` is **true**. Verified live: during the survivor's opening speech all four Choice buttons were `Visible=true` with `Text=''`, BackgroundTransparency 0, 421x41 px each, covering the right 35% of the panel. This is the first thing a new player sees, and it hits villagers, the caravan master and refusals too. -> `b.Visible = c ~= nil and c ~= false` (or `local c = (hasChoices and last) and d.choices[i] or nil`).
- **Guard topics resolve the tribe from the player's tile, not the conversation.** Interact.lua:249-251 `local ti = tribeAt(ps.x, ps.y) or 1` — talk to a guard from a tile `villageAt(...,1)` does not cover and you silently get *farmer* prices and rumours from a hunter guard. -> store `tribe = tribeIdx` in `ps.dialogue` in `dialogue()` (Interact.lua:73) and read it back in `topic`.
- **Trade rows are column-aligned text in separately-scaled labels.** The header ("good stock buy sell you have") and each row are independent `TextScaled` TextLabels (Hud.lua:21-36), so the columns only line up by luck, and on a phone `TextWrapped` will fold a row and destroy the alignment. -> give each row real sub-labels with fixed scale positions, or drop `TextWrapped` and let MinTextSize 10 clip.

CONSIDER:
- Flood text vs behaviour: the notice says "under water until nightfall" but `tickCalamity` only ends it when `day > c.day` (Sim.lua:1063), i.e. at the next day boundary. -> either end it at `frac >= 1 - NIGHT_FRACTION` or say "until tomorrow".
- Pressing F at a tree or a wall does nothing at all — no prompt, no message (Interact.lua:230-236 falls through). I hit this twice while testing and thought the key was broken. -> a cheap "Nothing here." notice.
- `endCalamity` early-returns when not active but is the only place `c.warned` resets (Sim.lua:1057-1066), so a warning that never fires an event latches warnings off forever.
- Villages read as five scattered huts for a stated population of 30-60; the farmer village in view_29_70@5x.png is mostly empty grass inside a big palisade. Denser footprints would sell the "living world" better.
- A wolf spawned near the player survives daybreak while a player is within 9 tiles (Sim.lua:301) — I had a wolf on screen at "Day 2, morning".

UNCERTAIN:
- Camp placement at runtime: every tile I faced was water or tree, so I never saw a camp appear, the fire burn down, or wolves trample it. Code path looks right; unverified live.
- Beast tide: only flood was triggered. `Ecology.beastTide` is unit-tested but I did not see one in game.
- Two players, PvP visibility, and leaving mid-move: single-player session only.
- Phone-shaped screens: only measured the 1529x717 Studio window (which already hit MAX_COLS=22).

## Builder decisions

PRESERVE: all five kept as is. The fixes below touch Hud.lua (dialogue and trade layout only), Interact.lua (topic
tribe, a "Nothing here" line) and Sim.lua (calamity warning reset, flood wording). No change to the knowledge bank,
prices, movement authority, the debug channel or the pcall guards.

FIX, all three done:
- Empty choice buttons: `Hud.renderDialogue` now computes the choice as `nil` when there are no choices, so the
  buttons hide; the text label also takes the full width whenever no choice is shown.
- Guard topics: `dialogue()` records the tribe of the person you are talking to in `ps.dialogue.tribe`; `topic`
  uses it. The player's tile is no longer consulted.
- Trade rows: each row has separate labels for name, stock, "you have" and two buttons at fixed scale positions,
  no wrapping; the header uses the same positions. Columns line up on any width.

CONSIDER:
- Flood wording: changed to "until tomorrow" (the flood ends at the day boundary, which is what the code does; ending
  at dusk would strand people the other side of the river at night).
- "Nothing here." on F at a solid tile: done (only when the tile in front is not walkable and holds nothing usable).
- Warning latch: `warned` is now keyed by day (`warnedDay`), so a warning can never be latched off across weeks.
- Denser villages: deferred. It is a template and art pass (more huts, fences, props) that belongs with the next art
  round; noted in the summary.
- Wolf at daybreak near a player: kept on purpose. A wolf that is chasing you should not vanish in front of you; it
  folds back when you are more than 9 tiles away. Noted.

UNCERTAIN: the builder verified camp placement, the fire going out (`camp_out`), camp respawn and the beast tide live
in Studio before the review (notices, objects and 17 tide wolves in the north at night). Two players and phones remain
untested here.
