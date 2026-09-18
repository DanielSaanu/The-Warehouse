# Architecture: where the data lives

**Status: a plan, not the code.** Written 2026-09-18, before rung 3 part 2 (save and catch-up), because the shape
of the data decides whether saving is a morning's work or a rewrite. Revised after review; the verbatim report is
`docs/qa/archive/architecture-round1.md`.

Danzo's brief: *"set it up in a way where the data flows instead of congesting… a village has x amount of people,
those people are split into groups, those groups are split into individuals. Data that affects the group is
applied at the top level, data that applies to a family is at the group level, and so on… the data is in one
place, or several, whatever works, and the systems that rely on it are not directly moving it."*

---

## 1. What is actually wrong today

Measured, not asserted.

**The creature record is a bag of ~47 fields.** `newEntity` (`Sim.lua:140`) sets 31; another 16 are bolted on
later (`npcTarget, threat, alarm, attacked, provokedBy, beatenBy, mercyGiven, escapeGiven, broken, nextHeal,
blockedCount, nextWitnessAt, aggroUntil, person, first, last`). Six unrelated concerns — identity, body, position,
pathfinding scratch, an AI mind, a combat memory — in one table that every system reaches into. **That is the
congestion.**

**Nothing owns anything.** `S.tribes` is written from four files (Sim 18 sites, Interact 8, Sides 5, Debug 4).
There is no module you can point at and say "this is the only thing that changes a tribe's stock", so no change
can be reasoned about locally.

**Twelve full sweeps over every entity** on the server (eight in `Sim.lua`, two in `Sides.lua`, two in
`Debug.lua`), plus twenty `pairs(S.players)` sweeps in `Sim.lua` alone.

**`Sim.lua` is 1,617 lines.** It did break Luau's type inference once, at roughly 1,800 lines, and the fix was
splitting out `Sides.lua` and `Debug.lua`. Today it lints clean — **but both it and `Hud.lua` are `--!nonstrict`,
so the type checker is barely looking.** The inference budget is a tripwire we already hit, not a guard. The real
reason to split is §4b: a person and a model both have to read this.

**Nothing durable is separable from the transient** — and worse, per R5, the durable parts are timestamped with a
clock that resets to zero on every new server.

---

## 2. The shape: one tree, by tier

One serialisable **World Record**. No functions, no Roblox Instances, no cycles, and **no object references —
ids only**. If it cannot be JSON, it does not belong.

```
world
├─ meta        version, seed, day, dayFraction            (never os.clock; see R5)
├─ mapDiff     sparse { tileIndex -> objectId } of player-caused changes only
│              (the map is regenerated from the seed — it is derived, R4)
├─ calendar    calamity { kind, active, day, warnedDay }
├─ regions[]   per 16x16: grass, deer, boar, wolf, forest, tide          36 rows, fixed
├─ tribes[]    type, sizeTier, stock{}, population, walled, surnames, news, chiefId
├─ villages[]  id, tribeId, name, bounds, spawn/bed/stall, roster, bank, memory{}
├─ groups{}    caravan / squad / band / (rung 4: hire, warband)
│              route, pos, dir, memberIds[], carry{}, morale, memory{}
├─ people{}    id -> { first, last, sex, born, died, cause, killer, tribe, role,
│                      father, mother, spouse, children[] }
├─ camps{}, bags{}                                        (game-time timers, R5)
└─ players{}   a SEPARATE DataStore key per player (DESIGN §14):
               pos, inv, coin, rep{}, grudges{}, rest, goalStage, flags
```

**The tier rule, which is Danzo's rule made precise:**

> A fact lives at the **highest tier where it is still true of everything below it** — and if it is *derived*
> from a lower tier, it is not stored at all (R4).

- True of a tribe → tribe row: stock, size tier, surnames.
- True of a village → village row: roster, knowledge bank, **what happened here**.
- True of a party → group row: route, load, morale, what they saw.
- True of one person → person row, small fixed fields only.
- True of a player's relationship with a tribe → **that player's own key**, never the tribe's, never a villager's.

**A family is not a group.** It is a derived index over `Person.father/mother/spouse/children`
(`Population.familyOf(id)`). Storing it as a group row would be storing derived data (R4), and the entity model
refuses it anyway: `newEntity` gives an entity exactly one `group` field, while a hunter in a squad is also
somebody's son. **Groups are only things with a route, a position and morale.**

---

## 3. The five rules

