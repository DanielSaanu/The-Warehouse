# Architecture §10–§12: where the build departed, rung 3 part 3, and dev mode

Part of [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md), which maps every § and rule ID to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of ARCHITECTURE.md, wherever it now lives.

## 10. Where the build departed from the plan (Track A, 2026-09-18)

Written after building it, because a plan that is not corrected by its own implementation becomes fiction.

1. **R1's `ps.save` sub-table became a whitelist.** `inv`, `rep`, `goalStage` are read at ~100 sites across four
   `--!nonstrict` files; moving them under `ps.save` would have been a hundred chances at a silent nil. Instead
   `Save.encodePlayer` copies **named fields**, and `Save.encode` does the same for every node of the world — so
   nothing is saved by accident, and "what is durable" is one list per node in `shared/Save.lua`.
2. **`Calendar.now()` is continuous, not tick-fed.** It folds `os.clock()` deltas into `gameSeconds` on every call,
   so attack cooldowns keep their resolution and there is exactly one sim-side wall-clock read.
3. **The calendar only moves forward.** With absolute timers, a backwards `Debug day` would leave every NPC's next
   thought hours in the future. `setDay` refuses the past; `skipTo(frac)` means "the next time it is that hour".
4. **The `os.clock` rule and the line ceiling live in `test/structure.test.js`**, not in the Luau linter: `npm test`
   runs everywhere, the linter needs a gitignored binary. The ceiling is a ratchet — each allow-listed file has its
   own limit that may only shrink — and it stopped this build twice, which is what it is for.
5. **`server/Restore.lua` exists.** The restore constructor needs Sim's innards and Sim was at its ceiling, so it is
   a bound module like `Sides` and `Debug`. `Sim.init(saved, slept)` runs exactly one constructor.
6. **The lease contends instead of forbidding.** A server that finds a live lease plays without saving, and takes
   over when the lease runs out — so a crash costs at most `LEASE_SECONDS` of not saving, where the plan's version
   would have left a quick-restarted server NO-SAVE for its whole life.
7. **`children[]` is not saved** (derived from `father`/`mother`, R4) and is rebuilt by `decode`.
8. **Catch-up at the cap costs 3 ms**, measured in `tick.test.luau`. No slicing needed.
9. **`headlines[]` was carried by the format with no writer; it has one now** (`shared/Headlines.lua`, branch
   `headlines`): births from the pure tick, deaths and calamities from Sim, read once on join.

---

## 11. Rung 3 part 3: gossip, and what it does to this document (decided 2026-09-23)

Written by the heavy session for handoff H1. The full spec is `docs/RUNG3.md` §"Part 3 — Gossip and grudges";
only what is *architectural* is here, so this document stays the one place the shape of the data is stated.

1. **Reputation stays stored, and is re-keyed from tribe type to holder.** A "holder" is a village or a group —
   the two things that can know something and can meet each other. `ps.rep` is keyed `"v1".."v3"` (villages) and
   by group id, sparse, with a fallback chain holder → its village → `Reputation.START[tribeType]`. It is **not**
   derived from memory: memory is capped, and a reputation recomputed from capped memory heals when the cap
   evicts, which is the opposite of what DESIGN §7 asks for. **Memory is the transport; rep and grudge are the
   ledger.** The read path therefore stays one table lookup per read — no scan, no cache.
2. **Three new nodes, and their tier** (§2's tree is updated): `rumours[]` at the world (a ring: it is news in
   flight, true of nobody in particular), `knows[]` on each **village** row and each **group** row. Village memory
   is on `villages[]`, *not* on the tribe row, because §8.4 settles that villages are their own tier — "what this
   village heard" is not true of the whole tribe. This is the first writer `villages[]` has ever had, which §2
   reserved for exactly this.
3. **A rumour stores the event, not its consequences** (R4): `Reputation.deltas` is re-derived at the moment the
   rumour is applied, so a saved rumour can never disagree with the rule, and the row is smaller.
4. **`knows[]` is both the memory and the dedupe set.** Appending a rumour id *is* applying it, so double-booking
   is impossible by construction rather than by a flag.
5. **Nothing decays by ticking, and this is now a rule (learnings P2).** Grudge "decays over years" while catch-up
   caps at four in-game weeks; there is no conflict because decay is a **closed form over a day count**, the way
   `Reputation.fade(v, days)` already is at `Restore.player`. Every span is in **in-game days**, and a world
   nobody plays does not age.
