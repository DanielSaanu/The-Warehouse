# Round 2 — SCORE: 8/10 (target hit, loop ends here)

Reviewer: Opus subagent, 2026-09-18. Studio MCP available; desktop Studio reports `TouchEnabled=false`, so the
touch branch was again reviewed from source — but this reviewer additionally built a throwaway probe button in
Play to establish the underlying Roblox input semantics, which is what turned up the drift bug.

## Report (verbatim)

## What I ran

`npm test` and `node test/luau/run.js` both green (movement/sim/worldgen). `node bin/warehouse.js roblox build` → **"unchanged, asset 82793847565859 (image id, hard-coded)"**, `git status` clean — the sheet on disk matches what is uploaded, so `ui_arrow`/`bag`/`item_knife` will actually render. `preview_tiles@4x.png` renders (round-1 regression fixed; the two arrows are visible bottom-left). `world_1.png`, `view_29_70@5x.png` and the 0.55 night version all read well.

Live in Studio (place "working on it"), full Play session: boot output was only `[World] seed 1…` / `[Sim] 19 villagers…` — **zero game errors** across inventory clicks, bag open/close, dialogue, teleports, `give`, `freeze`. Desktop confirms `TouchEnabled=false`, so `DPad`/`Actions` correctly do not exist; I reasoned about that branch from source and probed the two Roblox semantics it rests on.

**The round-1 fix is real, and I checked the reasoning.** `self.holds` is assigned exactly once, at `Hud.lua:147`; `refreshChrome` (`Hud.lua:720-727`) clears keys in place during `pairs`, collects the closures into `pending`, and calls them *after* the loop — no reentrancy, no orphaned table. `padButton:113` and the catch-all at `Hud.lua:150` both nil the key before firing, so no double-release; `releaseDir` is idempotent anyway. I then verified the underlying API with a throwaway probe button in Play: press → drag off → release elsewhere logged `btnBegan btnENDED uisEnded`. So drag-off *and* lift-away both release. A direction cannot stick.

Verified live: clicking `Inventory.Slot1` enabled its UIStroke and did not swing or move the player (29,70 unchanged); a second click cleared it. `Bag.Bag3` selected food; `Bag.CloseX` (44x44, Z=32) closed the panel and the legend/prompt came back (`Prompt="F: Eat"`). Talking to Brilo Saltby opened the dialogue with four choices, hid the legend and prompt, and `Dialogue.CloseX` closed it and fired `onClose`. `Dialogue.Active=false`, so on touch a tap on the box body *does* reach the handler — "tap to go on" is honest.

Layout math from `Viewport.lua:118-138` (COLS 16/MAX 22, ROWS 12, ART 16): at 844x390 → play 704x384, d-pad buttons 50x45; at 640x360 → 630x360, buttons 45x45; portrait 390x844 → play 384x288, buttons 45x45. **The 44 px promise holds at every size I could produce.**

SCORE: 8/10
GOALS:
- 1 The name: met - `roblox/default.project.json:2` `"Lowlands"`; README leads with it; DESIGN.md §19 strikes it from open questions with a date.
- 2 A d-pad: met - `Hud.lua:322-355`, four `padButton`s at 0.32 of a 140-min frame; release proven by the `btnBegan btnENDED uisEnded` probe.
- 3 Four verb buttons ≥44 px: met - `Hud.lua:365-386`; smallest computed size 45x45 (d-pad) and ~61x64 (acts, 0.46 of a 140x132 min frame).
- 4 Tap-to-move survives: met (by code) - `Client.client.lua:312-316` `pressDir` nils `touchTarget/touchPath` and `setMarker(nil)`; the Touch branch at :574 is untouched. Not exercised on a device.
- 5 Tappable slots: met - verified live both ways (ring on, then off); but see FIX on target size.
- 6 Touch wording: met - keyboard branch read live (`Foot=1-9 to take a slot…`, `Legend=WASD move…`, `More=Esc: leave`); touch strings at `Hud.lua:758-760, 776-782, 839` read correctly, and every `promptFor` return starts `"F: "` so the `gsub` always strips cleanly.
- 7 It fits on a phone: partial - landscape is genuinely clean (360 px of 704 clear between clusters); portrait is not (see FIX).
- 8 Publishing: met - `docs/PUBLISH.md` is 92 lines of exactly the right things: the two clicks, placeId, the free-until-saves rule, store blurbs, the CC-BY credit (lorc/game-icons, the only non-repo asset in `library/index.json`), and the re-upload→`setid` loop with the *wrong-tiles* warning.

PRESERVE (done well, must survive future iterations):
- Routing the d-pad through the same `held` list (`Client.client.lua:312-321`, `onMoveStart/onMoveEnd`): prediction, pace budget and tap-to-move needed zero touch-awareness. This is why the feature is small.
- The two-layer release (button `InputEnded` + UIS catch-all + `refreshChrome` flush). Empirically both layers fire. Do not collapse it to one.
- `closeX` on bag, standing and dialogue: on touch it is the only exit from a panel, and it works.
- `docs/PUBLISH.md` and the honest §19 entry. The limitations are written down where the next person will read them.