**R1. Entities are a projection, not data.** A live entity is a view of a person record plus transient scratch,
rebuilt when a player comes near and thrown away when they leave. **Nothing durable is ever stored on an entity.**
This is what makes the save boundary obvious: *save records, never entities.*

**R2. One writer per slice.**

| Slice | Only writer |
| --- | --- |
| `regions` | `Ecology` |
| `tribes[].stock`, prices | `Economy` |
| `people`, roles, succession | `Population` |
| `groups` | `Bands` |
| player `rep`, grudges, village/group `memory` | `Standing` |
| player `inv`, coin | `Inventory` |
| entities, positions, occupancy | `Bodies` |
| `calamity`, `day` | `Calendar` |

**R3. Systems ask, they do not reach.** `Economy.deposit(tribe, goods)`, not `t.stock.hide += n`. The call is the
contract, and the place for a log line, a test, or a save-dirty flag. Deliberately **not** an ECS or a message
bus: the failure mode here is unclear ownership, not too little indirection.

**R4. Derived data is never stored.** The map comes from the seed. A family comes from person fields. "What this
tribe thinks of you" is `Witness.feel(...)` over stored numbers, not a cached matrix.

**R5. Stored time is game time; stored links are ids.** Two save-blockers, both live in the code today:

- **`os.clock()` restarts near zero on a new server.** `S.dayStart` (`Sim.lua:1548`), `camps.litUntil` (`:1286`),
  `bags.droppedAt` (`:841`), `groups.pauseUntil` (`:416`), `replenishAt` and `retreatUntil` are all `os.clock`
  based and all sit in tables the tree must persist. Loaded fresh they are garbage: every campfire out, every bag
  an hour old, every group paused forever. **Every persisted instant is an in-game day plus fraction; every
  persisted duration is remaining seconds, rehydrated on load.**
- **The tree holds ids, never references**, and every id read is nil-checked. `removeEntity` (`Sim.lua:183`) does
  not clear other entities' `npcTarget`, `threat` or `alarm.to` — survivable while entities are transient, fatal
  the moment an id is durable.

---

## 4. The module map after

Shared stays as it is — 18 files, median 80 lines, mostly pure Luau — **except `WorldGen.lua` at 877 lines**,
which is split into generate / query / encode before part 2, because `encode` *is* the save format.

```
server/
  World.lua        the tree: load, save, migrate. Owns nothing else.       ~200
  Calendar.lua     day, clock, calamities                                  ~120
  Bodies.lua       entities: spawn, move, occupancy, replication           ~250
  Brains.lua       the think dispatcher and the AI states                  ~250
  Targeting.lua    pickTarget / pickNpcTarget / preysOn                    ~150
  Fighting.lua     damage, death, loot, break points                       ~250
  Bands.lua        groups: routes, materialise/collapse, carry             ~200
  Wildlife.lua     spawning animals from region counts                     ~80
  Population.lua   people, families, roles, succession                     ~150
  Economy.lua      stock, prices, deposits                                 ~80
  Standing.lua     reputation events; later gossip and grudges             ~150
  Sides.lua        who takes whose side                          (exists, 278)
  Interact.lua     the F key                                      (exists, 341)
  Debug.lua        the test console                               (exists, 214)
  Sim.lua          the tick loops and nothing else                         ~150
```

Budgeted at **250, not 400**, so headers and boilerplate do not push a module through the ceiling. `Brains` is
split from the start rather than re-split under it later.

---

## 4b. The codebase has a second reader, and it has a context window

Claude writes most of this (Danzo, 2026-09-18: *"your coding this and your context matters"*). A 1,617-line file
costs ~20k tokens; a session that opens three has spent its budget before changing anything.

**H1. A hard ceiling of 400 lines, target 250** — a check that fails `npm test`, not a guideline. Today's
violators: `Sim.lua` 1617, `Hud.lua` 1021, `WorldGen.lua` 877, `Client.client.lua` 653, `Viewport.lua` 429.
Generated files exempt. Line count is a proxy; if it ever disagrees with real cost, add "and no file over ~6k
tokens".

**H2. The first fifteen lines say what the file owns** — its job, its slice, what it deliberately does not do.

**H3. One job per file, and the filename is the job**, so a task maps to a file before anything is read.

**H4. Plain `require` by default; `bind(ctx)` only for a genuine cycle.** `bind` was invented to break a cycle
with a god object and it costs real safety: `Sides.bind` takes an untyped `ctx` into a row of `any` locals in a
`--!nonstrict` file, so there is no go-to-definition and `luau-analyze` cannot see a typo. Once `Sim` is only the
tick loops, siblings require each other directly. Keep `bind` for the one mutual pair (`Brains` ↔ `Fighting`).

