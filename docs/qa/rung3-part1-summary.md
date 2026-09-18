# QA summary: Rung 3 part 1 (the world answers for itself)

One round, one Opus reviewer, target 8.0. Hit on the first round, so the loop stopped there.
Verbatim report: `docs/qa/archive/rung3-part1-round1.md`.

## Scores

| Round | Score | Main finding |
| --- | --- | --- |
| 1 | 8/10 | All nine goals met or partial, every verdict reproduced live. Three real faults: wolves took sides against their own packmates, fights scattered villages permanently, and the whole feature was silent — legible only as sprites moving. |

## Fixed

- **Wolves attacked wolves.** A wolf feels −70 about a wolf and 0 about a guard, so the rule had it join the
  guard against its own packmate — during a beast tide, which is the exact scenario goal 7 names. Animal
  witnesses are now excluded entirely: animals have no politics, they hunt. A test asserts the *feeling* that
  makes the exclusion necessary, so the reason lives next to the numbers.
- **Villages scattered and never came home.** `flee` was not treated as busy, so every later blow re-armed the
  flight and villagers ended twenty tiles out. Flight is now busy, never re-armed (`math.max`), and a tribed
  villager more than eight tiles from their village walks home with a budget big enough to get there. Verified:
  all four Glenworth villagers back inside the footprint twelve seconds after two consecutive fights.
- **The feature said nothing.** One line per fight, ranked so a louder line can interrupt the cooldown. Verified
  live on the Notice remote: *"They watched. Nobody moved."* in the wary village.
- **And a gap the review did not catch, found while testing that fix:** when a village protects you so well that
  you are never hit, no blow lands, so nothing was said at all. `Sides.tellHelp` fires when an armed local sets
  about someone who was coming for you. Verified: *"Glenworth turns out for you."*
- Predator pile-on capped at two per prey; `baby` no longer sits in `alarm` for 25 seconds.

## Preserved

- **`Witness.lua` as pure comparative logic**, 103 lines, testable outside Studio, with `witness.test.luau`
  encoding Danzo's four cases verbatim. The `ownBrawl` exemption is what lets "family" and "murder" coexist.
- **The Sides/Debug extraction and the `bind(ctx)` pattern**: no require cycle, no globals, lint back under
  Luau's inference budget. Keep the rule that neither module requires Sim.
- **The held-back branch plus the per-tick re-read in `huntStep`** — a guard who turns around mid-charge when he
  sees who the bandit has got hold of is the comparative idea made visible.
- **`Sides.sheltered` as the single sanctuary gate**, replacing three scattered `inVillage` checks.

## Deferred

- **Predation finishes off-screen** (deer speed 1.3 > wolf 1.25, so a chase runs ~20 tiles). The fix is a speed
  or leash change — a rung 2 balance decision, not a QA tail.
- **One armed NPC per village caps goal 7.** The rule is right; the roster is thin. Village headcount belongs
  with size tiers in part 5.
- **A bandit can be pulled off a player by a nearby brawl.** Correct behaviour; worth watching once part 4 lets
  the player ride with a band.

## Open FIX items not acted on

None. All three were taken.

## Still unverified by anyone

- A **"watch" verdict between two NPCs** driven purely by the rule rather than by standing hostility — bandits
  always re-target the player, so only the unit tests cover it.
- **Two players at once.** `witnessed` is per-blow and stateless per entity, so no cross-talk is expected, but
  nobody has run a second client.
- **A player disconnecting mid-fight** while an NPC holds their UserId in `e.alarm`. `sideOf` nils out on a
  missing player, which reads correct, but it was not exercised.
- **Sustained performance** with two players and a full beast tide over minutes; the longest sample was ~40 s.
