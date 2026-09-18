# Architecture plan review — round 1 — SCORE: 7/10

Reviewer: Opus subagent, 2026-09-18, reviewing `docs/ARCHITECTURE.md` (not a build). Verified the plan's factual
claims against the code and checked the design against `docs/RUNG3.md` part by part.

## Report (verbatim)

SCORE: 7/10

CLAIMS CHECKED:
- "forty fields on an entity record": true (understated) - `Sim.lua:140-162` `newEntity` sets 31 keys; another ~16 are attached later (`npcTarget, threat, alarm, attacked, provokedBy, beatenBy, mercyGiven, escapeGiven, broken, nextHeal, blockedCount, nextWitnessAt, aggroUntil, person, first, last`). ~47 distinct fields.
- "four files write S.tribes": true - `/usr/bin/grep -rn "S\.tribes" roblox/src/server/` → Sim 18, Interact 8, Sides 5, Debug 4.
- "eight full `pairs(S.entities)` sweeps on the server": true for Sim.lua exactly (625, 1082, 1087, 1265, 1324, 1382, 1560, 1571); understated server-wide — Sides 111/190 and Debug 37/144 make 12.
- "twenty `pairs(S.players)` sweeps in Sim.lua": true - `grep -c` → 20.
- "Sim.lua is 1,592 lines": false - `wc -l` = 1617 (and Hud 1021, WorldGen 877, Client.client 653, Viewport 429 are all exact).
- "Sim.lua grew past Luau's inference budget and lint failed outright": true in substance, wrong number - `Sides.lua:5-7` records "a 1800-line module had already reached" it. At today's 1617 lines `npm run lint:luau` prints `ok roblox/src/server/Sim.lua`. The ceiling is ~1800, not 1592, and both Sim and Hud are `--!nonstrict`, so the type budget is not what is actually protecting them.
- "R3 is deliberately not an ECS": true - one-writer + named accessors, no component storage, no systems registry.
- "regions ~36 rows": true - 96/16 = 6×6 = 36 (`Config.WORLD_WIDTH=96`, `WorldGen.REGION=16`).

GOALS:
- Tiered tree matching village→group→individual: partial - the tiers are right, but §2 draws families as children of `groups{}`, which is false (see FIX).
- "Data applied at the highest level it is true of": partial - the rule is well stated but §2 contradicts itself: line 69 puts "what the tribe thinks of a player" on the tribe row, line 74 says that belongs on the player row. The code already does the latter (`ps.rep[tribeType]`, `Sim.lua:653-657, 1495`).
- "Systems are not directly moving the data": met - R2/R3 plus the step-4 grep-for-zero-direct-writes evidence rule is the right weight for this size.
- "Say how it will be implemented": met - step 0-6 with verification per step, and the move mechanics in §6 are the best part of the document.
- "No file so large it burns the context budget": partial - the ceiling is right, §4b's `bind` rule works against it (see FIX).

PRESERVE:
- R1 (entities are a projection; save records, never entities): the whole save story rests on it, and step 5's "walk the tree, fail on any function/Instance/cycle" test is the correct contract.
- §6's move mechanics: bare calls to moved locals, definition order, move-verbatim-then-rename. These are the actual failure modes of this refactor and they are written from scars.
- The step-4 ownership proof (grep for direct writes, expect zero, put it in the PR): makes R2 checkable instead of aspirational.
- The escape hatch (1, 2, 5 ship alone): correct, and it is what keeps this from being a rewrite.
- H6 (server/README.md index) and H7 (greppable names): the two cheapest wins for a model reading this tree.

