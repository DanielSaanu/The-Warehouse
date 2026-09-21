# QA round 2: track-b1 — SCORE 8.5/10

Reviewer: a fresh Opus subagent, with Studio. Target for this loop: 8.5 (met). Verbatim report follows.

---

SCORE: 8.5/10

Tested in Studio (fresh world, seed 1, days 1-9, `savetest 600` reload, two floods, a band wipe and its replenish). `npm test` 13/13, `node test/luau/run.js` all ok, `npm run lint:luau` clean on all 37 files, **zero warns or errors in Output across the whole session**. `Sim.lua` 1281 / ceiling 1285.

GOALS:
- 1 A villager has a day: **met** — morning `farms` "Glenworth ... 5 at work"; ScreenCapture_1 shows villagers standing on both plot blocks; at night ScreenCapture_2 shows them clustered at the one standing hut ("3 at home"). Pregnant women keep the day (`Sim.lua:1004` dispatches on `villager` *or* `pregnant`; persons 11/15/23 morphed to `pregnant` on day 8 and stayed in the rotation).
- 2 Farms grow as a pure rule: **met** — day 3 `[Sim] Glenworth brought in 8 plots: 8 food, 38 in the store`, and 37 the next morning (the 10% trade drift, not a clamp). Round 1's deletion bug is gone: `Trade.lua:60-62` tops up only, and `farmed` stops the double feed. `savetest 600` came back with the sleep's harvest in. `farms.test.luau:95-103` pins full-month 75 vs empty-month 35.
- 3 People are born again: **met** — observed live this round: three pregnancies on day 8 (`people 1/2`), which round 1 could not reach. `Families.cap` 18/15/14 over rosters 14/13/12.
- 4 `Bands.lua` carved verbatim: **met** — diff is a pure move; `grep "[^.a-zA-Z_:](collapse|groupTurn|carryTotal|materialise|groupScratch)("` finds no bare call left behind; `Sim.groupPos = Bands.pos` keeps five call sites working. Squad materialised, walked, collapsed, kept moving as a record.
- 5 Groups are the same people: **met** — squad members 43-46 identical before and after `savetest 600` (new entity ids e76-e79 → none → fresh). Day 6 the band lost all four (headlines name 47-50); the empty group collapsed instead of freezing (round-1 fix confirmed: `band 0 members (0 visible)` still advancing 21/35 → 19/35), and day 8 it came back as **new** people 51-54.
- 6 A stranger is a trade until met: **met** — ScreenCapture_1/2: unmet villagers, hunters and the band carry no caption at all; `merchant`, `guard`, `caravan master` keep theirs; the survivor is named. All three reveal paths exist (`Interact.lua:107`, `Sim.lua:520`, `Sim.lua:631`).
- 7 The earlier carves hold up: **met** — `State.lua` (121) and `Tiles.lua` (144) own their slices, require only Map + shared, no cycle.
- 8 Nothing regresses: **met** — save 11.3-11.8 KB, lease honoured (`lease blocks a second server: true`), `[Restore] day 5, 39 living (39 bodies)` with road people correctly excluded (`Restore.lua:111`), flood took 30% of food, headlines/goal line/trade intact.

PRESERVE (must survive future iterations):
- `Restore.apply` calling `Villagers.reset()` at line 156 — *before* `Tick.catchUp` at 165. That ordering is what lets a pre-farms save farm through its sleep, and it is easy to "tidy" into the wrong place.
- `Farms.scan` reading through `world.floodBackup` (`Farms.lua:36-38`) so a mid-flood scan cannot shift plot rows off their tiles.
- `killEntity` removing the member row it actually found (`Sim.lua:469`), and `Bands.collapse` clearing `person.entity` but not the person (`Bands.lua:160-161`). Both are the difference between a person and a body.
- `farms.test.luau` + `members.test.luau`: identity, cap exclusion, death-and-replacement, save round trip, catch-up. This is the H5 standard.

FIX (done poorly; why it matters; concretely how to fix):
- **The harvest is in lockstep and the fields are never half-ripe.** `Farms.daily` resets a ripe plot to exactly `0` (`Farms.lua:82`) and every plot grows exactly `+0.5`, so after the very first harvest all 8 plots ripen on the same day forever. Output shows harvest lines on days 3, 6, 8 and nothing on 4, 5, 7, 9; `farms` reads `0.00 grown` → `4.00 grown` → `0.00`. The staggered start in `Farms.ensure:50` is thrown away on day 3, and "ripest first" becomes meaningless. A player walking past sees all-ripe or all-bare, never a working farm. -> On harvest keep the remainder and re-stagger: `plot.growth = (plot.growth - 1) + ((k * 37) % 50) / 500`, or give each plot its own rate (`GROW_PER_DAY * (0.85 + ((k*17)%7)/20)`).
- **`docs/DESIGN.md §20` does not exist.** `Farms.lua:2` and `Villagers.lua:2` both cite "DESIGN.md §20 (the world up close)" as their contract, and so does `docs/qa/track-b1.md:10`; DESIGN.md ends at §19. H2 says the first fifteen lines say what the file owns, and CLAUDE.md says the files are the shared brain — the next reader chasing the design of the villagers' day finds nothing. -> Write §20 into DESIGN.md (it presumably exists on the unpushed `world-up-close` branch), or repoint both headers at `ideas/INBOX.md` and ARCHITECTURE.
- **`met` is world-scoped data kept in a key with no world identity.** `Save.encodePlayer:172-175` stores raw person ids; this branch deliberately makes old worlds obsolete (`Save.migrate` v1 → obsolete, no upgrade). On a brand-new world, day 1, having talked to nobody, the player already sees "Brilo Saltby", "Mary Saltby", "Wenon Saltby", "Halin Saltby" (ScreenCapture_1) — ids 1/2/4/6 carried over from round 1's wiped world. It is only harmless today because seed 1 regenerates the same names; after a `genVersion` bump or a seed change it hands out the wrong acquaintances and silently defeats goal 6's whole point. -> Add a `meta.worldId` at `generate` (or reuse `meta.seed` + the first `savedAt`), write it beside `met`, and have `Save.applyPlayer` drop `met` on mismatch.

