# QA round 1: track-b1 — SCORE 8/10

Reviewer: Opus subagent, with Studio. Target for this loop: 8.5. Verbatim report follows.

---

SCORE: 8/10

Tested in Studio (fresh world, seed 1, days 1-6, save/restore, flood). `npm test` 13/13, `node test/luau/run.js` all ok, `npm run lint:luau` clean on all 37 files. No warns or errors in Output across the whole session.

GOALS:
- 1 A villager has a day: **met** - `farms` morning "Glenworth ... of 8 villagers 8 at work"; night "0 at work, 4 at home". ScreenCapture_1 shows villagers standing on both plot blocks; ScreenCapture_3 shows them bunched at the one hut door. `Villagers.step` + `danger()` at Villagers.lua:74-99.
- 2 Farms grow as a pure rule: **partial** - growth 2.32 -> 6.32 -> 8 ripe -> +24 food, verified across `day` ticks and through a 600 s catch-up (`savetest 600` came back with the harvest in). But see FIX: `Trade.dailyRestock` caps farmer food at 45 the next morning, so most of the yield is deleted; and `ev.harvests` is never read by any adapter.
- 3 People are born again: **met** - `Families.cap` (Families.lua:22) with 18/15/14 over rosters 14/13/12; members.test.luau asserts a hunter village with a squad out still conceives. Not observed live (first conception roll lands day 8; I reached day 6).
- 4 Bands.lua carved verbatim: **met** - Sim.lua 1417 -> 1282, ceiling ratcheted to 1285 (test/structure.test.js:20). Diff is a pure move; only `Sim.groupPos = Bands.pos` and `Bands.carryTotal`/`Bands.turn` call sites changed. Squad materialised, walked, collapsed, kept moving as a record (pos 6/12 -> 7/12 -> 9/12 while collapsed).
- 5 Groups are the same people: **met** - `group band` before/after a collapse: persons 47-50 both times, new entity ids (e58-e61 -> e120-e122). Caravan 40/41/42 identical across a full save+reload. A death removed that person and the replacement was a new id. v1 -> obsolete wired end to end (Save.lua:114, Persistence.lua:86-92).
- 6 A stranger is a trade until you meet them: **met** - ScreenCapture_1: "guard", "merchant", "villager", survivor "Fenwyn Saltby" named. After `strike e6`/`strike e2`, ScreenCapture_2 shows "Mary Saltby" (I hit her) and "Brilo Saltby"/"Wenon Saltby" (they hit me) named; the untouched guard still reads "guard". All three reveal paths work.
- 7 The earlier carves hold up: **met** - State.lua/Tiles.lua are coherent, own their slices, no cycles. One stale comment (see CONSIDER).
- 8 Nothing regresses: **met** - save 12989 B, lease honoured, reload restored 35 living / 35 bodies (road people correctly excluded, Restore.lua:110), flood took 30% of food and expired on schedule, headlines/goal line/trade intact.

PRESERVE:
- `shared/Farms.lua` as a pure rule counting records: it is the cleanest expression of H9 in the repo, and catch-up farming fell out for free (verified through `savetest 600`).
- `test/luau/members.test.luau`: identity, cap exclusion, death-and-replacement, save round trip, v1-obsolete AND v99-left-alone, catch-up stability. This is the H5 standard.
- `Farms.scan` reading through `world.floodBackup` (Farms.lua:34) so a mid-flood scan cannot shift every plot row off its tile. Exactly the right instinct.
- The v1 reset path: `decode` returns the third `obsolete` flag, Persistence starts a new world and saves over the key. No half-migrated world is possible.

FIX:
- **The harvest is deleted the next morning.** `Trade.dailyRestock` (Trade.lua:58) clamps the tribe's `makes` good to `floor(target*1.5)` = 45 food for farmers. Observed: 34 -> 61 (harvest) -> 44 the next day. 8 plots x 3 food every 2 days is almost entirely thrown away, so goal 2's payoff is cosmetic in steady state. -> Make the `makes` branch top up only (`have = math.max(have, math.min(cap, have + gain))` and skip the `drift` pull when `have > cap` came from a harvest), or give the tribe a separate `stock.granary` that Farms deposits into and Trade never touches.
- **`ev.harvests` is written and never read** (Tick.lua:72-76; grep finds no consumer). H9 says adapters print and notify; `Sim.dailyTick` logs deer/boar/wolf and says nothing about the fields. A player in the village at dawn gets zero signal. -> In `dailyTick`, print one `[Sim]` line per harvest and push a `Headlines` entry, so "the plots came in" reaches the join line and the welcome-back text.
- **Labels are unreadable exactly where the villagers' day puts people.** ScreenCapture_1 bottom row: "guarvillagërlayirillayivillager"; ScreenCapture_3: "villagetlager", "villagevillavillager". Trades made every villager the same 8-character word, so bunched crowds are now identical smears that carry no information at all. -> Suppress the label for unmet, un-targeted entities below a distance (or draw only the nearest/hovered one), and keep the full label for met people, the survivor and group leaders. Cheaper than a Viewport rewrite and fits under the 430-line ceiling.
- **A group at zero members stays materialised and frozen.** `Bands.tick` (Bands.lua:172-179) only collapses on player distance, and `Tick.groups` skips `g.materialised`, so the band sat "visible, 0 members, RETREATING" at 45,32 until I walked away. -> Add `or #g.members == 0` to the collapse condition.
- **`killEntity`'s member removal falls back to the last row.** Sim.lua:469-471 initialises `gone = #g.members`, so an entity whose `person` is not in `members` silently deletes an innocent member. -> Only `table.remove` when the search actually found an index.