FIX (done poorly; why it matters; concretely how to fix):
- **A drifting thumb stops the walk and will not resume.** My probe proved `InputBegan` does *not* re-fire when the press slides back onto the button — only `btnBegan btnENDED` was logged for off-and-back-on. On a phone, thumbs drift constantly on a 45 px target during a long walk, so the player will feel the d-pad repeatedly letting go and have to lift and re-press. -> Make the `DPad` *frame* the input surface: on `InputBegan` over the frame store the input, on `UserInputService.TouchMoved`/frame `InputChanged` hit-test the touch position against the four button rects and swap the held direction (release old, press new); release on the existing catch-all. That also gives free slide-between-directions.
- **The tap targets goal 5 created are ~23-26 px on a phone**, half the 44 px goal 3 set. `Hud.lua:271` gives the touch inventory bar `Size 0.5, 0.062` with `MinSize 250x26`, so slots (RelativeYY) are 26 px tall at 844x390; `Hud.lua:566` sizes the bag `0.66 x 0.82` with no MinSize and rows at `0.072`, so bag rows are ~23 px there. Both routes to "take a slot in hand" are unhittable with a thumb, on the one screen the feature exists for. -> Raise the touch bar's `MinSize` to `(250, 44)`, and give the bag panel a `UISizeConstraint MinSize` (about 320x460) so rows clear 44 px; or on touch draw the bag as a 2-column grid of 44 px rows.
- **Portrait wastes the letterbox and covers the world instead.** At 390x844 the play area is 384x288 centred in the screen, leaving **278 px of black bar above and below** — and the d-pad (140x140) and acts (140x132) are parented to `PlayArea.Overlay`, so they eat ~48% of the play *height* and leave 84 px of 384 clear. I confirmed the nesting live: `PlayArea abs=1254x684 pos=137,4` inside `Viewport abs=1529x693`. The centred legend (`0.3` wide = 115 px) also overlaps both clusters in portrait. -> When the vertical bar exceeds the cluster height, parent `DPad`/`Actions` (and the legend) to the `Viewport` container rather than `PlayArea.Overlay` and pin them into the bottom bar. In landscape the bars are only 70 px wide, so keep today's behaviour there.

CONSIDER (fine but could change; why; how):
- `promptMin.MinSize = Vector2.new(42, 42)` (`Hud.lua:426`) is the one survivor of the 42→44 pass. It never binds (the acts frame forces ≥61 px), but it contradicts the stated rule and will mislead the next editor. -> Make it 44.
- Touch dialogue says "tap a question, or the map to leave" (`Hud.lua:839`) and never mentions the `x` that is now sitting in the corner — the more reliable exit. -> "tap a question, or the x to leave".
- The hot bar stays visible under open panels (`Inventory.Visible=true` with the bag up). On touch it sits top-right where the bag panel reaches. -> Hide it in `refreshChrome` alongside the touch controls.
- `repBtn` shows the word "you" while the panel it opens is titled "Your standing". Fine, but a person icon would survive translation and shrink better.

UNCERTAIN (could not verify):
- The entire `TOUCH == true` branch at runtime. Desktop Studio reported `TouchEnabled=false`, so `DPad` and `Actions` were never instantiated; everything about them above is from source plus the probe. I did not force the layout on, since that would mean editing tracked files.
- Multi-touch (two fingers on two d-pad buttons, or d-pad + attack). Per-finger `InputObject` keys in `holds` make it look correct, but a mouse cannot exercise it.
- Real finger accuracy on a real phone, and whether tap-to-move and the d-pad fight each other in practice. This is genuinely what publishing is for.
- Two players at once, and leaving mid-move — not in scope for this PR and not exercised.

## Builder decisions

The score hit the 8.0 target, so the loop ends here. FIX items were still acted on first, as the procedure requires.

**FIX — two of three taken, one deferred.**

- **Drifting thumb — taken, and it was the best find of the loop.** The reviewer's probe result (`InputBegan` does
  not re-fire when a press already down slides back onto a button) is the kind of thing that only shows up on a
  real device, and it would have made the d-pad feel broken during exactly the long walks the game is made of.
  Implemented close to the suggestion but tracked per frame rather than via `TouchMoved`: `padTake` records the
  `InputObject` and calibrates an offset from the button it landed on, `refreshChrome` re-tests that point against
  the four rects every frame, and `padSteer` swaps the direction (release old, press new). Calibrating the offset
  at press time means the input's coordinate space and the GUI's never have to be assumed equal, which they are
  not, and it makes the mouse and touch paths identical.
  Verified live with the touch layout forced on: held the right arrow and walked x 45 -> 59, slid to the up arrow
  **without lifting** and walked y 68 -> 64, then released and stopped. Sliding between arrows now works, which
  the reviewer correctly noted comes free with the fix.
- **23-26 px tap targets — taken.** On touch the bag is now a two-column grid: rows measured live at 47 px
  (844x390) and 44 px (640x360), up from 23. The hot bar itself stays a display: ten 44 px slots need 440 px of
  width, which a 384 px portrait play area cannot give, so the bag is the honest selection surface and its footer
  already points there. The bar is still tappable where there is room for it.
- **Portrait letterbox — deferred.** The recipe is right and the measurement is right, but it means re-parenting
  `DPad`/`Actions`/legend out of `PlayArea.Overlay` into the `Viewport` container and re-deciding on every resize,
  which changes the Viewport/Hud contract that everything else in the HUD depends on. Portrait is already recorded
  in DESIGN.md §19 and the goals file as not the intended orientation, landscape measures clean at every size, and
  this is the wrong moment in a PR to take on that coupling. It belongs in its own small PR.

**CONSIDER — three of four taken.**

- `promptMin` 42 -> 44 — **taken**. It never binds, but a stated rule with an exception in the source is a trap.
- Dialogue touch text now says "tap a question, or the x to leave" — **taken**.
- Hot bar hidden under panels on touch — **taken**, `refreshChrome` hides it with the rest of the chrome.
- A person icon instead of the word "you" — **not taken**. A new sprite and a sheet re-upload for a label that is
  already legible is not worth the round trip; worth doing next time the sheet changes for another reason.
