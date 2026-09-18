# QA goals: Rung 3 part 1b (the hunt is a loop, not a slaughter)

Branch: `rung3-part1b`, stacked on `rung3-part1`. Source: Danzo's playtest of part 1, 2026-09-18:

> "WOLVES ARE GOOD but the bandits got wiped out instantly because i brought the hunters over. furthermore the
> hunters are a little too blood thirsty same with the wolves — its fine for now because it doesnt seem like we
> ever run out of animals but they dont seem like they hunt and return back with theyre materials"

Three things, and the third is the real one. Part 1 gave everyone the will to fight; nobody was given a reason to
stop, or anything to show for it. A hunter squad currently kills animals forever and **nothing happens** —
`killEntity` only produces loot when the killer is a player (`Sim.lua:594`), so an NPC kill feeds nothing.

## Goals of this PR

1. **A hunt is a round trip.** A squad that kills something carries the hides and meat, walks them home, and the
   village's stock actually goes up. `Trade.dailyRestock` already moves a tribe's goods; this makes the squad a
   real source rather than a decoration, and it is what makes the hunter villages' whole existence legible.
2. **They stop when they have enough.** A squad heads home once it is carrying a load, rather than killing until
   the route runs out. That is the answer to "too bloodthirsty": not a nerf to their aim, a reason to stop.
3. **A fed predator does not hunt.** A wolf that has just eaten leaves the next deer alone for a while. Same
   idea, applied to the animal that Danzo says is otherwise good.
4. **The band retreats instead of dying to the last man.** `ideas/INBOX.md` is explicit that plunderers are the
   *weakest* tribe and fight by ambush — "theyre strength comes from theyre sudden and brutal nature". A band
   that loses a member should break off and run for home, not stand and be wiped. Leading a hunter squad onto
   them should still be a win; it should not be an extinction.
5. **Nothing from part 1 regresses.** The witness rule, the four verdicts, the player-facing lines, predation,
   and the villagers walking home all still work.

## Out of scope (do not penalise absence)

Persistence (part 2); gossip and grudges (part 3); joining a squad or a band (part 4); tribute (part 5); hunger
(part 6). Squads do not yet trade what they bring home, and the player cannot yet buy it from them directly —
that is the merchant's stock going up, which is all this part claims.

## Known limitations expected going in

- Carried goods are a flat table on the group record, not items on individual hunters. Killing a laden squad does
  not spill its load on the ground.
- The deposit happens when the group turns at its home end of the route, so it can be a couple of in-game hours
  after the kill. That is the intent, but it means the stock rise is not immediately legible as "that kill".
- A retreating band is still made of individuals with break points, so a member cornered on the way out will
  still fight.
