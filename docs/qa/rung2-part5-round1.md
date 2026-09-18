# Round 1 — SCORE: 7/10

Reviewer: Opus subagent, 2026-09-18. Studio MCP available; touch widgets could not be instantiated on a desktop
Studio, so the whole `if self.touch` branch was reviewed by reading code.

## Report (verbatim)

## What I ran

- `npm test` — 11/11 pass. `node test/luau/run.js` — movement, sim, worldgen, families all `ok`.
- Studio MCP (`f4251802…`, place "working on it"): started Play, waited 9 s, read Output. Exactly two lines, no errors or warnings:
  `[World] seed 1, 96x96, villages: Glenworth (farmer), Kenstow (hunter), Wild's Rest (plunderer) (21 ms)` / `[Sim] 19 villagers, 3 groups, 36 regions`. Read the live GUI tree on the Client datamodel, then stopped Play. Working tree left clean (`git status --porcelain` empty).
- Tried to force the touch layout by `require`ing the Hud module in the Client sandbox: refused — *"The current thread cannot require 'Hud' since 'Hud' has additional values for the Capabilities property: LoadUnownedAsset (and 3 more)"*. So the entire touch branch is reasoned from code, not observed.
- Rendered `ui_arrow@16x.png` (clean, readable chevron+shaft, 2 colours, reads at 42 px) and `view_29_70@5x.png` + night (unchanged, still legible). `render preview_tiles` fails with `ENOENT scenes/water.json` — **pre-existing on main** (`git show main:scenes/preview_tiles.json` has the same 6 refs), not this PR.

## Notable good news the goals did not ask about

`roblox/assets.lock.json` was genuinely re-uploaded for the new sprite (`assetId` 132265826966593 → 82793847565859, `uploadedAt` 2026-09-18, `manual: true`) and `Sprites.lua` regenerated with `["ui_arrow"] = { Sheet = 1, X = 239, Y = 86 … }`. Adding a sprite after PR #8 hard-coded the image id is exactly the trap CLAUDE.md warns about — every other sprite's rect shifted — and it was handled. Had it not been, the published game would have shown garbage.

## The one real bug

`Hud.lua:78` — `padButton(holds, …)` **captures the table** `self.holds` in its `InputBegan`/`InputEnded` closures. `Hud.lua:713-717` (`refreshChrome`) **rebinds** it: `local holds = self.holds; self.holds = {}`. After the first time a panel opens while a direction is held (two thumbs: hold left, tap bag), the buttons write into the orphaned table while the `UserInputService.InputEnded` catch-all at `Hud.lua:146-149` reads the new empty one. From then on the safety net is dead for the session: a thumb that slides off a d-pad button and lifts elsewhere never releases, and `refreshChrome` can never clear it either (`next(self.holds)` is permanently `nil`). The stuck direction is precisely the failure the feature's own comment says it exists to prevent.

---

SCORE: 7/10

GOALS:
- 1 The name: partial - `roblox/default.project.json:2` and `docs/DESIGN.md:1,397-402` say Lowlands; `README.md:1` is still "# The Warehouse" and the word Lowlands appears nowhere in it, though the goal names the README.
- 2 A d-pad: met - `Hud.lua:311-348`, touch-only, feeds `pressDir`/`releaseDir` (`Client.client.lua:311-321`) into the same `held` list the keyboard uses; `InputBegan`/`InputEnded` rather than `Activated` is the right call for multi-touch. Release safety net present but broken (see FIX).
- 3 The other four verbs: partial - all four exist (`Hud.lua:350-372` + the prompt repurposed at `410`, `421-433`) and act is always visible (`768-774`), but the stated 44 px floor is missed: `padButton(..., 42)` for the d-pad and for bag/standing, and `0.32 × 132 = 42.2 px` is the actual size at the pad's `MinSize`. Only Attack gets 48.
- 4 Tap-to-move survives: met - `Client.client.lua:569-573` still aims on touch, the `processed` guard means GUI taps do not double as map taps, and `pressDir` clears `touchTarget`/`touchPath` and the marker (`314-315`).
- 5 Tappable slots: met - verified live in Studio: `Slot1 class=TextButton`, `Bag1…Bag10/TextButton`; wired at `Hud.lua:292,582` to `onSelect = selectSlot`; `SLOT_KEYS` 1-9 untouched (`Client.client.lua:566`).
- 6 Touch wording: met - `Hud.lua:748-750` (bag footer), `828-832` (dialogue "tap to go on"), `912` (standing), `553` (trade close), `Client.client.lua:134` (`TOUCH_LEGEND`).
- 7 It fits on a phone: partial - arithmetic holds in landscape (640×360 play area: `640 − 20 − 140.8 − 153.6 = 326 px`, 51 % of width clear), but at a 390-wide portrait play area both `MinSize` floors dominate and only `390 − 20 − 132 − 140 = 98 px` (25 %) stays clear. Could not measure live.
- 8 Publishing: not met - nothing new. No description text for the Roblox page exists anywhere in the repo; the "two-click handover" is the pre-existing `docs/DESIGN.md:351-353`, untouched by this branch (the DESIGN diff is only the title, the §16 rung-3 lines and §19).

PRESERVE (done well, must survive future iterations):
- One input path for both devices: `pressDir`/`releaseDir` (`Client.client.lua:311-321`) means prediction, the pace budget and tap-to-move needed no touch-awareness at all. This is why the change is 250 lines and not 800.
- `closeX` on dialogue, bag and standing (`Hud.lua:104-127`, used at `464,599,613`): the thumb controls hide behind an open panel, so without it a phone player is trapped. Someone thought this through.
- Re-uploading the sheet and regenerating `Sprites.lua` in the same commit as the new sprite — the thing CLAUDE.md says goes wrong.
- `padButton` using `InputBegan`/`InputEnded` instead of `Activated`; `Activated` does not multi-touch cleanly.

