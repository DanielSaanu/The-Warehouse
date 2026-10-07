# The first week, and what to play with after rung 3

**Written 2026-10-07 (heavy, handoff H12). Proposal only, no code. Status: waiting for Danzo to pick.** Nothing in
`docs/DESIGN.md` or [`build-rungs.md`](../design/build-rungs.md) changes until he does.

Danzo, after riding the caravan in phase 2: *"there is a gap between starting and being told to join a caravan and
after where im just told to be inside for 7 days later which is boring admittedly also i dont want the joining the
caravan to be the main objective we need more fun things for the player to do and experiment with after were done
with this rung"*.

Two questions: **(a)** how to fill the first week (now), and **(b)** what the player gets to play with after rung 3.

---

## What the first week is today (read from the code)

| Real time (rough) | Goal line | What moves it |
|---|---|---|
| 0–2 min | "Talk to the person calling you" | closing the survivor's window (`Interact.close`) |
| 2–10 min | "Go east down the road to Kenstow" | walking into Kenstow (`Goals.tick`) |
| ~10 min | "Talk to the guard at Kenstow" | closing the Kenstow guard's window |
| 10–25 min | "Sell a hide at a stall" | the first sale anywhere (`Interact.lua:332`) |
| **25–70 min** | **"Be inside walls or by a fire before day 7"** | nothing: it just sits until day 7 (`Sim.lua:939` clears it) |

Times are estimates from `Config.DAY_SECONDS = 600` and the walk, not measured. The three problems:

1. **The last step is a deadline, not a thing to do.** Every other step is finished by an action; stage 5 is
   finished by the clock. A player who sells on day 2 reads the same sentence for about 45 minutes. (Selling jumps
   straight to stage 5; `Goals.tick` would also set it from day 6.)
2. **Nothing points at the caravan, the squad, the camp or the people.** The survivor's seven lines teach the keys and
   the road; the caravan master is found by accident. Yet a fresh player already *qualifies* for the caravan: farmer
   standing starts at 20 (`Reputation.START`) and the caravan's bar is 15 (`Belong.BAR`). The squad's is also 15 and
   hunter standing starts at 0, so Kenstow's squad says "Earn it first", which is a pointer nobody is told to follow.
3. **The week has no shape.** The calamity is warned the day before (`Calamity.warning`), so days 2–5 have no
   rising tension and nothing to prepare for.

