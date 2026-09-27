# Design §19: open questions

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 19. Open questions

- ~~Name~~ **Lowlands** (Danzo, 2026-09-18). The Rojo project is named for it, so Studio is too.
- ~~Touch controls layout for phones~~ **decided (rung 2 part 5)**: a d-pad in the bottom-left corner and the four
  verbs (bag, standing, act, swing) in the bottom-right, both thumbs where they already rest. Tap-to-move stays,
  because travel wants it even when a doorway does not. DESIGN.md §11 offered swipe instead; the d-pad won because
  a tile game wants discrete steps and a d-pad is the one a new player can see.
  Known limit, not worth fixing yet: the layout is chosen once, from `UserInputService.TouchEnabled` at load, so
  pairing a Bluetooth keyboard mid-session leaves the d-pad up and a tablet with a keyboard attached never gets
  one. Every verb is on a key in that case, so nobody is stuck.
- Portrait on a narrow phone. A 44 px d-pad needs about 140 px however you draw it, so on a 390 px-wide play area
  the two thumb clusters leave only a quarter of the width clear. Landscape is the intended orientation.
- Exact cap numbers (section 4 has first guesses; tune on a real phone).
- **Do goods get a second axis?** They are pure sell-value today, which makes the inventory the least systemic
  part of the game (§13). Cheapest candidates that plug into systems already built: goods that are *food* (feeds
  a village, matters in a drought), goods that are *tribute* (a plunderer wants specific things), goods that
  **spoil**, and goods a tribe type cannot make itself. Do not add a crafting tree to fix this.
- ~~Do we commit to a shared world?~~ **Yes** (Danzo, 2026-09-18). §14 above; `docs/RUNG3.md` part 1.
- **Does the "what now" elder topic (§12) go in rung 3 part 3 with the chief, or earlier?** It is the only
  answer to the hour-twenty lost minute and it is maybe half a day of work, so it could ride along with almost
  anything. Argument for earlier: the first public players (rung 2 part 5) will hit the lost minute and quit
  before rung 3 exists.
- **When does the chief role appear?** §13's succession needs one, and rung 3 part 3 (tribute and tax) needs a
  face to make the demand. Recommendation: add `chief` in part 3 rather than waiting for the full talk system in
  part 5 — it is one more role reading the village bank, and it makes "who do I pay" answerable.
- **Does a player-held tribe keep running while that player is offline?** Catch-up (§14) simulates the world,
  not players, so a tribe you own would keep sending caravans and collecting tax without you. Probably right —
  it is the world-does-not-need-you pillar applied to your own kingdom — but it means you can lose a war in your
  sleep. Decide before rung 4.
- **"A little bit of the third dimension" (Danzo, 2026-09-18) — which kind?** `docs/RUNG3.md` parks real
  elevation and interiors in rung 4 because elevation touches every routing call and the wire format. Fake
  height (taller sprites on their own draw layer, cliff edges, drop shadows) changes no server code and could go
  in any week it is wanted. If the goal is that the world *looks* like it has depth, that is the cheap one and we
  can do it soon; if the goal is climbing and rooftops and being on a level someone else is not, that is rung 4.
