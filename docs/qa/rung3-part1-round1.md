# Round 1 — SCORE: 8/10 (target hit, loop ends here)

Reviewer: Opus subagent, 2026-09-18. Studio MCP available and used: Play started, four scripted scenarios driven
through the `Debug` channel, Play stopped. `npm test` green, `npm run lint:luau` exit 0.

## Report (verbatim)

## Evidence base

All tests run: `npm test` green (movement/sim/witness/worldgen); `npm run lint:luau` exits **0** and covers the two new files (`ok roblox/src/server/Sides.lua`, `ok roblox/src/server/Debug.lua`). Live in Studio (place "working on it"), Play started, four scripted scenarios driven through the `Debug` Workspace attribute, then Play stopped. Console after all of it: no warnings, no `[Sim] think` pcall errors — only `[World] seed 1…`, `[Sim] 19 villagers, 3 groups, 36 regions`, and three legitimate deaths.

## Goals, tested one by one

**1. Predation you can watch — met.** Spawned deer e56 @45,70 and wolf e57 @48,70 at night: `t1 wolf … npcTarget:"e56" state:"hunt"` → `t4 deer hp1 state flee` → `t8 no entity e56`. Under the beast tide, `state` deer went **131 → 122** in ~10 s of visible hunting, so the watchable and simulated layers agree (`Sim.lua:594-628` killEntity decrements `r[species]`, `Sim.lua:180` removeEntity decrements `r.live`). Caveat: the chase ran the deer from x=48 to x=70 — 30 tiles from the player — so the kill usually finishes off-screen.

**2. One witness rule replacing the special cases — met.** The hard-coded guard block is gone (`Sim.lua:690-694` is now a comment), and `Sim.lua:948-951` routes every tribed NPC through `Sides.hostileToPlayer`. All four verdicts observed live.

**3. Three inputs — met.** `Witness.feel` reads per-tribe rep, `TRIBE_FEELING`, kin (`Witness.lua:56-64`); `Sides.canFight` (`Sides.lua:36-39`) is what you are; `seerOf`'s `home` via `villageAt` is whose ground.

**4. Four outcomes — met, all four seen.** help_victim: `E1 e1 guard hunt ->e195`. watch: Test B below. flee: `e4 villager flee`. alarm: `C2 e3 villager alarm`, `W2 e5 villager alarm` — and the alarm actually fetches (`Sides.alarmStep`).

**5. Standing is comparative — met, all four named cases reproduced.**
- likes you (rep farmer 45): `t1 e1 guard hunt ->e86`, plus e2/e3/e4/e6/e7 in `alarm`; bandit dead by t5.
- wary (rep −20): guard e1 sat `idle` at 28,66 for all 8 samples while bandit e98 took the player from hp 6 to hp 2 three tiles away. This is the single best piece of evidence in the PR.
- neutral (rep 0) vs someone they hate: `E1 e1 guard hunt ->e195`, bandits killed.
- family (rep 85) then murder: struck villager e3 → `C1 e1 guard chase ->8061215879` → `[Sim] Stifffchoclate died to guard e1`, rest point moved to Kenstow.

**6. Not about the player — partial.** Live, the farmer guard and a spawned hunter both fought the band while the band was busy with a third party, and the "is the village held back?" branch (`Sides.lua:179-183`) fired correctly. But a pure NPC-vs-NPC fight where the *witness rule* (not standing hostility) picks the side is only covered by unit tests (`witness.test.luau:48-51`) — bandits always re-target the player, so I could not isolate it in game.

**7. Villages defend themselves — partial.** Under `calamity beast_tide`, guard e1 *and* hunter e190 both hunted wolves e250/e251 while villager e5 raised the alarm — no longer one guard standing alone. But a farmer village contains exactly one armed NPC (`list guard` → e1, e8, e14, one per village), so "everyone else stands still" is now because they are unarmed, not because of a missing rule.

**8. Nothing regresses — met.** Break points, flight, mercy, conduct rep, `died_to` all intact and exercised (`e86 bandit hp2 idle` after breaking; `strike e3 … beatenBy 8061215879`). Grace-day tutorial untouched.

**9. Sanctuary is grace days only — met.** Day 5, inside Glenworth, `[Sim] Stifffchoclate died to bandit e98`. `Sides.sheltered` (`Sides.lua:162-164`) is the single gate and all three old `inVillage` call sites now use it.

## The three lenses

