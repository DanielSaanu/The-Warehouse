# Design §20: the world up close is inert

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 20. The world up close is inert (found in play, 2026-09-18)

Danzo played the build and found the gap between what §1, §5 and §9 promise and what the simulation actually does
when you stand still and watch it. His words: the wolves only attack him and not the NPCs, and the NPCs barely
interact with each other or with the world beyond the hunters hunting. All of it checks out in
`roblox/src/server/Sim.lua`:

- **Predators are hostile to exactly one species: the player.** `pickNpcTarget` returns immediately unless the
  entity is a hunter, a guard or a caravan guard, so a wolf's only route to aggression is `pickTarget`, which
  searches `nearestPlayer` and nothing else. A wolf will cross a field of deer to reach you, and will stand next
  to a villager all night. Worse, the one rule that does exist is one-directional: hunters and guards attack
  wolves, so the wolf takes hits it can never return.
- **Bandits raid nobody.** A bandit's target test is `ps.rep.plunderer < -10` — a player-only check. §5 says
  plunderers live off caravans and villages. Today the caravan and the bandit band can walk straight through each
  other, which makes the hunter tribes' "natural enemies of plunderers" relationship pure backstory.
- **Predation is a spreadsheet.** Wolves eat deer in `Ecology.dailyTick`: once a day, per region, as numbers. The
  ecosystem is real and completely invisible. Nobody can ever watch a wolf take a deer, and that one moment is
  what would make §9 legible without a single line of UI.
- **Farms are scenery.** `farm` is a tile and nothing more — no growth, no harvest, no villager who tends one.
  Nothing under `roblox/src/server/` so much as mentions it. The farmer tribes' entire economic identity is a
  sprite.
- **Villagers have one behaviour: wander.** They do not work, eat, go home at night, or acknowledge each other.
  Families are real as records — parents, children, births, succession when a guard dies — and are never once
  visible as behaviour.

§1 pillar 1 is "the world does not need you". Up close, the world currently does nothing *but* need you: every
interaction in the game has the player on one end of it. This is the most likely cause of the "kind of boring, I
don't know what to do" verdict in `ideas/INBOX.md`, and it is a bigger hole than any single missing feature,
because it is the one a player sees in the first minute without being told to look.

**What it takes** (rung 3 part 1 in `docs/RUNG3.md`):

- Every hostile kind gets an NPC target test, not just hunters and guards. Wolves hunt deer and boar; bandits
  ambush caravans and people caught outside walls; boar defend themselves against more than the player.
- Predation becomes an event that can be watched when a player is near, and stays a number when nobody is.
  The region count is decremented either way, so the ecology stays authoritative.
- Villagers get a day: a work tile (farm, stall, well), a home hut, and a night that sends them to it.
- Farms become stock that grows and is harvested into the tribe's food, so the farmer economy is a thing you can
  watch happen rather than a label on a tribe.

**Where it stands (2026-09-21).** This section was written on Danzo's PC on 2026-09-18, on a branch that was never
pushed, so main built part 1 without it. All four are now in: NPC target tests, watched predation and the witness
rule (part 1, part 1b: `Sides.lua`, `shared/Witness.lua`); a villager's day (`server/Villagers.lua`); farms as a pure
rule over records (`shared/Farms.lua`, run by `Tick.daily`, so a sleeping world farms too). One thing the rebuild
changed on purpose: what a farm yields counts the LIVING villagers, not where their bodies stood, so the walk to
the plot is a projection of the rule and catch-up needs no bodies (docs/ARCHITECTURE.md H9).
