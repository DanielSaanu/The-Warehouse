# Architecture §7–§9: costs, settled questions, the six decisions of 2026-09-18

Part of [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), which maps every § and rule ID to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of ARCHITECTURE.md, wherever it now lives.

## 7. What this costs, and what could go wrong

- **A lot of moving with no new gameplay** — which is why Track A is ordered so part 2 arrives at its end, and
  Track B is optional.
- **Over-abstraction.** The honest risk is building a framework for three villages. R3 is the lightest thing that
  fixes the real problem; if a rule is not paying, drop it.
- **The save format is a commitment.** `meta.version` + `Save.migrate` exist from the first save, with a test per
  migration.
- **A2 changes behaviour on purpose** (births complete unobserved; `jump` expires timers). Those are the only two
  intended behaviour changes in Track A; anything else that changes is a bug.

---

## 8. Settled questions (do not re-litigate without new evidence)

1. One tree, `people` a versioned sub-table that can be lifted into its own key later; players in their own keys.
2. Named owners, not queued intents. 3. A family is a derived index, not a group.
4. Villages are their own tier keyed by id (rung 4 gives a tribe several; `MAX_PEOPLE` is per *tribe* today and
   must become per village then).
5. Entity budget ~100; the index is demand-driven.
6. Catch-up records a **world-level headline ring** (`meta.headlines[]` of `{day, kind, subjectId}`, 64 entries
   ≈ 2.5 KB), not per-player diffs; the join line is built from headlines newer than `lastSeenDay`.
7. DataStore is not denser than JSON; budget in JSON bytes.
8. "Capped at 4 weeks" is in-game weeks.
9. `groups[].route` is derived; the accepted risk is that a `WorldGen.route` change snaps a loading caravan to
   the nearest point on its new road — and `genVersion` now makes even that a non-event.

---

## 9. What the second reader changed (2026-09-18), and why

Five review rounds by one model family converged on a document that a different model, reading it cold, changed
in six places. Each is a decision reversed or a gap filled, not a rewording:

1. **Ids stay numeric; `Save` writes arrays of rows.** The round-4 fix (stringify every id) solved a
   serialisation problem by changing the in-memory model, and round 5 then found two silent bugs it caused. The
   problem is only at the JSON boundary, so the fix belongs only there.
2. **`mapDiff` is deleted.** All eight runtime map writes are stamps of `camps`/`bags` rows — the diff was stored
   derived data (R4) with two places to get out of sync. Rounds 2–4 spent three fixes on a node that should not
   exist. If rung 4 adds real terrain edits, that is when it earns a node.
3. **One clock.** "Instants are day-plus-fraction, durations are remaining-seconds-rehydrated" was two conventions
   and a load-time fix-up where one absolute `gameSeconds` needs neither.
4. **Tracks A and B.** The old escape hatch said steps 2–4 were optional while the calamity split and `g.to`
   lived in step 2, and `villageId`, `ps.save` and the bag counter had no step at all.
5. **Persistence has a failure policy and a boot order with a door.** Never write a key you failed to read; one
   server holds the lease; players wait for `ready`. None of the five rounds asked what happens when `GetAsync`
   fails or a player joins mid-load.
6. **`genVersion`.** Round 1 removed the stored map because a generator change would corrupt it; deriving the map
   from the seed has the mirror problem, and nothing guarded it.

Also: catch-up has one stated granularity (the draft said "hourly" in one place and "1 Hz" in two); the
`observed`-flag test, which tested a flag the pure tick does not have, is replaced by record invariants;
`regions[].tide` and `meta.nextPersonId` were each stored twice; `Persistence` no longer "owns" fields that
`generate` writes.
