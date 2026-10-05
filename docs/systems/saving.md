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
