# QA goals: Rung 2 part 4 (the first five minutes, for real)

Branch: `rung2-part4`, from `main` after PR #7. Source: the first playtest (`ideas/INBOX.md`, "Playtest
2026-09-17"), whose verdict was "kind of boring, I don't know what to do", and DESIGN.md §12, which promises a
first five minutes where one person tells you where to go. Everything here is about a stranger playing past minute
three without a human explaining the keys.

## Goals of this PR

1. **The survivor cannot be missed.** A bobbing marker sprite floats over the survivor until you have talked to
   them, and the opening banner's second line reads "Someone is calling you" instead of the tribe word. The
   survivor's last line becomes the first goal (goal 3).
2. **Signs.** A new `sign` object (solid, prompt "F: Read"). World generation places one at every gate or road
   exit of each village and at each ford, with text built from the world: "Kenstow, east. Hunters." /
   "Glenworth, west. Farmers." / "Ford. Wolves at night. Stay on the road." A line on first spawn: "Read the
   signs." Reading a sign opens the dialogue box with one page.
3. **A goal line, not a quest log.** One sentence under the clock, set by the server and changed by events:
   "Talk to the person calling you" -> "Go east down the road to Kenstow" (on finishing the survivor's talk) ->
   "Talk to the guard at Kenstow" (on entering Kenstow) -> "Sell a hide at a stall" (after the guard) -> "Be
   inside walls or by a fire before day 7" (after the first sale, and always on days 6 and 7). Cleared on the
   first calamity. Stored on the player record so rung 3 can save it.
4. **Day one is survivable.** For the first two in-game days the bandit band's ambush spot sits two thirds of the
   way toward its own village (not the farmers'), the survivor says "not north yet", and bandits never chase a
   player who is inside a village footprint plus one tile. After day 2 the band moves to its real spot.
5. **HUD readability.** Hearts are square (the RelativeYY sizing bug). Trade rows and header are larger and
   white. A key legend sits bottom-right of the play area: "WASD move · click swing · F act · E bag · Tab
   standing · X close", always on, dimmed, and hidden while a panel is open.
6. **Eat, select, gift.** E opens an inventory panel listing every slot with counts; 1-9 select a hot bar slot
   (the selected slot is outlined). With food selected, F on nothing in front of you eats one (+3 hp, "You eat.").
   With a good selected, F on a villager, guard or merchant gives it: the stock rises, +2 standing ("A gift.
   They remember that."), which is the gift event DESIGN.md §7 already lists.
7. **Wading.** River water becomes a `river` ground tile: walkable at 0.35 speed, hides nothing. Lakes stay
   `water` and impassable. Fords keep their 0.6. The map no longer funnels every crossing to three fords.
8. **Art:** food icon redrawn as a turkey leg; water and river tiles get a second frame and animate like the
   campfire; a sign sprite; a marker arrow sprite. Sheet re-uploaded, `Sprites.lua` + `assets.lock.json` committed.
9. **Going-public chores** (parked in DESIGN.md §16): the resolved image id hard-coded with
   `npx warehouse roblox setid 0 <image id>` after the upload, and the loading message reworded so it never
   mentions `rojo serve` to a stranger (after 5 s: "Still loading. If this stays, the server is starting up.").

## Out of scope (do not penalise absence)

Touch d-pad; hunger; persistence; gossip and grudges; the elder or priest role; a title screen; music; shore edge
tiles beyond the two-frame water animation; a full quest system; any change to the ecology or families.

## Known limitations the builder is aware of

- The goal chain is linear and stops after the first calamity; it is a tutorial, not a quest system.
- Signs are placed by rule (gates, road exits, fords), not by hand, so a few will stand in odd spots.
- Eating heals a flat amount; there is no hunger to make food matter beyond healing.
