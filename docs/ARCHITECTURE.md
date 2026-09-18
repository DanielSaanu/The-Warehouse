# Architecture: where the data lives

**Status: a plan, not the code.** Written 2026-09-18, before rung 3 part 2 (save and catch-up), because the
shape of the data decides whether saving is a morning's work or a rewrite.

Danzo's brief: *"set it up in a way where the data flows instead of congesting… a village has x amount of people,
those people are split into groups, those groups are split into individuals. Data that affects the group is
applied at the top level, data that applies to a family is at the group level, and so on… the data is in one
place, or several, whatever works, and the systems that rely on it are not directly moving it."*

That is the right instinct and this document turns it into something buildable.

---

## 1. What is actually wrong today

Not opinion — measured on the current tree.

**The creature record is a bag of forty fields.** One flat table per entity carries identity (`id, kind, sprite,
label, name, first, last, person, tribe, group, role, species`), a body (`hp, maxHp, atk, def, speed`), a
position (`x, y, facing, home, radius`), pathfinding scratch (`path, pathI, nextStepAt, lastPathAt,
blockedCount`), an AI mind (`state, target, npcTarget, threat, nextThink, windupAt, cooldownUntil, aggroUntil,
fleeUntil`) and a combat memory (`attacked, provokedBy, beatenBy, mercyGiven, escapeGiven, broken, invulnUntil,
nextHeal`). Six unrelated concerns in one table that every system reaches into. **That is the congestion.**

**Nothing owns anything.** `Sim.state.tribes` is written from four files (Sim, Interact, Sides, Debug);
`Sim.state.entities` from four. There is no module you can point at and say "this is the only thing that changes
a tribe's stock". So a change anywhere can break anything, and a reviewer cannot reason locally.

**The big file already broke a tool.** `Sim.lua` grew past Luau's type-inference budget and `npm run lint:luau`
failed outright; the only fix was splitting `Sides.lua` and `Debug.lua` out. It is 1,592 lines and eighteen
sections. `Hud.lua` is 1,021 lines and one class with 32 methods. The compiler is telling us what a reviewer
would.

**Everything is a linear sweep.** Eight `for _ in pairs(S.entities)` full sweeps on the server, twenty
`pairs(S.players)` sweeps in `Sim.lua` alone. `Sides.witnessed` sweeps every entity on **every blow that lands**.
At 19 people that was free. At 38 it is fine. At the hundreds rung 4 wants, with several players, it is not.

**Nothing durable is separable from the transient.** Rung 3 part 2 has to write this to a DataStore key with a
4 MB limit, and right now the thing to save and the thing to throw away are the same tables.

---

## 2. The shape: one tree, by tier

One serialisable **World Record**. No functions, no Roblox Instances, no back-references, no cycles. If it cannot
be JSON, it does not belong. Everything that must survive a restart lives here; **nothing else does**.

```
world
├─ meta        seed, day, dayStart, version
├─ map         ground[], object[], signs{}, villages[]        (from the seed; rarely changes)
├─ calendar    calamity { kind, active, day, warnedDay }
├─ regions[]   per 16x16: grass, deer, boar, wolf, forest, tide    ~36 rows
├─ tribes[]    type, size tier, stock{}, population, walled, surnames, news, chief   3 rows
│   └─ villages[]   name, bounds, spawn/bed/stall, roster, knowledge bank
├─ groups{}    caravan / squad / band / (rung 4: hire, warband)
│   │          route, pos, dir, members[], carry{}, morale, memory{}
│   └─ families{}   couples, children — the family IS a group, see §3
├─ people{}    id -> { first, last, sex, born, died, cause, killer, tribe, role, parents, children, spouse }
├─ players{}   userId -> { pos, inv, coin, rep{}, rest, goalStage, flags }
└─ world bits  camps{}, bags{}
```

**The tier rule, which is Danzo's rule made precise:**

> A fact lives at the **highest tier where it is still true of everything below it.**

- True of a whole tribe → tribe row. Prices, stock, size tier, what the tribe thinks of a player.
- True of a village → village row. Its roster, its knowledge bank, what happened *here*.
- True of a party → group row. A caravan's route and load; a hunting squad's morale; **a family's couples and
  children**. A family is a group that never leaves the village.
