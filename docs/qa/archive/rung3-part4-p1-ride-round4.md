# QA round 4: rung 3 part 4 phase 1 (ask, ride, arrive)

**SCORE: 8/10** (Opus reviewer, 2026-10-06, Studio played at 1d62682 over two Play sessions, DevMode; a 4th round
at Danzo's request after the 3-round loop ended at 7)

## Report (verbatim)

Round 4 QA review: rung 3 part 4 phase 1 (ask, ride, arrive), branch h9-sim-carve at 1d62682

I tested in Studio across two Play sessions, using Debug through ServerStorage.Debug and Action/Notice remotes fired
from the Client datamodel. I stopped Play at the end and modified no files.

Every Studio item flagged "never yet seen" now works on screen. I found one new real issue, in the round 3 fix:
reading the window long enough ends the ride silently.

**Studio evidence (session 2, a fresh world)**
- **Ask at Glenworth:** the yes line reads "Walk with us to Kenstow. Keep bandits off the goods. Your share's paid when we get there."
- **Blow on your own group:** two `attack up` on guard e56 produced one line, "Brilo: Oi! Watch it." The guard stayed at hp 10 and idle, and caravan standing did not change. The 3 s line limit worked.
- **Natural Glenworth → Kenstow ride:** pos went 1→56 with no Debug `arrive`. The client got "Gweno: Here's your share, 7 coin. Kenstow will hear you rode with us. They're short of food here." Output showed `[Ride] Stifffchoclate paid 7 at Kenstow (rode 55 of 55)`. Standing went v2 (Kenstow) 0 → 2.25 and caravan 20 → 24. 7 = floor(30/4) is correct.
- **Clean leave during the Kenstow pause:** "Ride with us again.", and caravan standing 24 → 26. Re-asking in the same window gave a yes, so `dialogue.e` is kept.
- **Lag wait-and-face:** I stood still 7 tiles back. The master stood at 65,56 facing right (toward me) for about 20 s, then walked on.
- **Mid-route walk-off:** about 10 s after passing 12 tiles, exactly one line, "Gweno: Suit yourself.", with no failure notice. Caravan standing 26 → 23.
- **Squad as a stranger:** "Earn it first. Folk in Kenstow don't know you well enough yet." The same day: "I gave you my answer."
- **Talking to a squad member who isn't the leader:** "Squad's out for deer. Ask Maren if you want to walk with us." The leader says "…Want to walk with us?"
- **Kill while riding:** "Into the pot: 1 hides, 2 food." The caravan's carry became `[1 hide, 2 food]` and my coin did not change.

**Session 1: the yes window left open, world unfrozen**
- At 35 s, standing was unchanged ({"v1":20,"v2":0,"v3":-20}) while the master was 20 tiles away. The "reading is present" part of the fix works.
- Some time later the caravan was folded (no entity e55). After I closed the window, no line ever came, and at Kenstow the master gave a fresh yes instead of "You're with us already". The ride had ended silently.
- Reading the code: `tickGroup` checks `not g.materialised` before `ps.dialogue` (Ride.lua:150 vs :154). `farSince` was kept nil while reading, so `finish(..., away=true)` runs: no cost, no line, no ride.
- While reading, `r.rode` also stops counting (the `elseif l` branch is skipped), so the share shrinks too.
- In that session my Debug `jump` (default day 7) started the beast tide and wolves killed me, so I restarted. That was my error, not the build's.

**Tests:** `npm test` pass 13, fail 0; `node test/luau/run.js` every file ok; `npm run lint:luau` all ok. Sim.lua 1152,
Gossip.lua 396, Belong.lua 127, Ride.lua 255. `view_29_70@5x.png` renders as before.

**Lenses**
- **Player:** the whole loop now reads well. You ask, get a clear job, walk, and are paid in the master's voice with the village told. The non-leader pointing at "Maren" is a nice touch, but four identical hunters give no way to find Maren without talking to each one.
- The master bolted ("flee") twice near Kenstow, probably witnessing villagers fight wildlife ("Kenstow turns out for you" appeared when a boar chased me). Each time the ride stalled about 30 s with no explanation to the rider. Not this PR's code, but it hurts the ride's feel.
- "Suit yourself." does not tell the player they just lost standing. Deferred to phase 2; noted, not penalised.
- **Technical:** the hooks are small and pure where they should be. The `ps.dialogue` exemption leans on the client always sending `close`; a modified client could hold a window open to dodge the −3. Low stakes.

SCORE: 8/10
GOALS:
- 1 Ask is a conversation: met - leader offers "ride", non-leader points to Maren, standing "no" with reason, "I gave you my answer." seen in Studio.
- 2 Yes line teaches the job: met - "Walk with us to Kenstow. Keep bandits off the goods. Your share's paid when we get there." (and "to Glenworth" on the home leg).
- 3 Rider is scratch: met - Save.VERSION untouched; belong.test.luau encode test passes; the silent fold proves the ride is not persisted state.
- 4 Riding: met - "Brilo: Oi! Watch it.", guard hp 10; master held about 20 s facing me at 7 tiles, then walked on.
- 5 The pot: met - 7 coin = floor(30·1/4·55/55); boar loot into `carry[1 hide, 2 food]`, coin kept.
- 6 Village hears: met - "Kenstow will hear you rode with us"; v2 0 → 2.25.
- 7 Leaving costs: met (one gap) - clean +2 (24→26), walk-off −3 (26→23) with one line; but a long read ends the ride silently through the fold path.
- 8 Ceilings and purity: met - structure test passes, Gossip 396, Belong pure with tests.
- 9 Nothing regresses: met - npm test, test:luau and lint:luau are clean. Sourcemap diff and part 0 checks not re-run.
PRESERVE (done well, must survive future iterations):
- Payout line in the leader's voice, with pay, hearing and the scarce good in one sentence: it is the moment that makes riding worth it.
- `Belong.legStep` (H10): Studio shows rode 55 of 55, so it is exact after a real natural leg.
- The `Ride.blocks` 3 s line limit: two quick blows gave one line, not spam.
- The non-leader `groupLine(kind, ctx, boss)`: it teaches who to ask without a new UI.
- Lag patience spent only outside the pause (Ride.lua:172): the hold began only after the 120 s pause ended.
FIX (done poorly; why it matters; concretely how to fix):
- A long read ends the ride silently (Ride.lua:150-155): reading the yes window for about 40 s lets the caravan get 30 tiles away and fold (COLLAPSE_RANGE); the rider is dropped with no line and believes they are still riding. -> Count a rider with `ps.dialogue` open as a lagger at their position, so the leader waits up to `WAIT`; or skip `Bands.collapse` while a rider reads; at minimum, when a fold ends a ride, say "The caravan went on without you."
- "1 hides" (Ride.lua:246 uses `Items.def(item).label`, which is plural): reads as a typo on the first loot of a ride. -> Singular for n == 1.
CONSIDER (fine but could change; why; how):
- `rode` stops counting while reading (Ride.lua:154): a rider reading next to the master loses share. -> Still add `step` when reading within NEAR.
- The leader cannot be picked out ("Ask Maren"): four identical hunters. -> Dialogue title "Maren Greenton, squad leader", as the caravan master has.
- The caravan master's flee near Kenstow stalls rides ~30 s with no word. -> Phase 2: a line while busy, or no witness flee for members walking a route.
- "Suit yourself." for a −3 walk-off is too gentle to teach the cost (deferred to phase 2).
UNCERTAIN (could not verify):
- The squad ride end to end, and hide/food carry value paid at the home end (`dir == -1`).
- A late joiner and two riders at once (needs a second player).
- The sourcemap diff and the part 0 checks (squad banking seen in Output: "came home with 12 hide, 15 food").
- The cause of the master's flee near Kenstow (guess: witnessing fights).

## Builder decisions

- **FIX silent end after a long read: done, both halves.** A reader is a lagger at their own distance (the leader
  waits up to `WAIT` for them, within `LEAVE`), and a fold that ends a ride without a leave line now says "They went
  on without you. The ride is over." Not Studio-checked by the builder.
- **FIX "1 hides": done.** The pot line uses the item's name for one (`hide`), the label for more.
- **CONSIDER `rode` while reading: done** (a reader within NEAR still counts the road).
- **CONSIDER leader title for the squad: deferred** to phase 2 (talk); the member line already names them.
- **CONSIDER master's flee stalling a ride: deferred** to phase 2 / phase 3 (`ctx.withGroup`, barks).
