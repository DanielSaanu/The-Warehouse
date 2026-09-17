# QA goals: Rung 2 part 2 (a small living world)

Branch: `rung2-part2`. Closes out rung 2 of `docs/DESIGN.md` §16 on top of part 1 (generated world, scrolling
viewport, validated movement). Everything below is server-authoritative; clients only draw what they are told.

## Goals of this PR

1. **The first five minutes.** You spawn in the plundered farmer village with the day one kit (knife, waterskin,
   2 food, 1 camper set) and a named survivor (same surname as the village's people) stands by the road. Only they
   have a prompt. F on them: three lines that teach move / attack / interact, then "the bandits came from the
   north, go east down the road to <hunter village>". A controls hint shows on spawn until you take a step.
2. **Attack with feel rules.** Left click (or Space) swings at the tile you face: 0.4 s cooldown, the target
   flashes and is knocked back one tile, 0.6 s invulnerability after being hit, NPC and animal attackers telegraph
   for half a second (a visible wind-up) before they swing. Hearts HUD. Death drops a bag that only you can see for
   10 minutes, respawn at your rest point after 3 s, reputation hit with the tribe that killed you.
3. **F interact with one prompt at a time** ("F: Talk", "F: Trade", "F: Rest", "F: Camp", "F: Pick up"), the
   nearest thing in front of you. Talk: villagers give a random line from their village's knowledge bank
   (flavour, rumours, the calamity forecast, local wildlife). The village **guard** opens a four-choice window
   (the road / the tribes / prices / me). The **merchant** trades. The **caravan master** talks about trade and
   standing. Hostile NPCs will not talk.
4. **Trade** at a merchant stall: 4 goods (food, hides, tools, ore) plus coin; prices per village move with stock
   and with your standing; farmer and hunter merchants also sell camper sets. 10 inventory slots, goods stack.
5. **Rest and camp.** F at a village bed sets your rest point (hostile villages refuse: "They won't let you
   stay"). F on a free tile outside a village uses up a camper set and places a camp (bedroll + fire). The fire
   burns a few in-game hours and keeps wolves off a small radius, then goes out; the bedroll stays as your rest
   point. Placing a new camp abandons the old one. Floods and wolves can destroy a camp.
6. **Reputation per tribe**, shown as words (hostile / wary / neutral / welcome / family) on a standing screen
   (Tab). Moves on trade, hits, kills, and killing bandits (up with farmers and hunters, down with plunderers).
   Fades toward neutral over in-game months. You start welcome with your farmers, neutral with hunters, wary with
   plunderers. Grudges and gossip are rung 3.
7. **NPC groups as records with routes**, materialised as sprites only when a player is near: one farmer caravan
   (master + 2 guards, farmer village <-> hunter village, pauses at each end), one hunter squad (4, hunter
   village <-> a forest, hunts deer), one bandit band (4, plunderer village <-> an ambush spot on the north
   road; attacks players it is not friendly with). Groups keep moving abstractly when nobody is near.
8. **Wildlife from regional counts.** The map is 6x6 regions of 16x16 tiles, each with grass health and deer,
   boar, wolf counts. Daily tick: eat, breed, starve, drift to neighbours, and a north-south border flow (wolves
   push in from the north, deer drift south). Individuals are spawned near players from the counts and folded
   back when nobody is near; a kill decrements the count. Deer flee, boar charge when hit, wolves hunt at night
   (and avoid a lit campfire). Deer drop hide + food, boar food, wolves hide.
9. **Weekly calamity clock** with two calamities: **flood** (tiles near the river become water for the rest of the
   day; caravans stop; village food stocks damaged; camps on those tiles destroyed) and **beast tide** (wolves surge
   in the northern regions and roam by day; unwalled villages lose people). A warning the day before (HUD line and
   the guard mentions it). For testing there is a debug channel: set the string attribute `Debug` on `Workspace`
   from the server side (Studio command bar or a server-context Luau tool) to a command line and read the string
   attribute `DebugResult` (JSON for tables). Commands: `state`, `player`, `list [kind|role]`, `entity <id>`,
   `calamity flood|beast_tide`, `teleport x y`, `give <item|coin> n`, `rep <tribeIndex> <value>`, `night`, `day`,
   `hurt n`, `kill`, `spawn <kind> [x y]`, `summon caravan|squad|band` (brings the group to the player),
   `group <id>`, `camp`, `freeze 1|0` (NPCs stop thinking, for deterministic tests), `verbose 1|0` (log hits).
   `ServerStorage.Debug` is the same thing as a BindableFunction for scripts that are allowed to invoke it.
10. **Villages look different**: hunter huts are hide tents with a totem, plunderer huts are dark and spiked with a
    skull post, farmers keep the thatched huts and the palisade.
11. **Part 1 leftovers**: the play area widens with the screen's aspect ratio (phones get more columns, not black
    bars), tap-to-move path-finds around obstacles, controls hint on spawn.
12. **Art**: ~45 new 16x16 sprites in the existing palette (people x5 kinds x 4 facings x 2 frames from a recoloured
    base body, deer/boar/wolf x 2 frames, 8 item icons, camp x3, hut variants, landmarks, flood water, bag,
    hearts), one sheet, uploaded, `Sprites.lua` + `assets.lock.json` committed.
13. **State is shaped for persistence** (rung 3): tribes, groups, regions, calamity clock and player state are
    plain tables in `server/Sim.lua`, nothing lives only in closures.

## Out of scope (rung 3+; do not penalise absence)

Gossip, grudges and amends; tribute, tax, extortion; size tiers; hunger; save + catch-up; blizzard and drought;
knights and adventurers; hiring; the elder role and role replacement on death; dash, shield, bows; settlement
healing and ruins; touch d-pad; music; title screen.

## Known limitations the builder is aware of

- One first pass of pixel art; people are one base body recoloured per kind, animals face left/right only.
- The abstract simulation is deliberately small: one group per tribe, three species, two calamities.
- Calamities are weekly (70 real minutes). Use the Debug hook to see one without waiting.
- No PvP. Other players are visible and named but cannot be hit.
