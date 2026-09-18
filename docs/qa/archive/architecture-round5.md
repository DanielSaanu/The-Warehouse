# Architecture plan review — round 5 — SCORE: 9.0/10 (the 5-round cap; bar was 9.5)

Reviewer: Opus subagent, 2026-09-18. The final round of Danzo's capped loop, asked to audit round 4's repairs as
suspects and to split whatever remained into true blockers and polish.

## Report (verbatim)

SCORE: 9.0/10

Environment: `npm test` green (node + 4 luau suites); `npm run lint:luau` ok on all 27 files.

ROUND 4 FIXES:
- `startCalamity` split into `applyOverlay`/`beginCalamity`: partial - the split is written and load calls only the overlay, but `Ecology.beastTide` is assigned to neither half (see NEW PROBLEMS). Flood half verified idempotent: `WorldGen.setFlood` self-clears (`WorldGen.lua:778-785`).
- `shared/Save.lua` vs `server/Persistence.lua`: landed - §4 map, step 1, step 6 and Q16 all agree; no contradiction left.
- Id-shaped *values* are strings: landed as written - §2 lines 103-110, plus the separate id-shape assertion. But it breaks two sorts (see NEW PROBLEMS).
- 4-week cap, `+=`, "the world slept", catch-up replays missed dailies: landed - arithmetic re-derived: 28 × 600 = 16,800 s = 4.67 real h = 16,800 1 Hz steps. Live driver confirmed assigning at `Sim.lua:1598-1602`.
- Groups replay at 1 Hz; every assertion names its gate; `observed` stub: landed.
- `regions[].live` transient: landed - `Sim.lua:1551` init, `:602` inc, `:180` dec, `:619` read confirmed.
- Group row gains `to`/`fullSize`/`pauses`/`speed`/`lateTarget`/`kind`/`tribe`; step 2 stores `to`: landed - `makeGroup` `Sim.lua:411-421` stores no `to`; `fullSize` read at `:720`.
- `tribes[].villageId`: partial - the decision is right, the site list is wrong (see CLAIMS).
- `mapDiff` = object layer; pruning rule; day maths in `shared/`; `sizeTier`/`chiefId` dropped; lint-gate caveat: landed.
- Self-corrections (dense `reg.people`, median ~74): landed and correct - median of the 18 shared files is (68+79)/2 = 73.5.

NEW PROBLEMS INTRODUCED BY ROUND 4'S FIXES:
- **`Ecology.beastTide` falls between the two halves of the split — blocker candidate.** `applyOverlay` is specified as "the flood tiles and `setFlood`, **or the region `tide` flags**"; `beginCalamity` is "`c.day`, the food cut, the population hit, the shoves, the camps, the notices". `Ecology.beastTide` (`Ecology.lua:131-142`) is the *only* function that sets tide flags, and it also does `r.wolf = math.min(CAP*2, r.wolf*2+3)` for all 36 regions. `wolf` is durable in §2's region row. An implementer who reaches for the existing function to satisfy "the region tide flags" re-doubles every region's wolves on **every load during a tide** — with a 2-minute autosave, wolves saturate at 12/region. Exactly the pattern rounds 3 and 4 hit.
- **String ids silently change `Families`' ordering.** `Families.lua:68` and `:177` sort `a.id < b.id`. With `"p1".."p12"` that is lexicographic: `"p10" < "p2"`. `Families.villagers` feeds `formCouples` (who pairs with whom), `weeklyConceive` (who conceives before the cap breaks), `successor` (who inherits the role) and `relatives`. Not a save blocker — both catch-up and live use the same comparator — but a silent gameplay change the plan does not mention, in the one module it says is a `--!strict` type change.
- **Camp keys become strings and the plan names no read sites.** `S.camps[uid]` is read at `Sim.lua:805, 1281, 1298, 1300, 1315` with a numeric `UserId`. `Sim.lua` is `--!nonstrict`, so nothing catches it; the fire simply never exists. The plan names all five `villageId` sites (wrongly, below) but zero camp sites.

CLAIMS CHECKED:
- "the five read sites (`Sides.lua:63`, `Interact.lua:38`, `Sim.lua:312, 477, 1406`) resolve through `Map`": **false** - there are **13** reads of `tribes[].village`, and **three** are pointer-equality, not one: `Sides.lua:63`, **`Interact.lua:80`** (`tribeAt`), **`Debug.lua:128`**. The eight unnamed: `Interact.lua:80, 94, 144`, `Sides.lua:180, 206`, `Sim.lua:932, 952`, `Debug.lua:128`. `Interact.tribeAt` returning nil is what the F key uses to know which village you are in — trade and guard dialogue die silently.
- §1 counts (Sim 18 / Interact 8 / Sides 5 / Debug 4): true - `grep -c` exact.
- `setFlood` idempotent: true - `if world.floodBackup then clearFlood end` (`WorldGen.lua:779`).
- `Sim.clock` 73 / `tickGroups` 542 / `groupTurn` 570 / `Debug.lua:79`: overstated by one each - actual 72, 543, 571 (call site), 80. `newEntity` 150, `removeEntity` 168, `makeGroup` 411, `pauseUntil` 416, `fullSize` 720, `droppedAt` 841, `camps` 1286, daily driver 1598-1602: all true.
- "shared … median ~74": true - 73.5.
- Cap arithmetic and §5's byte maths: true - re-derived.

