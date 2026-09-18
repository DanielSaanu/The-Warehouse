# QA goals: Rung 3 part 1 (the world up close)

Branch: `world-up-close`. First part of rung 3 (`docs/RUNG3.md`). Design contract: `docs/DESIGN.md` §20, and the
pillar it fails, §1 pillar 1: **the world does not need you.**

Danzo played the build on 2026-09-18 and said the wolves only attack him and not the NPCs, and that the NPCs
barely interact with each other or the world beyond the hunters hunting. The code agrees. Today every single
interaction in the game has the player on one end of it:

- `pickNpcTarget` returns immediately unless the entity is a hunter, a guard or a caravan guard — the only
  NPC-vs-NPC rule there is. A wolf's only route to aggression is `pickTarget`, which searches `nearestPlayer`.
- A bandit's target test is `ps.rep.plunderer < -10`, a player-only check. The caravan and the band walk through
  each other.
- Wolves eat deer once a day, per region, as numbers in `Ecology.dailyTick`. Nobody can ever see it.
- `farm` is a tile; nothing under `roblox/src/server/` mentions it.
- Villagers wander. That is the entire behaviour.

The bar for this PR: **stand still anywhere for thirty seconds and watch the world do something that is not about
you.**

## Goals of this PR

1. **Predators hunt prey.** Wolves pick deer and boar as targets, and the **nearest** target wins: a wolf standing
   next to a deer no longer walks past it to reach the player. A wolf that catches a deer kills it and the
   region's deer count goes down by one — the same count `Ecology` would have decremented, so the ecosystem stays
   authoritative and does not change shape depending on who is watching. (Wildlife is still only materialised near
   a player, and wolves still only come out at night or during a beast tide: §4 and §9 both stand.)
2. **Predation is visible.** A kill near a player plays out as entities (chase, telegraph, strike, the deer's
   death) and folds back into counts when nobody is near. Away from players it stays arithmetic in the daily tick.
   The wolf does not lose interest in a deer because a player walked up.
3. **Prey behave like prey.** Deer flee from wolves, not only from players. Boar charge whatever hit them, NPC or
   player. A fleeing deer is a thing you can see from across a meadow and read instantly.
4. **Bandits raid.** A bandit band ambushes caravans and people caught outside village walls, not just players
   with bad standing. A caravan that loses a fight loses cargo to the band's tribe stock; caravan guards fight
   back with the break-and-flee rules that already exist. The hunter/plunderer antagonism in §5 becomes real
   behaviour instead of backstory.
5. **Villagers get a day.** Each villager has a home hut and a work tile (farm plot, stall, well). Morning: go to
   work. Night: go home. Wolves and bandits near an unwalled village send them running for the gate. They are not
   decoration any more, and the family records that already exist (parents, children, succession) become something
   you can watch rather than something the debug command prints.
6. **Farms grow.** A farm plot carries stock that rises daily when tended and is harvested into the tribe's food,
   which makes a plunderer raid on a farmer village mean something. Drought and flood already have hooks; a
   trampled or flooded plot loses its stock.
7. **The ecology stays the authority.** Every visible kill, birth and harvest moves the same region counts and
   tribe stock the daily tick moves. No double counting: a wolf that eats a deer near a player must not also eat
   it again in `Ecology.dailyTick`. This is the thing most likely to be got wrong and it is what the tests are for.
8. **Caps hold.** DESIGN.md §4 caps stand: 60 NPC sprites and 40 animal sprites materialised at once, and the
   furthest-from-any-player things stay abstract. NPC-vs-NPC fighting must not push entity counts or the 10 Hz
   think loop past what part 5 measured on a phone.
9. **Debug commands** on the existing `Workspace.Debug` channel: `hunt` (make the nearest wolf take the nearest
   deer), `raid` (send the band at the caravan), `village <n>` (who is where and doing what), `farms`, and
   `freeze 1` must still stop everything dead for deterministic tests.
10. **Tests.** `test/luau/ecology.test.luau` grows a case for a visible kill and the daily tick agreeing on the
    count. Behaviour selection (who targets whom) moves somewhere pure enough to test outside Studio. `npm run
    lint:luau` and `npm run test:luau` clean.

## Out of scope (later rung 3 parts; do not penalise absence)

Save and catch-up (part 2 — the world still regenerates each server). Gossip, grudges and amends (part 3).
Tribute, tax, extortion, size tiers (part 4). Hunger (part 5). Blizzard and drought, the full talk system,
knights, adventurers, hiring, dash, shield, bows, settlement healing and ruins (part 6).

## Known limitations the builder is aware of

- NPC-vs-NPC fights away from players are resolved as a roll, not tile by tile. A caravan that loses off screen
  loses cargo and people; you do not get to replay it.
- Villager routines are a work tile and a home hut, not jobs with output (except farms). A villager at a stall is
  standing at a stall.
- There are three villages and one band. Raids are rare by construction, so a reviewer may need `raid` to see one.
