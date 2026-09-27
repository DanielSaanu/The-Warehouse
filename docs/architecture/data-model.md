# Architecture §1–§3: what was wrong, the shape, the five rules

Part of [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), which maps every § and rule ID to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of ARCHITECTURE.md, wherever it now lives.

## 1. What is actually wrong today

Measured, not asserted.

- **The creature record is a bag of ~47 fields.** `newEntity` (`Sim.lua:150`) sets 31; another 16 are bolted on
  later. Identity, body, position, pathfinding scratch, an AI mind and a combat memory in one table that every
  system reaches into. **That is the congestion.**
- **Nothing owns anything.** `S.tribes` is touched from four files and written from two (Sim, and
  `Interact.lua:167,293,305`). There is no module you can point at and say "this is the only thing that changes a
  tribe's stock".
- **`Sim.lua` is 1,617 lines** (~20k tokens). It and `Hud.lua` are `--!nonstrict`, so the type checker is barely
  looking. Twelve full entity sweeps, twenty `pairs(S.players)` sweeps.
- **Nothing durable is separable from the transient**, and the durable parts are stamped with a clock
  (`os.clock`) that resets to zero on every new server.

---

## 2. The shape: one tree, by tier

One **World Record**: plain data. No functions, no Instances, no cycles, no object references — ids only.

```
world
├─ meta        version, genVersion, seed, gameSeconds, savedAt, rngState,
│              nextBagId, nextRumourId, lastDailyTick, headlines[]
├─ calendar    calamity { kind, active, day, warnedDay }
├─ regions[]   per 16x16: grass, deer, boar, wolf                 36 rows, fixed
├─ tribes[]    type, villageId, stock{}, population, walled, surnames, news
├─ villages[]  id, knows[]                (rung 3 part 3: knows[] is what this village has heard. tribeId derived)
├─ rumours[]   id, about, event, victim, victimPerson, tribe, day, hops, mult   (part 3: a 64-row ring)
├─ groups{}    id, kind, tribe, from, to, pos, dir, acc, speed, pauses, fullSize, knows[],
│              lateTarget, carry{}, members[] {kind, role, person}, pauseUntil, replenishAt, retreatUntil
├─ people      nextId, rows: the full Families.Person minus `entity` (`group` = on the road with that group)
├─ camps{}     owner, x, y, litUntil, out
├─ bags{}      id, x, y, owner, slots, droppedAt, public
└─ players     a SEPARATE DataStore key per player (DESIGN §14):
               version, pos, inv, coin, rep{}, grudge{}, rest, goalStage, flags, lastSeenDay, lastGroupId
               rep{} is keyed by HOLDER ("v1".."v3", or a group id), grudge{} by tribe type (RUNG3.md part 3)
```

**What is deliberately *not* in the tree** — each of these is in memory today, and saving any of them is a bug:

| Not stored | Why | Rebuilt from |
| --- | --- | --- |
| the map (`ground`, `object`) | derived (R4) | `meta.seed` via `WorldGen.generate` |
| camp and bag tiles on the map | derived: every runtime `world.object` write (`Sim.lua:842, 1283, 1287, 1302, 1317, 1340, 1366`) is a stamp of a camp or bag row | re-stamped from `camps`/`bags` on load |
| flood tiles, `floodBackup`, `calamity.flood`, `regions[].tide` | an overlay derived from `calamity.kind` | `Calamity.applyOverlay` (§6 boot order) |
| `groups[].route` | derived from `from`/`to` | `WorldGen.route` on load, `pos` clamped |
| `regions[].live` | the count of *materialised* animals (`Sim.lua:180, 602, 619, 1551`); persisted, `r.live[sp] < want` is false forever and nothing ever spawns again | zeroed on boot |
| `regions[].forest/open/col/row/village`, village name/bounds/spawn | derived from the map | the map |
| every entity id: `person.entity`, `g.entities`, `g.leader`, `g.target`, `t.guard`, `t.merchant`, `t.survivor` | the `"e"..n` counter restarts, so a stale id **collides** with a new object rather than dangling | `restore` re-points them (A4) |
| `day`, `dayFraction` | derived from `gameSeconds` | `DayCycle` |
| a family | derived index over `father/mother/spouse/children` | `Families` |
| `sizeTier`, `chiefId`, village `bank` | no writer exists; rung 4 | — |

**The tier rule, which is Danzo's rule made precise:**

> A fact lives at the **highest tier where it is still true of everything below it** — and if it is *derived*
> from anything else, it is not stored at all (R4).

- True of a tribe → tribe row: stock, surnames, which village is theirs (by id).
- True of a village → village row: from part 3, **what happened here**.
- True of a party → group row: where it is going, load, who is in it.
- True of one person → person row, small fixed fields only.
- True of a player's relationship with a tribe → **that player's own key**, never the tribe's, never a villager's.