GOALS:
1 tiered tree: met. 2 highest tier / derived not stored: met. 3 systems ask: met - R2 covers every node I could find. 4 ordered verifiable steps: partial - gates are excellent, but step 2's `villageId` work is scoped to 5 of 13 sites. 5 no context-burning file: met. 6 unblocks part 2: partial - six blockers closed; a seventh found, plus the beastTide ambiguity.

PRESERVE (right; must survive):
- §6's move mechanics, the per-step Gate column, the escape hatch: still the strongest part of the document.
- R1's round trip + the id-shape assertion the deep-equal cannot fake.
- The load-order sequence and the `applyOverlay`/`beginCalamity` split itself — the idea is right; only its edges leak.
- The 1 Hz group replay reasoning (one lump = one leg vs eleven) and the 16,800-step cost.
- `regions[].live` transient; `shared/Save.lua` vs `server/Persistence.lua`; the H9 testability argument.

FIX (wrong or missing; why it matters; concretely what to change):
- **Blocker 7: the load order never re-encodes the map clients draw.** `World.encoded = WorldGen.encode(world)` is computed **once**, inside `World.init()` (`World.lua:21`), immediately after `generate`; `Server.server.lua:78` ships that frozen buffer to every joining client forever. The plan's load order (regenerate → apply `mapDiff` → overlay) touches `World.world` only. Follow it literally and every persisted camp, bag and pickup exists on the server map and is absent from every client's: the client paints grass where `TileTypes.walkable` says the server has an obstacle, and moves get rejected with no visible cause. -> Add a step 4 to the load order: "**re-encode**: `Map.encoded = WorldGen.encode(world)` *after* the diff and the overlay; `Map.init` never encodes a map it has not finished loading."
- **Blocker 7b: `c.flood` is a live field the join payload reads, and the plan deletes it.** `Server.server.lua:79` sends `flood = c.flood`; `Client.client.lua:384` only calls `applyFlood` `if calamity.active and calamity.flood`. §2 says "no tile list: recompute on load". If `applyOverlay` does not repopulate the in-memory `c.flood`, a player joining a restored flooded world gets `nil` and never applies the flood — client dry, server water. -> Say `applyOverlay` returns the tile list and the caller assigns `c.flood`; it is transient, not saved.
- **`Ecology.beastTide` must be named explicitly.** -> "`applyOverlay('beast_tide')` sets `r.tide = true` and **nothing else**; the wolf surge in `Ecology.beastTide` is one-time and moves into `beginCalamity`, so `beastTide` splits too."
- **The `villageId` site list is wrong.** -> Replace with all 13, and flag the three identity comparisons (`Sides.lua:63`, `Interact.lua:80`, `Debug.lua:128`) as the ones that fail silently.
- **String ids and `a.id < b.id`.** -> "`Families.villagers`/`relatives` sort on the numeric suffix (or a stored `seq`), not the string, so pairing and succession order is unchanged by the id change."
- **Camp-key sites.** -> Name `Sim.lua:805, 1281, 1298, 1300, 1315`; `Sim.lua` is `--!nonstrict` so nothing will catch a missed one.

CONSIDER (defensible but worth changing; why; how):
- Offline reputation never fades: `Reputation.fade` runs inside `dailyTick` over `S.players` (`Sim.lua:1495`), so catch-up with nobody online skips it entirely. -> Fade on join by `day - lastSeenDay`, which the player key already stores.
- "Both ticks land in `shared/` as pure functions" — `tickGroups` (`Sim.lua:543-577`) also does `materialise`/`collapse`/`anyPlayerWithin`, which cannot leave `server/`. -> Name the seam: the abstract advance (pause gate, `acc`/`speed`/`pos`, `groupTurn`, `depositCarry`, the `lateTarget` retarget) is pure; materialise/collapse stay in `server/Bands`. Also `depositCarry` prints `t.village.name` — the pure half returns events, the adapter prints.
- Calamities are absent from the catch-up replay list (hourly groups; daily ecology/families/economy). A capped jump over a calamity day leaves `c.day`/`c.warnedDay` stale. -> One line: "the world slept through it; `warnedDay` is reset to the post-catch-up day."
- Three line numbers off by one (73→72, 542→543, 570→571, `Debug.lua:79`→80).

