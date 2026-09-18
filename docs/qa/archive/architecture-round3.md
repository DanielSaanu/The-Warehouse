# Architecture plan review — round 3 — SCORE: 8.5/10 (bar is 9.5; round 4 follows)

Reviewer: Opus subagent, 2026-09-18, reviewing `docs/ARCHITECTURE.md` after round 2's fixes, against the bar
Danzo raised to 9.5. Re-derived the arithmetic and re-checked every line number independently.

## Report (verbatim)

SCORE: 8.5/10

Environment: `npm test` green (11 node tests + 4 luau suites), `npm run lint:luau` ok on all 27 files.

ROUND 2 FIXES:
- Durable id counters in `meta`, entity ids never persisted, bag counter: landed (partial) - R5 clears `person.entity`, `g.entities/leader/target`; **misses `t.guard`, `t.merchant`, `t.survivor`**, which are entity ids written onto the durable tribe row (`Sim.lua:373, 388, 397` via `spawnPerson` returning an entity). Same collision class R5 exists to kill.
- `meta.rngState`: landed - correct; `Rng` is one number (`Rng.lua:11`), `rng = Rng.new(world.seed*31+7)` at `Sim.lua:1547` (plan says 1546 — off by one).
- `Sim.clock()` becomes an accumulator: landed (partial) - `Sim.lua:73` confirmed. But `Debug.lua:69,75,79` each assign `S.dayStart = os.clock() - …`; round 2 named those three lines and they are still unmentioned. Step 1 as written silently breaks the `night`/day-fraction debug commands, and `Debug` writing the clock violates R2 (`Calendar` owns `meta.gameSeconds`).
- R1: live player record is a projection, `ps.save`: landed - `Sim.lua:1515-1523` holds `player` (Instance), `snap` (function), `budget`, `known`.
- Step 1b restore path: landed - `initTribes` at `:349`, `initGroups` at `:425` (plan gives no line) both rebuild from scratch.
- Step 2 stable group members: landed - `makeGroup` `:411`, anonymous specs `:427-442`.
- Daily tick into `shared/` + H9: landed - `test/luau/run.js:12` bundles only `SHARED`. Correct.
- Cross-key authority rule: landed.
- "Every node in §2 has an owner", by field path: partial - see FIX.
- Memory cap reshape (242 KB): landed, arithmetic re-derived below.
- `Wildlife`→`Bodies`, `Targeting`→`Brains`: landed, but self-contradictory (see CONSIDER).
- `mapDiff` = every runtime change, `Tiles`, `calamity.flood` dropped: landed — and it **creates a new save blocker** (see FIX).
- Three stale line numbers, `MAX_PEOPLE` per tribe, derived fields removed, RUNG3 corrected: landed - 150/168/1451 all verified exact; `docs/RUNG3.md` now says "not serialisable today".

CLAIMS CHECKED:
- `newEntity` sets 31 fields, ~47 total: true - 32 top-level keys at `Sim.lua:153-167`; the 16 later-bolted names all exist.
- "12 full sweeps (Sim 8, Sides 2, Debug 2), 20 `pairs(S.players)`": true - `grep -c` exact.
- "`S.tribes` is **written** from four files (Sim 18, Interact 8, Sides 5, Debug 4)": **false** - those are occurrence counts, not writes. All 5 Sides sites are reads (`Sides.lua:49,55,60,180,206` → `.tribeType`, `.village.name`); all 4 Debug sites are reads (`Debug.lua:64,127,135,169`; `:65` writes `ps.rep`, not the tribe). Only Sim and Interact mutate (`Interact.lua:167,293,305` → `t.stock`). Substance ("no owner") holds; the headline number in §1's "measured, not asserted" does not.
- `Sim.lua` 1617, Hud 1021, WorldGen 877, Client 653, Viewport 429; both big files `--!nonstrict`: true.
- 36 regions: true - 96/16 = 6².
- Person record ~274 B full: true (within rounding) - I re-derived a living-adult-with-parents-spouse-death record at ~250 B; 4 MiB/274 = 15,307; ×600 s = 106.3 real days. ✓
- §5 memory: 43×5×60 = 12.9 KB, ×300 = 3.87 MB; cap 43×32×3×60 = 247,680 B = 242 KiB: true.
- §8 Q8 headlines 64 × ≈40 B ≈ 2.5 KB: true (I get ~42 B/entry).
- §8 Q9 `"1234":5` ≈ 11 B: overstated - `"9216":12,` is 10 B, `"123":5,` is 8. Conclusion unaffected.
- §8 Q10 ≤0.9 births/day → 17,000 in-game days → 118 real days: true.
- "`WorldGen.encode`'s `packBytes` already gets tiles to ~1 B each": true - `WorldGen.lua:820,849`; measured `ground` = 9216 B for 96×96.
- `Families.MAX_PEOPLE` caps living per tribe: true - `Families.villagers(reg, tribe, …)` `Families.lua:63-71`.
- §4 module budgets fit: true - 2,100 budgeted vs 1,654 today (Sim 1617 + World 37); ~226 lines of slack after 11 headers + requires.