**A family is not a group.** It is a derived index over person fields. **Groups are only things with a route, a
position and members.**

### Ids stay numbers. The *serialised* form has no id-keyed maps.

DataStore serialises to JSON, and JSON object keys are strings: a sparse `{ [7] = person }` comes back
`{ ["7"] = person }` and `reg.people[p.father]` silently returns nil. Three nodes are id-keyed in memory:
`people.people` (`Families.lua:30`), `camps` (by `UserId`) and `bags` (already string ids — fine).

The fix lives **entirely inside `Save.encode`/`Save.decode`**: id-keyed maps are written as **arrays of rows that
carry their own id** (`Person.id`, `camp.owner` — both fields exist today), and `decode` rebuilds the in-memory
index. JSON number *values* round-trip as numbers, so `father = 7` needs no change. Nothing outside `Save.lua`
knows. *(An earlier revision turned every id into a string instead; that was a type change across `--!strict`
`Families.lua`, silently changed the sort order that decides pairing and succession — `"p10" < "p2"` — and
touched five camp read sites in a `--!nonstrict` file. It is reverted: §9.)*

---

## 3. The five rules

**R1. Live objects are projections; the durable half is a named sub-table.** An entity is a view of a person
record plus scratch. **The live player record is a projection too** — `Sim.lua:1515` puts a `Player` Instance, a
function, `budget` and `-math.huge` in the same flat table as `inv` and `rep`. Its durable half moves to
`ps.save`, and the save writes only that. *Save records, never live objects.*

**R2. One writer per slice.** Ownership is by **field path**, so two systems can own different fields of one row.

| Slice | Only writer |
| --- | --- |
| `meta.gameSeconds`, `.lastDailyTick`, `calendar.calamity` | `Calendar` |
| `meta.version`, `.genVersion`, `.seed`, `.savedAt`, `.rngState` | `Save` (stamped at encode; `rngState` is a snapshot of the one `Rng`) |
| `meta.nextBagId`, `camps`, `bags`, their tiles on the map | `Tiles` |
| `meta.headlines`, `tribes[].news`, `.population`, `.surnames`, `people` | `Population` |
| `tribes[].type`, `.walled`, `.villageId`, `villages[].id` | written once by `generate` (A4), never after |
| `villages[].knows`, `groups[].knows`, `rumours[]`, `meta.nextRumourId` | `Standing` (rung 3 part 3; the rule is `shared/Gossip.lua`) |
| `tribes[].stock`, player `inv`, `coin` | `Economy` |
| `regions[]` counts | `Ecology` (exists, pure) |
| `groups{}` | `Bands` |
| memory on villages and groups (part 3), player `rep`, `grudges`, `goalStage`, `flags`, `lastSeenDay` | `Standing` |
| entities, occupancy, player `pos`, `rest` | `Bodies` |

**`Bands` must never recreate a group row wholesale** once part 3 hangs `memory` on it. Grow and shrink rows.

**R3. Systems ask, they do not reach.** `Economy.deposit(tribe, goods)`, not `t.stock.hide += n`. The call is the
contract, and the place for a log line, a test, or a save-dirty flag. Deliberately **not** an ECS or a message
bus: the failure mode here is unclear ownership, not too little indirection.

**R4. Derived data is never stored.** See the table in §2. The test for any new field: *can I recompute this from
something else in the tree plus the seed?* Then it is not in the tree.

**R5. One clock, and it is game time.**

- `os.clock()` restarts near zero on a new server, and today it stamps `S.dayStart` (`Sim.lua:1548`),
  `camps.litUntil` (`:1286`), `bags.droppedAt` (`:841`), `groups.pauseUntil` (`:416`, `groupTurn`),
  `replenishAt`, `retreatUntil` — all in tables the tree persists — and `Sim.clock()` (`:72`) derives the day
  from it, so catch-up has no calendar to advance.
- **`Calendar.now()` returns `meta.gameSeconds`**, an accumulator (`+= dt` per tick; catch-up adds a lump).
  **Every sim timer, durable or not, is an absolute `gameSeconds` value.** One unit, no "day plus fraction", no
  "remaining seconds rehydrated on load" — a timer that is already in game time needs nothing done to it on
  load, and it expires correctly across a catch-up for free.
- `os.clock` survives in exactly two places: `Movement.newBudget` (a per-tick budget) and profiling prints. A lint
  rule in `tools/luau-check.js` fails any other use in `server/` (allow-list by file:function).
- `os.time()` is read in exactly one place: `meta.savedAt` at save, and `os.time() - savedAt` at load, which is
  how the world knows how long it slept.
- **Known consequence:** `Debug jump` moves `gameSeconds`, so campfires burn out and bags expire across a jump.
  That is correct — time passed — and it is a behaviour change QA should expect.
