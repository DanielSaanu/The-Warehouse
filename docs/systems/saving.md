# Saving and catch-up

**What it does.** The world and its players persist in a DataStore (`Lowlands_v1`, keys `world` and
`player_<userId>`). The server autosaves every `AUTOSAVE_SECONDS` and on shutdown. On boot it loads, then runs the
pure ticks for the time it slept (capped at four in-game weeks). A returning player gets "You were gone N days"
plus a few headlines.

**Key modules**
- `shared/Save.lua` holds the saved shape. `encode` copies named fields only, so nothing is saved by accident.
  Id-keyed maps are written as arrays of rows. `VERSION` 4, `PLAYER_VERSION` 1.
- `server/Restore.lua` has `snapshot()` (what a save writes) and `apply()` (the restore constructor that rebuilds
  everything not saved).
- `server/Persistence.lua` is the ONLY DataStore code. Its policy: never write a key you failed to read, one
  server holds the lease, an unreadable save means NO-SAVE.
- `shared/Headlines.lua` is a 64-entry ring of world news, worded at read time.

**Tunables:** `SAVE_WORLD` and `AUTOSAVE_SECONDS` in Config.

**Gotchas.** This is escalation trigger 3: anything here goes to the heavy agent.
- Never bump `PLAYER_VERSION`: `applyPlayer` discards a record whose version differs (→ P1). A world-shape change
  bumps `Save.VERSION` and adds a step in `Save.migrate`.
- Studio needs Game Settings → Security → "Enable Studio Access to API Services". Without it the server runs
  NO-SAVE and says so.
- Server Debug commands `reload [s]` and `savetest [s]` exercise the whole path without a real DataStore.

## Expansion: deficits at scale

Notes for the map/village/NPC expansion (2026-10-05). Nothing here is decided.

- **One world key**, `server/Persistence.lua:27`. Hard limit: 4 MB, one `UpdateAsync`. Measured 15.7 KB (day 1),
  32.0 KB (day 120) ([§5](../architecture/modules-and-limits.md)). Graves are ~71 B each, for ever: 4 MiB holds ~59,000.
  At ten times today's deaths that is ~40 real days of uptime (a guess). Probably: lift `people` or just the graves
  into their own key(s), which [decision 1](../architecture/decisions.md) already allows.
- **No byte test**, `test/luau/save.test.luau`. Nothing asserts the encoded size; growth only shows in the
  `world saved: N bytes` print (`Persistence.lua:131`). Probably: encode a big synthetic world against a budget.
- **Graves never go**, `shared/Save.lua:70`. Tuning: `PRUNE_DAYS` (`:24`) shrinks a record, never deletes it.
  Probably: drop graves nobody living points at.
- **Each save walks the world four times**, `Persistence.lua:113-131`: `encode` copies, `Save.check` walks,
  `UpdateAsync` serialises, and the print runs `JSONEncode` again just to count bytes. Soft limit: at multi-MB, a
  server hitch every 120 s (a guess). Probably: drop the extra encode, then measure.
- **Catch-up is per second over every group**, `shared/Tick.lua:230-248`. `CATCHUP_CAP` = 16,800 seconds (`:22`),
  each running `Tick.groups` over all groups, plus 28 daily ticks over all people, synchronously before the door
  opens. Fine at 40 groups; maybe seconds at hundreds (a guess). It must not be lumped (`gossip.test.luau:162` pins
  catch-up = live). Probably: skip groups paused past the next second, or index by next event.
- **Restore gives every villager a body**, `server/Restore.lua:108-127`, near a player or not. Hard limit against
  the ~100 entity budget ([decision 5](../architecture/decisions.md)). It also assumes one village per tribe
  (`Map.village(t.villageId)`, `t.guard`/`t.merchant`/`t.survivor`). Probably: bodies only near players, per village.
- **Fixed rings and caps**: headlines 64 (`Headlines.lua:13`), rumours 64 (`Gossip.lua:25`), `MET_CAP` 128
  (`Save.lua:23`). Tuning numbers. More villages means a welcome covers less time, rumours evict faster and players
  forget faces sooner. Probably: scale the rings per village or region.
- **Players save only on leave and shutdown**, `Server.server.lua:136`, `Persistence.lua:168`. A crash loses the
  session, and more players share the 30 s `BindToClose` window with a growing world write. Probably: stagger
  player saves into the autosave.
- **A bigger map is a new world**, `Save.lua:178`. Any `GEN_VERSION` bump makes the save obsolete. Expected, but
  say so before the expansion lands. Once `people` spans several keys, `Save.migrate` (`:135`) must cover all of them.

Measure first: world-key bytes per game day at the expanded population; `Tick.catchUp(CATCHUP_CAP)` wall time at
the target group count; the autosave hitch in ms at that key size.