GOALS:
- 1 Tiered tree: met - tiers are right and the tier rule is sharp.
- 2 Highest-tier / derived-not-stored: partial - `groups[].route` is stored but derivable from `from`/`to` (I measured 55-62 nodes per route, ~900 B JSON each); `meta` stores `day` + `dayFraction`, both derived from R5's `gameSeconds`.
- 3 Systems ask, not reach: partial - R2 is the right weight, but the claim "every node in §2 has one" is false (below).
- 4 Says how it will be implemented: met - §6 remains the strongest part of the document.
- 5 No context-burning file: met.
- 6 **Unblocks part 2: partial** - three blockers closed; I found two new ones plus a schema hole (below).

PRESERVE (right; must survive revision):
- R1 + R5 together, and the "walk the tree, fail on function/Instance/cycle" test: the whole save story.
- §6's move mechanics (verbatim-then-rename, bare calls to moved locals, definition order): written from scars.
- Step 4's grep-for-zero-outside-writes as the ownership proof.
- The demand-driven index and the ~100-entity reasoning; the escape hatch; "step 1 is the only non-optional one".
- H9 and the daily-tick-in-`shared/` move: verified correct against `test/luau/run.js:12`.
- §5's re-derived arithmetic and "people are not the thing to watch".

FIX (wrong or missing; why it matters; concretely what to change):
- **Save blocker 4: the flood cannot be lifted after a load, and the plan's own round-2 fix causes it.** `startCalamity` calls `WorldGen.floodTiles` then `setFlood`, which writes `world.floodBackup` (`WorldGen.lua:779-786`) — an in-memory sparse table that is never persisted; `endCalamity` restores from it (`Sim.lua:1420`). Under "`mapDiff` = EVERY runtime tile change" the 1,011 flood tiles (measured, seed 1) land in `mapDiff`, and "recompute `calamity.flood` on load" cannot work: `floodTiles` skips tiles already `G.flood.id` (`WorldGen.lua:762`), so after the diff is applied it returns a different list and `clearFlood` has no backup. The map stays flooded forever -> state the **load order** explicitly (regenerate from seed → apply `mapDiff` → re-apply the active calamity overlay last), and **exclude calamity tile writes from `mapDiff`**, reconstructing them from `calamity.kind` on the pre-flood map.
- **Save blocker 5: numeric table keys do not survive the round trip.** `S.people.people` is `[number] -> Person`, `S.camps` is `[userId]`, `mapDiff` is `{tileIndex -> id}`. DataStore serialises to JSON, so a sparse numeric-keyed table comes back **string-keyed**: `reg.people[p.father]` (a number) returns nil and the family tree silently detaches. §8 Q9 notices the string-key fact for *byte budgeting* and never draws the correctness conclusion -> add to §2: every map key in the tree is a string (or the node is an array with an `id` field), and R1's JSON-able test becomes a **round-trip** test (`decode(encode(t))` deep-equals `t`), not just a walk.
- **Catch-up has no wall clock to measure against.** R5 bans wall time outright, `meta` has no real-world stamp, and nothing in the plan says how "the missed days" is computed -> add `meta.savedAt = os.time()` (UNIX epoch, stable across servers, unlike `os.clock`) and say plainly that `os.time` is the one permitted wall-clock read, used only at load to compute elapsed real seconds → `gameSeconds`.
- **§2's person node is an incomplete schema and a model will execute it literally.** It lists `{first,last,sex,born,died,cause,killer,tribe,role,father,mother,spouse,children}` — missing `village`, `stage`, `alive`, `due`, `grown`, `widowed`, all real non-derived fields `Families` depends on (`Families.lua:19-28`, `p.stage == "adult"`, `p.due`, `p.grown`). Also `Person.village` is the village **name string** (`Sim.lua:312`), which §2 says is seed-derived, so a WorldGen rename orphans every record -> list the full field set, and make `village` a village **id**.
- **Catch-up needs the 1 Hz group tick, not only the daily tick.** DESIGN §14 and RUNG3 part 2 both specify "one step per in-game hour … so caravans arrive"; group route advance lives in the 1 Hz tick (`Sim.lua:542-566`), which step 1 leaves in `server/`. Step 6 as written cannot make caravans arrive -> step 1 moves the abstract group-advance step into `shared/` too, and says catch-up replays {hourly: groups; daily: ecology/families/economy}.
- **`server/World.lua` already exists and does a different job** (37 lines: `World.init/get/walkable/encoded`, the generated map, used at `Sim.lua:1546`). §4 assigns the name to "the tree: load, save, migrate. Owns nothing else" with no mention of the collision, violating H3 -> name the new one `Save.lua` (or rename the existing to `Map.lua`) and say which.
- **"Every node in §2 has one [writer]" is false.** Unowned: `meta.version/seed/rngState/nextBagId`, `tribes[].type/sizeTier/walled`, and player `pos`, `rest`, `goalStage`, `flags`. R2 also names `Inventory` as an owner with no entry in §4's module list -> add the rows, or add a "`World`/`Save` owns `meta` except `gameSeconds`" line.
- **No serialiser exists before step 6, yet steps 1 and 1b are verified by one.** "Two consecutive boots do not grow the registry" and "no persisted field came from `os.clock`" cannot run in `npm test` as stated — the first needs save/load, the second is not mechanically checkable in Luau -> have step 1 land a pure `shared/Save.lua` (encode/decode + the round-trip and JSON-able assertions) so every later step round-trips in `npm test`, and make the `os.clock` rule a **lint** check in `tools/luau-check.js`, not a test assertion.

