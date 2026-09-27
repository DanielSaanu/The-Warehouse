# Design §12–§13: the first five minutes, the long arc

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 12. The first five minutes

You wake in your village the morning after the plunder. Huts are burnt, a few people are left. One survivor
(a named relative) is the only prompt: F to talk. They teach the three controls in three lines, tell you the
bandits came from the north, and point you down the road to the hunter village for help. The road is clear and
straightforward; one encounter happens on it (a deer to hunt, or a wounded caravan guard to talk to, picked so
the player learns one more thing). No quest log. Just a person who told you where to go.

### After the first job: the elder is the compass (2026-09-18)

Rung 2 part 4 added a visible first job — one line under the clock, five steps, retired for good at the first
calamity. That line is pillar 6 in miniature, and retiring it was right: it is scaffolding for the first minute.
But nothing replaces it, and **the lost minute at hour twenty is the one that loses players**. What replaces it:

- **Ask the elder "what now".** A topic on the elder's multiple-choice window (§8) that answers with the next
  step of the long arc, chosen from where the player actually stands: what they own, who trusts them, what they
  have not seen. "You have coin and no roof. Kenstow would sell you a hut if you were worth more to them."
- It reads the village's knowledge bank like every other topic, so **a far elder gives worse advice than a near
  one**, an elder who dislikes you gives grudging advice, and an elder who is dead gives none until the role is
  taken up again. The compass is a person and can be wrong, biased or absent. That is the feature.
- It never opens a quest log, never adds a marker, never blocks anything, and it is happy to tell you that you
  have already done the thing it was going to suggest (principle 1.5 in `docs/PRINCIPLES.md`: a step completed
  by accident is the proof it is guidance).
- Cheap: it is one more topic on a role that already exists, reading a bank that already exists. Lands naturally
  with the chief role and the full talk system in rung 3.

## 13. The long arc: becoming a power

Everything a tribe can do, the player can eventually **initiate and take part in**, from a chosen **true home**:
the plundered starting village or any village that comes to trust you.

- **Hire villagers to build** (huts, walls, a market, a gate). Reputation and coin gate what they'll build for you.
- **Raise groups**: fund a caravan, hire a hunter squad, lead a raid. Their success feeds your village's stock
  and standing, and their losses are yours.
- **Politics**: pay or demand tribute, tax villages in your territory, make peace or war between tribes.
- **Take over places**: absorb a ruin, seat your people in a captured village, expand your territory.
- Multiplayer: several players can build the same home village up together, or build rivals.
- The endgame is a world superpower that you built, in a world that will still push back.

### Hirelings, not gear, are the composable thing (2026-09-18)

Measured against principle 2 in `docs/PRINCIPLES.md`, Lowlands is already systems-shaped in the world and
content-shaped in the player's hands, and it is worth being honest about which is which before rung 4:

- **Already multiplying.** A person sits in the family tree, the gossip network, a role, and a tribe's
  population at once — harm one and four systems answer. Wildlife counts feed ecology, which feeds tribe food,
  which feeds caravans, which feeds prices, which feeds what a raid is worth stealing. These are real edges and
  they were free, because everything is a record in §4.
- **Not multiplying.** Goods are sell-value and nothing else. The 10-slot inventory is things you carry to a
  merchant. No levels is right (pillar 4), but nothing in the player's own kit *composes* with anything —
  it is the flattest part of the game.

The fix is not to bolt a crafting tree on. It is to notice that **the game's Pal-shaped entity is a named
person**, and the data for it already exists:

- A hireling is in the family tree (their relatives have an opinion about how you use them), the gossip network
  (they tell people what they saw you do, which makes betraying your own hires expensive), their birth tribe
  (hiring shifts standing on both sides), combat (strength, and who they will not fight), and labour (build,
  carry, guard, farm, hunt). **One entity, five systems, no new subsystems required.**
- That makes §13's "hire villagers to build" and "fund a caravan" the same mechanic wearing two hats, and it
  makes a roster of people the progression that replaces levels and gear.
- Orthogonal axes to give a person, added slowly (principle 2's cost note): what they are **good at**, what
  they **will not do**, who they are **related to**, and who they have **told about you**. Four axes, all of
  which already have data behind them.

Rung 4 work. Written down now so hiring is not built as a menu that spends coin.

### Chiefs, heirs, and taking a tribe (Danzo, 2026-09-18)

The kingdom end of the arc runs on the family registry from §15, so most of it is a lookup rather than a system.

- Every tribe has a **chief**: a named person, a role NPC like the guard or the elder (§8). The registry already
  knows their children, siblings and surname, so "who is next" needs no new data.
- **Killing the chief does not end the tribe.** It is the tempting version and it is the wrong one: a world that
  loses a tribe every time you win gets emptier the more you play, which is the exact opposite of pillar 5. What
  happens instead:
  - the registry names an **heir**: eldest adult child, else a sibling, else the strongest surviving squad or
    caravan leader;
  - with no clear heir and a violent death, the tribe **drops a size tier** — fewer groups out, caravans stop,
    walls go unmanned;
  - with two equal claimants it **splinters**: the loser walks out with a share of the people and founds a new
    small tribe of the same type. That is where new small tribes come from, besides resettled ruins (§5);
  - and the tribe carries a **grudge at tribe level, for years**. Killing a chief is the largest single grudge
    in the game, and §7 makes sure the far side of the map hears about it eventually.
- **Two roads to a throne, both legitimate.** Take it by force and hold it, or earn standing with the chief
  until they hand it over: kin by marriage, regent while an heir is a child, chief by acclamation where there is
  no heir at all. The slow road leaves you a tribe that still works; the fast one leaves you a tribe that is
  afraid of you and neighbours who all know. Pillar 5 says both roads stay open, and neither is the "good end".
- A player holding a tribe inherits what tribes already do in §6: groups to send out, tribute to collect from the
  villages in the territory, tax, war and peace with the neighbours. Section 13's "become a power" is then not
  new machinery at all — it is the tribe systems already built, pointed at a player.

This is rungs 4 and 5; the data model in section 4 is shaped for it from the start.
