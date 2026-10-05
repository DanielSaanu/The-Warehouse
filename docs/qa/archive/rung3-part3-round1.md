# QA round 1 — rung 3 part 3 (gossip and grudges)

**Score: 6/10** · 2026-10-05 · reviewer: Opus (independent subagent), Studio Play run · branch `refactor/ai-friendly` (contains 43e7b10)

## Report (verbatim)

SCORE: 6/10

The core decision is sound and well written up: memory carries the news, `ps.rep` and grudge keep the score. The pure tests are strong. But I found five real defects, and four of them hit what a player actually sees. One has probably already reset Danzo's real player reputation. None of the goal's own tests catch them, because those tests build their fixtures in ways that hide the bugs.

**What I ran and saw**
- `npm test`: fail 0. Gossip prints "worst case is 7691 B over 5 holders".
- `lint:luau`: everything ok.
- Studio Play: Output was clean. `[Persistence] loaded the world: saved 543 s ago`, `[Restore] day 43, 37 living ... 3 groups, 1 camps, 0 bags`, `[Server] Stifffchoclate is back: You were gone a day.` No errors. I stopped Play afterwards.
- I could not see live gossip state. A `require` from `execute_luau` gets its own module cache (`onChange bound: false`).
- `view_29_70@5x.png` renders fine. No art changed in this PR.
- I wrote a scratch Luau script (bundled with `test/luau/run.js` against the shared modules) to test the five suspected bugs below. Its results are P1–P5.

GOALS:
- Squad-only rumour, village moves after one contact, once: met - `gossip.test.luau` lines 56-72. But the "contact" between groups is broken, see `meet` below.
- Strength falls exactly HOP_FADE per hop: partial - `r.hops` is a single counter on the shared rumour row (Gossip.lua:296). P2: squad sees it, it goes squad→v2→v1, then squad→band, and the band books it at hops 3 although it is one hand from the eyewitnesses.
- Never applied twice per holder, including eviction and compaction: met - per-holder `ps.heard[holderKey]` (Gossip.lua:231-233), and compaction scrubs `knows`.
- Offline player gets it on return, once: partial - P3: if the rumour goes stale (`STALE_DAYS` 14 = 140 real minutes) or is evicted before the player returns, the village has it in `knows` but it is never applied (standing 0 → 0). Logging off launders the kill.
- catchUp(n) == n live seconds: met for `meet` (Tick.lua:141). `arrive` runs through `Tick.groupTurn`, which both the live path (Bands.lua:137) and catch-up share, so it should match too; I did not test it.
- Migration v2→v3 in place: partial - the world migrates correctly (Save.lua:133-140). The player key does not: `Standing.rekey` drops the old v2 values (details under FIX).
- `Sides.witnessed` join cap without break: met - the `joined < WITNESS_JOIN` gate is inside the condition (Sides.lua:213). The extra loop work is one distance check per entity per blow, which is negligible.
- Unwitnessed kill, nil killer: met - Sim.lua:437 passes nil, and Headlines.lua:38 handles nil.
- A human plays it: not met - still open.

PRESERVE (done well, must survive future iterations):
- "Memory is the transport, rep is the ledger" (Gossip.lua:5-10): it stops reputation healing when the ring evicts, which DESIGN §7 needs.
- The fallback chain in `Gossip.standing` (Gossip.lua:107-119): `ps.rep` only holds keys that have diverged, and a read is one lookup.
- Rumours store the event, and deltas are worked out again when applied (Gossip.lua:227): a saved rumour can never disagree with Reputation's rule.
- The worst case asserted in bytes, and `heard` saved as sorted arrays (Save.lua:208-215).
- `Standing.sawIt` ("Nobody saw that."): this one line is what makes the feature readable to a player.
- `PLAYER_VERSION` held at 1, with the reason written down (Save.lua:19-21).

FIX (done poorly; why it matters; concretely how to fix):
- **`Standing.rekey` loses every v2 player's reputation**
  - What happens: `addPlayer` sets `rep = Standing.newRep()` (Sim.lua:1149), which already fills v1/v2/v3 with the START values. `applyPlayer` then adds the old farmer/hunter/plunderer keys. `rekey` only copies when `ps.rep[holder] == nil` (Standing.lua:169), which is never true, so START wins and the real values are deleted.
  - Why it matters: a one-time silent reset of every returning player. It has most likely already happened to Danzo's players. The Studio pass checked the world, not player rep, and `save.test.luau` has no rekey test.
  - How: in rekey, let the v2 value win unless the saved record itself had that holder key. Pass `saved.rep` in and check `saved.rep[holder] == nil`. Add a test that starts from a `newRep()`-seeded table.
- **`Gossip.meet` buckets by route index, not by position on the map**
  - What happens: `floor(g.pos/2)` (Gossip.lua:324) compares indices into each group's own route. P5: squad and band are both at pos 1, at tiles (70,56) and (53,32), and they "meet". Groups resting at home at pos 1 swap news across the whole map every 60 s.
  - How: bucket by the tile (`g.route[g.pos]` x,y divided by 2), or by a shared road-segment id.
- **Witnessed animal kills become rumours**
  - What happens: `TRAVELS.kill` does not check the victim (Gossip.lua:264). P1: a deer kill seen by the squad is pushed into the ring. Hunting near hunters fills and evicts the 64-row ring, and `Standing.heard` then makes villagers say "They say you killed someone." about a deer.
  - How: in `Gossip.seed`, return nil when `tribeIdx` is nil or when `Reputation.deltas` is all zero.