CONSIDER (defensible but worth changing; why; how):
- Steps 2 and 3's verifications ("a squad completes a round trip", "the part 1 QA script") are Studio-only, which contradicts "each step ends green on `npm test`" — and a cloud session cannot press Play (CLAUDE.md) -> label each step's gate `npm test` / `lint` / **Studio**, as round 2 forced for step 1.
- §4 budgets `Brains` at 350 while the paragraph below says split it "when `Brains` actually passes 250". By its own estimate it passes on day one -> pick one number.
- `groups[].route` stored vs. recomputed is never decided; `pos` is an index into it, so a model must guess whether the route regenerates identically -> say "routes are recomputed from `from`/`to` on load and `pos` is clamped", or store them and accept ~36 KB at 40 groups.
- H1's allow-list has five violators but only two (`Sim`, `WorldGen`) have a step. `Hud.lua` 1021, `Client.client.lua` 653, `Viewport.lua` 429 stay allow-listed forever -> give them a named owner and a rung, even if deferred.
- `-math.huge` sits in the live player record (`lastAttack`, `lastWorldInit`, `Sim.lua:1517-1518`). The JSON-able test checks functions/Instances/cycles but not inf/NaN -> add them.
- §4b lists H9 before H8 (lines 213 and 219).
- §2's `meta` omits `lastDailyTick` (`Sim.lua:56`), `headlines[]`, `rngState` and the bag counter that R5 and §8 Q8 introduce -> show the real `meta` node.
- `rng` is at `Sim.lua:1547`, not 1546.

WHAT WOULD MAKE THIS A 9.5:
1. The calamity/`mapDiff` interaction plus an explicit load order.
2. The string-key rule and a round-trip (not walk) test.
3. `meta.savedAt = os.time()` and the one permitted wall-clock read.
4. The complete person schema with `village` as an id.
5. Catch-up replays the hourly group tick, so step 1 moves that too.
6. `t.guard/merchant/survivor` added to R5's clear-list; `Debug.lua:69,75,79` named in step 1.
7. `World.lua` collision resolved; the unowned fields given owners; per-step gates labelled test/lint/Studio; a pure `Save.lua` landed in step 1 so steps 1 and 1b are actually verifiable.
8. §1's "written from four files" corrected to two.

UNCERTAIN:
- Whether Roblox's DataStore returns string keys for sparse numeric tables is from the documented JSON serialisation, not a measurement I can run here; the round-trip test is cheap insurance either way.
- Per-tick CPU: no Studio run, so the "index not yet needed" argument still rests on DESIGN §4's ~100-entity cap.
- Whether `Sim.clock()` can become an accumulator without disturbing the 10 Hz movement budget (`Movement.newBudget(os.clock())` legitimately wants wall time); I did not trace every `now` consumer.

