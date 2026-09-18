# Track A: the world can be saved (docs/ARCHITECTURE.md §6, rung 3 part 2)

Branch `track-a`. Builder: Fable. This PR is mostly invisible on purpose: it changes what the world IS (a record
with bodies projected out of it) so that it can be saved, and then saves it. **The player-facing claim is small
and absolute: nothing that worked before is worse, and the world is still there when you come back.**

## Goals

1. **Nothing regressed.** Everything rung 2 and rung 3 parts 1/1b shipped still works on the new clock and the
   pure ticks: NPCs think and walk, day turns to night, the squad hunts and deposits, the caravan walks, the band
   retargets after its grace days, a calamity warns / starts / ends, trade and guard talk work in all three
   villages, a villager at home still takes sides, a campfire burns out, a bag goes public and expires.
2. **One clock (A1).** No sim timer is stamped with `os.clock()`; `test/structure.test.js` enforces it. Debug
   `night` / `day` / `jump` still get QA where it needs to go, and only ever move time forward.
3. **The ticks are pure and finish their work unobserved (A2).** `shared/Tick.lua` runs in `npm test` with no
   entities and no players. A birth raises the tribe's population and becomes its news whether or not the mother
   has a body. Catch-up equals live ticking second for second, expires a running calamity, begins none, and is
   capped at four in-game weeks.
4. **Records hold ids, not references (A3).** No live village table on a tribe; `Person.village` is an id. A
   calamity's OVERLAY (`Calamity.applyOverlay`: water, tide flag) is separate from its BEGINNING (food lost, wolves
   arriving, camps destroyed, end date), and re-applying the overlay any number of times changes nothing saved.
5. **`Save.lua` and the restore path (A4).** The save is JSON-safe by construction (named fields only), id-keyed
   maps survive as arrays of rows, the long dead shrink to gravestones the family tree still resolves through, a
   save from another map generator or a newer version is refused. Debug `reload [seconds]` saves through real
   JSON and restores in place: the same named people, the same pregnancy, the campfire where it was (burnt out if
   enough time passed), a flood gone if the world slept through its end, the calendar later.
6. **Persistence (A5).** Never writes a key it failed to read (Studio without API access runs NO-SAVE, and says
   so, and the game plays). One server holds the lease; a second contends instead of overwriting. Boot order:
   the save is read before anything a player could join exists. A returning player has their kit, coin, standing
   (faded for the days away), rest point and goal line, and stands where they left or wakes at their rest point.
   Debug `savetest [seconds]` runs save → lease → load → restore → player key against a store in memory.
7. **Guard rails (A0).** `npm test` fails on a Lua file over 400 lines (allow-listed violators have their own
   ceiling that may only shrink) and on a stray `os.clock()`. `roblox/src/server/README.md` is the module index.

## Out of scope (do not score these)

- Track B: carving `Sim.lua` into `Bodies` / `Brains` / `Fighting` / `Bands` / `Tiles`, naming owners (R2/R3),
  splitting `WorldGen.lua`, stable group members. `Sim.lua` is still ~1,600 lines and that is known.
- The "you were gone eleven days" line (`meta.headlines` is carried by the format; nothing writes it yet).
- The real DataStore round trip in Studio needs Danzo to tick Game Settings → Security → "Enable Studio Access to
  API Services". If it is off, that is the NO-SAVE path in goal 6, not a failure: use `savetest` and `reload`.
- New gameplay, art, HUD. Nothing here should look different.

## How to test this one (in addition to the usual)

Debug channel: set the Workspace attribute `Debug` to a command line from the Server datamodel, read `DebugResult`.
New or changed commands: `reload [seconds]`, `savetest [seconds]`, `camp <x> <y>`, `calamity none`,
`night` / `day [frac]` (forward only), `jump <day> [frac]` (refuses the past). Existing: `state`, `people <tribe>`,
`family <id>`, `birth [tribe] [now]`, `group <id>`, `list <kind>`, `teleport x y`, `freeze 1`, `give`, `player`.
`freeze 1` before anything that must hold still. A day is 600 s, so `reload 3600` is six days of sleep.