**H5. Tests are the cheap way to read a rule.** `witness.test.luau` states every side-taking case in assertions;
reading it is faster and less ambiguous than reading thresholds, and it cannot drift.

**H6. `roblox/src/server/README.md`: one line per module** — what it owns, how big — updated in the same commit
as any move. Read first, every session.

**H7. Greppable, stable names.** `Economy.deposit`, not `handle`/`process`/`update`.
`/usr/bin/grep -rn "Economy\."` should list a module's whole public surface without opening it.

**H8. One worked example per module header.** A two-line "the call that matters looks like this" is worth more
than a dependency list, because it shows the shape of correct use.

---

## 5. Not blowing up the machine

### The 4 MB key

The first draft warned about the wrong table. `Families.MAX_PEOPLE = 9` caps the **living** per village, so the
registry grows at the *death* rate, not the birth rate. A full person record is ~274 B of JSON, pruned ~71 B:

- 4 MiB ÷ 274 B ≈ **15,300 full records**; pruned, ≈ **59,000**.
- At roughly one death per in-game day (600 s), 15,300 days ≈ **106 real days** of continuous simulation.

**People are not the thing to watch. Memory per holder, per player, is.** Rung 3 part 3 puts gossip memory on
villages and groups: 3 villages + up to 40 groups ≈ 43 holders. At 5 entries × ~60 B that is **~13 KB per player
ever seen**, and 300 lifetime players ≈ 3.9 MB. The key dies of gossip, not of the dead.

What prevents it:
- **A holder's memory is capped**: N most recent, expired by day stamp. Bounded by design, not by hope.
- **Per-player standing and grudges live in that player's own key** (DESIGN §14 already saves player state
  separately). The world key holds what *places and parties* remember; the player key holds what the player
  carries.
- `people` is a versioned sub-table, so it can be lifted into its own chunked key later without touching the rest.

### CPU

The first draft over-claimed a spatial index. DESIGN §4 caps materialised entities at 60 NPC + 40 animal, so
`Sides.witnessed` sweeping ≤100 cheap `cheb` comparisons per blow is microseconds. Of the eight `Sim.lua` sweeps
only four are radius queries; the fold-back sweep, the flood sweep and **the 10 Hz think loop — the actual
dominant cost — must touch every entity anyway**, and an index does not help them.

So **the index is demand-driven**: built when a measurement says a query is hot, not on faith. The design is
sound when wanted — a 3×3 block of 16-tile regions covers any radius ≤ 16, which is what `nearestArmedKin` (16)
and `witnessed` (8) need.

Rung 4's real answer is the tiering DESIGN §4 already describes: distant groups stay abstract and never
materialise, and a far village ticks once a day. That, not an index, is what buys hundreds of NPCs.

---

## 6. How we get there without stopping the game

A strangler, not a rewrite. Each step is its own PR, ends green on `npm test` and `npm run lint:luau`, and leaves
the game playable.

### The mechanics of moving code, already proven here

Splitting `Sides.lua` and `Debug.lua` out of `Sim.lua` worked, and it worked a particular way:

- **Move text verbatim first, rename after.** Mixing a move with a rewrite turns a refactor into a bug hunt.
- **Watch for bare calls to moved locals.** A `local function canFight` that becomes `Sides.canFight` leaves
  callers saying `canFight(...)` — `nil` at runtime and **silent** until that branch runs. The linter flags the
  unused definition, not the broken call. After every move:
  `/usr/bin/grep -n "[^.a-zA-Z_]name(" roblox/src/server/*.lua`, then start Play and read the Output.
- **Definition order is load-bearing.** A helper used at line 400 and defined at line 900 is a nil global;
  `luau-analyze` calls it `LocalShadow`, which reads as harmless and is not.
- **One module per PR**, so a bisect lands on one move.

### The steps, in dependency order

**Step 0 — the ceiling and the index file.** `npm test` gains a check failing any non-generated `.lua` over 400
lines, landing with an allow-list of the five known violators that later steps delete entries from — a refactor
with a progress bar. Write `roblox/src/server/README.md`.

