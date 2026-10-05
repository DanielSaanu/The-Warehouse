# Architecture §4–§5: the module map, the second reader (H1–H9), the budget

Part of [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), which maps every § and rule ID to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of ARCHITECTURE.md, wherever it now lives.

## 4. The module map after

```
shared/  (pure Luau — the only code `npm test` can run; `test/luau/run.js:12`)
  Save.lua         encode / decode / migrate / shape-check the tree            ~200   NEW (A4)
  Tick.lua         Tick.daily, Tick.groups, Tick.catchUp — pure over the tree   ~200   NEW (A2)
  Gossip.lua       rumours, who knows what, standing per holder, grudge        ~200   NEW (rung 3 part 3)
  Calamity.lua     + applyOverlay / the one-time half as data                 (exists)
  DayCycle.lua     + day/fraction from gameSeconds                            (exists)
  WorldGen.lua     877 → generate / query / encode                              (B4)

server/
  Map.lua          the generated map: init, get, walkable, encoded   (exists as World.lua, 37)
  Persistence.lua  DataStore adapter: load, save, autosave, failure policy      ~150   NEW (A5)
  Calendar.lua     gameSeconds, now(), setDay(), calamity begin/end             ~120   NEW (A1)
  Bodies.lua       entities: spawn, move, occupancy, replication, wildlife      ~300
  Brains.lua       the think dispatcher, the AI states, targeting               ~250
  Fighting.lua     damage, death, loot, break points                            ~250
  Bands.lua        groups: materialise/collapse, members; adapter for Tick.groups ~200
  Tiles.lua        camps and bags, and their stamps on the map                  ~150
  Population.lua   adapter for Families + Tick.daily events → bodies            ~150
  Economy.lua      stock, prices, deposits, the player inventory slice           ~80
  Standing.lua     reputation events; later gossip and grudges                  ~150
  Sides.lua / Interact.lua / Debug.lua                          (exist: 278 / 341 / 214)
  Sim.lua          the tick loops and nothing else                              ~150
```

`server/World.lua` already exists and holds the *map*; it is renamed `Map.lua` (two require sites:
`Server.server.lua:11`, `Sim.lua:27`) so nothing called "world" sits next to the World Record.

**`Save.encode` returns a JSON-safe table, not a string** — pure Luau has no JSON encoder and DataStore takes
tables. "JSON-safe" is checkable without JSON: every table is either a dense array or string-keyed; every number
is finite; no functions, userdata or cycles. `Save.check(t)` asserts exactly that, which is what makes
`decode(encode(tree))` deep-equal `tree` a *meaningful* test in `npm test`: under that shape, real JSON is the
identity. `Persistence` measures the real byte size with `HttpService:JSONEncode` and logs it on every save.

---

## 4b. The codebase has a second reader, and it has a context window

**H1. A hard ceiling of 400 lines, target 250** — a check in `npm test`. Generated files exempt. Every allow-list
entry names what deletes it: `Sim.lua` 1617 (B1–B3), `WorldGen.lua` 877 (B4), `Hud.lua` 1021 and
`Client.client.lua` 653 (rung 3 part 5, the client split), `Viewport.lua` 429 (rung 4, or never: one job, 29 over).
**H2.** The first fifteen lines say what the file owns, and what it deliberately does not do.
**H3.** One job per file, and the filename is the job.
**H4.** Plain `require` by default; `bind(ctx)` only for a genuine cycle (`Brains` ↔ `Fighting`). `bind` takes an
untyped `ctx` into `any` locals, so `luau-analyze` cannot see a typo.
**H5.** Tests are the cheap way to read a rule (`witness.test.luau`).
**H6.** `roblox/src/server/README.md`: one line per module, updated in the same commit as any move.
**H7.** Greppable, stable names: `Economy.deposit`, not `handle`/`process`/`update`.
**H8.** One worked example per module header.
**H9.** New logic goes in `shared/` as pure Luau unless it touches a Roblox API; `server/` modules are thin
adapters. This is the rule that lets the model check its own work without Studio. **Pure functions return events;
adapters print, notify and spawn.**

---

## 5. Not blowing up the machine

**The 4 MB key.** `Families.MAX_PEOPLE` (per tribe type: 18 / 15 / 14; it was a flat 9) caps the *living per tribe*, so the registry grows at the death rate.
A full person record is ~274 B of JSON, pruned ~71 B: 4 MiB ÷ 274 ≈ 15,300 records ≈ 106 real days of continuous
simulation at one death per in-game day (the real rate is ≤ 0.9). **People are not the thing to watch. Memory per
holder, per player, was**, and that estimate is what part 3's shape was chosen to avoid: 43 holders × 5 entries ×
60 B ≈ 13 KB per player ever seen; 300 players ≈ 3.9 MB. Measured, a per-(holder, player) shape at 43 holders × 32
players × 3 entries really is **216 KB** — so it was rejected.

**Superseded by measurement, 2026-09-23 (rung 3 part 3, `docs/RUNG3.md`).** Holder memory is **not** per (holder,
player). It is **one world-level ring of rumour rows** (`rumours[]`, 64 rows × 117 B) plus a dense array of rumour
ids per holder (`knows[]`). The whole of it **does not grow with the number of players**: 300 players make the
same 64-row ring. Measured worst case, every holder knowing every rumour: **+9.6 KB** at today's 6 holders,
**+22.2 KB** at DESIGN §4's cap of 43 — about 1.4% of the key, against a world key measured at 15.7 KB on day 1
and 32.0 KB at day 120 with 110 dead. `knows[]` needs no cap of its own: a holder can know at most every rumour in
the ring, and an eviction compacts that id out of every holder in the same call. Per-player standing
(`rep` per holder, `grudge` per tribe type) stays in the player's own key: 449 B at its own worst case.

**Pruning is a rule from the first save.** A person dead longer than `PRUNE_DAYS` keeps `id, first, last, died,
cause, killer` and loses the rest; never deleted, because the living point at them. A pure function in
`Save.lua`, run at encode, with its own test.

**CPU.** Entities are capped at ~100 (DESIGN §4), so a full sweep is microseconds; the 10 Hz think loop is the
dominant cost and an index does not help it. **The spatial index is demand-driven**: built when a measurement
says a query is hot. Rung 4's answer is DESIGN §4's tiering, not an index.

**Catch-up cost.** At the cap: 16,800 group steps × ≤40 groups of integer arithmetic + 28 daily ticks. Measure it
in A2's test; if it exceeds ~50 ms, `Persistence` runs it in slices with `task.wait()` *before* the door opens
(§6 boot order), which is free because nobody is in the server yet.