What the fix has to satisfy (`docs/PRINCIPLES.md` principle 1): it points, never choreographs (1.3); every step can
be finished by accident (1.5); it is said by a person (1.6); and the caravan is **one** road among several (1.4,
Danzo's "not the main objective"). It is for the first minute, but must not leave the minute after it empty.

---

## (a) Three options for the first week

### Option A: patch the line (smallest)

- **Survivor:** one added line: "The caravan still runs from here to Kenstow. Walk with the master if he's in."
- **Goal line:** stage 4 becomes "Earn something in Kenstow" (finished by a sale, a ride's pay, or a gift). Stage 5
  becomes "Find a bed or make a camp" (finished by resting or placing a camp: an action). Stage 6, set on the
  warning day: "<Calamity> tomorrow. Be inside walls or by a fire." Then retire as today.
- **Before day 7:** nothing new; the line just stops sitting still.
- **Size:** half a day. `Talk.survivor`, `Talk.goal`, `Goals.lua`, two hooks in `Interact.lua`. No new system.
- **Risk:** it fixes the sentence, not the dead days. A player who has a bed by day 2 still has 40 minutes with
  nothing pointing anywhere. It also stays a single corridor.

### Option B: the line widens into "things worth trying", and people say "what now" (recommended)

- **Survivor:** names three doors in one line, not one: "Kenstow's hunters owe us. The caravan runs there from here.
  Or just keep your head down and trade." The order stays (road first), the caravan stops being the secret.
- **Goal line, stages 1–3 unchanged** (they work: the 30-second test passed). After the Kenstow guard, the line
  stops being a chain and shows **one untried thing at a time**, picked from a short list by where the player
  stands, each finished by doing it *or by doing it without being asked* (1.5):
  sell something · ride with a group to its end · make a camp · give someone a gift · rest in a bed ·
  hunt with the squad (once Kenstow likes you). When one is done, the next one shows. The list is a menu of verbs
  the game already has; nothing new is built for it.
- **"What now" on the guard, now.** DESIGN §12's elder topic, given to the guard (a role that exists in every
  village) instead of waiting for the chief. It answers from where you stand, through the same pick: "Kenstow
  doesn't know you yet. Sell them hides; the squad will have you after." A far or wary guard says less. This is
  open question §19 ("earlier?") answered yes.
- **The week gets a shape (cheap slice):** from day 5 the warning spreads by people, not the sky: guards and road
  talk say "River's rising" or "Wolves in the north, they say" a day early, using the existing `warning` text and
  RoadTalk. The goal line's last stage is still "<Calamity> tomorrow. Be inside walls or by a fire" on day 6.
- **Size:** about two days. `Talk.goal` and a pure picker (`Talk` or a small new `shared/` module, tested),
  `Goals.lua` reading what the player has done, a `whatnow` topic on the guard (reuses `Talk.whatNow`'s shape),
  one RoadTalk fact.
- **Save:** one new optional player field, a small set of "tried" flags (`ps.tried`). Additive-optional under
  learnings P1, **no version bump**, nothing lost. `goalStage` keeps its meaning for 1–3; stages 4–5 are
  re-read as "past the chain". In development mode this is moot, but it is still the cheap kind.
- **Risk:** the line starts to look like a checklist if it shows more than one thing or nags. Rules: one item,
  never the same item twice in a row once skipped, it retires at the first calamity exactly as now, and the guard's
  "what now" carries on afterwards (that is the hour-twenty compass).

### Option C: the first week is a story with a climax (biggest)

- Everything in B, plus: from day 3 the coming calamity is **visible**: river tiles creep, wolf counts in the north
  rise and you see more of them, villagers carry food indoors. Villages **ask** for what the calamity needs (food
  before a flood, hides and guards before a beast tide) through `ctx.scarce` and the merchant's price. On the day,
  the player can stand with a village's guards; the guards remember who stood with them (a `stood` rumour).
- **Size:** four to six days. Touches `Calamity.lua` and `Ecology.lua` (shared, trigger 2), the tick loop (trigger
  6), and a new rumour value (cheap, like `rode`).
- **Risk:** it is the best version, and it is mostly not the first week's problem: it makes *every* week better. It
  belongs after rung 3 as a toy in its own right (it is #4 in the list below), not as the fix for the opening.

**Recommendation: B now.** It answers both halves of Danzo's complaint (the gap before the caravan and the dead
days) with verbs that already exist, makes the caravan one door of several, and builds the "what now" compass that
RUNG3 already calls urgent. C's full version waits for (b); its cheap slice (the warning a day early, by people) is
inside B.

---

## (b) What to play with after rung 3: ranked by fun per day of work

The test for every item: it is a **verb, not a quest**; it touches systems that already exist (principle 2.1, 2.4);
an NPC could do it under the same rules (pillar 5); and a stupid use gets a stupid result, not a refusal (2.5).
Sizes are rough, in focused days. "Fits" places each against [`build-rungs.md`](../design/build-rungs.md) rung 4
(more villages, raids, walls, hiring to build, funding caravans, territory).

| # | Toy | Size | Fits |
|---|---|---|---|
| 1 | Bait and lure: start fights between others | 1–2 d | end of rung 3 (part 7) |
| 2 | Say things: tell, warn, lie | 3–4 d | end of rung 3 / start of rung 4 |
| 3 | The first hireling: you lead a group of one | 4–6 d | **opens rung 4** (it is §13's hiring) |
| 4 | Calamities you can see coming and stand against | 4–6 d | rung 3 part 7 (with blizzard, drought) |
| 5 | Fire: flint as a verb | 4–6 d | rung 4 |
| 6 | Your camp becomes a place: a plot, a fence, a store | 5–8 d | rung 4 (before walls and building) |
| 7 | Prices travel by word: trade runs on old news | 2–3 d | rung 3 part 6 (goods' second axis) |
| 8 | Pick a side in a raid on a village | 6–10 d | rung 4 ("raids on villages") |

### 1. Bait and lure

- **What you do:** let a wolf chase you into Kenstow and watch the guards take it; pull the band onto the caravan's
  road; drag a boar into the plunderer camp; lead wolves away from a hurt friend. You never swing once.
- **Why fun:** "I did not know you could do that" (principle 2's test) for nearly no code: the rules are already
  there. `Sides.preysOn`, `pickNpcTarget` and `Witness` decide who joins, and `Sides.tellHelp` already tells you
  who stepped in. A wolf avoids a lit camp, so a fire is a tool too.
- **Reuses:** Witness/Sides, wildlife, bands, the caravan, standing, gossip (whoever saw it).
- **The build:** mostly a ruling and words. (1) Decide blame: is luring "drawing first"? Proposal: no hit, no blame,
  but a witness who *saw* you lead the band in remembers (`lured`, a new rumour value, as cheap as `rode`). (2) A
  bark when it works ("Glad you brought it here, not to the farms.") and when it is noticed ("You led them to us.").
- **Risk:** cheap griefing of other players' caravans in a shared world; the `lured` witness is the answer. Guess,
  not measured: how reliably a chasing wolf switches to a guard today. Check in Studio before building.

### 2. Say things: tell, warn, lie

- **What you do:** a "Tell them…" choice on any talk window: warn a village the band is coming, tell the hunters
  where the deer are, tell the plunderers the caravan's leaving, or **lie** about who killed whom.
- **Why fun:** information becomes a weapon and a gift (pillar 2 "everything remembers", principle 2.6: many valid
  answers). Players will surprise each other with this one.
- **Reuses:** the gossip ring and its rumour events (the player becomes a source, at "heard" strength, never
  "saw"), `Reputation.deltas`, talk windows. A lie is a rumour whose truth the world can check: a group that
  meets the "dead" person, or a witness who saw otherwise, turns the lie back on you (`lied`, grudge-sized).
- **Risk:** the ring is capped (learnings S1): player-made rumours must not crowd out real ones, so a per-player
  cap per day. Lies need a truth check that is cheap; scope it to kills first. Wording work is real.

### 3. The first hireling

- **What you do:** ask a named villager to walk with you, guard your camp, carry, or hunt. They have a name, a
  family, an opinion of you, things they will not do, and they tell people what you did.
- **Why fun:** DESIGN §13 already argues it: the Pal-shaped thing in this game is a person, and one person touches
  five systems (principle 2.1). It is the progression that replaces levels (pillar 4).
- **Reuses:** **part 4's own machinery reversed**: a group record with the player as leader and one member, so
  `Belong` rules, `whatNow`, barks and the leave grades all apply the other way round (pillar 5's NPC test passes
  by construction). Families, gossip, Witness for "who they will not fight".
- **Risk:** the biggest design surface on this list (pay, loyalty, death, a hireling's relatives). It must be
  asked, never bought from a menu (RUNG3 "What is deliberately not in rung 3"). Members are saved, so this is a
  **save question** (trigger 3) to settle in its own plan before code.

### 4. Calamities you can see coming and stand against

- **What you do:** read the week (the river creeping, more wolves north), stock a village with what it will need,
  then stand with its guards on the day, or profit from the shortage instead.
- **Why fun:** the clock (DESIGN §3, "the calamity is the clock") becomes a thing you play rather than wait out;
  two valid answers (help or profit, 2.6). It also fixes the dead days of every later week, not just the first.
- **Reuses:** `Calamity`, `Ecology` counts (the visible creep is the real number), `ctx.scarce` and prices,
  Witness on the day, a `stood` rumour. Blizzard and drought (rung 3 part 7) slot in as new kinds.
- **Risk:** shared modules and the tick loop (triggers 2 and 6); the "visible creep" must be a projection of
  numbers that already exist, never a second state.

### 5. Fire

- **What you do:** your flint lights more than a camp: burn tall grass to flush deer or bandits, set a firebreak
  before a beast tide, or burn a plunderer hut.
- **Why fun:** the most Palworld-shaped rope on the list (pillar 5); it composes with ecology (habitat, §9 already
  plans "burn a forest"), wildlife fleeing, Witness (arson is witnessed), calamities, and camps.
- **Reuses:** the camper set's flint, `Ecology` habitat, Witness, the tile map, calamity overlays.
- **Risk:** it changes tiles in a shared, saved world, so where burnt ground lives is a **save question**; it
  should be a decaying overlay like the flood (`Calamity.applyOverlay`), closed form over days (learnings P2), never
  a map edit. Griefing a shared map: grass regrows, huts burn only with witnesses who remember.

### 6. Your camp becomes a place

- **What you do:** plant a plot by your bedroll, put up a fence, leave goods in a stash. Bandits find it, a flood
  takes it, a hireling (#3) guards it.
- **Why fun:** the first thing that is *yours* in the world, and the seed of §13's "true home", built by the same
  rules a village uses.
- **Reuses:** `Farms` (a plot is a record), the camp, Bands (raiders), Calamity (it can be lost), DESIGN §11's camp
  rules.
- **Risk:** a stash is "a shared stash anyone can empty" (the research's avoid list) unless it is per player;
  persisted structures are a **save question**. Best after #3, because a home nobody guards is just a loss.

### 7. Prices travel by word

- **What you do:** hear at Kenstow that Glenworth is short of tools, carry a load there, and find out whether the
  news was old. Run goods ahead of a calamity.
- **Why fun:** trade becomes a bet on information, and the caravan becomes a rival, not a job. Gives goods the
  second axis §19 asks for without a crafting tree.
- **Reuses:** the merchant board, `ctx.scarce`, RoadTalk ("Glenworth's short of tools, they say": phase 2 already
  says it), gossip's travel time.
- **Risk:** small; mostly tuning so it pays sometimes and not always (principle 1's "fastest route is not the most
  fun").

### 8. Pick a side in a raid

- **What you do:** the band raids a village; you defend it, ride with the raiders, or loot the aftermath.
- **Why fun:** every system at once: Witness, grudges, families (who dies), part 4's riding, the village's stock.
- **Reuses:** almost everything, and rung 3 part 4 phase 3 (sides, the band, betrayal) is its base.
- **Risk:** large, and it changes the population balance (villages losing people for real). It is rung 4's own
  headline; listed so it is not mistaken for something small.

**Top three to build first, in order:** 1 (it nearly exists and proves the "experiment" feeling cheaply), 2 (the
most original, and it is pillar 2 made playable), 3 (it opens rung 4 the way §13 wants it opened).

---

## Where this lands against the rungs

- **Rung 3 tail:** option B (the first week), then #1 and #7. #4 rides with part 7's blizzard and drought.
- **Rung 4, first:** #3 (hirelings), because #6 and DESIGN §13's building and funding caravans are the same
  mechanic and want it underneath them. #2 can go either side; it gets better once there are more villages.
- **Rung 4, later:** #5, #6, #8, in that order. Every one of these scales with the map growing (Danzo, 2026-10-05):
  more villages mean more people to lure toward, lie to, hire and raid, with no per-village content to write.

## What Danzo needs to pick

1. **(a):** A, B or C. Recommendation: **B**.
2. **(b):** which of the eight, and in what order. Recommendation: **1, 2, 3** first; the rest as listed.
3. **One ruling for #1, if picked:** is luring a fight onto someone "drawing first"? Recommendation: **no blame for
   the hit, but a witness remembers you led it there** (`lured`).

After he picks: the chosen (a) goes into [`long-arc.md`](../design/long-arc.md) §12 and RUNG3 part 7, the chosen
toys into [`build-rungs.md`](../design/build-rungs.md) rung 3 / rung 4, and each gets a phase plan before code.
