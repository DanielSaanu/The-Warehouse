# Track A — QA round 1 — SCORE: 9/10 (target 8.0 hit; loop ends)

Reviewer: Opus subagent, 2026-09-18, with the Roblox Studio MCP (place "working on it", seed 1). Builder: Fable.

## Report (verbatim)

SCORE: 9/10
GOALS:
- Nothing regressed: met - groups walked, day/night, prediction==authority (`TileX=29 TileY=65 PredX=29 PredY=65`), world_1.png unchanged, 13+6 tests green
- One clock: met - `jump 3` refused at day 7; structure.test.js:44-62 enforces it
- Pure ticks: met - tick.test.luau:141-179; live cap hit exactly 28 days (day 9→37)
- Records hold ids: met - three reloads, still `39 people (39 bodies), 1 camps`
- Save.lua + restore: met - `reload 3600` → day 7, same names, campfire `out`, coin kept
- Persistence: met - NO-SAVE path observed verbatim in Output; savetest lease/player key pass
- Guard rails: met - both rules in `npm test`; server/README.md is current

Detail per goal: G1 live in Studio — boot printed `[Sim] 39 villagers, 3 groups, 36 regions`; caravan `route 12/56` → `13/56` a second later; `night` → dusk; W-key walk 29,70→29,65 with `MoveEpoch=0` (no snaps); HUD `Day 9, morning`, coin `40`. G2 — `jump 3` at day 7 returned `the calendar only moves forward (it is day 7)`; client clock is a pure follower of `Clock:FireAllClients` (Client.client.lua:528). G3 — `reload 100000` capped at exactly 28 days; `reload 1200` expired a running flood; `reload 0` during a flood kept it running and began none. G4 — three consecutive reloads, no doubling of food loss, wolves or villagers. G5 — `savetest` → `saved 9376 bytes; lease blocks a second server: true; reloaded as 'loaded': true; player key: true, inv coin 40`; a new couple formed during the sleep (12↔14). G6 — `CharacterAutoLoads = false` is set above the boot yield; the join guard plus the client's 1.5 s retry is sound.

PRESERVE (done well, must survive future iterations):
- `Save.check` + encode-by-named-field: makes the pure round-trip tests load-bearing and stops accidental saves. Do not replace with a generic deep-copy.
- One constructor (`Sim.init` runs `Restore.apply` XOR `initTribes/initGroups`): the 39/39 body count is the evidence it works.
- `Tick.catchUp` at 1 Hz granularity, with the "catch-up == live ticking" test (tick.test.luau:141). Any future "optimisation" into hourly lumps breaks it.
- Never-write-a-key-you-failed-to-read + the early-out on "not allowed": verified live.

FIX (done poorly; why it matters; concretely how to fix):
- `savetest` permanently hijacks the store: Debug.lua:85-88 calls `Persistence.useStore(fake)` and sets `Persistence.mode = "new"` and never restores either. Output shows every later autosave and the BindToClose save going to that in-memory table while printing `[Persistence] world saved: day 37, 9386 bytes` — on a live server that is silent total data loss with convincing logs. -> Snapshot `store`/`mode`/`why` and `ps.noSave` and restore them in a `finally`, and refuse the command unless `RunService:IsStudio()`.
- `Map.walkable` calls an undefined global: `roblox/src/server/Map.lua:50` is `return MapGen.walkable(...)` — a rename slip from `World.lua`. Dead today, but it throws the moment anyone calls it, and `luau-analyze` reported `ok roblox/src/server/Map.lua`, so the linter will not catch the next one. -> `WorldGen.walkable(Map.get(), x, y)`, or delete the function (nothing calls it).
- `reload` leaves a connected client disagreeing with the server: after `reload 1200` the server had `active:false` and dry ground, but the client GUI still read `Flood — ...`. The client only clears water on the `phase="end"` notice (Client.client.lua:509), which `Tick.catchUp` never fires; the client's stale water also blocks its own movement prediction. -> At the end of `Restore.apply`, re-run `sendWorld` for every connected player, or at minimum push a calamity end/start notice reflecting the restored `S.calamity`.

CONSIDER (fine but could change; why; how):
- `Calendar.advance` (Calendar.lua:35) is unused — catch-up writes `meta.gameSeconds` directly. Delete it or use it.
- `[Restore] day 37, 39 people` prints `rec.people.nextId`, an id counter, not a count. Count the living instead.
- structure.test.js:49 claims "os.time() is allowed in exactly one durable role" but tests only `os.clock()`. Either add the assertion or soften the comment.
- Forward-only `jump` means QA cannot replay days 1-7 after a `reload`. Consider a `restart` debug command that rebuilds a fresh world in place.

UNCERTAIN (could not verify):
- The real DataStore round trip (`GetAsync`/`UpdateAsync`, 4 MB limit, throttling): Studio API access is off. From the code, `UpdateAsync` returning `nil` correctly aborts, and the retry/backoff is outside the transform function, which is right.
- Two genuine servers contending, and lease takeover after a crash — only the pure `Save.mayWrite` logic and the `savetest` simulation were exercised.
- `BindToClose` under a real shutdown: it fired on Studio stop, but the 30 s budget against player writes plus a world write with backoffs was not stress-tested.
- Whether a returning player's saved tile being a wall/flood resolves well in practice — could not rejoin as a second session.

## Builder decisions

9/10 against the normal 8.0 target, so the loop closes after acting. **All three FIX taken; three of four CONSIDER.**

- **`savetest` hijacked the store — the most dangerous line in the PR was in its own test command.** It now refuses
  outside Studio, runs inside a `pcall`, and puts back the store, the mode, the reason and the player's `noSave`
  whatever happens; its result says `persistence is back to 'nosave'`. `Persistence.useStore` returns what it replaced.
- **`MapGen.walkable` was my rename regex**, in a function nothing calls; deleted. The real fix is the second half of
  the reviewer's point: the linter hid *every* "Unknown global" as Roblox noise. It now hides only Roblox's own
  globals by name, so any other unknown global fails lint — proved by planting `MapGen.walkable()` in a scratch file.
- **`reload` with a client connected:** `Restore.apply` now sends every connected player the restored calamity
  (`start` with the tiles, or `end`), which is the one thing that can change under a client that keeps its map.
  Checked in Studio: flood → `reload 1200` → zero flood sprites on the client. A real boot never needs this — it
  restores before the door opens — and a full re-send is not possible today because the client ignores a second
  `WorldInit` (`if vp then return end`), which is right for the retry loop it exists to serve.
- **CONSIDER taken:** `Calendar.advance` deleted; the log line counts the living; the structure-test comment no
  longer claims to police `os.time`.
- **Deferred:** a `restart` debug command. Stop and start Play does it in five seconds.
- **PRESERVE:** all four untouched by these fixes.
