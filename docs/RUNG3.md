# Rung 3: memory and money — the build plan

DESIGN.md §16 names rung 3 in three lines. This is the order to build it in and why, split into parts the way
rung 2 was, each one its own branch, goals file and QA loop.

Rung 2 ended with a world that lives, remembers you for as long as the server is up, and can be played by a
stranger on a phone. Rung 3 is about that memory outliving the server, and about the tribes wanting something
from you rather than merely existing near you.

## The one thing that gates everything

**Nothing a player does survives a shutdown.** Reputation, families, standing, the goal you were on, the camp you
paid fifteen coin for: all of it regenerates from the seed next time. Every other item in rung 3 is worth less
than it should be until this is fixed:

- A grudge that decays over years is meaningless in a world that forgets overnight.
- Tribute and tax are a relationship over weeks, and there are no weeks.
- DESIGN.md §16 is explicit: **do not charge for anything before save + catch-up lands**, because until then
  whatever is sold evaporates.

So persistence is part 1, and it is not negotiable. It is also the least fun to build and the least visible in a
playtest, which is exactly why it goes first rather than last.

## Part 1 — Save and catch-up

**What it is.** The world and every player survive a server restart, and time keeps passing while nobody is
looking.

Sim.state was structured for this from the start: `day`, `tribes`, `people`, `regions`, `groups`, `players`,
`camps`, `bags`, `calamity` are already plain tables. Entities are deliberately not saved — they are materialised
from records when a player is near, and rebuilt on load.

- **World save**: seed, day, tribe stock and population, the family registry, region ecology counts, group route
  positions, camps and bags. One DataStore key, versioned, written on a timer and on `BindToClose`.
- **Player save**: position, inventory, coin, reputation per tribe, rest point, `goalStage`. Keyed by UserId.
- **Catch-up**: on load, run the days that passed while the server was down through the daily tick — ecology
  breeding and migration, trade restock, births and coming of age, reputation fade — capped so a month away does
  not take a minute to load. The player is told what changed: "You were gone eleven days. Kenstow has a new
  guard."
- **The hard question, to settle before writing code**: one world per server, or one world shared by everyone?
  Per-server is trivially easy and means your friend's Glenworth is not your Glenworth. Shared is what "a world
  that persists and is shared by everyone on the server" in `ideas/INBOX.md` actually asks for, and it needs
  MemoryStore or a single authoritative place. **Recommendation: one shared world, because the whole pitch is
  that the world remembers, and a world that only remembers you alone is a save file, not a place.**

**Risks:** DataStore request budgets, 4 MB per key, writes on shutdown that do not finish. The family registry is
the thing most likely to outgrow a key; it may need pruning of the long dead.

**Done when:** stop the server mid-game, start it again, and your coin, your standing, your camp and the guard's
name are all still there, and the calendar moved on.

## Part 2 — Gossip and grudges

**What it is.** The pillar from DESIGN.md §7, and the reason the game is not just another survival game.

Reputation today is instant and global: hit a hunter and every hunter in the world knows at once. That is a
placeholder. What §7 describes is information that has to **travel**.

- **Memory per group and village**: what they personally saw you do, with a day stamp.
- **Exchange on contact**: when two groups, or a group and a village, are on the same or adjacent tile, they
  trade memories. Each hop loses weight and detail. Caravans are the big spreaders; a lone bandit tells his band
  when he gets home; a hunter squad tells the caravan it is guarding.
- **Grudge**: the scar. Only from serious harm, decays over years, and **multiplies** the damage of the next bad
  act against the same people. Harm done as part of a group spreads thin; the same harm done alone lands entirely
  on you.
- **Amends**: gifts, paying back what you took, doing a job. Time alone barely helps.
- The payoff a player can feel: you can outrun your reputation for a while, and a tribe on the far side of the map
  may not know you yet.

**Depends on:** part 1, because a grudge that resets nightly is not a grudge.

**Done when:** kill a hunter where only one person sees it, walk the other way, and watch the news reach their
village over the next in-game day — and arrive at the far tribe later still, weaker and vaguer.

## Part 3 — Tribute, tax and extortion

**What it is.** The tribes stop being scenery and start wanting things from you. `ideas/INBOX.md` describes this
at length and none of it exists yet.

- Size tiers (small, mid, large) per tribe, driving how much of everything they do.
- Plunderer tribes demand tribute from villages in their territory, and from the player once he has something
  worth taking. Large bands extort rather than destroy: they want a paying neighbour, not a ruin.
- Farmer tribes collect tax from smaller villages in their territory and send caravans out from the strongest.
- The player can pay, refuse, or fight, and each is remembered by part 2's machinery.

**Depends on:** part 2, so that refusing a demand actually costs you something that lasts.

## Part 4 — Hunger, and making food matter

DESIGN.md §11 parks hunger with a condition on it: **"if it makes the food economy matter"**. It only does once
there is something to spend food on and something to lose by running out. After parts 1 and 3 there is: caravans
to supply, tribute to pay, a long walk between villages that persists across sessions.

Small, and it makes the farmer tribes' whole existence legible.

## Part 5 — The rest of the list

Ordered by how much each adds per day of work:

- Blizzard and drought (two more calamities; the machinery already takes a `kind`).
- Full talk system: every role answers topics, and roles get replaced when their holder dies.
- Knights and adventurers, and hiring them.
- Dash on double-tap, shield block, bows for hunters.
- Settlement healing and ruins.

## What is deliberately not in rung 3

Interiors and elevation. Both were asked about on 2026-09-18 and both belong in rung 4 with the map growth:
elevation touches every routing call in the game and the wire format, and interiors want to be sub-maps rather
than a height axis. Fake height (a taller-sprite draw layer, cliff edges, drop shadows) is cheap and could be
slipped in any time it is wanted — it changes no server code at all.

## Suggested order, and why

1. **Save and catch-up** — gates everything, least fun, so do it first.
2. **Gossip and grudges** — the pillar; the reason to play.
3. **Tribute, tax, extortion** — gives the tribes a reason to come to you.
4. **Hunger** — small, and only earns its place after 3.
5. **The rest** — content, in whatever order looks most fun.

Publishing free happens before all of it (rung 2 part 5), because real players will change what is on this list.
