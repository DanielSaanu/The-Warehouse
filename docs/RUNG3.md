# Rung 3: memory and money — the build plan

DESIGN.md §16 names rung 3 in three lines. This is the order to build it in and why, split into parts the way
rung 2 was, each one its own branch, goals file and QA loop.

Rung 2 ended with a world that lives, remembers you for as long as the server is up, and can be played by a
stranger on a phone. Rung 3 is about that memory outliving the server, and about the tribes wanting something
from you rather than merely existing near you.

## The order, and the two things pulling at it

**The world up close does nothing without the player** (DESIGN.md §20, found in play 2026-09-18). Wolves hunt only
the player, bandits raid only the player, predation is a daily number, farms are a tile, villagers wander. §1
pillar 1 says the world does not need you, and up close it needs nothing else. This is what a new player meets in
the first thirty seconds, and it is the most likely reading of "kind of boring, I don't know what to do" in
`ideas/INBOX.md`.

**Nothing a player does survives a shutdown.** Reputation, families, standing, the goal you were on, the camp you
paid fifteen coin for: all of it regenerates from the seed next time. A grudge that decays over years is
meaningless in a world that forgets overnight, tribute and tax are a relationship over weeks and there are no
weeks, and DESIGN.md §16 forbids charging for anything until it lands.

Both are true and neither blocks the other. The world up close goes first (Danzo, 2026-09-18) because the game is
about to be public and boredom costs players now, while persistence costs nothing until there is something to sell
and someone who stayed long enough to lose it. Save and catch-up is second and still gates all the money.

## Part 1 — The world up close

**What it is.** DESIGN.md §20, found by Danzo in play on 2026-09-18 and verified in the code: every interaction in
the game has the player on one end of it. Wolves hunt only the player, bandits raid only the player, predation
happens once a day as a number in `Ecology.dailyTick`, farms are a tile with no logic behind it anywhere in
`roblox/src/server/`, and villagers have exactly one behaviour, which is to wander.

That is the opposite of §1 pillar 1, "the world does not need you", and it is almost certainly what "kind of
boring, I don't know what to do" meant in the playtest note in `ideas/INBOX.md`. A player who stands still for
thirty seconds should see the world do something that is not about them.

- **Hostility stops being player-only.** `pickNpcTarget` currently exits unless the entity is a hunter, a guard or
  a caravan guard. Every hostile kind gets a target test: wolves hunt deer and boar, bandits ambush caravans and
  anyone caught outside walls, boar defend themselves against whatever hit them.
- **Predation you can watch.** A kill near a player materialises and plays out; with nobody near it stays a number.
  The region count moves either way, so `Ecology` stays the authority and the ecosystem does not change shape
  based on who is looking.
- **Villagers get a day.** A work tile, a home hut, and a night that sends them to it. The family records that
  already exist (parents, children, succession) become something you can see rather than something the debug
  command can print.
- **Farms grow.** Stock that rises, is harvested into the tribe's food, and is worth raiding — which is what makes
  a plunderer band attacking a farmer village mean anything.

**Depends on:** nothing. It is first because the game is about to be public, this is what a new player sees in
the first thirty seconds, and save and catch-up costs nothing until someone has stayed long enough to lose
something. Watch its scope: it is the item most likely to grow while it is being built.

**Feeds:** part 3. Gossip is NPCs telling each other what they saw, and right now there is almost nothing for them
to see that does not involve the player.

**Done when:** stand in a meadow at night and watch a wolf take a deer without ever touching either; leave a
caravan on the north road and come back to find the band has been at it.

## Part 2 — Save and catch-up

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
- **The hard question, settled (Danzo, 2026-09-18): one shared world.** Every server reads and writes the same
  save, because the whole pitch is that the world remembers, and a world that only remembers you alone is a save
  file, not a place. It needs a **session lock**: one live server owns the world, claimed in MemoryStore and
  renewed on a heartbeat, expiring on its own if a server dies without releasing it. A server that cannot get the
  lock loads the save, plays on locally and never writes the world back — a guest in someone else's world, and it
  says so rather than silently rolling anyone's standing back. Player saves are keyed by UserId and are not
  locked, so a guest server still saves your own coin and standing.

**Risks:** DataStore request budgets, 4 MB per key, writes on shutdown that do not finish. The family registry is
the thing most likely to outgrow a key; it may need pruning of the long dead.

**Depends on:** nothing, but it must land before anything is sold (DESIGN.md §16), and part 1 gives it
more to save: farm stock, a villager's work and home tile, the state of a hunt.

**Done when:** stop the server mid-game, start it again, and your coin, your standing, your camp and the guard's
name are all still there, and the calendar moved on.

## Part 3 — Gossip and grudges

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

**Depends on:** part 2, because a grudge that resets nightly is not a grudge.

**Done when:** kill a hunter where only one person sees it, walk the other way, and watch the news reach their
village over the next in-game day — and arrive at the far tribe later still, weaker and vaguer.

## Part 4 — Tribute, tax and extortion

**What it is.** The tribes stop being scenery and start wanting things from you. `ideas/INBOX.md` describes this
at length and none of it exists yet.

- Size tiers (small, mid, large) per tribe, driving how much of everything they do.
- Plunderer tribes demand tribute from villages in their territory, and from the player once he has something
  worth taking. Large bands extort rather than destroy: they want a paying neighbour, not a ruin.
- Farmer tribes collect tax from smaller villages in their territory and send caravans out from the strongest.
- The player can pay, refuse, or fight, and each is remembered by part 2's machinery.

**Depends on:** part 3, so that refusing a demand actually costs you something that lasts.

## Part 5 — Hunger, and making food matter

DESIGN.md §11 parks hunger with a condition on it: **"if it makes the food economy matter"**. It only does once
there is something to spend food on and something to lose by running out. After parts 2 and 4 there is: caravans
to supply, tribute to pay, a long walk between villages that persists across sessions.

Small, and it makes the farmer tribes' whole existence legible.

## Part 6 — The rest of the list

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

1. **The world up close** — the pillar §1 claims and the code does not keep. Found in play, and it is what
   "boring" meant. First because the game is about to be public.
2. **Save and catch-up** — gates all the money, least fun, and nothing is sold before it lands.
3. **Gossip and grudges** — the pillar; the reason to play. Wants 1 first, because gossip is NPCs telling each
   other what they saw.
4. **Tribute, tax, extortion** — gives the tribes a reason to come to you.
5. **Hunger** — small, and only earns its place after 4.
6. **The rest** — content, in whatever order looks most fun.

Publishing free happens before all of it (rung 2 part 5), because real players will change what is on this list.
