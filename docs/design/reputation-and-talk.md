# Design §7–§8: reputation, grudges, gossip; talking

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 7. Reputation, grudges, gossip

Two numbers per (tribe, player), plus what individuals remember.

- **Reputation** is the current feeling, from hostile to family. It moves on events: trade, gifts, killing
  their people, protecting their caravan, paying tribute, freeing captives. It **fades toward neutral**: half
  the distance every in-game month, so a new player who blundered can come back.
- **Reputation is a record of your conduct, never of your luck** (Danzo, 2026-09-17). The rules, in order:
  - Who drew first is the story. Hitting someone who attacked you costs nothing; killing someone who attacked
    you costs half. Hitting someone who never touched you costs a little (-1 a blow); killing them costs the big
    number (villager -25, guard or hunter -20, bandit -15 with the plunderers and +5 with the settled tribes).
  - Beating someone and letting them go is worth more than killing them: when a broken fighter gets away from
    you, +3 with their tribe, once per fight. They come home with a story, and a story is what gossip carries.
  - Killing someone who is running from you is murder: the full kill penalty, plus a grudge in rung 3.
  - Being killed costs nothing. Dying never feeds a grudge and never stacks, however many times the same band
    kills you. Being murdered is their doing, not yours.
  - If the band chases you and loses you, +2 with the plunderers: they respect what they could not catch.
    Nothing for escaping guards or wolves.
- **Grudge** is the scar. It only comes from serious harm, decays very slowly (years), and it **multiplies**
  the damage of any new bad act against the same people: reputation damage = base x (1 + grudge). So you can be
  forgiven, but if you come back and do it again without ever making amends, they remember everything at once.
  This is what stops farming the same village for loot.
  - Harm done as **part of a group** (you rode with a bandit band) spreads the grudge across the group: small.
  - The same harm done **alone** lands entirely on you: near irreconcilable. "Don't let me recognise you."
  - **Amends** (big gifts, paying what you took back, doing a job for them) reduce grudge. Time alone barely does.
- **Standing decides who helps you in a fight, and it is comparative** (Danzo, 2026-09-18). Every NPC who can
  see a fight is a witness, and picks the side they dislike less: they will help someone they are merely neutral
  about against someone they hate, and they will stand and watch a player they are wary of being killed in their
  own square. Unarmed witnesses flee and carry what they saw, or run for the nearest armed kin. Built in
  `docs/RUNG3.md` part 1; it is what makes riding with a band (part 4) mean anything.
- **Memory** is per NPC group / village: what they personally saw you do, with a timestamp.
- **Gossip**: when two groups (or a group and a village) are on the same or adjacent tile, they exchange
  memories about players. Each hop loses detail and weight. Caravans are the big spreaders. A lone bandit tells
  his band when he gets home. Hunter squads tell the caravan they are guarding. Information really has to travel,
  so you can outrun your reputation for a while, and a tribe on the far side of the map may not know you yet.
- Harming someone from a large farmer tribe hurts you with their friends and family first, then their village,
  then the tribe, as the news spreads.

## 8. Talking: how the player learns anything

Reputation, gossip and the ecosystem are invisible numbers unless the game shows them. The game shows them by
**talking**, not by menus.

- Each village and each group has a **knowledge bank**: facts about the area (wildlife, who is raiding whom,
  prices, the calamity forecast) plus what they know about you.
- F on a **regular villager** gives one random line from the bank. Flavour and rumours.
- **Role NPCs** hold the vital stuff and open a **multiple-choice window** (Ask about the road / the tribes /
  prices / me). Roles: village **guard** (survival basics and what's dangerous nearby), **caravan master**
  (trade and standing), **merchant** (prices, what's scarce), **elder** (tribe politics, grudges).
  Examples of the tone:
  - Guard: "There are bandits afoot because of the plunderers in the north. Head that way, don't start trouble."
  - Caravan master: "Get close with the villages round here and they'll cut you a deal. Get on their bad side
    and they won't trade at all. Or worse."
- Role NPCs are **named people**. If one dies, another villager takes the role, preferably a relative (same
  last name). The knowledge bank belongs to the village, not the person, so the role carries on.
- **Names identify people; roles decide what they can tell you.** A guard knows guard things (danger, the road,
  who was seen where), a merchant prices and scarcity, a caravan master trade and standing, an elder or priest
  (later) the tribe's politics, grudges and the long arc: story beats, tutorial beats, player events. Each role
  reads its own slice of the village bank, and the bank holds only what has happened here or what gossip has
  carried here. Far villages know less about you, and about the world, than near ones.
- NPCs that are hostile to you won't talk. That is itself information.
- A standing screen on a key shows your reputation per tribe as words, not numbers ("wary", "welcome").