6. **Gossip spreads during catch-up, on a schedule derived from `gameSeconds`.** This does **not** reopen §9's
   "one stated granularity": *movement* stays 1 Hz. Contact is evaluated when `math.floor(now / Gossip.EVERY)`
   increments, which is a pure function of game time, so n live seconds and `catchUp(n)` produce the identical
   sequence of exchanges — and A2's existing invariant test is extended to assert it.
7. **The save step is the first in-place migration**: world `VERSION` 2 → 3, adding empty nodes, losing nothing,
   resetting no world. `WorldGen.GEN_VERSION` is **not** touched (bumping it discards the world). The **player**
   key does **not** bump: `Save.applyPlayer` discards the whole record on a version mismatch, so player-key changes
   must always be additive-optional (learnings P1).
8. **R2 is unchanged and pre-satisfied**: `Standing` was already named the owner of "memory on villages and
   groups, player `rep`, `grudges`". Part 3 builds `server/Standing.lua` and moves `Sim`'s `applyRep` into it,
   which is B3's first step arriving early — and it is not optional, because `Sim.lua` is 1282 lines against a
   1285 ratchet that may only shrink.

**None of §9's six decisions is touched.** Item 6 above is the only one that even brushes against the §9 rider on
granularity, and it is compatible for the reason given there.

---

## 12. Development mode: a save that is never touched (handoff H4, 2026-10-05)

Danzo: *"project wide we are in DEVELOPMENT mode … we need to not worry about my personal save … easily able to
test things … easily turned off so that we can have testing from the perspective of an ordinary player."* He settled
the shape himself: (1) dev mode saves **nothing at all**, (2) it is **forced off outside Studio**, (3) it is
**toggled in Studio**, not in code.

**The switch.** A boolean attribute `DevMode` on **Workspace** (Explorer → Workspace → Properties → Attributes).
Workspace was picked because it is not in `default.project.json`, so Rojo never resets the attribute, and it already
holds the console's `Debug` / `DebugResult` attributes. The rule is pure, `shared/DevMode.lua`
(`resolve(isStudio, flag)`, tested in `test/luau/devmode.test.luau`); `server/Dev.lua` reads it **once at boot**:

| | Studio, `DevMode` ticked or **not set** | Studio, `DevMode` unticked | Live / published server |
| --- | --- | --- | --- |
| DataStore | never opened: no read, no write | the real save (`Lowlands_v1`) | the real save |
| World | fresh every Play (seed `WORLD_SEED`) | Danzo's saved world | the saved world |
| Debug console | `Workspace.Debug` attribute + `ServerStorage.Debug` | absent | absent |
| On join | one notice line "DEV mode: nothing is saved …" | nothing | nothing |

**Why each choice.**
- **Not set = on.** The project is in development, and the failure that matters is writing a throwaway world over
  the real one. Only an explicit `false` turns it off; a non-boolean (a typed string "false") counts as on.
- **Read once.** Unticking mid-Play would put a throwaway world on a path to the real save. A change takes effect
  on the next Play.
- **Through NO-SAVE, not a new mode.** `Persistence.loadWorld` returns NO-SAVE with the reason "DEV mode", so every
  existing guard (`saveWorld`, `loadPlayer`, `savePlayer` via `ps.noSave`, `BindToClose`) already refuses. On top of
  that `getStore()` errors in dev mode, so no later code path can open the real store by mistake. Debug `savetest`
  still works: it swaps in a store in memory, which `getStore` returns without touching the real one.
- **Debug is gated twice.** `Server.server.lua` creates neither the bindable nor the attribute listener, and
  `Debug.run` refuses on its own, for any script that reaches `Sim.debug` directly.
- **What an ordinary player could reach before this: nothing.** A client cannot set a Workspace attribute the server
  sees (client-side attribute writes do not replicate) and cannot see `ServerStorage`. So gating Debug makes the
  ordinary game *the same game* rather than closing a hole; only server-side code (the owner's server console, a
  plugin) could reach it, and a non-dev server now has nothing there to reach.

**What it does not change.** None of §9's six decisions: the failure policy (decision 5) gains one more reason to
be NO-SAVE and nothing else. The save format is untouched (`Save.VERSION` 4, `PLAYER_VERSION` 1). `Config.SAVE_WORLD`
still exists and still forces NO-SAVE everywhere. Verified in Studio 2026-10-05: not set → `[Dev] DEV mode ON`,
NO-SAVE, a day-1 world, Debug `state` and `savetest` work, the notice reaches the client; unticked → `[Dev] dev mode
off`, the real world loaded (day 52), no `ServerStorage.Debug`, the `Debug` attribute ignored, no notice.
