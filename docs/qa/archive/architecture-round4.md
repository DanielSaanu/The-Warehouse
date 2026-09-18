# Architecture plan review — round 4 — SCORE: 8.5/10 (bar is 9.5; round 5 is the last)

Reviewer: Opus subagent, 2026-09-18, reviewing `docs/ARCHITECTURE.md` after round 3's fixes, and explicitly
asked to audit those fixes for problems they introduced — which is how round 3 found two blockers.

## Report (verbatim)

SCORE: 8.5/10

Environment: `npm test` green (11 node tests + 4 luau suites); `npm run lint:luau` ok on all 27 files.

Calibration note: this is materially better than round 3 — every round-3 FIX landed, and every factual claim I re-derived checked out except two minor overstatements. It stays at 8.5 because round 3's own fixes introduced one new save blocker, one step-gate contradiction, and one half-fix that its new test certifies as passing. Three things would still stop an implementer cold.

ROUND 3 FIXES:
- Load order (regenerate → mapDiff minus calamity → overlay last): landed, but see NEW PROBLEMS - `setFlood`/`clearFlood`/`floodBackup` verified at `WorldGen.lua:778-793`, skip-if-flooded at `:762`.
- String keys everywhere + three numeric nodes named: partial - see FIX; `Families.lua:30`, `Sim.lua:1286`, mapDiff all confirmed numeric-keyed.
- Round-trip test rejecting inf/NaN: landed - `-math.huge` confirmed at `Sim.lua:1517-1518`.
- `meta.savedAt = os.time()`: landed (wording hazard, see FIX).
- Person schema: landed, exact - §2's 20 fields == `Families.Person` (`Families.lua:18-29`) minus `entity`. `village` as id is right: today it is the name string (`Sim.lua:312`).
- Step 1 moves both ticks + lands `Save.lua`: partial - `tickGroups` confirmed at `Sim.lua:543` (542 is its doc comment); Save.lua location contradicts §4 (see FIX).
- `t.guard/merchant/survivor` in R5's clear-list: landed, exact - writes at `Sim.lua:369, 380, 391` (plus a succession write at `:700`), reads at `Interact.lua:52, 221`.
- `Debug.lua:69,75,79` → `Calendar.setDay`: landed - verified verbatim (`:74` and `:76` also write `S.day`/`S.lastDailyTick`; `setDay` should cover them).
- `World.lua` → `Map.lua`, step 0: landed - require sites `Server.server.lua:11`, `Sim.lua:27` confirmed.
- R2 owners for meta/tribes/player fields; Inventory → Economy slice: landed.
- Per-step gates + Gate column + escape hatch seam: landed.
- `groups[].route` derived: landed but wrong, see NEW PROBLEMS.
- H1 allow-list dated; Brains 250; H8 before H9; §1 "two files": landed - re-verified: Sides' 5 sites and Debug's 4 are all reads (`Debug.lua:65` writes `ps.rep`); only Sim and `Interact.lua:167,293,305` write.

NEW PROBLEMS INTRODUCED BY ROUND 3'S FIXES:
- **Blocker 6: "re-apply the active calamity … exactly as a live `startCalamity` would" (§6 step 3) re-runs one-time consequences.** `startCalamity` (`Sim.lua:1374-1415`) does far more than lay tiles: `c.day = S.day` (resets the end date, `tickCalamity` ends it at `day > c.day`, `:1438`), `t.stock.food = floor(food*0.7)` for every tribe (`:1402`), `Ecology.beastTide` + a population hit for tide (`:1404-1408`), shoves entities/players, destroys camps (`:1399`). Executed literally, every load during an active calamity steals another 30% of every tribe's food and **the calamity never ends** — and with a 2-minute autosave plus restarts, repeatedly.
- **`Save.lua` is in two places.** §4's module map lists it under `server/` (line 197, "~200"); step 1 says "**`shared/Save.lua`** … it is pure Luau over the tree, so it belongs in `shared/` (H9)". `test/luau/run.js:12` bundles only `shared/`, so if a model follows §4, step 1's round-trip gate is a fiction — the exact defect round 3 raised. And a real save needs DataStoreService, so the honest answer is two files, which re-creates the `World.lua` name collision H3 just fixed.
- **"Route is derived from `from`/`to`" does not survive the band.** There is no `g.to` in the code at all (`makeGroup`, `Sim.lua:411-423`, takes `to` as a parameter and stores only `from`). Worse, `tickGroups` **replaces** `g.route` at runtime from `g.lateTarget` and clears it (`Sim.lua:553-563`) without any `to` to update. Recomputing from a generate-time `to` teleports the band back to its day-one grace ambush on every load.
- **The string-key rule is half a fix, and the new round-trip test passes anyway.** §2 makes the *keys* strings but leaves `Person.id`, `father`, `mother`, `spouse`, `children[]` as numbers in its own schema. `reg.people["7"]` vs `p.father == 7` still returns nil; `decode(encode(t))` deep-equals `t` regardless. Also `Families.add` (`:40-46`) does `reg.people[reg.nextId] = p`, so the whole `--!strict` id type must change, which the plan never says.

