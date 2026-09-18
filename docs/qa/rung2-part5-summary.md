# QA summary: Rung 2 part 5 (Lowlands — a phone can play it)

Two rounds, one Opus reviewer each, target 8.0. Hit in round 2, so the loop stopped there.
Verbatim reports: `docs/qa/archive/rung2-part5-round1.md`, `docs/qa/archive/rung2-part5-round2.md`.

## Scores

| Round | Score | Main finding |
| --- | --- | --- |
| 1 | 7/10 | The d-pad's own safety net was broken: `refreshChrome` rebound the `holds` table that every button's closures had captured, so after one panel-open-while-held a direction could stick for the rest of the session. Goal 8 (publishing) was not done at all. |
| 2 | 8/10 | The round-1 fix verified by reasoning and by an API probe. But a thumb drifting off a d-pad button stopped the walk and could not resume, because Roblox does not re-fire `InputBegan` for a press already down — and the tap targets goal 5 created were 23-26 px on a phone, half the 44 px goal 3 promised. |

## Fixed

**Round 1**

- **The stuck direction.** `refreshChrome` rebound `self.holds`, orphaning the table `padButton`'s closures held.
  Buttons then wrote to one table while the catch-all read another, permanently. Now cleared in place, never
  reassigned, and the code says why. Verified live: held the d-pad right (x 45 → 49), opened a panel over the held
  direction, player stopped at 49 and was still at 49 three seconds later.
- **The 44 px promise the PR made and missed.** `padButton` minimums 42 → 44, d-pad frame `MinSize` 132 → 140
  (0.32 of it = 44.8), `closeX` 34×34 → 44×44 with a size constraint. `closeX` mattered most: on touch it is the
  only way out of the bag and standing panels.
- **Goal 8, which was simply undone.** `docs/PUBLISH.md`: store blurb, the two clicks, placeId, the
  free-until-saves rule, the re-upload → `setid` loop with its wrong-tiles warning, and the CC-BY credit
  `library/index.json` owes. `README.md` now leads with Lowlands.
- "rep" → "you"; `TextWrapped` on the act button so "Give hides" wraps instead of clipping; touch controls hidden
  under the death overlay.
- `warehouse render preview_tiles` works again — broken since part 4 renamed `water.json` to `water_0.json`, and
  CLAUDE.md tells every session to run it. Repointed, plus the five sprites drawn since.

**Round 2**

- **The drifting thumb.** The reviewer's probe established that Roblox does not re-fire `InputBegan` when a press
  already down slides back onto a button, so the d-pad would have let go repeatedly during exactly the long walks
  the game is made of. The press is now tracked from where it lands: `padTake` calibrates an offset from the
  button under the thumb, `refreshChrome` re-tests that point against the four rects every frame, `padSteer` swaps
  the direction. Sliding between arrows without lifting comes free. Verified live: walked right x 45 → 59, slid to
  the up arrow without lifting and walked y 68 → 64, released and stopped.
- **Tap targets on a phone.** The bag is a two-column grid on touch: rows measured 47 px at 844×390 and 44 px at
  640×360, up from 23 px.
- `promptMin` 42 → 44 (the last survivor of the pass); the touch dialogue now names the `x` as the way out; the
  hot bar hides under panels on touch.

## Preserved (confirmed in both rounds)

- **One input path for both devices.** The d-pad feeds the same `held` list the keyboard uses, so prediction, the
  pace budget and tap-to-move needed no touch-awareness at all. Both reviewers called this out as the reason the
  feature is small.
- **The layered release.** Button `InputEnded`, plus a `UserInputService` catch-all keyed on the `InputObject`,
  plus a flush when a panel opens. Round 2 proved empirically that both layers fire. Do not collapse it to one.
- **`closeX` on dialogue, bag and standing.** On touch it is the only exit from a panel.
- **Re-uploading the sheet and regenerating `Sprites.lua` in the same commit as a new sprite.** Adding one sprite
  shifts every other sprite's rectangle, so skipping it shows wrong tiles, not blank ones.
- **`docs/PUBLISH.md` and the honest §19 entries.** The limits are written where the next person will read them.

## Deferred

- **Portrait wastes the letterbox.** At 390×844 the play area is 384×288 with 278 px of unused black bar, and the
  thumb clusters eat the play area instead. The fix means re-parenting them out of `PlayArea.Overlay` into the
  `Viewport` container and re-deciding on every resize, which changes a contract the whole HUD rests on. Landscape
  measures clean at every size and is the documented intended orientation. Its own PR.
- **`TOUCH` is decided once at module load.** Pairing a Bluetooth keyboard mid-session leaves the d-pad up; a
  tablet with a keyboard attached never gets one. Every verb is on a key in that case, so nobody is stuck.
  Noted in DESIGN.md §19.
- **A person icon instead of the word "you".** A new sprite plus a sheet re-upload for a label that already reads
  fine. Worth folding in next time the sheet changes anyway.

## Open FIX items not acted on

Only the portrait letterbox, above, with reasoning. Nothing else was left.

## Still unverified by anyone

- **The touch branch on a real touch device.** Desktop Studio reports `TouchEnabled=false`, so both reviewers read
  it from source. The builder drove it with a mouse by temporarily forcing the layout on, which exercises the same
  `padButton` press path, but that is not a finger.
- **Multi-touch.** Nobody has held a direction with one thumb while tapping swing with the other. The per-finger
  `InputObject` keys in `holds` look correct for it.
- **Real finger accuracy on real glass**, and whether the d-pad and tap-to-move fight each other in practice.
  This is what publishing is for.
