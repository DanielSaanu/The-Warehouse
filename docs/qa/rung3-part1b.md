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
4. **A pack breaks when it has lost more than half**, not the moment it loses one. Corrected by Danzo,
   2026-09-18: *"if u encounter a bandit group and kill more than half the rest run away like with wolf packs
   but they shouldnt abort instantly once one dies"*. Until then they fight, and each of them can still break
   individually at their own hp threshold. `ideas/INBOX.md` has plunderers as the weakest tribe, fighting by
   ambush, so leading a hunter squad onto them should still be a win — just not an extinction.
5. **Nothing from part 1 regresses.** The witness rule, the four verdicts, the player-facing lines, predation,
   and the villagers walking home all still work.

## Out of scope (do not penalise absence)

Persistence (part 2); gossip and grudges (part 3); joining a squad or a band (part 4); tribute (part 5); hunger
(part 6). Squads do not yet trade what they bring home, and the player cannot yet buy it from them directly —
that is the merchant's stock going up, which is all this part claims.

6. **One person cannot body-block a caravan.** (Danzo, same playtest.) Roads are one tile wide, so someone
   standing on the next route tile stalled a whole group indefinitely: the route says "next tile", the tile is
   occupied, and re-planning returns the same road. A blocked walker now steps around, and a group leader walks
   on to the tile after the blocked one rather than waiting for it to clear.

7. **A village is a place people live.** Danzo, 2026-09-18: the walls are the farmers showing off their
   established might, so the farmers really should be better defended — but the other two *"should not be so
   super easy to just walk in and kill everything. people live here"*. Every village used to get an identical
   one guard, one merchant and four villagers regardless of tribe. Now each tribe type has its own roster:
   farmers the largest watch behind their walls, hunters fewer guards but their own hunters at home (the best
   fighters one-on-one), plunderers fewer guards but raiders in residence.

## Known limitations expected going in

- Carried goods are a flat table on the group record, not items on individual hunters. Killing a laden squad does
  not spill its load on the ground.
- The deposit happens when the group turns at its home end of the route, so it can be a couple of in-game hours
  after the kill. That is the intent, but it means the stock rise is not immediately legible as "that kill".
- A retreating band is still made of individuals with break points, so a member cornered on the way out will
  still fight.