CLAIMS CHECKED:
- §1 counts (Sim 18 / Interact 8 / Sides 5 / Debug 4; 12 sweeps = 8+2+2; 20 `pairs(S.players)`): true - `grep -c` exact.
- `newEntity` at 150, `removeEntity` 168, `Sim.clock` 73, `nextId` 42, `lastDailyTick` 56, `person.entity` 317, `initTribes` 349, `makeGroup` 411, `pauseUntil` 416, `initGroups` 425, `bags.droppedAt` 841, `camps` 1286, `tickFamilies` 1451 + `if me` 1465, player record 1515, rng 1547, dayStart 1548: true - all verified.
- `endCalamity` at 1420: overstated - 1420 is the `clearFlood` line; the function starts at 1417.
- §5 arithmetic: true - re-derived independently: 4 MiB/274 = 15,307; ×600 s = 106.3 real days; 43×5×60 = 12.9 KB, ×300 = 3.87 MB; 43×32×3×60 = 247,680 B = 242 KiB; 64×40 ≈ 2.5 KB; 0.5×4×3/7 = 0.857/day → 15,300/0.9 ≈ 17,000 in-game days = 118 real days; 96/16 = 6² = 36 regions.
- §4 budgets fit: true - 2,037 budgeted vs 1,654 today (Sim 1617 + World 37) = 383 lines of slack.
- "shared … 18 files, median 80 lines": overstated - 18 files correct; median is 73.5 (68, 79 midpoints). And it becomes 19 after step 1 and 21 after step 5.
- "`Families.Registry.people` … comes back `{["7"]: Person}` … the family tree detaches on the first load": overstated - nothing ever deletes from `reg.people` (no `people[x] = nil` anywhere), so it is dense 1..nextId and JSON-encodes as an **array** today. The rule is right prospectively — the moment §5/RUNG3's pruning lands it goes sparse — but the present-tense claim is not true as stated. `S.camps` (UserId) and `mapDiff` are genuinely sparse.
- "rebuilding `floodBackup` exactly as a live `startCalamity` would": overstated - a bag/camp that existed at flood time and despawned since (`Sim.lua:1302,1340,1366`) makes `floodTiles` return a different set on recompute. Cosmetic, but "exactly" is wrong.

GOALS:
- 1 tiered tree: met.
- 2 highest tier / derived not stored: partial - route decision is broken (above); `regions[].live` (`Sim.lua:1551`) is a transient materialised-animal count bolted onto the durable region row and §2 never mentions it — save it and `r.live[sp] < want` (`:619`) is false forever, so **animals never spawn again**.
- 3 systems ask, not reach: met - R2 now covers every node I could find except the ones under FIX.
- 4 ordered, verifiable steps: partial - step 1's verification cannot run where it says (below).
- 5 no context-burning file: met.
- 6 unblocks part 2: partial - five blockers closed; one new one created, one half-closed, plus the catch-up cap gap.

PRESERVE (right; must survive revision):
- §6's move mechanics and the per-step Gate column: the strongest part of the document.
- R1's round trip, R5's clear-list, the `os.clock` lint-not-test decision, `shared/` + H9 as the testability argument.
- The load-order *sequence* (regenerate → diff → overlay) — only the "call startCalamity" part is wrong.
- All of §5's arithmetic and "people are not the thing to watch"; the demand-driven index; the escape hatch.