VERDICT FOR THE OWNER (this is the last round — be direct):
- **Does it clear 9.5? No — 9.0.** Every one of round 4's fourteen items landed, the arithmetic is right, and the document is now genuinely executable for most of its length; but a seventh blocker survives in exactly the place the brief pointed at (what a load does to state nobody enumerated — the pre-encoded map and `c.flood` that every *client* reads), and round 4's own calamity split left `Ecology.beastTide` unassigned to either half. The pattern has not stopped, but the gap is much smaller: these are four short paragraphs, not a re-plan.
- **TRUE BLOCKERS remaining for starting rung 3 part 2:** (1) re-encode `Map.encoded` after the diff and overlay; (2) `applyOverlay` repopulates the transient `c.flood`; (3) `Ecology.beastTide` splits — the wolf surge is one-time; (4) the `villageId` read-site list (13 sites, 3 identity comparisons) — this one blocks step 2, not step 1.
- **POLISH that can be done while coding:** the `a.id < b.id` sorts, the camp-key sites, offline rep fade, the `tickGroups` pure/impure seam, calamity-days-during-catch-up, the four off-by-one line numbers.
- **If you were starting step 1 tomorrow, the one thing you would still want written down:** a short "what a load hands the *client*" section — `Map.encoded` is rebuilt after the diff and overlay, and `c.flood` is repopulated — because everything else in the plan describes the server's tables and this is the only state that silently desyncs the two.

UNCERTAIN:
- Whether Roblox's `JSONEncode` emits an array for a dense numeric table (reasoned, not measured) — inherited from round 4.
- Real per-tick CPU and the true cost of a 16,800-step replay: no Studio run permitted.
- Whether `applyFlood(nil)` on a client that never applied a flood is harmless (`WorldGen.clearFlood` early-returns without a backup, so it looks safe, but I could not run it).

## Builder decisions

9.0 against a bar of 9.5, at the 5-round cap, so **the loop closes here and Danzo decides what happens next**.
All six FIX items taken and all four CONSIDER. Verified in the code first, as every round.

- **Blocker 7 is real and it is the one class of state nobody had looked at: what a load hands the *client*.**
  Verified `World.encoded = WorldGen.encode(world)` inside `World.init` (`World.lua:21`), shipped to every
  joining player at `Server.server.lua:78` and never recomputed. The load order regenerated the server's map and
  left that buffer frozen, so every restored campfire and bag would exist on the server and on nobody's screen —
  the client paints grass, the server refuses the move, and nothing errors. Load now has a fourth step, and the
  plan has a short **"What a load hands the client"** section, which is also what round 5 said it would most
  want written down before starting step 1.
- **7b, the same class:** `c.flood` is sent in the join payload (`Server.server.lua:79`) and the client applies
  the flood only if it is present (`Client.client.lua:384`). §2 is right not to save the tile list, but
  `applyOverlay` has to put it back in memory. It now returns the list and the caller assigns it.
- **`Ecology.beastTide` was the third self-inflicted trap in three rounds.** Verified (`Ecology.lua:131-142`):
  the only function that sets the tide flags also doubles every region's wolves, and `wolf` is durable. An
  implementer satisfying "the overlay sets the tide flags" with the existing function would double the world's
  wolves on every load during a tide. `beastTide` splits too, and step 2 now carries the general lesson in one
  line: **before load calls anything, ask what else that function does.**
- **The `villageId` site list was wrong in my own text** — five sites, and there are twelve, of which **three**
  are pointer equality rather than one. The one that hurts most is `Interact.tribeAt` (`Interact.lua:80`), which
  is how the F key knows which village you are standing in: silently broken means trade and guard dialogue stop
  working with no error.
- **The string-id change had two silent consequences in `Families`**: `villagers` and `relatives` sort
  `a.id < b.id`, which on `"p1".."p12"` is lexicographic, and that order decides pairing, conception and
  succession. Sort on the numeric suffix. And the camp keys have five read sites in a `--!nonstrict` file, where
  a miss does not error.
- **CONSIDER, all taken:** reputation never fades for an absent player because `Reputation.fade` lives in the
  daily tick over `S.players` — it moves to a join-time fade over `day - lastSeenDay`; `tickGroups` has a seam
  (the abstract advance is pure, materialise/collapse are not, and the pure half returns events instead of
  printing); a calamity the world slept through does not happen, and `warnedDay` resets.
- **One correction against the reviewer:** it called `Debug.lua:79` an off-by-one and asked for 80. Checked —
  69, 75 and 79 are exact, and 80 is wrong. The other three (`Sim.clock` 72, `tickGroups` 543, `groupTurn` call
  site 571) were right and are fixed.

**Nothing deferred.** What round 5 classified as polish is written down too, because the loop is closing and
there is no round 6 to carry it.
