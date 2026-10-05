# QA round 1 — rung 3 part 4, phase 0 (make room in Sim)

**Score: 9/10** · 2026-10-05 · reviewer: Opus (independent subagent), Studio Play run in DevMode · commit a2e852e

## Report (verbatim)

**Bottom line:** it is a pure move. I re-checked the move, the sourcemap, the tests and a Studio run myself, and nothing a player can see has changed. The only real defect: `roblox/src/server/README.md`'s size table is stale, so the commit breaks that README's own "update it with any move" rule.

**What a player sees:** the same world. `exports/view_29_70@5x.png` (spawn view) renders normally. That was expected, since the commit touches only server Lua. The Studio Output showed the same log lines as before, with the same text. I did not open the night view or `world_1.png`: there is no art or shared code change.

**Technical review:**
- **The text is verbatim.** I stripped indentation from the lines removed from Sim and the lines added to Bands and diffed them. The only differences are the two function wrappers (`if g then` and `if e.group then` become the function headers), the header comment and the new `Combat` require.
- **Same random numbers.** `Bands.rng` is the same `Rng` object as Sim's: it is passed in by `Bands.bind` at `Sim.lua:1151`, after `Sim.lua:1136`, and never reassigned. `Restore.lua:166` changes the generator's state in place (`getRng().s`), so Bands keeps the restored stream too. `Bands.carryKill` is still called before the player's `Combat.loot` (`Sim.lua:412` vs `:419`), so the draw order matches. `S` is `State.state` in both files.
- **Group writes outside Bands.** Re-running the commit's grep gives exactly the listed set: `Debug.lua:215-216`, and `Sim.lua:113, 519, 844, 847, 866`. A wider grep (`table.insert/remove(g.`, `S.groups[..].x =`) finds nothing else. The one omission is `Restore.lua:161`, which replaces the whole `S.groups` table on load. That is legitimate, but the commit's grep could not see it.
- **Kept on purpose, not penalised:** the log line inside Bands still says `[Sim] the band has broken off...`. That is correct for a verbatim move, and the Studio check relies on that text.
- **Small doc gap:** Bands' header usage list (`Bands.lua:11-12`) doesn't list the two new functions, though the "Owns:" line does.

SCORE: 9/10

GOALS:
- Verbatim move, two blocks: met. The indentation-stripped diff of removed vs added lines differs only in the wrappers. The `fedUntil` line stays at `Sim.lua:410`. The call points are unchanged (`Sim.lua:412`, `:451`) and share the one `rng`.
- Bands only writer of groups{}: met. The grep is in the commit message, and I reproduced it exactly. Everything left is transient B2 state or Debug, plus the unlisted bulk restore at `Restore.lua:161`.
- Room for phase 1: met. `Sim.lua` is 1224 lines by `wc -l` (the commit says 1225, probably counting a trailing newline), under the 1255 ceiling. That is 31 lines of room.
- Instance tree unchanged: met. I built sourcemaps of `a2e852e^` (in a temporary worktree, since removed) and of HEAD and compared names, classNames and nesting: TREE IDENTICAL, 52 nodes. `rojo build` succeeded.
- Nothing regresses: met. `npm test` passed 13 and failed 0. `test:luau` passed every file (movement, save, sim, tick, witness, worldgen). `lint:luau` printed "ok" for every server and shared file.
- Studio regression: met, seen live in DevMode.
  - Band: I struck e76, e77 and e78 dead. After the third the band showed "RETREATING", and Output printed `[Sim] the band has broken off and is running for home`.
  - Squad: 10 deer were spawned next to the squad, and its carry went 0 → 2/2 → 5/5 hide and meat. It turned home with `dir 1` → `-1` at about 10 carried, then `[Sim] the Kenstow squad came home with 8 food, 8 hide`, after which its carry was empty.
  - Replenish: I killed band member 47. After the band collapsed and two `day` skips, a new member "51 Maric Rockmere" had joined.
  - Output had no warnings or errors.

PRESERVE (done well, must survive future iterations):
- Passing `rng` through `bind` rather than making a new generator in Bands: one stream means seeded replays and save/restore still match. A local `Rng.new` in Bands would quietly break both.
- The commit message carrying the R2 grep and its output, with a reason for each remaining hit: it is a check anyone can re-run, which phase 1 and B2 can repeat.
- Keeping the ceiling at 1255 with the reason written down (`README.md:86-87`): the 31 lines are phase 1's, and the plan says when the ceiling comes down.
- Keeping the `[Sim]` log prefix in the moved code: a verbatim move should not change Output text that QA reads.

FIX (done poorly; why it matters; concretely how to fix):
- The sizes table in `roblox/src/server/README.md` is stale. Lines 18-19 still say Bands 198 and Sim 1282, and the Bands row doesn't mention `carryKill`/`lose`. The README's header says "Update it in the same commit as any move. Sizes are line counts", and this was a move. The next session reading it gets the wrong ownership and sizes. -> Set Bands to 232 and Sim to 1224, and add "what a fight does to a group (`carryKill`, `lose`)" to the Bands row.

CONSIDER (fine but could change; why; how):
- The R2 list in the commit leaves out `Restore.lua:161`, the wholesale `S.groups = rec.groups`. Someone auditing "who writes groups{}" will hit it and wonder. -> Add one line to the owner table in `docs/architecture/data-model.md:110`: "Restore assigns the table on load".
- `Bands.lua:11-12` usage list: add `Bands.carryKill(g, e)` and `Bands.lose(e)`, so phase 1's hook authors see the entry points in the header.
- A carry that keeps growing after the squad has turned home (I saw 10 → 16 while `dir -1`) is the old behaviour: the `dir == 1` guard was moved with the rest. Not a regression. If it ever looks wrong, it belongs in phase 1 or B2, not here.
- A seeded Luau test that runs a kill through Bands and checks the next `rng` draw would make "same rng order" a test rather than an argument. It isn't possible today because the server modules can't run outside Studio, so this is a note for B2.

UNCERTAIN (could not verify):
- Two-player and leave-mid-fight cases. The moved code has no player-specific path, so I expect no change, but I didn't test it.
- A seeded replay byte-for-byte match before and after. I reasoned it from the shared `rng` object and the unchanged call order; I didn't run it.
- Play stopped once by itself in edit mode partway through my first squad check. I restarted and the rerun was clean; I could not tell what stopped it (possibly something outside this change).

## Builder decisions

- **FIX, done:** the server README's Bands row now reads 232 lines plus "what a fight does to a group (`carryKill`, `lose`)"; Sim reads 1224.
- **CONSIDER, done (cheap):** `data-model.md`'s owner table says Restore assigns `groups{}` on load. Bands' header usage list names `carryKill` and `lose`. That is 2 comment lines; Bands is now 234 lines.
- **CONSIDER, deferred:** the squad carry growing after it turns home is old behaviour, so it goes to phase 1 or B2 if it ever matters. A seeded rng test can't be written while the server modules only run in Studio (B2).
- The score met the 8.0 target, so the loop stops after round 1.