FIX (wrong or missing; why it matters; concretely what to change):
- **Blocker 6, the calamity re-apply.** -> Split `startCalamity` into `Calamity.applyOverlay(kind)` (idempotent: flood tiles + `setFlood`, or `r.tide` flags) and `beginCalamity(kind)` (the one-time half: `c.day`, the food cut, the population hit, shoves, camp destruction, notices). Load calls **only** `applyOverlay`, and never touches `c.day`.
- **`Save.lua` location.** -> Say explicitly: `shared/Save.lua` = pure encode/decode/migrate/catch-up over the tree (in `npm test`); `server/Persistence.lua` = the DataStore adapter. Fix §4's map to match, and give the adapter a name that is not "Save" (H3).
- **String keys are only half the rule.** -> Add: every *reference value* is a string too (`Person.id`, `father`, `mother`, `spouse`, `children[]`, `e.person`, `chiefId`, camp keys), `Families.Registry.nextId` issues `"p"..n`, and add a test assertion that every id-typed field is a string after a round trip — the deep-equal cannot see this.
- **The 4-week catch-up cap is missing.** DESIGN §14 and RUNG3 part 2 both say "one step per in-game hour, **capped at 4 weeks**". The plan never mentions it, and says elapsed real seconds "**becomes** `gameSeconds`" — read literally that assigns, wiping the calendar to day 1. -> Say `gameSeconds += min(os.time() - meta.savedAt, CATCHUP_CAP)`, and decide the hard case: what `day` shows after a longer absence. Related: the live driver runs **one** `dailyTick` per second even if the day jumped (`Sim.lua:1598-1602`), so a capped catch-up plus a derived day silently skips every unsimulated day forever.
- **The hourly group replay assertion cannot hold.** Step 1 asserts "a 28-day run advances group `pos` identically whether replayed hourly or ticked live". One hour at speed 1.5 is 5,400 steps, clamped to a 55-62 tile route, then **one** `groupTurn` (`Sim.lua:570-571`) — an hourly lump traverses at most one leg where live ticking does ~11, and `depositCarry` fires once instead of eleven times. -> Replay groups at 1 Hz sim-steps (4 in-game weeks = 16,800 steps, trivially cheap) and amend the assertion, or state the tolerance.
- **Step 1's other verification cannot run in `npm test`.** "a run of the same 28 days **with a player present**" needs materialisation, a `Player` and `server/`. -> Restate as: pure tick vs pure tick + a stubbed "observed" flag, and move the real comparison to step 3's Studio script.
- **§2's group row is missing durable fields.** No `to`, and no `fullSize` (band-breaks-at-half, `Sim.lua:720` — reload and a 2-of-4 band never breaks), `pauses`, `speed`, `lateTarget`, `kind`, `tribe`. -> List them, and say `to` is rewritten whenever the route is retargeted.
- **§2's tribe row has no link to its village.** `t.village` is a live `WorldGen` table reference (`Sim.lua:352`) compared by **identity** at `Sides.lua:63`, and read at `Interact.lua:38`, `Sim.lua:312, 477, 1406`. RUNG3 part 2 already names it as a blocker. -> Add `tribes[].villageId` and say those five sites resolve through `Map`.
- **`regions[].live` must be named transient** (and `village`, like forest/open, is derived).

CONSIDER (defensible but worth changing; why; how):
- `mapDiff` is `{tileIndex -> id}` with no layer. Runtime writes hit `world.object` only (camps/bags) except flood, which hits `ground` — true today, unstated, and one future ground edit corrupts the map. -> Say "object layer" or carry a layer byte.
- RUNG3 part 2 calls pruning "a rule to build to from the first commit"; §5 only uses the pruned byte count. Pruning also makes `people` sparse (activating the string-key rule) and drops `father`/`mother` links. -> Give pruning a rule and a step.
- `server/Calendar.lua` sits beside `shared/Calamity.lua` and `shared/DayCycle.lua`, unmentioned in §4; the day maths is pure and belongs in `shared/`.
- `tribes[].sizeTier` and `.chiefId` appear nowhere in the code or docs (DESIGN §5 has "size tiers" prose only). -> Define, or defer to rung 4.
- `npm run lint:luau` needs the gitignored `tools/luau/` binary; a "lint" gate is not runnable everywhere.

WHAT WOULD MAKE THIS A 9.5:
1. Split `startCalamity`; load re-applies the overlay only.
2. `shared/Save.lua` vs the DataStore adapter, named and placed once.
3. Reference values become strings, with an assertion the round trip cannot fake.
4. The 4-week cap, `gameSeconds +=`, and what `lastDailyTick`/`day` do past the cap.
5. Group replay at 1 Hz, and step 1's two unrunnable assertions restated.
6. `to`, `fullSize`, `pauses`, `speed`, `lateTarget` on the group row; `villageId` on the tribe row; `regions[].live` marked transient.

UNCERTAIN:
- Whether Roblox's JSONEncode emits an array for a dense numeric table (I reason from JSON, not a measurement) — it decides whether the `people` claim is "overstated" or "false".
- Per-tick CPU and the catch-up cost of a 1 Hz group replay: no Studio run.
- Whether DESIGN §14's "4 weeks" means in-game or real weeks; the two differ by ~144×, and the plan inherits the ambiguity.

## Builder decisions

