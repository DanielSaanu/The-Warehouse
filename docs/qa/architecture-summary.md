# The architecture plan review — five rounds, 7 → 9.0

`docs/ARCHITECTURE.md` is the plan for where Lowlands' data lives. It was reviewed by one Opus reviewer per
round, never the builder's own model, against goals taken from Danzo's brief. Danzo raised the bar from 8.0 to
**9.5** after round 2 and capped the loop at **5 rounds**: *"points shouldnt be given for free, i want to make
sure we have this right before we start coding."*

**The loop closed on the cap, not on the target: 9.0.** Verbatim reports and each round's builder decisions are
in `docs/qa/archive/architecture-round1.md` … `-round5.md`.

## Scores

| Round | Score | The round's main finding |
| --- | --- | --- |
| 1 | 7.0 | `os.clock()` timestamps in durable tables — a save blocker invisible from the code |
| 2 | 8.5 | The id counter restarts, so a stale entity id **collides** rather than dangling |
| 3 | 8.5 | The flood can never be lifted after a load — **caused by round 2's own fix** |
| 4 | 8.5 | "Re-apply the calamity" would re-steal 30% of the world's food on every load — **round 3's fix** |
| 5 | 9.0 | The map buffer the client draws is never re-encoded after a load — **client and server silently diverge** |

## The seven save blockers

None of these were visible from reading the code; all seven would have surfaced only after rung 3 part 2 shipped
and somebody restarted a server. **Three were introduced by a previous round's own repair**, which is why every
round from 3 on audited the last round's fixes as suspects rather than as settled.

1. **`os.clock()` in durable tables** (round 1). It restarts near zero on a new server, so every campfire, bag
   and group timer loads as garbage. Fix: every persisted instant is game time.
2. **`Sim.clock()` derives the day from wall time** (round 2). Catch-up had no clock to advance. Fix: an
   accumulator, `meta.gameSeconds`.
3. **`nextId` restarts at 0** (round 2). A stale `"e7"` does not dangle — it **collides with a different new
   object**, which no nil-check can catch. Fix: entity ids are never persisted; counters live in `meta`.
4. **The flood cannot be lifted after a load** (round 3, caused by round 2). `floodBackup` is in memory and
   `floodTiles` skips already-flooded tiles, so the recomputed list differs and `clearFlood` has nothing to
   restore. Fix: an explicit load order, calamity tiles excluded from the map diff.
5. **Numeric table keys come back from JSON as strings** (round 3). `reg.people[p.father]` returns nil and the
   family tree detaches — with no error. Fix: string keys *and* string id values, plus an id-shape assertion the
   round-trip deep-equal cannot fake.
6. **"Re-apply the calamity" re-runs one-time consequences** (round 4, caused by round 3). `startCalamity` also
   sets the end date, takes 30% of every tribe's food, hits population and destroys camps — on every load, every
   two minutes. Fix: split into `applyOverlay` (idempotent) and `beginCalamity` (once).
7. **The client's map is never re-encoded** (round 5). `World.encoded` is built once in `World.init` and shipped
   to every joining player forever, so restored camps and bags exist on the server and on nobody's screen. Fix: a
   fourth load step, and a "what a load hands the client" section. Its twin: `c.flood` is transient state the
   join payload reads, so `applyOverlay` must repopulate it.

## What else was fixed, by round

- **Round 1:** the map is derived from the seed, not stored; a family is a derived index, not a group row; the
  people arithmetic was wrong in the plan's favour (the registry grows at the *death* rate — ~106 real days, not
  the birth rate), so the warning moved to memory-per-holder-per-player, which is where the key actually dies;
  `bind` demoted to plain `require`; the spatial index demoted to demand-driven.
- **Round 2:** the live player record is a projection too (it holds an `Instance` and a function); `init` had no
  restore path, so every boot duplicated the village; group members were anonymous specs re-rolled on every
  materialise; the daily tick moved to `shared/` because `npm test` can only bundle `shared/`; a cross-key
  authority rule for group membership; the memory cap reshaped per (holder, player) with an LRU, ≈242 KB.
- **Round 3:** `meta.savedAt = os.time()`, the one permitted wall-clock read; the full person schema with
  `village` as an id; catch-up needs the *hourly* group tick or caravans never arrive; `shared/Save.lua` moved
  into step 1 because steps 1 and 1b were verified by a serialiser that did not exist yet; the `World.lua` name
  collision; every step named its gate (test / lint / Studio).
- **Round 4:** the 4-week catch-up cap was missing entirely and "becomes `gameSeconds`" read as an assignment
  that wipes the calendar; groups replay at 1 Hz, not hourly lumps (a lump traverses one leg where live ticking
  does eleven); `regions[].live` is transient — persist it and animals never spawn again; `tribes[].village` is a
  live reference compared by **identity**, so after a load no NPC recognises its own home; the group row was
  missing `to`, `fullSize`, `speed`, `pauses`, `lateTarget`; pruning got a real rule.
- **Round 5:** `Ecology.beastTide` sets the tide flags *and* doubles every region's wolves, so the calamity split
  left a one-time effect inside something a load re-runs — the third instance of that pattern; the `villageId`
  site list was five and is twelve, three of them pointer equality; string ids silently change `Families`' sort
  order, which decides pairing, conception and succession; reputation never fades for an absent player.

## Preserved across all five rounds

- **R1 + R5 together** — live objects are projections, stored time is game time, stored links are ids. The whole
  save story rests on them.
- **§6's mechanics of moving code** — move verbatim then rename, watch for bare calls to moved locals, definition
  order is load-bearing. Written from the scars of the `Sides.lua` split.
- **Step 4's ownership proof**: grep for writes outside the owner, expect zero, put the grep in the PR.
- **The escape hatch**, and "steps 1 and 1b are the only ones that are not optional".
- **The demand-driven index** and the ~100-entity reasoning: the 10 Hz think loop is the dominant cost and an
  index does not help it.
- **H9 and the `shared/` testability argument** — the rule that lets the model check its own work without Studio.
- **§5's arithmetic**, re-derived independently by three separate reviewers and correct each time.

## What was deferred, and why

- **`Hud.lua` (1021), `Client.client.lua` (653), `Viewport.lua` (429)** stay over the 400-line ceiling, dated in
  H1 to rung 3 part 5 and rung 4. This plan is about the server tree; opening the client mid-refactor doubles the
  QA surface for no save benefit. They are dated, not exempt.
- **`sizeTier` and `chiefId`** left the v1 schema: no writer exists for either, and chiefs are DESIGN §13, rung 4.
  A field with no writer is a promise the schema cannot keep.
- Nothing else. Every FIX and CONSIDER item from all five rounds is in the document, including what round 5
  classified as polish, because there is no round 6 to carry it.

## The 0.5 that was never closed

Round 5's verdict, verbatim in intent: the remaining gap is *"four short paragraphs, not a re-plan"* — and those
four paragraphs are now written. What is unproven is whether a sixth round would find an eighth blocker. The
evidence cuts both ways: every round has found something real, and the last three found progressively smaller
things (a save blocker in round 3, a food-stealing loop in round 4, a client desync in round 5). **Danzo's call:
another round, or build step 1 and let the code find the rest.** Step 1 is the only truly non-optional step, it
is gated by `npm test` alone, and its own verification — a 28-day pure replay that round-trips through the
serialiser — is the thing most likely to surface an eighth blocker for real rather than on paper.
