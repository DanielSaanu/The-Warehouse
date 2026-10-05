# Architecture §10–§11: where the build departed, and rung 3 part 3

Part of [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), which maps every § and rule ID to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of ARCHITECTURE.md, wherever it now lives.

## 10. Where the build departed from the plan (Track A, 2026-09-18)

Written after building it, because a plan that is not corrected by its own implementation becomes fiction.

1. **R1's `ps.save` sub-table became a whitelist.** `inv`, `rep`, `goalStage` are read at ~100 sites across four
   `--!nonstrict` files; moving them under `ps.save` would have been a hundred chances at a silent nil. Instead
   `Save.encodePlayer` copies **named fields**, and `Save.encode` does the same for every node of the world — so
   nothing is saved by accident, and "what is durable" is one list per node in `shared/Save.lua`.
2. **`Calendar.now()` is continuous, not tick-fed.** It folds `os.clock()` deltas into `gameSeconds` on every call,
   so attack cooldowns keep their resolution and there is exactly one sim-side wall-clock read.
3. **The calendar only moves forward.** With absolute timers, a backwards `Debug day` would leave every NPC's next
   thought hours in the future. `setDay` refuses the past; `skipTo(frac)` means "the next time it is that hour".
4. **The `os.clock` rule and the line ceiling live in `test/structure.test.js`**, not in the Luau linter: `npm test`
   runs everywhere, the linter needs a gitignored binary. The ceiling is a ratchet — each allow-listed file has its
   own limit that may only shrink — and it stopped this build twice, which is what it is for.
5. **`server/Restore.lua` exists.** The restore constructor needs Sim's innards and Sim was at its ceiling, so it is
   a bound module like `Sides` and `Debug`. `Sim.init(saved, slept)` runs exactly one constructor.
6. **The lease contends instead of forbidding.** A server that finds a live lease plays without saving, and takes
   over when the lease runs out — so a crash costs at most `LEASE_SECONDS` of not saving, where the plan's version
   would have left a quick-restarted server NO-SAVE for its whole life.
7. **`children[]` is not saved** (derived from `father`/`mother`, R4) and is rebuilt by `decode`.
8. **Catch-up at the cap costs 3 ms**, measured in `tick.test.luau`. No slicing needed.
9. **`headlines[]` was carried by the format with no writer; it has one now** (`shared/Headlines.lua`, branch
   `headlines`): births from the pure tick, deaths and calamities from Sim, read once on join.

---

## 11. Rung 3 part 3: gossip, and what it does to this document (decided 2026-09-23)

Written by the heavy session for handoff H1. The full spec is `docs/RUNG3.md` §"Part 3 — Gossip and grudges";
only what is *architectural* is here, so this document stays the one place the shape of the data is stated.

1. **Reputation stays stored, and is re-keyed from tribe type to holder.** A "holder" is a village or a group —
   the two things that can know something and can meet each other. `ps.rep` is keyed `"v1".."v3"` (villages) and
   by group id, sparse, with a fallback chain holder → its village → `Reputation.START[tribeType]`. It is **not**
   derived from memory: memory is capped, and a reputation recomputed from capped memory heals when the cap
   evicts, which is the opposite of what DESIGN §7 asks for. **Memory is the transport; rep and grudge are the
   ledger.** The read path therefore stays one table lookup per read — no scan, no cache.
2. **Three new nodes, and their tier** (§2's tree is updated): `rumours[]` at the world (a ring: it is news in
   flight, true of nobody in particular), `knows[]` on each **village** row and each **group** row. Village memory
   is on `villages[]`, *not* on the tribe row, because §8.4 settles that villages are their own tier — "what this
   village heard" is not true of the whole tribe. This is the first writer `villages[]` has ever had, which §2
   reserved for exactly this.
3. **A rumour stores the event, not its consequences** (R4): `Reputation.deltas` is re-derived at the moment the
   rumour is applied, so a saved rumour can never disagree with the rule, and the row is smaller.
4. **`knows[]` is both the memory and the dedupe set.** Appending a rumour id *is* applying it, so double-booking
   is impossible by construction rather than by a flag.
5. **Nothing decays by ticking, and this is now a rule (learnings P2).** Grudge "decays over years" while catch-up
   caps at four in-game weeks; there is no conflict because decay is a **closed form over a day count**, the way
   `Reputation.fade(v, days)` already is at `Restore.player`. Every span is in **in-game days**, and a world
   nobody plays does not age.
6. **Gossip spreads during catch-up, on a schedule derived from `gameSeconds`.** This does **not** reopen §9's
   "one stated granularity": *movement* stays 1 Hz. Contact is evaluated when `math.floor(now / Gossip.EVERY)`
   increments, which is a pure function of game time, so n live seconds and `catchUp(n)` produce the identical
   sequence of exchanges — and A2's existing invariant test is extended to assert it.
7. **The save step is the first in-place migration**: world `VERSION` 2 → 3, adding empty nodes, losing nothing,
   resetting no world. `WorldGen.GEN_VERSION` is **not** touched (bumping it discards the world). The **player**
   key does **not** bump: `Save.applyPlayer` discards the whole record on a version mismatch, so player-key changes
   must always be additive-optional (learnings P1).
8. **R2 is unchanged and pre-satisfied**: `Standing` was already named the owner of "memory on villages and
   groups, player `rep`, `grudges`". Part 3 builds `server/Standing.lua` and moves `Sim`'s `applyRep` into it,
   which is B3's first step arriving early — and it is not optional, because `Sim.lua` is 1282 lines against a
   1285 ratchet that may only shrink.

**None of §9's six decisions is touched.** Item 6 above is the only one that even brushes against the §9 rider on
granularity, and it is compatible for the reason given there.
