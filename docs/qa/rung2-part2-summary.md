# QA summary: Rung 2 part 2 (a small living world)

Goals file: `docs/qa/rung2-part2.md`. Verbatim round report: `docs/qa/archive/rung2-part2-round1.md`.
One Opus reviewer per round, live in Studio through the Roblox_Studio MCP. The target (>= 8.0) was hit in
round 1, so the loop stopped after one round. Builder session: Claude Fable 5.1 on Danzo's Mac, 2026-09-17.

## Scores

| Round | Score | Main finding |
|---|---|---|
| 1 | 8 | All 13 goals met live (survivor script, combat cadence 1.8 s, trade moving four numbers, guard answering from live state, flood painting 106 tiles, groups materialising, wildlife counts drifting over a day). Zero runtime errors. Three UI/logic defects: empty choice buttons on every choice-less dialogue, guard topics keyed to the player's tile, fragile trade column alignment. |

## What was fixed (round 1, commit `eaea94b`)

- Choice-less dialogues (survivor, villagers, caravan master, refusals) no longer show four empty grey buttons;
  the text takes the full panel width when there are no choices.
- Guard topics use the tribe of the guard you are talking to (stored on the conversation), not the tile you stand
  on, so a hunter guard never quotes farmer prices.
- Trade rows are separate cells (good, stock, buy, sell, you have) at fixed positions shared with the header; no
  wrapping, so columns line up at any width.
- Flood notice says "under water until tomorrow", matching when the flood actually lifts (the day boundary).
- F at a wall or tree says "Nothing here." instead of doing nothing.
- The calamity warning is keyed by day, so it can never latch off across weeks.

## What was preserved (confirmed by the reviewer)

- The knowledge bank wired to live state: the guard tells you where the band actually is, that a flood is on, what
  the region's wildlife is doing.
- Prices that move with stock and standing; selling two hides visibly moved four numbers.
- Server authority with epoch fencing: predicted and authoritative tiles matched after knockback, flood
  displacement and respawn.
- The debug attribute channel on Workspace (`Debug` / `DebugResult`) that made a live review possible.
- Zero runtime errors, with `pcall` around every think and tick so one bad entity cannot stop the world.

## Deferred, and why

- Denser village footprints (the reviewer found the walled farmer village mostly empty grass): a template and art
  pass (more huts, fences, props) for the next art round, not a code fix.
- Wolves near a player surviving daybreak: kept on purpose. A wolf chasing you should not vanish in front of you;
  it folds back into the region count once you are more than 9 tiles away.
- Two players, leaving mid-move, PvP visibility and real phone screens: not testable in Play Solo through the MCP.
  The reviewer measured a 22-column play area on the wide Studio window; a phone needs Danzo's hands.

## Verified by the builder before the review (the reviewer marked these UNCERTAIN)

Camp placement, the fire burning down to `camp_out`, waking at the camp after death, bag drop and pick-up, and a
beast tide at night (17 wolves materialised in the north, one chasing) were all exercised live in Studio during
the build session.

## Open items from the last round

None: every FIX was acted on and every CONSIDER was either taken or deferred above.

## Going public (parked in DESIGN.md, PR #6, merged into this branch)

Two chores touch this PR's files and should happen before rung 3 ships: hard-code the resolved image id
(`npx warehouse roblox setid 0 130039133248340`, the image the server resolved from decal 92588138876546) and
reword the loading message in `Client.client.lua` so it does not mention `rojo serve` to strangers.