CONSIDER:
- The known hunter-squad problem is worse than "five dead on day 1": in my untouched session it killed the whole band (persons 47-50), three of its own four hunters, and left Wild's Rest with 8 of 12 people and no fighters at all - all before the first daily tick. Stable members make it permanent and legible now (headlines name every corpse). -> At minimum make `squad` ignore `bandit` entities whose `tribe` has a village (Sides has the predicate already).
- Pregnant and baby villagers fall out of the day: `think` (Sim.lua:1006) dispatches on `e.role == "villager"`, so a pregnant woman wanders at night instead of going home, and `Farms.workers` (Farms.lua:55) does not count her. -> Match on `e.stage`/a `VILLAGE_ROLES` set.
- `Restore.apply` never re-runs `Villagers.ready()`/`Farms.ensure`, and `Villagers.bind` (the only place `sites` is cleared) is not called on a reload. Safe today only because the map is identical. -> Call `Villagers.ready()` at the end of `Restore.apply`.
- `t.news` is only set by Farms when it is nil (Farms.lua:88) and nothing ever clears it, so "The plots came in well" is sticky until a birth overwrites it.
- Tiles.lua:81 `age > 3600` with the comment "vanish after an hour": `DAY_SECONDS = 600`, so a bag lives 6 in-game days, and `BAG_PRIVATE_SECONDS = 600` is a whole day of privacy. Carried verbatim, but wrong as written.
- The v1/genVersion-obsolete branch returns before `Save.mayWrite`, so two servers meeting a v1 key would both generate and both write.

UNCERTAIN:
- `Farms.drown`: the flood started while all 8 plots were at growth 0, so nothing drowned. On seed 1 Glenworth's plots sit inside the walls with no water near them, so I could not confirm the path ever fires in the shipped world.
- Two players, and a player leaving mid-move, could not be exercised through the MCP (one client only).
- Phone-shaped screen: `screen_capture` gives the Studio viewport (1291x606); I could not judge label density at a 9:16 aspect, where the overlap will be worse.
- `PredictedX`/`PredictedY` were nil on the Player from the server datamodel, so prediction-vs-authority was not checked this round.

---

## Builder decisions (round 1)

**PRESERVE** - all four kept and re-checked against the diff: the pure farm rule, `members.test.luau`, the scan through
`floodBackup`, the v1-obsolete path.

**FIX - done**
- *The harvest is deleted the next morning.* `Trade.dailyRestock` takes `farmed`: a tribe with fields gets its food from
  the HARVEST and the abstract gain is skipped (it was being fed twice), and making only ever tops up to the ceiling,
  never cuts down to it. `Farms.FOOD_PER_PLOT` 3 -> 1, so a full village brings in the same 4 a day the restock used to
  hand it for nothing. `farms.test.luau`: a month at full strength settles at 75 food, the same month with nobody left
  falls to 35. Studio: 30 -> 38 on the harvest, 37 the next morning (the 10% trade drift, not a clamp).
- *`ev.harvests` is never read.* `Villagers.harvested` prints one `[Sim]` line per harvest and tells any player standing
  in that village at dawn. **The Headlines half is declined on purpose:** a harvest every other day would push births
  and deaths out of the 64-entry ring, and "you were gone eleven days: the plots came in five times" is not news.
- *Labels unreadable where the villagers' day puts people.* No client change was possible (`Viewport.lua` 429/430,
  `Client.client.lua` 659/660), so it is done on the server: the trades that come in crowds (villager, hunter, bandit,
  caravan guard, baby) carry NO caption until met; the posts a player goes looking for (guard, merchant, caravan master)
  keep theirs; met people and the survivor show names. Studio: the fields are clean.
- *A group at zero members stays materialised and frozen.* `Bands.tick` collapses on `#g.members == 0`.
- *`killEntity` removes the last row when the person is not found.* It now removes only the row it found.

**CONSIDER - done**
- Pregnant villagers keep their day (`think` dispatch) and their hands (`Farms.workers`, with a test).
- `Restore.apply` calls `Villagers.reset()` (rescan + `Farms.ensure`) right after the tribe rows are swapped, which is
  before catch-up, so a save from before farms farms through its sleep. Studio `reload 1200`: fields intact.
- An obsolete save under another server's live lease: that server is replacing it, this one runs NO-SAVE.

**CONSIDER - attempted, reverted, deferred to Danzo: the squad at Wild's Rest**
Three targeting rules were tried in `Sides.preysOn` (leave people at home alone; people at home do not sally out;
"fighting" means fighting a person, not chasing a deer) and tested in Studio each time. The band survived under the
first, but every variant still ended in a battle, and the last was the worst (9 dead). **The root cause is not
targeting: the squad's road route runs through the middle of Wild's Rest** (route index ~48-50 is 2 tiles from the
village centre), so any rule that lets a village defend itself turns the squad's commute into a siege. The fix is
routing - the squad's route should avoid hostile villages (a cost in `WorldGen.route`, or a forest target that does
not need that road) - which is a design-level change with its own regression surface (part 1b's goals), not a QA
patch. All three rules were reverted rather than left as half-measures. `Sides.lua` is unchanged from main.

**Deferred**
- `t.news` is sticky: pre-existing pattern for every news writer, not this stack's; part 3 (gossip) replaces `news`.
- `Tiles.lua` bag lifetime (3600 game seconds = 6 in-game days, comment says "an hour"): carried verbatim from main;
  which number is right is Danzo's call, so the code is untouched and the question is in the summary.
