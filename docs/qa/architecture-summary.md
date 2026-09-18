# QA summary: the architecture plan

Two rounds, one Opus reviewer each, reviewing a **plan** rather than a build. Target 8.0, hit in round 2.
Verbatim reports: `docs/qa/archive/architecture-round1.md`, `docs/qa/archive/architecture-round2.md`.

## Scores

| Round | Score | Main finding |
| --- | --- | --- |
| 1 | 7/10 | Two save blockers nobody had named: every durable timer uses `os.clock()`, which resets on a new server; and the daily tick only half-completes a birth when nobody is watching, so catch-up would contradict itself. Plus my people-registry arithmetic was wrong in my own favour. |
| 2 | 8.5/10 | A **third** save blocker: the id counter restarts, so stale ids *collide* with new objects rather than dangling — which no nil-check can catch. Plus the clock itself reads wall time, `init` has no restore path, and group members have no stable identity. |

## What the two rounds changed

**Three save blockers, none of which I had seen.** All three would have surfaced only after persistence shipped
and somebody restarted a server:
1. `os.clock()` in every durable timer — campfires out, bags an hour old, groups paused forever.
2. The daily tick completes a birth only if the mother is materialised, so catch-up produces a registry that
   disagrees with the population it explains.
3. `nextId` restarts at 0 while saved records hold entity and bag ids, so a stale id **collides**.

**The plan's own arithmetic was wrong twice, both times in its favour.** People are not the table that breaks the
4 MB key — `MAX_PEOPLE` caps the living, so the registry grows at the death rate (~118 real days). The thing that
breaks it is **gossip memory per holder per player**: 43 holders × every player ever seen ≈ 3.9 MB at 300
players. Fixed with a per-(holder, player) LRU at ≈242 KB.

**Two structural corrections.** A family is not a group — it is a derived index over person fields, and the
entity model refuses dual membership anyway. And the map should not be stored at all: seed plus a byte-packed
diff of runtime changes.

**One pattern I was proud of turned out to be a liability.** `bind(ctx)` — invented to break the cycle when
`Sides` was split out — launders types into `any` and kills go-to-definition, which works directly against the
context-window constraint it was meant to serve. Plain `require` is now the default.

**Two modules deleted rather than added.** `Wildlife` (80 lines) and `Targeting` (150) existed to stay under a
ceiling nothing had hit. Splitting pre-emptively is the same mistake as never splitting.

## What survived both rounds

- **R1 + R5 together** — save records not live objects, store game time not wall time, hold ids not references.
  Both reviewers called this the whole plan.
- **§6's move mechanics** — bare calls to moved locals are nil and silent, definition order is load-bearing,
  move verbatim then rename. Written from the scars of the `Sides`/`Debug` split.
- **Step 4's ownership proof** — grep for writes outside the owner, expect zero, put the grep in the PR body.
  It is what makes "one writer per slice" checkable rather than aspirational.
- **The escape hatch** — steps 0, 1 and 5 ship alone; only step 1 is non-optional.
- **The demand-driven index** — the entity cap is ~100 and the 10 Hz think loop is the real cost, so an index is
  built when a measurement asks for it, not on faith.

## Deferred

Nothing. Every FIX and CONSIDER from both rounds was taken.

## Still unverified

- Neither reviewer ran Studio, so per-tick CPU is reasoned from DESIGN §4's ~100-entity cap, not measured.
- Whether Roblox's 4 MB limit is byte-exact on the serialised JSON string.
- Whether `Sim.clock()` can become an accumulator without disturbing the 10 Hz movement budget — it looks local,
  but not every `now` consumer was traced.
