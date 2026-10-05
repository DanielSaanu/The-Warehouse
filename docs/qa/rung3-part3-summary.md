# QA summary: rung 3 part 3, gossip and grudges

Goals: `docs/qa/rung3-part3.md`. Gossip landed on `rung3-part3-gossip` (43e7b10) and was reviewed on
`refactor/ai-friendly`, which contains it. The target was **8.0** in at most three rounds, with one Opus reviewer per
round, each with Studio. Fixes between rounds went to the heavy agent (handoffs H3, H5), because they touch
`shared/` and the save format. All three rounds ran, and the target was **not** reached. The verbatim reports are
in `docs/qa/archive/`.

| Round | Score | The round's main finding |
| --- | --- | --- |
| 1 | 6 / 10 | Five real defects hidden by test fixtures: the v2→v3 rekey reset every player's rep, groups "met" by route index across the map, deer kills became rumours, one shared hop count, and logging off laundered a kill. |
| 2 | 7 / 10 | All five fixes confirmed live, and a v3 world migrated to v4 in real Studio. New bug: an arriving group told its OWN village at both ends of its route. |
| 3 | 7 / 10 | News now walks home, live: the squad told Kenstow only when it came back (`#3@1`) and the caravan heard at Kenstow (`@2`). The bug left is older code: a group chasing the player stays put while its route index keeps walking, so it can "arrive" 60 tiles from its bodies. |

## What was fixed

**After round 1** (H3, f4b3cf7, save v3 → v4)
- `rekey`: a v2 tribe value now wins unless the saved record already had that holder key. The test seeds from `newRep()`, as the real join does (→ Q2).
- `meet` buckets by the map tile (2×2 cells), not by route index, and skips materialised groups.
- `seed` makes no rumour when the victim has no tribe or nobody's number would move. Deer are out of the ring.
- Hops are stored per holder beside `knows` (→ S4). The eyewitnesses stay at 0 hops and stay sure.
- Standing is applied at tell time. An offline player's share goes into a world ledger `w.owed` and is paid silently on join. `ps.heard` is gone (→ S5).
- The `Gossip.quiet` module flag became a parameter. Grudge was split out to `shared/Grudge.lua` to stay under 400 lines.

**After round 2** (H5, ce441fe, no format change)
- `arrive(w, g, world)` exchanges with the village at the end the group reached, or with nobody (→ Q3). Six fixtures that only passed because of the bug now walk the squad home.
- The `owe` sums are clamped to ±(MAX − MIN). "Someone/Nobody saw that." comes before the standing line. One `villageIndex` parser. `rekey` moved to `Save.rekeyRep`.

## What was preserved (confirmed in every round)
- Memory is the transport, rep is the ledger: reputation never heals when the ring evicts (DESIGN §7).
- The standing fallback chain: `ps.rep` holds only keys that diverged.
- Rumours store the event, and deltas are recomputed when applied.
- The worst case asserted in bytes.
- `PLAYER_VERSION` held at 1.
- The `Someone saw that.` / `Nobody saw that.` lines and the holder-named announcements.
- `meet` is deterministic under catch-up.
- Each new test is confirmed to fail when its bug is put back.

## Deferred
- A rebuilt group inherits the dead crew's `ps.rep[id]`. The fix needs a group generation stamp; part 4.
- An id→row index for `Gossip.find`. Cheap at a ring of 64; see Scaling.
- A lone tribe member not in a group counts as their whole village. Recorded as a known limit in RUNG3; part 4.
- The online and offline owed totals can differ slightly over a long, mixed absence. Recorded in RUNG3.

## Open after round 3 (the loop ended before these) — landed 2026-10-05 (heavy, H6)
- **FIXED: a materialised group walked its route index while its bodies stood still.** The leader's route rule moved
  out of `Sim.lua` into `Tick.leaderStep` (pure). `pos` advances only on a path that was found or a step taken; the
  end turns only when the leader is within one tile of it (a long path to the last tile used to turn at once);
  pulled off the road, `pos` re-anchors to the nearest route tile and the leader paths there with an 800-node budget;
  after `Tick.LOST_TRIES` (5) failures it returns "lost" and Sim collapses the group (it re-materialises on the road
  if a player is still near). `Gossip.arrive` also refuses when a materialised leader is not inside that village
  (`Bands.turn` passes the leader's tile). Test: chase-then-return and walled-in cases in `gossip.test.luau`, each
  confirmed to fail with its fix removed. Still unknown: whether it happened without a chase (the rule now holds
  either way). Not checked in Studio.
- CONSIDER:
  - Done: `Save.rekeyRep`'s `"v"..i` carries a comment that it is pinned to the v3 form on purpose.
  - Done: Debug `group` prints the leader tile and `(route x,y)`.
  - Deferred: `tell` returning the moved list so Standing owns the wording. `onChange` works and is not a bug; the
    change touches every `tell` caller, so it waits for the next pass over gossip rather than the PR.

## Scaling deficits (round 3, for the map/village/NPC expansion; not scored)
The list keeps its file:line references so the expansion pass can use it without opening the archive.
- **Hard limits:**
  - `v<n>` keys name a tribe index, not a village (`Gossip.lua:42-50`), and the save builds one village per tribe
    (`Save.lua:140-141`). Several villages per tribe means re-keying by village id, which is a save migration.
  - Group ids are fixed strings (`Bands.lua:85-101`).
- **Soft limits:**
  - `compact` walks and sorts every holder on every eviction (`:142-150`, `:84-100`).
  - `villageAt` is linear over tribes (`:311-318`). It needs a tile→village lookup.
  - `ps.rep` gains a key per group met and is never pruned (`:117-129`).
  - `w.owed` grows with absent players × holders (`:224-235`). The test pins 32 players.
- **Tuning:**
  - The ring of 64 (`:25`) evicts within minutes at scale. Size it to the event rate, or keep one ring per region.
  - The linear `find` (`:167`) and the `knows` scans in `tell`/`latest`/`exchange` (`:246`, `:387`, `:297-309`) are
    quadratic per pair.
  - The 2×2 meet buckets (`:348`) miss groups crossing on long roads. That needs a road-segment index.
  - The 60 s sweep touches every group (`:338-344`).
  - The byte test is pinned at 6 holders.
  - The catch-up `meet` runs every simulated second (`Tick.lua:150`).
  - Grudge is keyed by tribe type (`Grudge.lua`).

## Danzo's play-test checklist
Dev mode: your world is disposable, so use the Debug commands freely (`gossip` shows who knows what, `#id@hops`).
1. **One witness:** kill a hunter where only the squad sees it. You should get "Someone saw that.", then a line
   about the hunters who were there. `gossip` shows the squad knows it at `@0` and Kenstow doesn't know it yet.
2. **News walks home:** follow the squad. Kenstow should change (and tell you) only when the squad gets back. At that point
   `gossip` shows `v2 knows #n@1`. Later the caravan picks it up at Kenstow at `@2`, weaker.
3. **Watch for the open bug:** if the squad chased you first, check that its bodies actually walk home before Kenstow
   hears. If Kenstow hears while the squad is still standing in the forest, that's the open FIX above.
4. **Nobody saw:** kill one far from anyone. You should see "Nobody saw that." and nothing else changes, not even the headline.
5. **Grudge:** kill a second hunter. It should cost visibly more (x1.30, then x1.60).
6. **Leave and rejoin** after a witnessed kill. You should see one welcome line, not a flood, and your standing should already include the news.
