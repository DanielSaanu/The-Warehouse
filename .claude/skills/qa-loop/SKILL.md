---
name: qa-loop
description: Run the three-round, three-reviewer quality assessment loop on the current branch. Reviewers are Opus subagents (never the main session's model) acting as average players and QA specialists; they press Play in Roblox Studio through the Roblox_Studio MCP when it is available. Between rounds the main session fixes what they flagged while preserving what they praised. Usage: /qa-loop docs/qa/<goals-file>.md
---

# QA loop

You are the **main session** (the builder). You do not review your own work. You orchestrate reviewers, then
act on their feedback. Rules of the experiment, set by Danzo:

- 3 rounds. 3 reviewers per round. Reviewers must run on the **opus** model (or a lesser model such as sonnet
  if you judge it capable), never the main session's model. Pass `model: "opus"` to the Agent tool.
- Target: every reviewer scoring **8.0 or higher** in a round. Stop early if that happens; otherwise run all 3.
- After the final round, report the state and results to Danzo, and tell him exactly what to look for when he
  tests it himself, so he can decide whether one more round is needed.

## Inputs

`$ARGUMENTS` is the goals file, e.g. `docs/qa/rung2-part1.md`. It lists the PR's goals and what is out of scope.
If no argument is given, use the newest file in `docs/qa/` that has no `-round` suffix.

## Studio access

If `/mcp` shows `Roblox_Studio` connected: reviewers **must** test for real. Preconditions you check once before
round 1: `rojo serve roblox/default.project.json` is running and Studio shows it connected (ask Danzo if not);
`Sprites.lua` has a real asset id (if it says `rbxassetid://0`, run `npx warehouse roblox build --upload`, then
commit `Sprites.lua` and `assets.lock.json`). Reviewers use the MCP tools to start Play, wait, read the Output
window, run Luau snippets, then stop Play. **Only one reviewer may use Studio at a time**: run the three
reviewers of a round sequentially, not in parallel. If Studio is not available, reviewers review by reading code
and running `npm test`, `npm run preview:world`, `npm run preview:view`, and say so in UNCERTAIN.

## Round procedure

For round N = 1..3:

1. Spawn reviewer A, wait for its report, then B, then C (sequential if Studio is in use). Give each the
   reviewer brief below verbatim, with its lens filled in, the goals file contents pasted in, and for rounds
   2 and 3 a short "changes since last round" list (what you fixed, what you deliberately kept).
2. Save the three reports verbatim to `docs/qa/<goals-basename>-round<N>.md` together with the average score.
3. Decide, then act:
   - **PRESERVE** items: never regress them. Re-read your diff before committing to make sure they survive.
   - **FIX** items: implement them. If a feature is terribly bad and cannot be fixed cheaply, remove it and say so.
   - **CONSIDER** items: use your judgement. Intervene when the change is cheap and clearly better, or when two
     reviewers raised it. Otherwise note it in the round file under "Deferred" with one line of reasoning.
   - If you disagree with a FIX, write why in the round file and skip it. Do not silently ignore feedback.
4. Run `npm test` and `npm run lint:luau`. If art changed, `node bin/warehouse.js roblox build` and ask Danzo to
   `--upload` (or run it yourself if `.env` is on this machine, then commit the two generated files).
5. Commit with a message starting `qa round N:` and push.
6. If every score in this round was >= 8.0, stop and report.

## Final report to Danzo

State the scores per round, what was fixed, what was preserved, what was deferred and why, and a **checklist of
things for him to look for when he plays** (concrete: "walk north through the gate, the banner should read...").

## Reviewer brief (paste verbatim, fill the lens and the goals)

```
You are an independent QA specialist and quality assessor for a game project. Your lens for this review:
<<LENS>>

Repository: <<ABSOLUTE REPO PATH>>. Do NOT modify any tracked files. You may run the read-only tools below and
use the Roblox_Studio MCP tools if they are available to you.

What is being reviewed: the current branch's latest work. Its goals and what is out of scope:
<<GOALS FILE CONTENTS>>
<<CHANGES SINCE LAST ROUND, if any>>

How to test:
- If Roblox_Studio MCP tools are available: Rojo is already syncing the repo into Studio. Start Play, wait about
  ten seconds, read the Output window (all messages, not just errors), try the controls by running Luau that
  simulates them if the MCP allows, stop Play. You may also run Luau snippets in edit mode to require the shared
  modules (ReplicatedStorage.Shared) and poke at them. Report exactly what you saw.
- Always: read roblox/src (shared, client, server) and roblox/default.project.json; read docs/DESIGN.md (the
  design contract) and CLAUDE.md; run `npm test`; run `node test/luau/run.js` then
  `node tools/preview-world.js exports/world_1.txt 1` and LOOK at exports/world_1.png with your Read tool; run
  `node tools/preview-view.js exports/world_1.txt 0 0 5` (spawn view) and `... 5 0.55` (night) and look at the
  PNGs; `node bin/warehouse.js render preview_tiles --scale 4` shows every sprite. The ASCII map in
  exports/world_1.txt lets you pick coordinates for preview-view (column = x, line = y; '@' spawn, 'H' hut,
  'B' burnt hut, 'S' stall, 'b' bed, 'W' wall, 'G' gate, '~' water, '=' ford, '.' road, 'T' tree, '^' rock,
  'O' cave, ',' tall grass, '#' farm).
- Where behaviour depends on the Roblox runtime and you could not run it, reason from the code and your
  knowledge of Roblox APIs and say clearly that you are uncertain.

Do the review in this order:
1. Test the goals one by one from the average player's perspective: met / partially met / not met, with
   evidence (file:line, image name, Output text, test output).
2. Apply your lens. Walk through what a player actually experiences.
3. Rate the work 1 to 10. 1 = abysmal: not done at all, or broke everything else trying. 10 = wonderful: done,
   done well, functional from a task-completion standpoint AND well done from a user-experience and
   overall-integration standpoint. Be calibrated and honest; do not inflate.

Finish with EXACTLY this structure:

SCORE: <number>/10
GOALS:
- <goal>: met|partial|not met - <one line of evidence>
PRESERVE (done well, must survive future iterations):
- <item>: <why>
FIX (done poorly; why it matters; concretely how to fix):
- <item>: <why> -> <how>
CONSIDER (fine but could change; why; how):
- <item>: <why> -> <how>
UNCERTAIN (could not verify):
- <item>

Under 900 words. Be specific: file paths, line numbers, image names, Output lines.
```

Lenses (one per reviewer, in this order):
- A, **the average player**: first five minutes and minute to minute. Is it clear what to do, does moving feel
  good, does the world feel alive and worth exploring, what confuses, what delights.
- B, **game feel and readability**: controls, camera, animation timing, pixel-art readability at real screen
  sizes, HUD, banner, night tint, how it looks on a phone-shaped screen.
- C, **integration and technical quality**: does the Lua actually work on Roblox (API usage, replication,
  timing, edge cases like two players or leaving mid-move), robustness, alignment with docs/DESIGN.md and
  CLAUDE.md, tests and tooling, anything that will bite the next PR.