- True of one person → person row, and **only small fixed fields** (DESIGN.md §4's data budget).
- True of one player's relationship with a tribe → the player row, not the tribe's, and never per-person.

That last line is the one that keeps this inside a DataStore key. See §5.

---

## 3. The four rules

**R1. Entities are a projection, not data.** A live entity is a *view* of a person record plus transient scratch
(path, think timer, current intent). It is rebuilt from records when a player comes near and thrown away when
they leave. **Nothing durable is ever stored on an entity.** This is already half-true and works; making it a
rule is most of the win, because it is what makes the save boundary obvious: *save records, never entities.*

**R2. One writer per slice.** Every table in the tree has exactly one module allowed to mutate it. Everyone else
reads, through that module's accessors.

| Slice | Only writer |
| --- | --- |
| `regions` | `Ecology` |
| `tribes[].stock`, prices | `Economy` |
| `people`, families | `Population` |
| `groups` (routes, carry, morale) | `Bands` |
| `players[].rep` | `Standing` |
| `players[].inv`, coin | `Inventory` |
| entities, positions, occupancy | `Bodies` |
| `calamity`, `day` | `Calendar` |

**R3. Systems ask, they do not reach.** A system that wants something to change in a slice it does not own calls
the owner's function — `Economy.deposit(tribe, goods)`, `Standing.witnessed(player, tribe, event)` — rather than
touching the table. The call is the contract and the place to put a log line, a test, or a save-dirty flag.

This is the direct answer to *"the systems that rely on it are not directly moving it"*. It is deliberately
**not** a full ECS or a message bus: those are a lot of machinery for a game this size, and the failure mode we
have is unclear ownership, not lack of indirection. One writer plus named functions fixes that.

**R4. Derived data is never stored.** Anything computable from the tree is computed. A tribe's "how do you feel
about this player" is `Witness.feel(...)` over stored numbers, not a cached matrix. Caches are where save bugs
and desyncs live.

---

## 4. The module map after

Shared stays as it is — it is already clean (18 files, median 80 lines, mostly pure Luau, testable outside
Studio). The server is what changes.

```
server/
  World.lua        the tree, load/save/migrate. Owns nothing else.
  Calendar.lua     day, clock, calamities                              (~120, from Sim)
  Bodies.lua       entities: spawn, move, occupancy, replication       (~260, from Sim)
  Brains.lua       think/chase/hunt/flee/wander, the AI states         (~300, from Sim)
  Fighting.lua     damage, death, loot, break points                   (~250, from Sim)
  Bands.lua        groups: routes, materialise/collapse, carry         (~200, from Sim)
  Wildlife.lua     spawning animals from region counts                 (~80,  from Sim)
  Population.lua   people, families, roles, succession                 (~120, from Sim)
  Economy.lua      stock, prices, deposits                             (~80,  from Interact+Sim)
  Standing.lua     reputation events, and later gossip and grudges     (~120, from Sim)
  Sides.lua        who takes whose side                                (exists, 278)
  Interact.lua     the F key                                           (exists, 341)
  Debug.lua        the test console                                    (exists, 214)
  Sim.lua          the tick loops and nothing else                     (~150)
```

`Sim.lua` stops being a cabinet and becomes what its name says: the thing that ticks. Every module lands under
Luau's inference budget, and each has one job you can name in a sentence.

The client wants the same treatment later — `Hud.lua` is 1,021 lines and one class — but it is not on the save
path, so it is not urgent and is out of scope here.

---

## 5. Not blowing up the machine

Two different budgets, and they fail differently.

### Memory and the 4 MB key

| Tier | Rows | Growth | Verdict |
| --- | --- | --- | --- |
| regions | ~36 | fixed | free |
| tribes / villages | 3 / 3 | rung 4 grows it | free |
| groups | ~3–40 | capped by design | cheap |
| **people** | grows with every birth, **never shrinks** | **unbounded** | **the one to watch** |
| players | one per account | per player | fine |

**The only unbounded thing is the dead.** Mitigations, in order: a person record carries only small fixed fields;
the long dead are pruned to `{ first, last, died, killer }`; and if it still grows, the registry moves to its own
DataStore key, chunked, because it is the one table that legitimately wants to be big.

**The forbidden shape is per-person-per-player.** Ten thousand people × fifty players is a matrix nothing
survives. Memory of a player belongs to the **village and the party**, never to each villager separately — which
is also what DESIGN.md §7 wants, since gossip travels by caravans and bands, not by a thousand diaries.

### CPU, per tick

The fix is one thing: **a spatial index.** Entities bucketed by region (already a 16×16 grid, already computed).
`Bodies.near(x, y, r)` walks the buckets in range instead of every entity in the world.

That single change turns eight full sweeps into neighbourhood lookups, and it matters most for
`Sides.witnessed`, which runs on **every blow that lands**. Everything else — `nearestPlayer`, `nearestFree`,
`nearestArmedKin`, `litCampNear`, `bagAt` — falls out of the same index.

Rung 4 also wants the tiering already in DESIGN.md §4 to become real: groups far from every player stay abstract
records and never materialise, and a distant village ticks once a day instead of every second.

---

## 6. How we get there without stopping the game

A strangler, not a rewrite. Each step is its own PR, ends green on `npm test` and `npm run lint:luau`, and leaves
the game playable. Nothing below requires a flag day.

### The mechanics of moving code, which are already proven here

Splitting `Sides.lua` and `Debug.lua` out of `Sim.lua` worked, and it worked a particular way. Reuse it:

- **The new module never requires `Sim`.** `Sim` requires *it*, and calls `Module.bind(ctx)` once during
  `Sim.init`, passing the innards it needs. No require cycle, no globals, and the bind call is a written list of
  exactly what that module depends on — which is a design review in itself. If a bind list is long, the seam is
  wrong.
- **Move text verbatim first, rename after.** Cut the functions across unchanged, get green, *then* rename and
  tidy in a second commit. Mixing a move with a rewrite is how a refactor turns into a bug hunt.
- **Watch for bare calls to moved locals.** A `local function canFight` that becomes `Sides.canFight` leaves
  callers that still say `canFight(...)`, which is `nil` at runtime and silent until that branch executes. Luau's
  linter catches the unused definition, not the broken call. After every move: `/usr/bin/grep -n "[^.a-zA-Z_]name("`
  across the server, and start Play and read the Output before believing it.
- **Definition order is load-bearing.** Luau locals are lexically scoped; a helper used at line 400 and defined
  at line 900 is a nil global. `luau-analyze` reports it as `LocalShadow`, which is easy to misread as harmless.

### The steps

**Step 1 — `Bodies.near` (the spatial index).** No shape change, pure win, de-risks everything after.
- Add `region -> { entity ids }` buckets, maintained in the two places a position already changes
  (`placeEntity`, `removeEntity`), so there is exactly one pair of write sites.
- `Bodies.near(x, y, r)` walks the 3×3 region block and filters. Regions are 16 tiles, so any radius ≤ 16 needs
  at most nine buckets.
- Convert the eight `pairs(S.entities)` sweeps one at a time, each with its own commit.
- **Verify:** a Luau test that a thousand random `near()` queries return exactly what a brute-force sweep returns.
  Then in Studio, `spawn` forty animals and compare `os.clock()` across a hundred `witnessed` calls before and
  after. The claim is a measured number, not "should be faster".

**Step 2 — carve `Calendar`, `Wildlife`, `Bands`.** Small, low-traffic, obvious seams, in that order.
- `Calendar` (~120): `Sim.clock`, `isNight`, `tickCalamity`, `startCalamity`/`endCalamity`. Almost no callers.
- `Wildlife` (~80): `spawnAnimal`, `tickWildlife`, `regionCenterNear`.
- `Bands` (~200): `makeGroup`, `materialise`/`collapse`, `tickGroups`, `groupStep`, carry and deposit.
- **Verify:** `npm test` plus a Studio session per PR — a squad completes a round trip and deposits, a calamity
  fires on schedule, wolves appear at night. These are the behaviours part 1 and 1b already proved, so a
  regression is obvious.

**Step 3 — carve `Fighting` and `Brains`.** The big ones, and only once the pattern is proven.
- `Fighting` (~250): `hitEntity`, `hitPlayer`, `killEntity`, `dropBag`, loot, break points.
- `Brains` (~300): `think` and the state steps (`chaseStep`, `huntStep`, `fleeStep`, `brokenStep`, `alarmStep`,
  `wanderStep`, `pickTarget`, `pickNpcTarget`).
- These two call each other, so they bind mutually through `Sim` rather than requiring each other.
- **Verify:** the whole part 1 QA script — welcome village defends, wary village watches, predation, band
  retreats at half. That script is the regression suite for this step and should be written down as one.

**Step 4 — name the owners (R2/R3).** Where the thinking is, and the only step that changes call sites rather
than moving them.
- Introduce `Economy`, `Standing`, `Population` as the sole writers of their slices.
- Convert writers one slice at a time: find every `S.tribes[i].stock` write (there are few), replace with
  `Economy.deposit` / `Economy.trade`. Repeat for `rep` → `Standing`, people/families → `Population`.
- **How to be sure a slice is really owned:** after converting, grep for direct writes and expect zero outside
  the owner. That grep belongs in the PR description as the evidence.
- Do `Economy` first: smallest surface, and it is what rung 3 part 5 (tribute and tax) will lean on.

**Step 5 — split durable from transient (R1).** The step that pays for part 2.
- Give the entity record an explicit `scratch` sub-table for path, timers and current intent, and move the
  transient fields into it. What remains on the entity is either a projection of a person record or position.
- Then `Bodies.spawnFrom(personId)` builds an entity from a record, and the save path can assert that no entity
  is ever reachable from the tree.
- **Verify:** a test that walks the world tree and fails on any function value, Roblox Instance, or cycle —
  i.e. "is this JSON-able". That test is the contract part 2 depends on, and it should exist before part 2 does.

**Step 6 — rung 3 part 2** writes and reads the tree, and catch-up replays the daily tick over it.

### Order, and what each buys

| Step | Size | Risk | Buys |
| --- | --- | --- | --- |
| 1 index | small | low | measured performance, headroom for rung 4 |
| 2 carve three | medium | low | the pattern proven, Sim shrinks ~400 lines |
| 3 carve two | medium | medium | Sim becomes the tick loops |
| 4 owners | medium | medium | "systems ask, they do not reach" is actually true |
| 5 durable/transient | small | low | saving becomes "write the tree" |

Steps 1–3 are mechanical. Step 4 is the design. Step 5 is the one part 2 cannot start without.

**A cheap escape hatch:** steps 1, 2 and 5 are independently valuable and can ship even if 3 and 4 are judged not
worth the churn. Nothing here is all-or-nothing.

## 7. What this costs, and what could go wrong

- **It is a lot of moving with no new gameplay.** Mitigated by ordering: the index is a real performance win on
  its own, and the carving steps are mechanical.
- **Churn against a live QA history.** Every refactor PR should run the loop, because "nothing regressed" is the
  entire claim being made.
- **Over-abstraction.** The honest risk is building a framework for a world with three villages. R3 is
  deliberately the lightest thing that fixes the actual problem. If a rule is not paying for itself, drop it.
- **The save format is a commitment.** Once players have saves, the tree's shape is load-bearing, which is
  exactly why this comes *before* part 2 and not after.

---

## 8. Open questions for review

1. **Is one tree right, or should the family registry be its own key from day one?** It is the only unbounded
   table and the only one that wants chunking.
2. **Is R3 (named owners) enough, or does anything genuinely need queued intents?** Two systems wanting to move
   the same person in one tick is the case to check.
3. **Is the family a group, or its own tier?** Modelling it as a group that never leaves the village is neat, but
   families overlap groups — a hunter in a squad is also somebody's son.
4. **Should villages be rows under a tribe, or their own tier?** Rung 4 gives one tribe several villages.
5. **What is the actual entity budget** on a phone with several players, and does the index alone reach it?
6. **Does catch-up work on the tree**, or does replaying days need state the tree does not keep?
