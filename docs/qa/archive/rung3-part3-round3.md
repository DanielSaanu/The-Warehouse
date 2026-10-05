# QA round 3 — rung 3 part 3 (gossip and grudges)

**Score: 7/10** · 2026-10-05 · reviewer: Opus (independent subagent), Studio Play run · branch `refactor/ai-friendly` (after ce441fe)
Danzo asked this round to also list scaling deficits (outside the score) for the coming map/village/NPC expansion.

## Report (verbatim)

SCORE: 7/10

What I ran: `npm test` (fail 0), `npm run lint:luau` (all ok), `node test/luau/run.js` (all ok, including gossip and save), and the world, spawn-view and night-view previews (`exports/world_1.png`, `view_29_70@5x.png`, `view_29_70_night@5x.png`). They look the same as before; no art changed in this PR.

Studio Play, on the real save:
- Boot Output: `[Restore] day 46, 37 living (37 bodies), 3 groups, 1 camps, 3 bags; slept 512 s = 1 days` and `Stifffchoclate is back: You were gone 4 days. (1 lines)`. No errors from game code. The one error line (`AssistantCommand:7`) was my own probe.
- I teleported next to the squad and used `strike e54 30`, so only the squad saw the kill. `gossip` then showed `squad knows ... #3@0`, Kenstow knew nothing, `you: squad -88` (was -56; grudge x1.60), and `v2 -24` unchanged.
- The squad walked home and printed `[Sim] the Kenstow squad came home with 2 hide`. After that: `v2 [Kenstow] knows #3@1` and `v2 -48`, so Kenstow got the news at 1 hop, once.
- The caravan reached Kenstow (its `to` end) and picked up `caravan knows #3@2`. This is the round-2 `villageAt` fix working live.
- The squad turned at its far forest end (pos 83/83, dir 1 → -1). Over 30 s nobody's `knows` changed. That is correct.
- I stopped Play.

