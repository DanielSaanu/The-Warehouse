# QA goals: Rung 3 part 1 (save and catch-up)

Branch: `rung3-part1`. First part of rung 3 (`docs/RUNG3.md`). Design contract: `docs/DESIGN.md` §14.

Rung 2 ended with a world that lives and remembers you **for as long as the server is up**. Nothing a player does
survives a shutdown: standing, coin, the camp you paid for, the guard's name, the goal you were on, all of it
regenerates from the seed next time anyone joins. This PR is the one that makes the world a place instead of a
demo, and `docs/DESIGN.md` §16 forbids charging for anything until it lands.

It is the least visible PR in the project. A reviewer who only walks around will see almost nothing new. The
review has to be done by leaving and coming back.

## Goals of this PR

1. **One world, shared by every server** (decided by Danzo, 2026-09-18; DESIGN.md §14). Every server reads and
   writes the same DataStore key. Glenworth is the same Glenworth for everyone who plays.
2. **The session lock.** One live server owns the world at a time: a claim in MemoryStore holding the JobId,
   renewed on a heartbeat, expiring on its own if a server dies without releasing it. A server that cannot take
   the lock still loads the save and plays normally, but never writes the world back, and the HUD says so once
   ("You are visiting. This server will not change the world."). Player saves are keyed by UserId and are never
   locked, so a guest server still keeps your own coin and standing.
3. **World save.** Seed, day, the tribes (stock, population, news), the family registry, region ecology counts and
   grass health, group route positions and members, camps, bags, and the calamity clock. One versioned key,
   written every 2 minutes and on `BindToClose`. Entities stay unsaved on purpose: they are materialised from
   records when a player is near, and rebuilt on load.
4. **Player save.** Position, facing, hp, inventory and coin, reputation per tribe, rest point, `goalStage` and
   whether the survivor has been met. Keyed by UserId. Written on leave, on the world timer, and on `BindToClose`.
   A returning player wakes at their rest point, not at the world spawn, and keeps the goal line they were on.
5. **Catch-up.** On load, the days that passed while nobody was here run through the daily tick — ecology breeding,
   starving and migration, trade restock, births and coming of age, reputation fade — capped so a month away does
   not cost a minute of loading. A returning player is told what changed in one line: "You were gone eleven days.
   Kenstow has a new guard."
6. **A real clock.** `Sim.state.dayStart` is `os.clock()` today, which is process-relative and starts at zero every
   boot, so the world cannot know how long it was gone. The calendar moves to wall time (`os.time`) while the
   10 Hz think timers, the movement pace budget and the camp fires stay on `os.clock()`, which is what they want.
7. **A first join is unchanged.** An empty DataStore generates the world from the seed exactly as it does now, and
   the first five minutes (survivor, arrow, signs, goal line) plays for a player with no save. Somebody joining a
   world that is already forty days old skips the tutorial goal line but still gets a rest point and a kit.
8. **Debug commands** for the QA loop, on the existing `Workspace.Debug` channel: `save` (force a write),
   `load` (re-read the key), `wipe` (delete both keys and regenerate — the reviewer's reset button), `lock`
   (who holds it and for how long), and `age <days>` (run catch-up for N days without waiting).
9. **Tests.** `test/luau/persist.test.luau`: a save round-trips to an identical state table, the serialiser drops
   the unsaveable fields (`player`, `snap`, live entity handles) rather than erroring on them, an unknown save
   version is refused instead of half-loaded, and catch-up for N days matches N daily ticks. `npm run lint:luau`
   clean. The serialiser must be pure Luau in `shared/` so it can be tested outside Studio.

## Out of scope (later rung 3 parts; do not penalise absence)

Gossip, grudges and amends (part 2). Tribute, tax, extortion, size tiers (part 3). Hunger (part 4). Blizzard and
drought, the full talk system, knights and adventurers, hiring, dash, shield, bows, settlement healing and ruins
(part 5). Charging money for anything.

## Known limitations the builder is aware of

- A guest server's world drifts from the owner's for as long as it runs, and its drift is thrown away. That is the
  accepted price of not silently rolling anyone's standing back. It should only ever happen once the first server
  is full.
- DataStore budgets and the 4 MB key limit. The family registry is the thing most likely to outgrow the key; the
  long dead may need pruning, and if that is not in this PR the limit needs a measurement and a written number.
- Catch-up runs the daily tick only. Groups do not walk their routes through the missed days; they resume from
  the record position, so a caravan does not arrive during a shutdown.
- Players are not simulated while offline (DESIGN.md §14), so nothing happens *to* you while you are away except
  what the world does to the place you left.
