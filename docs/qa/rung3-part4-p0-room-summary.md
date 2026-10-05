# QA summary: rung 3 part 4, phase 0 (make room in Sim)

Goals: `docs/qa/rung3-part4-p0-room.md`. Commit a2e852e on `dev`. The target was 8.0 in at most three rounds, with
one Opus reviewer who had Studio. The loop stopped after round 1, at the target. The verbatim report is in `docs/qa/archive/`.

| Round | Score | The round's main finding |
| --- | --- | --- |
| 1 | 9 / 10 | A pure move. The text is verbatim, the rng is the same and drawn in the same order, the tree is identical, tests are green, and the band, squad and replenish checks passed live. Only the server README's size table was stale. |

## What was fixed (after round 1)
- `roblox/src/server/README.md`: Bands is 232 lines and owns "what a fight does to a group", and Sim is 1224 lines.
- `docs/architecture/data-model.md`: the `groups{}` owner row now names Restore's bulk assignment on load.
- `Bands.lua` header: the usage list names `carryKill(g, e)` and `lose(e)` (2 comment lines).

## What was preserved
- One `rng` passed in through `Bands.bind`, never a new generator: seeded replays and save/restore still match.
- The R2 grep in the commit message, with a reason for each remaining hit, so phase 1 and B2 can re-run it.
- Sim's ceiling held at 1255 with the reason written down: its 31 lines of room are for phase 1.
- The `[Sim]` log prefix kept on the moved lines, so the Output text QA reads didn't change.

## Deferred
- The squad's carry keeps growing after it turns home. This is old behaviour, moved verbatim, so it goes to phase 1 or B2 if it matters.
- A seeded rng-order test needs the server modules to run outside Studio, which is B2.

## Danzo's play-test checklist
Nothing should look different. DevMode on, press Play:
1. Walk around and fight a little: the game should feel exactly like before.
2. Optional, with Debug: kill bandits one at a time. On the third, Output reads "the band has broken off and is
   running for home".
3. A hunting squad that kills enough deer turns home and Output reads "the Kenstow squad came home with …".