CONSIDER (fine but could change):
- **The squad does not just maul Wild's Rest — it wipes the band.** Day 6, untouched session: all four band members dead (`headlines`), the road threat gone for a day and back as strangers. I agree `Sides.preysOn` was the wrong place and the reverts were right, but the cheap fix is not general routing: it is local to `Bands.forestTarget` (`Bands.lua:35-45`), which today picks the forest region with the most trees and never asks where the road to it goes. -> Reject a candidate whose `WorldGen.route(hunter.spawn → c, roads)` passes within ~4 tiles of another village's bounds, and fall back to the next-best forest. No `Sides` change, no part-1b regression surface.
- `server/README.md` line counts are stale: `Villagers.lua` 130 (actually 152), `Debug.lua` 215 (actually 290). H6 asks for these in the same commit.
- `Villagers.report`'s "of %d villagers" counts only entities that already have a `workTile` (`Villagers.lua:140`), so the denominator drifts below the real roster until everyone has had an idle thought. -> Count `e.role == "villager"` and report "unassigned" separately.
- `danger(e)` (`Villagers.lua:73-79`) is a full `S.entities` sweep per villager per think tick — ~19 × 80 at 10 Hz. Cheap at the 100-entity cap, but ARCHITECTURE §1 counts full sweeps as the congestion; a cached "hostiles near village i" list refreshed once a second would remove it.
- A farmer village with nobody left still drifts back to 30 food (`Trade.lua:67`), so "a village that loses its people stops feeding itself" is half true — the test's "empty month → 35" is that floor, not zero.
- `Farms.daily` writes `t.stock.food` and `t.news` directly (`Farms.lua:91-93`); R2 gives those to `Economy` / `Population`. Fine while neither module exists — worth a note in B3's grep.
- "[Sim] the band has broken off" printed twice on the same wipe (fires on every death past half).

UNCERTAIN (could not verify):
- Two players, and a player leaving mid-move: one client only through the MCP.
- Phone-shaped screen: `screen_capture` gives the 1291×606 Studio viewport; at 9:16 the remaining overlap ("Fenwyn Sal|caravan master", "merWenon Saltbynwy Saltby" in ScreenCapture_1) will be worse, and it grows as a player meets more people.
- The nil `label` in the middle of the `spawn` RemoteEvent tuple: nothing broke and unlabelled villagers rendered and animated, but I could not prove `ekind` (the argument after the hole) arrives intact — `ekind or base` masks it either way.
- `Farms.drown` in the shipped world: two floods on seed 1 and Glenworth's plots never went under, same as round 1. The rule is covered by `farms.test.luau:43-45` only.
- `PredictedX`/`PredictedY` vs `TileX`/`TileY`: not exercised this round.

---

## Builder decisions (round 2)

The bar (8.5) was met, so this is the last round. The loop's procedure still acts on a round's findings before it
stops, and all three FIX items were cheap.

**PRESERVE** - all four re-checked against the diff; `Villagers.reset()` still runs before `Tick.catchUp`.

**FIX - done**
- *The harvest is in lockstep.* Each plot has its own pace (`Farms.pace`, 0.85-1.15 of the base rate, fixed by its
  place in the scan) and a harvest keeps its remainder. Test: something comes in on 30 days of 30, plots out of step
  on all 30, growth stays in [0, 1). A month at full strength still settles at 72 food.
- *`docs/DESIGN.md` section 20 does not exist.* It existed only on the unpushed PC branch. Ported to main's design doc
  with a "where it stands" note, including the one thing the rebuild changed on purpose (yield counts the living,
  not where their bodies stood).
- *`met` has no world identity.* `meta.worldId` is made with the world (and given to a world saved before ids
  existed), saved, and written beside `met` as `metWorld`; `Save.applyPlayer` drops `met` on a mismatch or when
  there is no id. Tested. Studio: a fresh world shows no carried-over acquaintances.

**CONSIDER - done**
- *The squad wipes the band / mauls Wild's Rest.* The reviewer's local fix was right and round 1's builder missed it:
  `Bands.forestTarget` rejects a forest whose road passes within 4 tiles of another village. Studio, three days with
  the player standing in Wild's Rest: zero deaths, squad home with 7 hide and 8 food. Raised in both rounds.
- README line counts corrected; `Villagers.report` counts every villager; the band's "broken off" line prints once.

**Deferred** - see the summary: `danger()`'s sweep, the 30-food trade floor, `Farms` writing stock and news directly
(B3), the sticky news line, the bag lifetime constant (Danzo's call).