GOALS:
- Rumour seeded at the squad moves the village only after contact, once: met. Live: v2 stayed at -24 until the squad came home, then went to -48 with `#3@1`.
- Strength falls exactly `HOP_FADE` per hop: met. gossip.test passes; live, the caravan holds the news at 2 hops.
- A holder never applies a rumour twice, including across eviction and compaction: met. Tests pass; live, there was no second move at v2.
- No witnesses means no rumour, no standing change, no scar: met (tests only). I did not set up an unseen kill live.
- Grudge multiplies the next kill, a gift reduces it, it fades: met. Live: x1.30 then x1.60 on successive hunter kills, and grudge went 0.60 → 0.90 → 0.89.
- Kindness never multiplied: met (tests).
- `catchUp(n)` equals n live seconds: met for the pure path. Partial for materialised groups (see FIX 1).
- Old news leaves the ring at `STALE_DAYS`: met (tests).
- Offline player gets it on return, once: met. Tests pass; live, the return produced exactly 1 welcome line.
- Byte worst case: met (gossip.test byte asserts pass).
- v2 fixture migrates in place: met (save.test passes).
- Migration against the real DataStore: met (the builder's run; this session loaded v4 cleanly).
- Round-2 arrival fix (the village at the end reached): met. Live: Kenstow heard on the walk home, the caravan heard at Kenstow, the forest end told nobody.
- "Someone saw that." before the standing line: met by code (`Sim.lua:428` comes before `Standing.event`). I could not capture the transient notice.
- A human plays it: not met. That box is Danzo's.

PRESERVE:
- Ledger and transport split (`ps.rep` per holder, memory as transport): reputation never heals on eviction, as DESIGN §7 requires.
- `Gossip.arrive(w, g, world)` picks the end by `dir` (`Gossip.lua:322-327`), with the reviewer's probe kept as a test (`gossip.test.luau:380-405`): news now physically travels, and a forest end is silent.
- `Gossip.meet` gated on `floor(now/EVERY)` with sorted ids and buckets (`Gossip.lua:338-366`): live play and catch-up stay deterministic.
- Holder-named announcements (`Standing.lua:26-46`): "The hunters who were there…" and "Kenstow now thinks…" read as two separate events.
- `Debug gossip` output: it made this whole live review possible in 10 minutes.

FIX:
1. **A materialised group can "arrive" with its bodies far away.** This is older code, but part 3 now depends on it.
   - What I saw: after chasing and killing me, the squad leader e52 stayed at 9,55 (the forest end). Meanwhile `g.pos` ran 47 → 1, Kenstow heard, and the hide was deposited, then pos ran 1 → 69 again while `groupPos` still read 9,55.
   - Cause: `Sim.lua:907-910` sets `g.pos = nextI` whenever the leader is not adjacent, even when `pathTo` (200-node budget) returns false.
   - Why it matters: gossip now hands over news at the tile where the group turns. A squad 60 tiles away in the forest told Kenstow. The player can watch bodies standing still while the village "hears", which breaks the very thing the play-test box asks Danzo to watch.
   - Fix: advance `g.pos` only when `pathTo` succeeds. On failure, path to the nearest route tile with a larger budget, or collapse the group if it is off-route by more than N tiles. Also make `Gossip.arrive` refuse when the materialised leader is not inside `villageAt` of that end. Add a Luau or Studio test: chase, then return.
2. **The "came home" headline and deposit fire on the abstract `pos`**, so the same bug lands in the world-news ring. The same fix covers it.

CONSIDER:
- `Gossip.onChange` is a mutable hook on a shared module, set by `Standing.bind` (`Standing.lua:50`). It works, but a pure module calling into server code by side effect is easy to break in tests. Alternative: `tell` returns the moved (uid, holder, before, after) list and Standing announces from that. The adapter then owns the wording, which answers the builder's question.
- `Save.rekeyRep` hard-codes `"v" .. i` (`Save.lua:250`) next to the now single parser `Gossip.villageIndex`. Fine for a frozen migration, but add a comment saying it is pinned to v3's key form on purpose.
- The `Debug group` output shows `groupPos` as the leader's tile while `pos` is the route index. Showing both tiles would have made FIX 1 obvious sooner.

SCALING (deficits when the map/villages/NPCs grow):
- **Ring of 64 rows**, `Gossip.lua:25`, `push` eviction at `:160`. Tuning number. With many villages and NPCs, 64 rows across the whole world evict within minutes, and news dies before it travels. Size it to the event rate, or bucket the ring per region.
- **Linear `find`**, `Gossip.lua:167`. Tuning. O(ring) per lookup. Becomes hot if the ring grows past a few hundred. An id→index map can be rebuilt on load without being saved.
- **`tell` scans `knows`**, `Gossip.lua:246`. Same with `latest` at `:387` and `exchange` at `:297-309`, which is O(knows_a × knows_b) per pair. Tuning. Quadratic once holders know hundreds of rumours.
- **`compact` walks every holder per eviction**, `:142-150`. It calls `Gossip.holders` (`:84-100`), which allocates and sorts every call. Soft limit: O(holders × knows) per eviction, so cost multiplies as holders and the event rate grow.
- **Meet buckets of 2×2 tiles**, `:348`, with all-pairs inside a bucket at `:357-362`. Tuning. Groups crossing on a long road in the same 60 s slot rarely share a 2×2 cell, so they miss each other. Larger buckets mean more pairs. Needs a route-segment or region index.
- **`EVERY = 60` global sweep**, `:28`, `:338-344`. Tuning, but every sweep touches every group. Fine at 3 groups, a cost at hundreds.
- **`villageAt` linear over tribes**, `:311-318`. Soft limit. Called on every arrive. Needs a tile→village lookup from WorldGen.
- **`v<n>` keys = tribe index**, `:42-50`. Hard limit. The key names a tribe index, not a village. Rung 4's several villages per tribe would need re-keying by village id, which is another save migration, and `tribeStanding` (`:133`) changes meaning.
- **One village per tribe in the save**, `Save.lua:140-141` (`villages[i]` built from `tribes[i]`). Hard limit, same as above.
- **Group ids are fixed strings** ("squad", "caravan", "band"), `Bands.lua:85-101`. Hard limit for many groups per tribe. A rebuilt group also inherits the dead crew's rep (already deferred). Needs generated ids plus a generation stamp.
- **`ps.rep` grows per holder**, fallback at `Gossip.lua:117-129`. Soft. Every group the player meets adds a key to the player's save, and nothing prunes rep that has faded back to the village value.
- **`w.owed` per absent player × holder**, `:224-235`, pruned at `:185-190`. Soft limit and the one node that grows with players. Many villages × many returning players stresses the 4 MB world key. The test pins only 32 players (`gossip.test.luau:489-500`).
- **Byte test pinned at 6 holders**, `gossip.test.luau:470-487`. Tuning. Its "does not grow with players" claim holds, but cost grows with holders × ring. Re-run it at the target village and group counts.
- **Catch-up cost**: `Tick.groups` runs `meet` every simulated second (`Tick.lua:150`) and walks every group. Today that is 10 ms for 28 days (tick.test). It grows linearly with groups and quadratically within buckets. Measure it at the target scale.
- **Grudge keyed by tribe type** (`Grudge.lua`). Tuning. Fine now, but with many tribes of one type a scar spreads across unrelated villages.

UNCERTAIN:
- Whether the "Kenstow now thinks of you as …" notice actually appeared on screen when the squad came home. Notices are transient and not in Output, and the HUD scan only caught the death screen.
- The unwitnessed-kill headline and gravestone with a nil killer, live. Only the code and tests were checked.
- Whether FIX 1 also happens without a chase. I saw it right after a chase that ended in my death; normal walking may keep the leader adjacent.
- Two-player edge cases. I tested with one player only.

## Builder decisions

The loop ends at round 3 (the third and last round). Nothing was changed after this report.
- **FIX 1–2 (a materialised group walks its route index while its bodies stay put): open.** This bug is older than
  part 3 and lives in `Sim.lua`'s group walking, not in gossip. It is logged in the summary and the inbox as the next fix.
- **CONSIDER items: deferred.** The `onChange` → returned-list reshape belongs with the fix above. The `rekeyRep`
  comment and the Debug `group` tiles are small cleanups for whoever does that fix.
- **SCALING:** handed to the expansion-notes pass (see `ideas/INBOX.md`, 2026-10-05) as the gossip section's source.