**Step 1 — make the tick pure over records, and fix game time.** *The step part 2 cannot start without, and the
review found both halves are broken today.*
- **Births only half-happen when nobody is watching.** `tickFamilies` (`Sim.lua:1461`) completes a birth only
  `if me` — if the mother is materialised. With no players, `Families.daily` adds the baby to the registry while
  `t.population`, `t.news` and the baby's body are skipped, and `weeklyConceive` mutates regardless. Catch-up
  would produce a registry that disagrees with the population it is meant to explain.
- **Every persisted timer moves to game time** (R5): `dayStart`, `litUntil`, `droppedAt`, `pauseUntil`,
  `replenishAt`, `retreatUntil`.
- **Verify:** run 28 simulated days with zero entities and assert registry, `t.population` and region counts
  match a run of the same 28 days with a player present. Plus a test that no persisted field came from
  `os.clock`.

**Step 2 — carve `Calendar`, `Wildlife`, `Bands`.** Small, low-traffic, obvious seams, one PR each; proves the
pattern. **Verify:** a squad completes a round trip and deposits; a calamity fires on schedule; wolves appear at
night — behaviours parts 1 and 1b already proved.

**Step 3 — carve `Fighting`, `Brains`, `Targeting`, `Bodies`.** The big ones, once the pattern is proven.
**Verify:** the part 1 QA script — welcome village defends, wary village watches, predation, band retreats at
half — written down as a regression script, because not breaking it is the whole claim.

**Step 4 — name the owners (R2/R3).** The only step that changes call sites rather than moving them. `Economy`
first (smallest surface, and rung 3 part 5 leans on it), then `Standing`, then `Population`. **The proof a slice
is owned:** grep for direct writes outside the owner, expect zero, and put that grep in the PR description.

**Step 5 — split `WorldGen.lua`** into generate / query / encode, because `encode` is the save format and should
not be buried in an 877-line file.

**Step 6 — rung 3 part 2** writes and reads the tree; catch-up replays the now-pure daily tick.

**The index is not a step.** It is built when a measurement says a query is hot.

| Step | Size | Risk | Buys |
| --- | --- | --- | --- |
| 0 ceiling + index file | tiny | none | a progress bar; the ceiling stops being optional |
| 1 pure tick + game time | medium | medium | **part 2 becomes possible at all** |
| 2 carve three | medium | low | the pattern proven, Sim sheds ~400 lines |
| 3 carve four | large | medium | Sim becomes the tick loops |
| 4 owners | medium | medium | "systems ask, they do not reach" becomes true |
| 5 split WorldGen | small | low | the save format is readable |

**Escape hatch:** steps 0, 1 and 5 are independently valuable and can ship even if 2–4 are judged not worth the
churn. **Step 1 is the only one that is not optional.**

---

## 7. What this costs, and what could go wrong

- **A lot of moving with no new gameplay.** Mitigated by ordering: step 1 is a bug fix part 2 needs regardless.
- **Churn against a live QA history.** Every refactor PR runs the loop, because "nothing regressed" is the claim.
- **Over-abstraction.** The honest risk is building a framework for three villages. R3 is the lightest thing that
  fixes the real problem; if a rule is not paying, drop it.
- **The save format is a commitment.** Once there are saves, the tree's shape is load-bearing — which is exactly
  why this comes before part 2.

---

## 8. Open questions

Settled by review, recorded so they are not re-litigated:

1. **One tree or a separate people key?** One tree, with `people` versioned as its own sub-table so it can be
   lifted out later. Player state gets its own key from day one, per DESIGN §14.
2. **Named owners, or queued intents?** Owners are enough; contention is already handled by the
   `busy`/`nextWitnessAt` guards. What was missing was reference hygiene, now R5.
3. **Is a family a group?** No — a derived index over person fields.
4. **Villages under tribes, or their own tier?** Their own tier, keyed by id with `tribe` as a field. Rung 4 gives
   a tribe several villages, and a per-tribe `MAX_PEOPLE` would starve all but one.
5. **Entity budget?** ~100 by DESIGN §4's cap. What scales is players × entities and the 10 Hz think loop;
   rung 4's answer is §4's tiering, not an index.
6. **Does catch-up work on the tree?** Not today — step 1 is what makes it true.
7. **Is 400 the right ceiling, and does shared obey it?** Yes and yes; `WorldGen.lua` is step 5.

Still genuinely open:

- **What must catch-up record** so the "you were gone eleven days" line has something to read?
- **Is DataStore's serialiser denser than JSON** for the sparse map diff? The budget above assumes JSON bytes.
- **What is the real death rate per in-game day?** The registry arithmetic assumes ~1 and holds under ~10.