## Builder decisions

8.5 against a bar of 9.5, so round 4 follows. **All eight FIX items taken, and all eight CONSIDER.** I verified
every FIX in the code myself before acting — at this bar a plan that repeats a reviewer's claim is no better than
a plan that repeats mine.

- **Save blocker 4, the flood, is the best find of the round, and round 2's own fix caused it.** Verified:
  `setFlood` (`WorldGen.lua:778-786`) stashes the overwritten tiles in `world.floodBackup`, which is not in the
  tree; `floodTiles` skips already-flooded tiles (`:762`); `endCalamity` (`Sim.lua:1420`) is the only restorer.
  So "mapDiff records every runtime tile change" + "recompute the flood on load" = a world that is flooded
  forever. §6 now fixes the **load order** (regenerate → apply diff → re-apply the calamity overlay last) and
  excludes calamity tiles from the diff. A fix landing a blocker is the argument for the loop, not against it.
- **Save blocker 5, numeric keys, is the quiet one.** Verified: `Families.Registry.people` is `{ [number]: Person }`
  (`Families.lua:30`), `S.camps` is keyed by `UserId` (`Sim.lua:1286`), `mapDiff` by tile index. JSON has no
  integer keys, so `reg.people[p.father]` returns nil after the first load and **the family tree detaches with no
  error**. §2 now requires string keys everywhere, and R1's test became a **round trip** rather than a walk —
  a walk cannot see a key that changes type in transit.
- **`t.guard`, `t.merchant`, `t.survivor`** are entity ids on the durable tribe row (`Sim.lua:369, 380, 391`),
  read back by `Interact.lua:52, 221` to find who you talk to and who you trade with. R5's clear-list missed all
  three — the exact collision class R5 exists to kill. Added, and step 1b's `restore` re-points them.
- **Catch-up had no clock to measure the gap with.** R5 banned wall time; nothing replaced it. `meta.savedAt =
  os.time()` is now the one permitted wall-clock read, at load only.
- **Catch-up needed the hourly tick, not just the daily one.** `tickGroups` (`Sim.lua:542`) is the 1 Hz abstract
  group advance, and DESIGN §14 specifies an hourly catch-up step so caravans arrive. Step 1 moves both ticks to
  `shared/`; catch-up replays hourly groups, daily everything else.
- **Steps 1 and 1b were verified by a serialiser that did not exist until step 6.** `shared/Save.lua` moves into
  step 1. That makes step 1 the largest step in the plan, so the escape hatch names its seam.
- **`server/World.lua` already exists** (37 lines, holds the generated map). The new module is `Save.lua` and
  step 0 renames the old one to `Map.lua` — two require sites. Two files called "world" breaks H3 before a line
  is written.
- **The person schema was incomplete and a model would have executed it literally**: `stage`, `alive`, `due`,
  `grown`, `widowed`, `village` all missing, all load-bearing in `Families`. And `Person.village` is the village
  *name string* while §2 calls names seed-derived, so a WorldGen rename would orphan every record — it becomes an
  id.
- **Every step now names its gate** (test / lint / Studio), because they are not the same gate and a cloud
  session cannot press Play. Three steps turn out to be Studio-gated.
- **Corrections taken:** §1's "written from four files" is two (Sides and Debug only read); `rng` is at
  `Sim.lua:1547`; `Brains` is budgeted 250 rather than 350-with-an-instruction-to-split-at-250; H8 now precedes
  H9; the `meta` node shows its real fields; `"1234":5` is 10 B, not 11; `Debug.lua:69, 75, 79` are named in
  step 1 (they set `S.dayStart` from `os.clock` and are the commands QA uses to reach a calamity).
- **Decided rather than deferred:** `groups[].route` is derived — recomputed from `from`/`to` on load, `pos`
  clamped — and §8 Q12 writes down the risk that buys (a loading caravan snaps to the nearest point on a changed
  road) instead of leaving a model to guess.

**Nothing deferred.** The H1 allow-list is the one place something is dated rather than done: `Hud.lua`,
`Client.client.lua` and `Viewport.lua` are client files, assigned to rung 3 part 5 and rung 4, and deliberately
out of scope for a plan about the server tree.
