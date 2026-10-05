# QA goals: rung 3 part 4, phase 0 (make room in Sim)

Branch: `dev`. Plan: [`docs/plans/rung3-part4-belonging.md`](../plans/rung3-part4-belonging.md) "Phase 0". Danzo
un-parked this one slice of Track B on 2026-10-05 (H7 Q4); B2, B3 and B4 stay parked. Review the phase 0 commit's
diff only (`git show <commit>`), with `Sim.lua` and `Bands.lua` as they stand after it.

The question for this loop: **is it a pure move?** Nothing a player can see should change. Part 4 phase 1 builds
its hooks into the room this makes, so a behaviour change smuggled in here would be blamed on phase 1 later.

## Goals

1. **A verbatim move, two blocks.** `killEntity` (`Sim.lua`) loses its two group halves to `Bands.lua`:
   - what an NPC's kill adds to its group: the loot into `g.carry`, and a laden squad turning for home
     (`Config.SQUAD_LOAD`). The `fedUntil` line stays in Sim: it is about the killer, not the group;
   - what a death does to the dead member's group: the member row removed, `replenishAt`, and the band breaking at
     more than half lost (`BAND_RETREAT`, the remaining bandits going idle, the server log line).
   The moved lines are identical apart from indentation and the function wrapper. Each call happens at the same
   point in `killEntity` as before, so `rng` is drawn in the same order (`Combat.loot`) and a seeded replay matches.
2. **Bands is the only writer of `groups{}`** (ARCHITECTURE R2's owner table). Proof: grep `server/` for writes to
   a group row (`g.carry`, `g.members`, `g.replenishAt`, `g.retreatUntil`, `g.dir`, `g.pauseUntil`) outside
   `Bands.lua` and the pure `shared/Tick.lua`, and list what remains with a reason (for example `groupStep`, which is
   B2's and stays in Sim). Put the grep and its output in the commit message.
3. **Room for phase 1.** `Sim.lua` gets at least 25 lines shorter than its 1255 ceiling. The plan needs about four
   short hooks in Sim (rider kill loot to the pot, `ctx.withGroup`, the blocked blow, the leader's wait).
4. **The instance tree is unchanged** (learnings G2). No file is added, moved or renamed, so the before and after
   sourcemaps match in names, classNames and nesting. `rojo build` succeeds.
5. **Nothing regresses.** `npm test` (including `test/structure.test.js`'s ceilings), `npm run lint:luau` and
   `npm run test:luau` pass with no new errors or warnings.
6. **Studio regression** (the B2 gate, written down once): with DevMode on (nothing saves),
   - a band that loses more than half runs for home, and the log says "the band has broken off";
   - a squad that kills 8 animals' worth turns for home and banks hides and meat in Kenstow's stock;
   - a dead member is gone from `group <id>` and is replaced by somebody new after a day (`day`);
   - no new line in the Output window.

## Out of scope (do not penalise absence)

Everything in part 4 phases 1–4: riders, the ask, pay, barks. The rest of Track B (`groupStep` and the rest of
`Brains`, `Bodies`, `Fighting`, B3, B4). Art.

## Known limitations going in

- `groupStep` still writes `g.target`, `g.aggroUntil` and `g.leader` from Sim. It is a group's brain (B2), not
  "what a fight does to a group", and the plan leaves it parked.
- `hitEntity` still sets `g.target` when a player strikes a member (`Sim.lua`, the aggro line). Same reason.
- The ceiling in `test/structure.test.js`: the ratchet may only shrink. If it is lowered to the new line count,
  phase 1 has no room again. The builder's note in the commit says what was chosen and why.

## Useful Debug commands

`group squad|band|caravan`, `summon <group>`, `strike <entityId> [dmg]`, `day`, `teleport x y`, `state`.
