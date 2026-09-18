# QA goals: Rung 2 part 5 (a phone can play it, and strangers can find it)

Branch: `rung2-part5`, from `main` after PR #8. Source: DESIGN.md §16 ("Publish free well before that: real
players find what we cannot"), §19 (touch controls were an open question), and §11 ("Touch: swipe direction or a
d-pad (later)"). Part 4 made the first five minutes teach themselves; this part makes them teachable **on a phone**,
and gets the game in front of people who are not us.

Both going-public chores from §16 are already done (PR #8): the image id is hard-coded with `Resolved = true` and
the loading message no longer mentions `rojo`. What is left is the game being playable with thumbs.

## Goals of this PR

1. **The name.** Lowlands (Danzo, 2026-09-18). `roblox/default.project.json`, the README and DESIGN.md §19 all say
   so, and §19 drops it from the open questions.
2. **A d-pad.** Four arrow buttons in a cross, bottom-left, only built on a touch device. Hold to walk, exactly as
   a held key walks: the direction goes into the same `held` list the keyboard uses, so prediction, the pace budget
   and tap-to-move all behave as they already do. Sliding a thumb off a button releases it; losing the touch
   entirely releases everything, so a direction can never stick.
3. **The other four verbs get buttons.** Attack (the knife), act (F), bag (E) and standing (Tab), bottom-right,
   sized so a thumb can hit them (no smaller than 44 px on any screen). The act button is always there, not only
   when something is in front of you, because eating needs F with nothing in front.
4. **Tap-to-move survives.** Tapping the map still walks you there with a marker, and touching the d-pad cancels
   it. Both ways of moving work, because travel wants one and a doorway wants the other.
5. **Tappable slots.** The hot bar slots become buttons: a tap takes that slot in hand, a second tap puts it away.
   Keyboard players get this too; 1-9 keep working.
6. **Touch wording.** The key legend, the bag panel footer and the dialogue's "F / click: more" say what a thumb
   should do when there is no keyboard, and say the keyboard thing when there is one.
7. **It fits on a phone.** Panels, the prompt and the legend are checked at a phone's aspect ratio and at the
   smallest tile scale the viewport will pick, and the touch buttons never cover the play area's centre.
8. **Publishing.** The repo carries what a stranger needs (name, description text for the Roblox page, and the
   two-click handover written down). Danzo does the publish itself: it is his account.

## Out of scope (do not penalise absence)

Persistence and catch-up; gossip and grudges; hunger; tribute and tax; dash, block and bows; a title screen;
music; gamepad support; landscape-lock; shore edge tiles; anything in rung 3.

## Known limitations the builder is aware of

- The touch buttons sit inside the play area rather than in the letterbox bars, so on a very narrow screen they
  overlap the world. They are translucent and out of the centre, but they do overlap.
- There is no swipe-to-walk. DESIGN.md §11 offered swipe *or* a d-pad; the d-pad is the discoverable one, and a
  tile game wants discrete steps rather than an analogue direction.
- The game has never been run on a real phone, only at phone aspect ratios in Studio (640x360, 844x390 and
  1024x768 were checked; nothing left the play area and the middle half of the width stayed clear of both thumbs).
  Fingers are fatter than a mouse cursor. That is what publishing is for.
- Portrait on a narrow phone is cramped: a 44 px d-pad needs about 140 px of width whichever way it is drawn, so
  at a 390 px-wide play area only about a quarter of the width is clear between the two thumb clusters. Landscape
  is the intended orientation and is comfortable (51% clear at every size checked).
- The touch path was driven with a mouse in Studio, by forcing the touch layout on. Mouse and touch both come
  through `padButton` as a press, so the wiring is genuinely exercised, but multi-touch is not: nobody has yet
  held a direction with one thumb while tapping swing with the other.