*Player.* The wary-village test is the moment this PR exists for and it lands: you stand in a square you have soured, a bandit works you down, and a guard three tiles away does nothing. That is a story. The family-murder test lands equally hard. What is missing is words — `Sides.applyVerdict` emits no `Sim.text`, no bubble, nothing; "shout" literally only turns a head. On a phone-shaped viewport a player will read "the guard walked over" and may never connect it to their standing.

*Feel/readability.* Fights now sprawl: a witnessed bandit scattered six villagers 20+ tiles and they were still out at 48,70 and 55,69 forty seconds later, because `flee` is not in the `busy` set (`Sides.lua:144`) so every subsequent blow re-arms `fleeUntil = now + 6`. A player who walks back into the village finds it empty. No client changes, so HUD/night tint/banner are unaffected.

*Technical.* The extraction is clean: no require cycle (Sides/Debug never require Sim, Sim binds them at `Sim.init` before `initTribes`, `Sim.lua:1417-1420`), every bound upvalue is defined above line 1410, lint passes on all five touched files, no runtime warnings. Performance is fine — `villageAt` is a 3-village loop, and `witnessed`'s cheb gate precedes every `seerOf`. `nearestArmedKin` matching on `o.tribe == e.tribe` would make tribeless animals kin to each other, but `playerParty` reads rep 0 for a tribeless seer so alarm is unreachable there.

SCORE: 8/10
GOALS:
- Predation you can watch: met - wolf e57 killed deer e56 in 8 s; tide drove Ecology deer 131→122.
- One witness rule replacing special cases: met - `Sim.lua:690-694` guard block deleted; `Sim.lua:948-951` routes all tribed NPCs through Sides.
- Three inputs: met - `Witness.lua:56-64` + `Sides.lua:36-39,53-59`.
- Four outcomes: met - help_victim/watch/flee/alarm all observed (`C1`, `B1-B8`, `W2`).
- Standing is comparative: met - all four named cases reproduced live, including the guard watching at rep −20.
- Not about the player: partial - the held-back branch fired live, but a rule-driven NPC-vs-NPC side-taking is unit-test-only.
- Villages defend themselves: partial - guard + hunter both answered the tide, but a village has one armed NPC.
- Nothing regresses: met - break/mercy/conduct rep intact, no console warnings.
- Sanctuary is grace days only: met - `[Sim] Stifffchoclate died to bandit e98` inside Glenworth on day 5.

PRESERVE (done well, must survive future iterations):
- `Witness.lua` as pure comparative logic with the OUTRAGE term: it is 103 lines, unit-testable outside Studio, and `witness.test.luau` encodes Danzo's four cases verbatim. The `ownBrawl` exemption (`Witness.lua:74`) is the detail that makes "family" and "murder" coexist.
- Sides/Debug extraction and the `bind(ctx)` pattern: no require cycle, no globals, lint back under budget. Keep the "Debug does not require Sim" rule.
- `Sides.preysOn`'s held-back branch (`Sides.lua:179-183`) plus the per-tick re-read in `huntStep` (`Sim.lua:983-985`) — a guard that turns around mid-charge is exactly the "comparative" idea made visible.
- `Sides.sheltered` as the single sanctuary gate replacing three scattered `inVillage` calls.

FIX (done poorly; why it matters; concretely how to fix):
- Wolves attack wolves: observed `W4: e251 wolf hp6 @29,70 hunt ->e250`. A wolf seer feels −70 about a wolf and 0 about the guard beating it, so `decide` returns help_attacker and the wolf joins the guard against its packmate — during the beast tide, the exact scenario goal 7 names. -> In `Witness.feel` (`Witness.lua:56`), before the animal lookup: `if p.species and w.species and p.species == w.species then return Witness.KIN end`, add `species` to `Seer`, set it in `Sides.seerOf`; or simplest, have `Sides.witnessed` skip `e.species` witnesses entirely (animals have no politics) and let predation stay in `pickNpcTarget`. Add a test case.
- Villages permanently scatter: `flee` is absent from `busy` in `Sides.witnessed` (`Sides.lua:144`), so every landing blow re-extends `fleeUntil`; e4/e5/e6 ended 20 tiles out and were still there 40 s later, and `wanderStep`'s `pathTo(…, 120)` is too short to walk them home. -> Add `or e.state == "flee"` to `busy`, and in `applyVerdict`'s flee branch use `e.fleeUntil = math.max(e.fleeUntil or 0, now + 6)` rather than an unconditional reset; consider a "go home" step for a tribed villager more than `radius + 4` from its village.
- The feature is silent: `applyVerdict` never speaks, and "shout" is a verdict with no shout. The whole PR is legible only as sprite movement, and DESIGN.md §7 is about the player understanding their standing. -> One `Sim.text` per verdict when the player is a party: "Glenworth turns out for you." / "They saw you. Nobody moved." / "Someone is running for the guard." Route "shout" through the same line so the name means something.