FIX (done poorly; why it matters; concretely how to fix):
- Orphaned `holds` table (`Hud.lua:78` vs `713-717`): after one panel-open-while-held, a direction can stick forever — the exact bug the d-pad was designed to avoid, and the hardest kind for a player to describe. -> Clear in place instead of rebinding: `for i, up in pairs(self.holds) do self.holds[i] = nil; up() end` (nilling the current key during `pairs` is legal), or pass `self` to `padButton` and index `self.holds`.
- 42 px touch targets (`Hud.lua:330,352,359`) against the PR's own 44 px promise, and `closeX` is a fixed `34×34` (`Hud.lua:137-138`) while being the *only* exit from the bag and standing panels on touch. -> Raise `padButton` minimums to 44; give `closeX` a `UISizeConstraint` of 44×44 (or 44 wide with a transparent hit pad).
- Goal 8 is undelivered. A stranger cannot find the game from this repo. -> Add the Roblox page blurb and the publish/playability steps to `README.md` (which should also lead with Lowlands), or a `docs/PUBLISH.md`, and include the CC-BY credit line `library/index.json` owes.

CONSIDER (fine but could change; why; how):
- `repBtn.Text = "rep"` (`Hud.lua:360`): a new phone player has no idea what "rep" is, and it is the only verb button without an icon. -> Reuse the standing/totem sprite, or label it "you".
- The act button's text is the prompt minus `"F: "` (`Hud.lua:770`), so it shows "Give Bread" or "Pick up" in a ~60 px `TextScaled` button. `button()` (`Hud.lua:55-71`) never sets `TextWrapped`, so it will bottom out at `MinTextSize` 10 and clip. -> Set `TextWrapped = true` on the touch prompt, or map long prompts to one word.
- `TOUCH` is decided once at module load (`Client.client.lua:134`) and the layout once at `WorldInit`. A Bluetooth keyboard paired mid-session leaves the d-pad up; a tablet with a keyboard attached gets no d-pad at all. Acceptable for now — worth a note in §19.
- `anyOpen()` (`Hud.lua:930-932`) excludes `deadFrame`, so the d-pad sits under the death overlay (ZIndex 40, non-Active Frame, so taps fall through). Movement is gated by `blocked = me.dead` (`Client.client.lua:598`), so it is cosmetic only. -> Hide `touchControls` on death too.
- `render preview_tiles` has been broken since before this branch (`scenes/water.json` missing) while CLAUDE.md tells every session to run it. -> Point it at `water_0` or add the alias.

UNCERTAIN (could not verify):
- Everything inside `if self.touch`. The sandbox refuses to `require` Hud, and desktop Studio reported `TouchEnabled=false Keyboard=true` with no `DPad`/`Actions` in the overlay, so no touch widget was ever instantiated in my session.
- Whether Roblox fires `GuiObject.InputEnded` when a touch *slides off* a button (the case the catch-all exists for). If it does not, the orphaned-table bug above is the whole safety net.
- Multi-touch: holding a direction while tapping swing was not exercised by anyone, including me.
- The top-right inventory bar on touch (`Hud.lua:264-272`, `MinSize 250×26`) versus the clock at top-left: at a 390-wide play area they clear each other by roughly 11 px by my arithmetic. Not measured.
- Real finger sizes on real glass. The known-limitations list is honest about this and it is what publishing is for.

## Builder decisions

**FIX — all three taken.**

- **Orphaned `holds` table.** Confirmed by reading `Hud.lua:713-717`: `refreshChrome` rebound `self.holds` while
  `padButton`'s closures held the old table. Real, and exactly the failure the feature exists to prevent. Fixed by
  clearing in place and never rebinding, with a comment on the table saying so.
- **42 px touch targets.** Taken: `padButton` minimums raised to 44, the d-pad frame's `MinSize` raised to 140 so
  `0.32 × 140 = 44.8` clears the promise at the floor, and `closeX` given a 44×44 `UISizeConstraint`. The reviewer
  is right that `closeX` mattered most: on touch it is the only exit from the bag and standing panels.
- **Goal 8 undelivered.** Correct — I wrote none of it. Added `docs/PUBLISH.md` (the Roblox page blurb, the exact
  publish and playability clicks, the re-upload-then-`setid` loop, and the CC-BY credit `library/index.json` owes)
  and made `README.md` lead with Lowlands.

**CONSIDER — four taken, one deferred.**

- `repBtn.Text = "rep"` → **taken**, now "you", to match the panel's own "Your standing".
- Act button text clipping → **taken**, `TextWrapped = true` on the touch prompt.
- Touch controls under the death overlay → **taken**, `refreshChrome` now hides them while the death overlay is up.
- `render preview_tiles` broken by the `water.json` → `water_0` rename → **taken**. This was my breakage in part 4,
  not pre-existing as the reviewer generously assumed; CLAUDE.md tells every session to run it. Repointed and the
  five sprites added since were added to the sheet.
- `TOUCH` decided once at module load → **deferred**, noted in DESIGN.md §19. Re-laying out the whole HUD when a
  Bluetooth keyboard appears mid-session is a bigger change than the case deserves, and a tablet with a keyboard
  attached still has every verb on a key.

**Deferred**

- Portrait at 390 px wide leaves only ~25% of the width clear between the thumbs. Real, but the honest floor for a
  44 px d-pad is about 140 px and there is no way around that on a narrow screen; landscape is the intended
  orientation. Recorded in the goals file's known limitations rather than papered over.
