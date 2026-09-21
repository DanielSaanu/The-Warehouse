# QA goals: the PC stack (villagers' day, births, Track B1, labels)

Branch: `track-b1-bands`, stacked on `villagers-day`, stacked on `main` (986b9cd). Everything here was built on
Danzo's PC on 2026-09-21 in one session and **none of it has been reviewed**. It also carries the two Track B carves
that were on main without a QA loop (`State.lua`, `Tiles.lua`). Review the whole diff: `git diff 986b9cd..HEAD`,
plus `State.lua` and `Tiles.lua` as they stand.

Danzo's bar for this loop: **8.5 or higher**, at most three rounds. The question he asked is "how well is the plan
implemented up to this point" - the plan being `docs/ARCHITECTURE.md` (rules R1-R5, H1-H9, Track B) and
`docs/DESIGN.md` §20 (the world up close).

## Goals

1. **A villager has a day** (`server/Villagers.lua`). Out to a plot (farmers) or a spot by the stall (others) in
   the morning, home to a hut door at night, home at a run when a wolf or a strange bandit is within six tiles.
   Done when: stand in Glenworth in the morning and the villagers are on the fields; at night they are around the
   hut. Debug `farms` reports who is where.
2. **Farms grow, as a pure rule** (`shared/Farms.lua`, run from `Tick.daily`). Every living adult villager works
   one plot a day, ripest first; a ripe plot is harvested into the tribe's food; an unworked plot goes to weeds; a
   flood drowns the plots under it. It counts RECORDS, so catch-up farms exactly as a watched day does, and a
   village that loses its people stops feeding itself. Plot growth is saved (`tribes[].plots`); plot and hut
   positions are derived from the map (R4) and scanned through a flood's backup.
3. **People are born again** (`Families.MAX_PEOPLE` per tribe type: farmer 18, hunter 15, plunderer 14). The flat 9
   sat below every starting roster (14 / 13 / 12), so nobody was ever born. Farmers get the most room because the
   design notes make them the biggest tribes.
4. **Track B1: `Bands.lua`**, carved verbatim out of `Sim.lua` (1417 -> ~1280 lines, ceiling ratcheted to 1285).
   No behaviour change intended: a group materialises near a player, walks its route, collapses when the player
   leaves, keeps moving as a record, and deposits its carry at home.
5. **Groups are made of people, and they stay the same people** (`Tick.enlist`, `members[].person`,
   `Person.group`). The same four hunters before and after a collapse; a death removes THAT person and the
   replacement is somebody new; people on the road are not `Families.villagers` (no cap, no pairing, no
   inheriting a post) but `relatives()` still finds them. This is what rung 3 part 3 (gossip) stands on.
   **Save format v2 with deliberately no v1 upgrade**: Danzo chose to reset the world, so a v1 world is obsolete.
6. **A stranger is a trade, not a name, until you have met them** (`State.labelFor`, `State.meet`). Per player;
   talking to, hitting or being hit by somebody reveals their name; the survivor is always named; `met` travels in
   the player's key, capped at 128.
7. **The two earlier carves hold up**: `State.lua` (the record, occupancy, client-facing helpers) and `Tiles.lua`
   (camps, bags, the map's object layer) - parked on main with "no QA reviewer has looked at it".
8. **Nothing regresses**: saves and catch-up (Track A), the witness rule, the hunting loop, headlines, the goal
   line, trade. `npm test` and `npm run lint:luau` pass.

## Out of scope (do not penalise absence)

Gossip itself (part 3); joining a group (part 4); tribute; hunger; the rest of Track B (the calamity half of
`Calendar`, B2 Bodies / Brains / Fighting, B3 named owners, B4 WorldGen split); the client split. Art.

## Known limitations going in (say if they matter more than the builder thinks)

- **Name labels still overlap when people bunch up.** Labels are wider than a tile; trades instead of names made
  it shorter, not solved. `Viewport.lua` is at its line ceiling (429 / 430).
- **The hunter squad slaughters Wild's Rest when a player is near both.** Hunters target any `bandit` kind, the
  plunderer village's home garrison is `bandit` kind, and the squad's route passes the village. Five dead on day 1
  in one test. It predates this stack (part 1b + the hunt rule) and is NOT fixed here; Danzo knows.
- Glenworth has one standing hut and eight villagers: at night some of them cannot get within a tile of the door
  and mill about near it.
- `State.meet` re-sends the entity as `leave` + `spawn` rather than adding a label message, so a name appearing
  can cost the entity one frame of walk animation.
- The villagers' walk is cosmetic: what a farm yields is the pure rule. A villager kept indoors all day by wolves
  still "worked" in the numbers, because the rule counts the living, not where they stood.
- The Studio place has "Enable Studio Access to API Services" ON, so Play reads and writes the REAL DataStore
  (`Lowlands_v1`). The world key was wiped before this loop so round 1 starts on day 1. A reviewer's Play session
  will autosave into it; that is fine.

## Useful Debug commands (set the `Debug` attribute on Workspace from server-side Luau, read `DebugResult`)

`state`, `farms`, `group squad|band|caravan` (lists members by id, name and body), `summon <group>`,
`teleport x y`, `day [frac]` (skip to the next morning - runs the daily tick), `night`, `jump <day> [frac]`,
`people [tribe]`, `headlines`, `strike <entityId> [dmg]`, `reload [seconds]`, `savetest [seconds]`,
`calamity flood`. Glenworth's fields are around (24-33, 72-76); the player's bed is near (31, 70).