CONSIDER (fine but could change; why; how):
- Predation finishes off-screen: deer speed 1.3 > wolf 1.25, so the kill ran 22 tiles from where it started. -> Shorten `huntStep`'s leash for animals from 8 to ~5, or drop deer speed to 1.2 so the kill happens near the player who is watching.
- Goal 7 is capped by one armed NPC per village: the rule is right, the roster is thin. -> A second guard, or let `canFight` include an adult villager holding a tool during an active calamity.
- Predator pile-on: `W6` had four wolves all `hunt ->e218`, one deer. `pickNpcTarget` has no equivalent of `WITNESS_JOIN`. -> Skip prey already targeted by 2+ predators.
- `Sides.canFight` includes `bandit`, so a lone bandit witnessing a fight takes a side — correct, but it means a bandit can be pulled off a player by a nearby brawl. Worth watching once part 4 lands.
- `baby` gets flee/alarm verdicts with speed 0; `followPath` guards it (`Sim.lua:244`) so it just sits in `alarm` for 25 s. Cheap to exclude in `applyVerdict`.

UNCERTAIN (could not verify):
- A "watch" verdict driven purely by the rule between two NPCs (no player party) — bandits always re-target the player, so I only have the unit tests for it.
- Two players at once: `witnessed` is per-blow and stateless per entity, so I expect no cross-talk, but I could not test a second client.
- A player leaving mid-fight while an NPC holds `e.alarm.att = { u = UserId }`: `sideOf` nils out on a missing `S.players[uid]` (`Sides.lua:74-77`), which reads correct, but I did not exercise a disconnect.
- Sustained performance with two players and a full tide over minutes — my longest sample was ~40 s.

## Builder decisions

The score hit 8.0, so the loop ends after this round. All three FIX items were acted on first, as the procedure requires, plus two of the five CONSIDER items.

**FIX — all three taken.**

- **Wolves attack wolves — taken, and it was a genuine bug.** A wolf feels −70 about a wolf and 0 about the guard
  beating it, so the rule had it side with the guard against its own packmate, during a beast tide. Took the
  reviewer's simplest option: `Sides.witnessed` now skips animal witnesses entirely, because animals have no
  politics — they hunt, via `pickNpcTarget`. `witness.test.luau` gains a case that asserts the *feeling* that
  makes this necessary, so the reason is recorded next to the numbers rather than only in a commit message.
- **Villages permanently scatter — taken.** `flee` is now in the `busy` set, the flee branch uses
  `math.max(e.fleeUntil or 0, now + 6)` so a flight already running is never re-armed, and `wanderStep` walks a
  tribed villager home with a 500-node budget when they are more than 8 tiles from their village centre. Verified
  live: after two consecutive fights in Glenworth, all four of its villagers were back inside the footprint
  (27,74 / 31,68 / 32,74 / 24,75) twelve seconds later.
- **The feature is silent — taken, and it needed more than the reviewer asked for.** One line per fight rather
  than per witness, with a rank so a louder line can interrupt the cooldown (a villager shouting on the first
  blow must not swallow "the guard came"). Verified live on the Notice remote: the wary village produces
  *"They watched. Nobody moved."*
  Testing it then exposed a gap the review had not: when a village protects you *so well that you are never hit*,
  no blow lands on you, so nothing was said at all. `Sides.tellHelp`, called from `pickNpcTarget` when an armed
  local sets about someone who was coming for you, closes it — verified live: *"Glenworth turns out for you."*

**CONSIDER — two taken, three deferred.**

- Predator pile-on → **taken**: `pickNpcTarget` skips prey already targeted by two or more predators.
- `baby` stuck in `alarm` for 25 s → **taken**, excluded in the same `busy` set as animals.
- Predation finishing off-screen → **deferred**. The fix is a speed or leash change, which is a balance decision
  touching rung 2 numbers; worth doing deliberately rather than as a QA tail.
- A second armed NPC per village → **deferred**. Goal 7's rule is right and the roster is what limits it; village
  size tiers are rung 3 part 5, and that is where a village's headcount should be decided.
- A bandit being pulled off a player by a nearby brawl → **deferred**, and the reviewer agrees it is correct
  behaviour. Worth watching once part 4 lands.
