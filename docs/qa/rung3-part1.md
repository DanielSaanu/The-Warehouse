# QA goals: Rung 3 part 1 (the world answers for itself)

Branch: `rung3-part1`, from `main`. Plan: `docs/RUNG3.md` part 1. Source: Danzo, 2026-09-18 — *"different
outcomes depending on who's doing what around whom"*, and *"don't ignore the sprites"*.

Rung 2 built a world that runs on its own in the numbers. This part makes it answer **on screen**: animals hunt
each other where you can watch, and every NPC who sees a fight decides for themselves whose side they are on.

It goes first in rung 3 because it depends on nothing, it is the only part of rung 3 a player can see happening
without being told, and it is the ground part 4 (riding with a caravan or a band) stands on — the moment you can
ride with bandits, "whose side are you on" has to be a question the world can already answer.

## Goals of this PR

1. **Predation you can watch.** Wolves hunt deer and boar as entities, the way hunters already hunt. `Ecology.lua`
   has run this in the numbers since rung 2 — grass grazed, herbivores breeding or starving, wolves eating them
   and starving when prey runs out — but a wolf sprite standing beside a deer sprite ignores it. A visible kill
   decrements the region's count, so the watchable layer and the simulated layer never disagree.
2. **One witness rule, replacing every special case.** Every NPC that can see a fight applies:
   *help the side you dislike less, if the gap is worth a fight; if you dislike both, watch; if you like both,
   shout but do not swing.* This replaces the two hard-coded behaviours in `Sim.lua`: the single `guard` entity
   reacting to the player hitting one of their own, and guards attacking any bandit within five tiles regardless
   of who that bandit is fighting or what they think of the other party.
3. **Three inputs, all of which already exist.** What the witness thinks of each side (per-tribe standing for a
   player; tribe-to-tribe relations for an NPC — hunters and plunderers are natural enemies per `ideas/INBOX.md`;
   same-tribe is kin), what the witness *is* (a guard, hunter or caravan guard can fight; a villager, merchant or
   pregnant woman cannot), and whose ground it is.
4. **Four outcomes.** Join in on one side, watch, flee, or raise the alarm — an unarmed witness runs for the
   nearest armed person of their tribe, which is how a village that is not looking finds out.
5. **Standing is comparative, not a permission check** (DESIGN.md §7). A village neutral about you helps you
   against someone they hate. A village wary of you watches you die in its own square. The specific cases that
   must be demonstrable:
   - chased into a village that likes you → several people turn out for you;
   - chased into a village that is wary of you → they watch;
   - jumped by someone they hate while they are only neutral about you → they help you anyway;
   - murder someone in a square where you are family → the same people come for you.
6. **It is not about the player.** A band hitting a hunter squad near a farmer village makes the farmers choose.
   The rule reads two parties, either of which may be an NPC.
7. **Villages defend themselves**, and not as its own feature — it falls out of the witness rule, because a wolf
   is something everyone dislikes. A beast tide should no longer be answered by one guard while everyone else
   stands still.
8. **Nothing regresses.** Fights still end in flight (break points, runners going home to heal), conduct-based
   reputation still holds (who drew first, mercy, murder of a runner), and the first five minutes still teach
   themselves.
9. **Sanctuary becomes something people do.** Rung 2 part 4 made every village a hard sanctuary: bandits never
   followed a player inside one, ever. That was a fair day-one safety net but it meant the world could never
   answer differently in two places, and the village never got to actually defend anyone. Now the sanctuary is
   the grace days only (`Config.GRACE_DAYS`, so a new player's first walk is still safe); after that the band
   follows you anywhere and whether that was a good idea is decided by whoever is standing there.

## Out of scope (do not penalise absence)

Persistence and catch-up (part 2); gossip, per-group memory and grudges (part 3) — witnesses use per-tribe
standing for now and get sharper when part 3 lands; joining groups (part 4); tribute, tax and the chief (part 5);
hunger (part 6); the elder's "what now"; blizzard and drought; anything in rung 4.

## Known limitations expected going in

- Witnesses judge a player by **tribe standing**, not by what they personally saw. That is part 3's job. Until
  then a village's opinion is still shared instantly across the tribe.
- Tribe-to-tribe relations are a fixed table, not a simulated relationship. Tribes do not yet fall out with each
  other over things that happen.
- "Can see" will be a radius and a distance check, not line of sight. A wall does not block a witness.
- More NPCs fighting means more pathfinding. The cap on how many witnesses join one fight exists for that reason
  as much as for fairness.
- Standing hostility and taking sides are separate questions, and the first can mask the second: a farmer village
  attacks bandits on its own ground whatever it thinks of you. It is held back only while that bandit is busy
  with someone the village likes even less — which is the case that makes "they just watch" visible, but it does
  mean the plain "watch" verdict is rarer in play than the rule alone suggests.
- `Sim.lua` had reached Luau's type-inference budget, so this PR splits `server/Sides.lua` (who takes whose side)
  and `server/Debug.lua` (the test console) out of it. That is a large diff for a behaviour PR, and it was not
  optional: `npm run lint:luau` fails outright once the budget is exceeded.
