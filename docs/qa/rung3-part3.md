# QA goals: rung 3 part 3 — gossip and grudges

**Created:** 2026-09-23 · **Branch:** `rung3-part3-gossip` · **Builder:** Claude (routine session)
**Design:** handoff H1, resolved by a heavy Opus session — `docs/handoffs.md`, spec in `docs/RUNG3.md` §Part 3

## What this PR is

Reputation used to be instant and global: hit a hunter and every hunter in the world knew at once. Part 3 makes
information **travel**. The one decision behind everything below (H1): **memory is the transport, reputation and
grudge are the ledger.** Memory has to be capped, so a reputation *derived* from it would heal when the cap evicted
— the opposite of DESIGN §7's "they remember everything at once". So `ps.rep` is still the stored number; what
changed is its **key**, from tribe type to **holder** — a village (`v1`..`v3`) or a group (its id).

## What landed

- **`shared/Gossip.lua`** (new, pure, 380 lines): holder keys, the standing fallback chain, the rumour ring and its
  compaction, the two contact rules, grudge gain / amends / fade, the offline replay.
- **`server/Standing.lua`** (new, 195 lines): the adapter. `Sim.applyRep` **moved** here rather than growing in Sim.
- `ps.rep` re-keyed across `Sim` (12 `Standing.` calls), `Interact` (15), `Restore` (3), `Sides` (1), `Debug` (1)
  and `State` (one function pointer, so `State` never requires `Standing`). New test: `test/luau/gossip.test.luau`, 274 lines.
- **`Save.VERSION` 2 → 3** with the first real in-place migration. `PLAYER_VERSION` stays 1 on purpose.
- Two new world nodes: `villages[]` (its own tier — rung 4 gives a tribe several) and `rumours[]` (the ring).
- `shared/Witness.lua` unchanged, as the design predicted: `Party.rep` was always "what this witness holds".
- Debug `gossip` command; `Talk.Context.heard` as a second channel beside `familyNews`.

## Reviewer: start here

1. **`Gossip.tell` is the only place a holder's opinion moves**, and appending to `knows` *is* applying the rumour.
   Is that actually airtight? The offline path is the risk: a rumour that reaches a village while the player is
   logged off must be applied when they return, **once per holder**. That is `ps.heard[holderKey][id]`, replayed by
   `Gossip.catchUpPlayer`. I got this wrong first time — my initial `ps.heard[id]` deduped per *player*, so a rumour
   known in two villages moved only one number. Look hard for a case the per-holder set still misses.
2. **Determinism.** `Gossip.meet` is gated on `math.floor(now / EVERY)`, so live play and `catchUp(n)` must produce
   the identical sequence. `gossip.test.luau` asserts that over 400 s across 10 keys. Is the *arrival* channel
   (`Tick.groupTurn`) equally deterministic under catch-up?
3. **The migration.** `Save.migrate`'s v2 step, and `Standing.rekey` for the player key. A v2 world must come back
   whole. Is there a path where `rekey` runs twice, or where a v2 `rep` key survives and is read as a holder?
4. **`Sides.witnessed` no longer `break`s early.** The join cap now gates the verdict instead of the loop, because
   holder collection has to see every witness including the ones already fleeing. Confirm at most
   `WITNESS_JOIN` still pile in, and that the extra iterations cost nothing that matters.
5. **Unwitnessed kills.** `killEntity` passes **no killer name** to `Families.die` when `e.seenBy` is empty, so the
   headline reads "was killed" with no "by". Check the gravestone, the welcome text and `Headlines.describe` all
   survive a nil killer.

## Known gaps, stated before review

- **Studio-tested, but not play-tested.** The server boots, and **Danzo's real saved world migrated v2 -> v3 in
  place** (day 13, 30 living, 3 groups, 1 camp, 3 bags, the welcome line, no errors). The gossip path ran under real
  Roblox: a kill seen only by a squad moved the squad and not their village, and moved the village by exactly
  `HOP_FADE` once they walked home; the scar multiplied the second killing; a returning player got no line spam.
  What has NOT happened is a human playing it - the last box below.
- **The Studio pass found a bug the pure tests could not**: gossip moved the number without ever telling the player,
  because `Gossip.apply` had no announcement (only `Standing.apply` did). Fixed with the `Gossip.onChange` hook,
  which also refreshes the HUD, and is silenced during `catchUpPlayer` so a returning player reads the welcome
  instead of forty lines. Recorded as learnings Q1. **Worth a reviewer's eye: is the hook the right shape, or should
  the announcement be the adapter's job entirely?**
- **`Gossip.find` is a linear scan of the ring** (64 rows) and `tell` scans `knows`. Fine at these sizes, and the
  byte test pins the sizes; a map would be faster and unsaveable, which is why it is a scan.
- **"The village knows, the tribe does not" is not observable yet.** Village ↔ tribe type is 1:1 until rung 4.
- **`GRUDGE_GROUP` is dormant** until part 4 passes `ctx.withGroup`.
- The tuning numbers (`HOP_FADE` 0.75, `STALE_DAYS` 14, `EVERY` 60, grudge gains) are first guesses from the spec.

## Done when (from the spec)

- [x] a rumour seeded at the squad does not move the hunter village's number, and does after one contact — once
- [x] strength falls with hops (exactly `HOP_FADE` per hop)
- [x] a holder never applies a rumour twice, including across a ring eviction and compaction
- [x] no witnesses → no rumour, no standing change, no scar
- [x] grudge multiplies the next kill, a gift reduces it, it halves in `GRUDGE_FADE_DAYS`
- [x] kindness is never multiplied by a grudge
- [x] `catchUp(n)` equals n live seconds including every exchange
- [x] old news leaves the ring at `STALE_DAYS` and every holder forgets it
- [x] a player offline when the news arrived gets it on return, once, and the replay is idempotent
- [x] the worst case asserted **in bytes** (7.7 KB over 5 holders with the ring full and everyone knowing everything)
- [x] `save.test.luau`: a v2 fixture migrates in place, loses nothing, and re-checks JSON-safe as v3
- [x] the migration, against the real DataStore: a v2 world loaded, upgraded in place and lost nothing
- [ ] **A human plays it** (Danzo): kill a hunter where exactly one person sees it, walk away, watch the news reach their village
      over the next in-game day — and the far tribe later, weaker. Kill one where nobody sees it and watch nothing
      happen, to you or to the headline. Then do it again and watch the grudge make the second one cost far more.
