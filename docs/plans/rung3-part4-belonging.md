# Rung 3 part 4: belonging, the build plan

**Written 2026-10-05 (heavy, handoff H7). Plan only, no code. Status: approved by Danzo 2026-10-05, every
question answered as recommended (below). Phase 0 is next.**

Inputs: [`RUNG3.md` §Part 4](../RUNG3.md#part-4--belonging-party-up-ride-along-join) (what and done-when), the three
research reports ([joining](../research/belonging-joining.md), [guidance](../research/belonging-guidance.md),
[activities](../research/belonging-activities.md)), and the code as it stands (`Bands.lua`, `Tick.lua`, `Sim.lua`,
`Interact.lua`, `Sides.lua`, `Save.lua`). The rule above the others still governs: *could an NPC do this, under the
same rules, with the same data?* Every rule below passes that test or says why not.

---

## The shape in five lines

1. You **ask the leader** in the talk window (a new choice, no new UI). The answer reads your standing and what
   they have heard about you. A "no" says why, in gossip.
2. A yes makes you a **rider**: a transient tag on the group (`g.riders`) and on you (`ps.ride`). **Not** a row in
   `g.members`, and **not saved** (why: "Membership and the save" below).
3. The **group's walking is the instruction.** The leader's yes names where, what you do and what you get; the
   leader waits and faces you if you fall behind; members say short lines when something happens.
4. **Pay at each arrival** from one shared pot, cut by losses. Your standing moves because the group tells the
   village at that end (part 3's `Gossip.arrive`), never by a flag.
5. **Leaving is graded**: clean at an end, small minus mid-route, desertion in a fight, betrayal if you turn on them.
   A disconnect is "stepped away" and costs nothing.

---

## Joining

**The ask.** A new topic `ride` ("Ask to ride along") on the group's **leader** only: the caravan master, the
squad's first hunter, the band's first bandit (`g.leader`, as `Bands.materialise` sets it). Server side only:
`Interact.topic` learns two more topics and the leader's dialogue offers them. The client already draws up to four
choices with labels sent by the server, so **no client file changes** (they are at their ceilings).

**The checks**, in this order. The first that fires gives the answer, most specific first (the Left 4 Dead rule):

| # | Check | Answer, in the leader's voice |
|---|---|---|
| 1 | The group is fighting, retreating, or not materialised | "Not now." (no cooldown spent) |
| 2 | You asked this leader today (one ask per player per group per in-game day, transient) | "I gave you my answer." |
| 3 | Riders already at the cap (Q2) | "We're full up." |
| 4 | A grudge with this group's tribe (`Grudge`) above a threshold | "Not after what you did." |
| 5 | The newest thing this group or its village has heard about you (`Gossip.latest`) is a killing of their tribe | "I heard about [victim]. No." (the reason is the rumour) |
| 6 | Standing: the **lower** of the group's number and its home village's (Q5) is below the kind's bar | "Earn it first. [what would help]" |
| 7 | Band only: you are "family" with the farmers | "You smell of farm. Walk on." |
| — | Otherwise | **Yes**, and the yes is the role line (below) |

Bars to tune: caravan `welcome` (≥ 15, so a new player at farmer START 20 can ride at once: the first-minute
group), squad ≥ 15 (earn it with a trade or a gift), band ≥ −10 (they will talk to you). The rule is pure:
`Belong.ask(facts) -> answer, reason` in a new `shared/Belong.lua`, tested per row. An NPC could ask the same rule
with the same facts.

**The yes line** names destination, job and pay in one breath, built from the group record:
caravan "Walk with us to Kenstow. Keep bandits off the carts. Your share's paid when we get there." Squad "We're
out for deer by the east wood. Hit what we hit. Hides go home, you get a cut." Band "We wait for the farm road.
When we go, you go. Loot's split at camp." (`Talk.joinYes(kind, ctx)`; `Talk.lua` has room.)

---

## Membership: what changes

**For the player**
- You walk the group's route; you never steer it. No "follow" button: you just walk with them.
- Your own group never attacks you, and your blows on members are blocked (Q7).
- While you ride, the loot from your kills goes **into the pot**, not your bag (Q6), so nobody races for a corpse.
- Harm you do while riding passes `ctx.withGroup = true`, which already makes the grudge `Grudge.GROUP` (0.25) of
  normal: DESIGN §7's "part of a group: small", written in part 3 and dormant until now.

**For the world**
- The group stays materialised while you ride (you are near it, so `Bands.tick` already keeps it).
- **Whoever would attack the group attacks you**, and whoever sees you *with* it reads you as one of it, locally
  and on sight (Fallout NV's disguise done as behaviour). That is a `Sides.lua` change, which has room.
- The group is your best witness: what you do near it is a rumour it carries to both ends (part 3, unchanged).

---

## "Slightly obvious what to do" (the guidance layer)

Danzo's ask, answered with people, never a log or an arrow:

| Cue | What it is | Built from |
|---|---|---|
| **The yes line** | where, what, pay, once, at the moment you join | `Talk.joinYes` |
| **The leader waits** | if a rider falls more than 4 tiles behind, the leader stops and faces them, up to 20 s per leg, then walks on (an AFK player never stalls a caravan) | `Belong.wait`, one hook in the leader's step |
| **Copy a member** | guards turn on bandits, hunters close on deer: you see the verb done before you need it | already there |
| **Barks** | under ~6 words, a name in front ("Bera: Wolves, east!"), only to riders who can see the speaker, never modal, newest wins | new `shared/Barks.lua`; existing `text` notice (fades after 4 s, 3 at most) |
| **Fade** | a teaching bark fires 3 times a session, then the short form, then nothing; nothing said twice in a row | per-player session memory, **never saved** |
| **"What now"** | a topic on every member of your group: the leader says the plan and how far, a member says what they know | `Talk.whatNow(role, ctx)`; the elder's §12 topic reuses it later |
| **Arrival** | the share, the standing line, and one onward pointer ("Kenstow's short of food. Their merchant's by the well.") | `ctx.scarce`, as `Talk.merchant` already does |
| **No fail state** | walk off and the group goes on; the leader says one line and remembers | the leaving grades below |

Bark facts for the first slice: joined, you lag, hostile seen (wolf, band, guards of a tribe that hates the
group), prey seen (squad), end near, arrived, member down, you hurt. The test of the whole layer is the research's
**30-second test**: a fresh tester joins the caravan and, within 30 s and without asking, can say where they are
going and what they are guarding.

---

## What groups do (most for least)

1. **The pot, split at each arrival, cut by losses** (all three). Caravan: a wage per leg from the master (it
   carries no cargo today). Squad and band: the sell value of the `g.carry` share; the goods still go to the
   village stock. Each rider and each living member is one share; the pot is cut by `alive / fullSize`. A rider
   who left before the end gets nothing. One pure rule, `Belong.share`, read by `Tick`'s deposit event.
2. **"First to spot it warns the group."** Any member (NPC or rider) who comes within range of a hostile body makes
   the group halt and bunch (`pauseUntil`, already the halt), and the spotter barks. Ahead of the leader you spot
   first, so **your role comes from where you walk**: the caravan's scout, the band's lookout (the caravan is the
   "hostile"), the squad's tracker (pointed at deer, the leader turns toward them). One rule, three roles, no new
   button. A rider who spots first gets a small extra share: effort shows in pay.
3. **Later, in this order:** the "yes, but" trial ride; the group asks you to go when its number of you falls;
   loyalty inertia (rides finished make the next ask easier); packer; haggling with your `priceMult` at the far end;
   beater; extortion (part 5 overlaps).

Avoided, from the research: loot races, a shared stash anyone can empty, pay that ignores effort, scripted ambush
points, followers as pets, a menu at either end. **The bad side keeps a trading partner:** the plunderer village
still trades with a band rider (it likes them more), so riding with the band is a life, not a dead end.

---

## Leaving, betrayal, rewards and blame

| How you leave | Detected by | What it costs | Who says it |
|---|---|---|---|
| **At an end, after the share** | ask "leave" at the end, or walk off within the pause | nothing; a small plus with the group ("Ride with us again.") | the leader |
| **Mid-route, quiet road** | more than 12 tiles from the leader for 10 s, or "leave" mid-route | small minus with the group only (−3) | the leader, one line |
| **Desertion** | you leave while the group is fighting | minus with the group and its home village; every member is a witness, so it travels | the members, as a rumour |
| **Betrayal** | you hit a member twice within 10 s (Q7) | membership ends first, then the full hit/kill rules at the **alone** grudge size, not 0.25 | everyone who saw |
| **Stepped away** | disconnect, server stop (Q1) | nothing, and no share | nobody |

New rumour events, all through the ring that exists: `rode` (seeded at the group at each arrival you were there
for: + with the group's tribe and the village reached, − with their enemies), `left`, `deserted`. They are new
**values** in the rumour's existing `event` field: `Reputation.deltas` returns nothing for an event it does not know,
so an older server reading them is harmless. Their deltas live in `Reputation.lua` (`Gossip.lua` is at 396/400).

**Blame is shared:** each member lost cuts every share. **The personal mark** is running: four witnesses carry it.

---

## Membership and the save (trigger 3, answered: no format change)

**Decided (Q3): the save holds nothing new.** `World VERSION` stays 4, `PLAYER_VERSION` stays 1.

- Membership is scratch, like `g.entities`: `g.riders[userId]` (joined at, share earned, spotted, last seen near)
  and `ps.ride = groupId`. Reset by `Bands.scratch`; never encoded.
- **Why not a row in `g.members`** (the plan in ARCHITECTURE §6 B1 said `{ player = userId }`): `members` is
  saved, and three rules read it as people. `materialise` makes a body for every row, `Tick.daily` refills to
  `fullSize` by counting rows, and the band breaks at `#members * 2 < fullSize`. A player row would spawn an NPC
  double, block replacements and skew the break, and it would sit in the world key after the player left. This
  departs from that line of ARCHITECTURE; it goes in `as-built.md` when phase 1 lands.
- What persists already does the remembering: the group's opinion of you is `ps.rep[groupId]` (holder-keyed since
  part 3, saved), and what the world heard is in the rumour ring.
- **What is lost:** a ride in progress on disconnect or server stop (by design: "stepped away", no penalty, no
  share), and the one-ask-a-day cooldown on a server restart (harmless).
- Later, if loyalty inertia is built: `ps.rides = { [groupId] = n }`, additive with an empty default (learnings
  P1), still no bump.

---

## Where the code goes (ceilings, learnings T1/T4)

| File | Now / limit | Part 4 adds |
|---|---|---|
| `server/Sim.lua` | 1255 / 1255 | **nothing it cannot pay for**: 4 short hooks (rider kill loot to the pot, `ctx.withGroup`, blocked blow, leader wait). Needs phase 0 |
| `server/Bands.lua` | 194 / 400 | phase 0's carve, `g.riders` in `scratch`, the arrival hook before `Tick.groupTurn` |
| `server/Ride.lua` (new) | — | join, leave, the 1 Hz rider tick (lag, wait, spot, barks), payout, drop riders who left the server |
| `server/Interact.lua` | 349 / 400 | the `ride`, `whatnow` and `leave` topics on group members |
| `server/Sides.lua` | 294 / 400 | own group never hostile to its rider; others read the rider as the group |
| `shared/Belong.lua` (new, pure) | — | `ask`, `share`, `leaveGrade`, `wait`, `spot`: all tested in `test/luau/belong.test.luau` |
| `shared/Barks.lua` (new, pure) | — | the fact → line table, most-specific pick, fade |
| `shared/Talk.lua` | 178 / 400 | `joinYes`, `joinNo`, `whatNow`, arrival and road lines |
| `shared/Reputation.lua` | 114 / 400 | the `rode` / `left` / `deserted` deltas |
| client files | full | **nothing** |

---

## Phases

Each is one branch, one goals file in `docs/qa/`, one QA loop. Luau gates every time: `npm test`,
`npm run lint:luau`, `npm run test:luau`.

**Phase 0: make room in Sim (a Track B slice; Q4)**
- What: move "what a fight does to a group" (`killEntity`'s two group halves, about 30 lines) verbatim out of
  `Sim.lua` into `Bands.lua`. Bands becomes the one writer of `groups{}`, as R2's owner table already says it should.
- Done when: sourcemap tree identical (new module only); `Sim.lua` has ≥ 25 lines free; Studio regression: a band
  breaks at half and runs, a laden squad turns home and banks its hides, a dead member is replaced next day.
- Goals file: `docs/qa/rung3-part4-p0-room.md`.

**Phase 1: ask, ride, arrive (the caravan half of the done-when)**
- What: the `ride` topic and `Belong.ask` with all seven checks; riders as scratch; own group never hostile, blows
  blocked; the leader waits; the pot and `Belong.share` at each arrival; the `rode` rumour seeded before
  `Gossip.arrive`; the yes line and the arrival line; walking off = "left", a disconnect = stepped away.
- Done when: tests for every ask row, the share split and loss cut, and `rode` round-tripping in `save.test.luau`
  with `VERSION` still 4. In Studio: ask the caravan master at Glenworth and get a yes that names Kenstow; walk it;
  get ambushed; arrive, get paid, and see Kenstow's standing line go up. Ask the squad as a stranger and get a
  "no" with a reason. Walk off mid-route: one line, a −3 with the caravan, no failure notice.
- Goals file: `docs/qa/rung3-part4-p1-ride.md`.

**Phase 2: the obvious layer**
- What: `Barks.lua` with the first eight facts and the fade; `whatnow` on every member; road talk lines.
- Done when: tests show the most specific line wins, no line twice in a row, a teaching line goes quiet after 3.
  In Studio: the 30-second test passes with someone who has not read this doc, and every bark has a face on screen.
- Goals file: `docs/qa/rung3-part4-p2-guidance.md`.

**Phase 3: sides, the band and betrayal (the band half of the done-when)**
- What: the band's ask rules; others read a rider as the group; desertion and betrayal; `ctx.withGroup`.
- Done when: tests for `leaveGrade` (all five rows) and the 0.25 vs alone grudge. In Studio: ride with the band into
  an ambush on the caravan and be seen; walk to Glenworth and find the gate shut (wary or worse, no rest, guards
  watching). Hit a band member once: warned. Twice: they turn on you, and the grudge is the alone size.
- Goals file: `docs/qa/rung3-part4-p3-sides.md`.

**Phase 4: first to spot it**
- What: `Belong.spot` for all three kinds; the halt-and-bunch; the spotter's bark and extra share.
- Done when: a test that a rider ahead of the leader spots first and a rider behind does not. In Studio: walk ahead of
  the caravan, see the band first, watch the caravan stop and bunch before the hit; as a band rider, see the caravan
  first and watch the band get set.
- Goals file: `docs/qa/rung3-part4-p4-spot.md`.

Part 4's RUNG3 done-when is met at the end of phase 3. Phase 4 is the first thing that makes the middle of the
walk a job. Everything in "Later" waits until phases 1–4 are fun in Studio.

---

## Track B: must it un-park?

**A slice of it, yes. Not the rest.** `Sim.lua` is exactly at its ceiling, and part 4 has to touch four places
in it (the kill, the hit, the fight context, the leader's step). Track B was parked on Danzo's word ("do not continue
without asking", `roblox/src/server/README.md`); he un-parked this slice only on 2026-10-05 (Q4). Phase 0 is the smallest carve that pays for those hooks, and it is
the one the owner table already wants. B2 (`Bodies`/`Brains`/`Fighting`), B3 and B4 stay parked.

---

## Danzo's questions: all decided 2026-10-05, as recommended

**Q1. Does a disconnect mid-route count as leaving?** *(blocked phase 1)*
- Options: (a) "stepped away": membership ends, no penalty, no share; (b) desertion; (c) membership persists and
  resumes on rejoin.
- **Decided** (as picked): **(a).** Phones drop and Roblox sessions are short; punishing a dropped signal is a fail state. (c) needs a
  save field and a group that has walked on without you.

**Q2. Can two players share a group?** *(blocked phase 1)*
- Options: (a) no, one rider; (b) yes, up to a cap; (c) no cap.
- **Decided** (as picked): **(b), cap 2 riders** (a Config number). There is one caravan, one squad and one band per world, so a busy
  server queues ("We're full up"); no cap lets six players swamp a three-person caravan. If one betrays, the other
  loses nothing unless they struck too: standing is per player.

**Q3. How does the save hold a member player?** *(blocked phase 1)*
- Options: (a) not at all: scratch only; (b) a field in the player key (additive, no bump); (c) a row in the world
  key's group (`VERSION` 4 → 5).
- **Decided** (as picked): **(a).** Nothing new is saved and nothing is stranded. What must persist (their opinion of you, what was
  heard) already does. (c) also breaks three rules that count `members` (above).

**Q4. Un-park the phase 0 slice of Track B?** *(blocked everything)*
- Options: (a) yes, phase 0 only; (b) no: squeeze Sim's lines some other way.
- **Decided** (as picked): **(a).** There is no other honest way to pay for four hooks in a file at its ceiling.

**Q5. In the ask, how do the group's and its village's standing combine?**
- **Decided** (as picked): **the lower of the two.** One number, easy to explain in the "no" line. (Average was the other option.)

**Q6. What is the share paid in, and does your kill loot go into the pot while you ride?**
- **Decided** (as picked): **coin, and yes.** Coin is simple (goods would fight the 10 slots), and loot into the pot is what stops loot
  races. Coin is minted at payout, as trade and loot already do.

**Q7. Friendly fire: what does hitting your own group do?**
- Options: (a) nothing, ever; (b) first blow blocked with a warning, a second within 10 s is betrayal; (c) every
  blow counts.
- **Decided** (as picked): **(b).** Phone players mash attack; one stray tap must not end a ride. A deliberate second blow is a choice.

**Q8. A line on the HUD while riding ("Riding with the caravan to Kenstow")?**
- **Decided** (as picked): **not in phase 1.** It costs no client lines (the goal line is server text), but it is a quest log in a
  costume. Add it only if the 30-second test fails.

**Q9. Can a player lead a group?** **Decided: not in part 4.** That is rung 4's hiring, on this same machinery.

**Q10. Is "no ask on the road" right?** Asking only while the group is materialised and not fighting means you
have to find them. **Decided: yes**; the caravan passes Glenworth twice a round trip.