8.5 for the third round running, and for the third time it is not a stalled score: every round-3 item landed, and
the round was spent on what those fixes broke. **All nine FIX items taken, and all five CONSIDER.** Verified in
the code first, as usual — and this time the most important finding was against my own writing.

- **Blocker 6 is mine.** Round 3's load order said to re-apply the calamity "exactly as a live `startCalamity`
  would". Verified what that function actually does (`Sim.lua:1374-1415`): it sets `c.day = S.day`, the end date
  `tickCalamity` compares against; takes 30% of every tribe's food; runs `beastTide` and a population hit; shoves
  entities and players; destroys camps; notifies everyone. On every load during a flood that re-steals the food
  and pushes the end date forward, so **the calamity never ends** — and the autosave is every two minutes. The
  fix is a split: `Calamity.applyOverlay` (idempotent, tiles only, what load calls) and `beginCalamity` (the
  one-time half, which only `tickCalamity` calls). Two of the six blockers now come from a previous round's
  repair, which is the argument for auditing the repairs and not just the plan.
- **`Save.lua` was in two places at once** — `server/` in §4, `shared/` in step 1 — which is precisely the
  "verification cannot run where the plan says" defect round 3 raised, reintroduced by round 3's own fix. Settled:
  `shared/Save.lua` is the pure half (encode, decode, migrate, catch-up, prune) and lives inside `npm test`;
  `server/Persistence.lua` is the DataStore adapter and is the only file where saving touches Roblox.
- **"The route is derived from `from`/`to`" was not true of the code.** There is no `g.to` — `makeGroup`
  (`Sim.lua:411`) takes it as an argument and stores only `from` — and `tickGroups` replaces `g.route` wholesale
  when a band takes its real ambush. Recomputing from a generate-time destination would teleport the band back to
  its day-one grace position on every load. Step 2 now stores `to` and rewrites it on every retarget.
- **The string-key rule was half a fix that its own new test certified.** Keys became strings; `Person.id`,
  `father`, `mother`, `spouse`, `children[]` stayed numbers, so the lookup still misses — and `decode(encode(t))`
  deep-equals fine, because both sides are equally wrong. Id-shaped *values* are strings now, with a separate
  assertion the deep-equal cannot fake. `Families.lua` is `--!strict`, so it is a type change, not a convention.
- **The 4-week catch-up cap was missing entirely**, and "elapsed seconds *becomes* `gameSeconds`" read as an
  assignment that wipes the calendar to day 1. Now `+=`, capped, with the reading settled (4 *in-game* weeks) and
  the consequence written down: past the cap the world slept. Related and verified: the live driver assigns
  `lastDailyTick = day` and runs one tick (`Sim.lua:1598-1602`), so a jumped day is never simulated — right for
  `Debug.jump`, wrong for a load, so catch-up replays the missed days itself.
- **Two of step 1's assertions could not run**: "with a player present" needs materialisation and `server/`, and
  the hourly group replay is not equivalent to live ticking (one lump traverses one leg where live does eleven,
  and `depositCarry` fires once instead of eleven times — caravans would arrive nearly empty). Groups replay at
  1 Hz, and every assertion now names the gate it runs in.
- **Three more durable fields were missing from the tree**: `regions[].live` is a *transient* materialised-animal
  count — persist it and `r.live[sp] < want` is false forever, so **animals never spawn again** (`Sim.lua:180,
  602, 619, 1551`); the group row needs `to`, `fullSize` (without it a reloaded 2-of-4 band never breaks,
  `Sim.lua:720`), `pauses`, `speed`, `lateTarget`, `kind`, `tribe`; and `tribes[].village` is a live table
  reference compared by **identity** at `Sides.lua:63`, so after a load no NPC recognises its own home — the input
  to half of part 1's side-taking. It becomes `villageId`.
- **CONSIDER, all taken:** `mapDiff` is the object layer and says so; pruning gets a real rule and lands with
  `Save.lua`, because it is what makes `people` sparse and therefore arms the string-key rule; the day maths goes
  in `shared/` beside `Calamity` and `DayCycle`; `sizeTier` and `chiefId` leave the v1 schema (no writer exists,
  and chiefs are rung 4); the lint gate's dependency on the gitignored `tools/luau/` binaries is stated.
- **Corrections to my own text:** round 3 claimed the family tree "detaches on the first load" — overstated.
  `reg.people` is dense today, so JSON gives an array and it survives by luck; the rule is prospective, and
  pruning is what runs the luck out. Also "exactly as `startCalamity` would" was wrong twice over, since the
  recomputed tile set differs slightly anyway; shared's median is ~74 lines, not 80.

**Nothing deferred.**