- **One global hop count** (Gossip.lua:286-301)
  - What happens:
    - Strength depends on the order of exchanges, not on distance.
    - The offline replay applies the hop count at replay time. P4: online delta -15, offline delta -8.44 for the same village.
    - The eyewitness squad's dialogue turns into "nobody here is sure of it" once the story has travelled elsewhere (Standing.lua:191).
  - How: store hops per holder. Make `knows` entries `{id, hops}`, or keep a parallel hops array, and keep the byte test.
- **Stale or evicted news is lost for offline players** (P3)
  - Why it matters: logging off is a way to escape your reputation.
  - How: either apply the rumour to the holder at the moment it is told, with the offline player's record kept in a pending-deltas map on the world, or replay rumours that are about to be evicted for absent players. At minimum, write the gap down as a known limit in RUNG3.

CONSIDER (fine but could change; why; how):
- The `onChange` hook is a mutable global on a shared module (Gossip.lua:34-35). It works, and `quiet` is restored by hand (lines 356-365). An error inside `apply` would leave `quiet` stuck on. Wrap that part in `pcall`, or have `apply` return before/after and let the adapter announce. The adapter announcing is the cleaner shape.
- `meet` also includes materialised groups, whose `pos` is out of date. Skip `g.materialised`, as `Tick.groups` does.
- Group ids are fixed strings ("caravan", "squad", "band"), so a squad rebuilt with new faces inherits the dead squad's `ps.rep["squad"]`. Clear `ps.rep[id]` and `ps.heard[id]` when a group is fully replenished.
- `Gossip.find` is a linear scan inside `exchange`, `tell` and `catchUpPlayer`. That is O(64²) per exchange. It is fine for now, but build an id→row index once per `meet` call.

UNCERTAIN (could not verify):
- Live gossip in Studio (the squad's reaction, the announce lines, the HUD refresh): Studio command-bar code cannot reach server module state, and I did not kill anyone.
- Whether Danzo's real players actually lost their rep in the v2→v3 load. The code says yes. Checking needs a look at a player record in the DataStore.
- The arrive channel under catch-up for materialised groups (Bands.lua:137): I reasoned about it but did not test it.
- How it reads on a phone: there is no new UI, so I did not check.

## Builder decisions

All five FIX items touch `shared/Gossip.lua` (trigger 2) and the rekey one touches the v2→v3 save migration (trigger 3),
so the routine session escalated them as handoff H3 to the heavy agent rather than doing them itself.
Worked by the heavy agent on 2026-10-05 (H3). Danzo ruled mid-task that the project is in **development mode**: his
save, character and progression do not matter, so a reset is acceptable where a migration is costly. Full reasoning
is in `docs/RUNG3.md` part 3, "QA round 1".

**Fixed**
- FIX 1 rekey: the v2 value wins unless the SAVED record held that holder key. Now pure (`Gossip.rekey`), tested
  from a `newRep()`-seeded table. Players already loaded under the old rule stay reset (dev mode: not recovered).
- FIX 2 meet: bucketed by map tile `route[pos]` in 2x2 cells, not by `pos`.
- FIX 3 animal kills: `Gossip.seed` returns nil when the victim has no tribe or every delta is zero.
- FIX 4 hops: per holder (`hops[i]` beside `knows[i]`), removed from the rumour row. Byte test kept: 7750 B worst
  case (was 7691).
- FIX 5 offline: applied at tell time; an absent player's share goes to a world ledger `w.owed`, faded by
  `Reputation.fade`, paid silently on join, forgotten below 0.5. Online and offline end on the same number even
  after the rumour leaves the ring. `ps.heard` is removed.
- CONSIDER 1: silence is a parameter on the apply path, not a module flag that an error can leave stuck.
- CONSIDER 2: materialised groups are skipped in `meet`.

**Kept** (every PRESERVE item): memory is the transport and rep is the ledger (now stricter: nothing is replayed
from the ring); the `standing` fallback chain; deltas re-derived from the event; the worst case asserted in bytes
(plus a new one for `owed`: 154 B per absent player at 5 holders); `Standing.sawIt`; `PLAYER_VERSION` 1.

**Deferred**
- CONSIDER 3 (a rebuilt group inherits `ps.rep[id]`): an offline player's key cannot be cleared from the world, so a
  real fix needs a group generation stamp. Part 4 gives groups an identity; do it there.
- CONSIDER 4 (`Gossip.find` index): O(64²) every 60 s is cheap. Revisit if `MAX_RUMOURS` grows.

**Changes since last round** (for the round-2 reviewer)
- Save `VERSION` 3 → 4, migrated in place: hops copied onto each holder, `owed` empty. Old code reads v4 as NO-SAVE.
- `shared/Gossip.lua`: `tell(w, key, id, hops)` applies or owes; `catchUpPlayer` pays `w.owed`; new `delta`,
  `rekey`; `latest` returns `(rumour, hopsHere)`; `apply` and `Gossip.quiet` removed.
- New `shared/Grudge.lua` (the scar), re-exported by Gossip under the old names. Rojo tree: one ModuleScript added.
- Server: `Standing.rekey(ps, savedRep)`, `Standing.heard` uses hops at the holder, `Restore` restores `S.owed`,
  `State.owed`, Debug `gossip` prints `#id@hops` and the owed count.
- Tests: 8 new blocks in `gossip.test.luau` (each confirmed to fail on a mutation that brings its bug back), v3→v4
  and owed round-trip in `save.test.luau`. The old `heard` assertion became "an old key's `heard` is ignored".
- Not checked in Studio (the brief said not to): the HUD line, Debug `gossip`, and a v3 world loading as v4.