FIX:
- **Durable tables hold `os.clock()` timestamps.** `Sim.lua:1286` `litUntil = os.clock() + ...`, `:841` `droppedAt = os.clock()`, `:1548` `S.dayStart = os.clock()`, plus `g.pauseUntil/replenishAt/retreatUntil`. `os.clock` restarts near zero on a new server, so every camp, bag and group timer in the plan's own tree (`meta.dayStart`, `camps{}`, `bags{}`, `groups{}`) is garbage on load. This is a save blocker the plan never names -> add to step 5: every field that crosses the save boundary is stored as an in-game day/hour (or as remaining seconds, rehydrated on load), and the JSON-able test grows a rule that no persisted number came from `os.clock`.
- **`map ground[]/object[]` in the tree contradicts R4.** §2 itself says "from the seed". 96×96×2 layers ≈ 55 KB of derived data in every write, and a WorldGen change silently corrupts every existing save -> store `seed`, `width`, `height` and a sparse diff of player-caused changes; regenerate the rest. This also answers §8 Q7's worry directly.
- **Family is not a sub-node of `groups`.** `newEntity` gives an entity exactly one `group` field and `removeEntity` (`Sim.lua:183-190`) assumes one owner; a hunter in a squad who is also somebody's son needs two. Worse, family membership is already stored on the person (`Families.Person.spouse/father/mother/children`), so a family group row would be stored derived data — R4 violated by §2 -> delete the `└─ families{}` line; families are a derived index (`Population.familyOf(id)`) over person fields, and `groups` keeps only things with a route, a position and morale.
- **The forbidden shape is not per-person-per-player, it is per-holder-per-player.** RUNG3 part 3 puts memory on villages and groups. 3 villages + up to 40 groups ≈ 43 holders; at 5 entries × ~60 B that is ~13 KB *per player who was ever seen*, and 300 lifetime players ≈ 3.9 MB — the key dies from gossip, not from the dead -> state the rule as "a holder's memory is capped (N most recent, expired by day stamp)", and put per-player standing/grudge in the per-player DataStore key (DESIGN §14 already says player state saves separately; §5's table says only "fine").
- **Catch-up does not work on the tree today, and the plan does not check it.** `tickFamilies` (`Sim.lua:1461-1479`) only completes a birth `if me` — i.e. if the mother is currently materialised — so with no players, `Families.daily` adds the baby to the registry while `t.population`, `t.news` and the baby's entity are skipped. `weeklyConceive` meanwhile mutates regardless -> make the daily tick pure over records before part 2, and add it to step 5's verify: run 28 simulated days with zero entities and assert population, registry and region counts agree.
- **The people arithmetic is wrong in the plan's favour and should be replaced with the real one.** `Families.MAX_PEOPLE = 9` caps the *living* per tribe, so the registry grows only at the death rate, not "with every birth". A full person record is 274 B of JSON, pruned 71 B: 4 MiB / 274 = 15,307 records, / 71 = 59,074. At one death per in-game day (600 s) that is 15,307 days ≈ 106 real days of simulated time, ~410 pruned. People is *not* the one to watch; say so and move the warning to memory-per-holder.

CONSIDER:
- **Demote step 1.** DESIGN §4 caps materialised entities at 60 NPC + 40 animal. `Sides.witnessed` (`Sides.lua:190`) sweeps ≤100 entities of cheap `cheb` arithmetic per blow — microseconds. Of the eight Sim sweeps, only 1082/1087/1265/1324 are radius queries; 625 (fold-back), 1382 (flood) and 1571 (the 10 Hz think loop, the actual dominant cost) must touch every entity and the index does not help them at all, so "turns eight full sweeps into neighbourhood lookups" is overstated -> keep the measurement discipline, but order 0 → 5 → 2 → 3 → 4 and build the index when the `os.clock()` measurement step 1 already specifies says it is needed. The radius-16 claim is sound: a 3×3 block of 16-tile regions guarantees 16 tiles in the worst case, and `nearestArmedKin` uses exactly 16.
- **`bind(ctx)` as a standing rule (H4) fights H1's own goal.** `Sides.bind` (`Sides.lua:17-28`) takes an untyped `ctx` into `local S, world, faceEntity, ...`, all `any`, in a `--!nonstrict` file — no types, no go-to-definition, and `luau-analyze` cannot see a typo. It exists to break a cycle with a god object; once Sim is only the tick loops, Rojo siblings can plain-`require` each other -> keep `bind` only for the genuinely mutual pair (Brains↔Fighting), require everywhere else, and get the types back.
- **§4's line estimates have no headroom.** They sum to ~1680 for a 1617-line file, before H2's 15-line headers (×10 modules) and bind boilerplate. `Brains` 300 and `Fighting` 250 will land at 350-400 -> budget 250 and plan Brains as two files (states vs. targeting) from the start rather than re-splitting under the ceiling.
- **The size check should count tokens, not lines.** A 400-line file of dense table literals costs more than a 500-line file of `if` chains. Line count is a fine proxy to ship on day one; add "and no file over ~6k tokens" if it ever disagrees.
- **Add H8: one worked example per module header.** The thing that most helps a model here is not the dependency list, it is a two-line "the call that matters looks like this". §4b has seven rules and none of them show a call.

ANSWERS (§8 has seven questions, not eight):
- 1: No separate key for people yet, but per-player keys from day one (§14 already requires them). 15,307 full / 59,074 pruned records is ~100+ real days of simulation; add a `version` and a `people` sub-table that can be lifted into its own chunked key without touching the rest.
- 2: R3 is enough; no queued intents. The real contention is already handled by `busy`/`nextWitnessAt` guards in `Sides.witnessed:195-199`. What is missing is not a queue but reference hygiene: `removeEntity` does not clear other entities' `npcTarget`, `threat` or `alarm.to`, which is survivable for transient entities and fatal for durable ids. State it: the tree may hold ids, never object references, and every id read is nil-checked.
- 3: Its own thing, and not stored — a derived index over `Person.spouse/father/mother/children`. See FIX; the one-`group`-field entity model already refuses dual membership.
- 4: Its own tier, keyed by id, with `tribe` as a field. `Families.villagers(reg, tribe)` and `MAX_PEOPLE = 9` are per-tribe today; the moment rung 4 gives a tribe three villages, that cap starves two of them. Villages are also the gossip holders and the territory owners (§4), so they want to be looked up directly, not walked for.
- 5: ~100 materialised entities by DESIGN §4's own cap, and the cost that scales is players × entities (`tickInterest`, `Sim.lua:1264-1266`) and the 10 Hz think loop, neither of which the index fixes. The index alone reaches the *current* budget easily because the cap does; rung 4's answer is the §4 tiering (distant groups never materialise), which the plan correctly defers but should name as the real fix.
- 6: Not today — see the `tickFamilies` finding. On a tree with a pure daily tick, yes, with two additions: every timer in game-time, and a record of what changed during catch-up so the "you were gone eleven days" line has something to read.
- 7: 400 is the right number (it is ~5-6k tokens, one comfortable read), and yes, hold shared to it. `WorldGen.lua` at 877 should be in step 0's allow-list with a named owner and split into generate / query / encode *before* part 2, precisely because encode is the save format.

UNCERTAIN:
- Real per-tick CPU: I did not run Studio, so the claim that the index is not yet needed rests on the ~100-entity design cap, not on a measurement. Step 1's own before/after measurement would settle it.
- Actual death rate per in-game day (the input to the registry arithmetic). One per day is my estimate from 27 living villagers, wolves and bandits; the conclusion holds for anything under ~10/day.
- Whether DataStore's serializer is meaningfully denser than JSON for the map arrays; I used JSON byte counts throughout.

## Builder decisions

Scored 7/10, below the 8.0 target, so a second round follows. Every FIX taken; three of five CONSIDER taken.

**All six FIX items taken.** Three of them I verified in the code myself before acting, because they were the
kind of claim that decides the plan:

- **`os.clock()` in durable tables** — confirmed at `Sim.lua:416, 841, 1286, 1548`. This is the best find in the
  review: it is a save blocker that would have surfaced only after part 2 shipped and someone restarted a server.
  Now **R5**, and the first half of step 1.
- **Catch-up is broken today** — confirmed: `tickFamilies` completes a birth only `if me`, so with no players the
  registry gains a baby the population never hears about. Now the other half of step 1, with a 28-day
  zero-entity test as the verification.
- **The people arithmetic was wrong in my favour** — confirmed: `Families.MAX_PEOPLE = 9` caps the *living*, so
  the registry grows at the death rate. ~15,300 full records ≈ 106 real days. §5 now says people are *not* the
  thing to watch and moves the warning to memory-per-holder-per-player, which is where the key actually dies.
- **The map is derived** — §2 now stores seed plus a sparse diff of player-caused changes.
- **A family is not a group** — deleted from the tree; it is a derived index over person fields. The entity model
  refuses dual membership anyway, which I had not noticed.
- **§2 contradicted itself** on where "what the tribe thinks of you" lives. Fixed: the player's own key.

**CONSIDER — three taken, two noted.**

- **Demote the index** — taken, and it was right: the entity cap is ~100 and the think loop is the dominant cost,
  which an index does not help. It is no longer a step at all; it is built when a measurement says so.
- **`bind` fights the context goal** — taken. H4 now says plain `require` by default, `bind` only for the one
  genuinely mutual pair. The untyped-`ctx` cost is real and I had treated a workaround as a pattern.
- **H8, one worked example per header** — taken.
- **Line estimates have no headroom** — taken: budgeted at 250, and `Brains` is split into `Brains`/`Targeting`
  from the start.
- **Token count over line count** — noted in H1 as the fallback if the proxy ever disagrees, rather than shipped,
  because a line check is trivial and a token check needs a tokeniser in the test suite.

**Corrected in passing:** `Sim.lua` is 1,617 lines, not 1,592; the inference ceiling is ~1,800, not where we are;
and both big files are `--!nonstrict`, so the type checker was never the thing protecting them. §1 says so now.
