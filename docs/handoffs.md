# Handoffs — routine → heavy

**Created:** 2026-09-23 · **Last updated:** 2026-10-05

A routine session appends here the moment an escalation trigger fires (CLAUDE.md, "Model policy and
escalation"). The heavy agent reads this file first, works the open entries, records its full reasoning in
the doc the entry names, and marks the entry RESOLVED.

Keep this file small. Once the detail lives in the real doc, trim the resolved entry to its heading plus one
resolved line.

## Entry template

```
### H<n> — <one-line title> — <YYYY-MM-DD HH:MM> — OPEN
- **Trigger:** <which of the numbered triggers>
- **Doc:** <path> §<section>
- **Observed:** <what was seen, plainly — exact error text, failing test, the diff, the Studio Output line>
- **Evidence:** <commands run, file:line, export PNG, branch, commit>
- **Routine session's read:** <best guess, clearly marked as a guess>
- **Decision needed:** <the specific question or action>
- **Blocked routine work:** <what is on hold, if anything>

Resolution (added by the heavy agent under the same entry):
- **Resolved <date>:** <one line> → recorded in <path> §<section>
```

## Open

### H7 — Rung 3 part 4, belonging: the plan (join a group, know what to do, what groups do) — 2026-10-05 — OPEN
- **Trigger:** 1 (a design with several reasonable options; adds to DESIGN §7/§8/§12 and RUNG3 Part 4)
- **Doc:** `docs/RUNG3.md` §Part 4; the three reports in `docs/research/belonging-*.md` (joining, guidance, activities)
- **Observed:** Danzo, 2026-10-05: the player should become a member of the group, "but it should be made slightly
  obvious what to do when they're there naturally this will lead to the expansion of what the groups that the players
  join can actually do". He asked for research first; the three reports are done (commit 5d98042).
- **Evidence:** the research's headline findings:
  - **Joining:** ask the leader in the talk window, and a "no" gives a gossip reason. Consequences travel only by
    witnesses. Leaving is graded: clean, mid-route, desertion, betrayal. Blox Fruits' memoryless recruiter is the trap.
  - **Guidance:** the group's movement is the instruction (the leader waits and looks back). The leader's yes teaches
    the role in one line. Barks are short, rule-picked, on-screen only, and fade. Never fail the player for wandering
    off. Every member can answer "what now".
  - **Activities:** the role comes from where you walk (ahead = scout/lookout, beside = guard). One "first to spot a
    hostile group warns and halts" rule. `g.carry` becomes the shared pot, split at `deposit`, and losses cut shares.
    Avoid loot races, burnable stashes and pay that ignores effort. The bad side must still have a trading partner.
- **Routine session's read (guess):** the research converges well; the plan should pick the smallest first slice that
  passes the RUNG3 "done when". Line ceilings matter: `Sim.lua` 1254/1255, `Gossip.lua` 396/400, `Hud.lua` 2 lines
  left, client files full. So the plan must name where new code lives, and may have to ask Danzo to un-park a slice
  of Track B.
- **Decision needed:** write the Part 4 plan only, with no code. Cover joining (the ask, the checks, the answer),
  membership (what changes for the player and the world), the "slightly obvious what to do" layer, the first
  activities per group (most for least), leaving and betrayal, rewards and blame, and what the save must hold.
  Phase it into buildable steps, each with a "done when" and a goals file it would get. List Danzo's open questions with
  a recommended answer each, including the research's three: does a disconnect mid-route count as leaving, can two
  players share a group, and how the save holds a member player. Also say whether Track B must un-park. Put it in a
  new `docs/plans/rung3-part4-belonging.md` (under ~300 lines), point RUNG3 §Part 4 at it, add a worklog line, and
  commit on `dev` (do not push). Don't touch Studio or code.
- **Blocked routine work:** building part 4 (waits on Danzo approving the plan).

Status (added by the heavy agent):
- **2026-10-05 (heavy): plan written, still OPEN.** → `docs/plans/rung3-part4-belonging.md` (phases 0–4, where the
  code goes, the save holds nothing new). Waiting on Danzo for Q1 disconnect, Q2 two riders, Q3 save, Q4 un-park the
  phase 0 Track B slice (recommended answers in the plan); Q5–Q10 have defaults. Resolve once he answers.

## Resolved

### H4 — A development-mode switch: easy testing, one flag back to an ordinary player — 2026-10-05 — RESOLVED
- **Danzo decided:** dev saves nothing at all; forced off outside Studio; toggled in Studio, not in code.
- **Resolved 2026-10-05 (heavy):** `Workspace.DevMode` (boolean attribute; not set = on in Studio, read once at boot):
  on = no DataStore read or write, a fresh world each Play, Debug console, a DEV notice; off = the real save, no Debug,
  no dev text. `shared/DevMode.lua` + `server/Dev.lua`; Studio-checked both ways. → `docs/architecture/as-built.md` §12,
  `CLAUDE.md`, `docs/systems/saving.md`, learnings P4.

### H6 — A materialised group walks its route index while its bodies stand still — 2026-10-05 — RESOLVED
- **Resolved 2026-10-05 (heavy):** the leader's route rule is now pure `Tick.leaderStep` (`pos` moves only with the
  bodies, re-anchors after a chase, "lost" collapses the group); `arrive` refuses unless the leader is in the
  village; tests fail without each fix. → `docs/qa/rung3-part3-summary.md` "Open after round 3", `docs/RUNG3.md`
  part 3 "After round 3", learnings S6.

### H5 — Gossip QA round 2 (7/10): a group's arrival tells its own village at both ends — 2026-10-05 — RESOLVED
- **Resolved 2026-10-05 (heavy):** `arrive` tells the village at the end reached (or nobody), probe is a test; owed
  sum clamped; saw-it line first; one village-key parser; rekey moved to `Save.rekeyRep`. → `docs/RUNG3.md` part 3
  "QA round 2", `docs/qa/rung3-part3-round2.md` "Builder decisions", learnings Q3.

### H3 — Gossip QA round 1 (6/10): five FIX items in Gossip, Standing.rekey and the meet rule — 2026-10-05 — RESOLVED
- **Resolved 2026-10-05 (heavy):** all five FIX items fixed with a test each; absent players' standing is now owed on
  the world at tell time (`w.owed`), hops per holder, save `VERSION` 3 → 4 in place, Grudge split out (Danzo: dev
  mode, a reset is acceptable, lost rep not recovered). → `docs/RUNG3.md` part 3 "QA round 1",
  `docs/qa/rung3-part3-round1.md` "Builder decisions", learnings S4, S5, Q2.

### H2 — Split docs/ARCHITECTURE.md and docs/DESIGN.md into hub + per-section files — 2026-09-27 — RESOLVED
- **Resolved 2026-09-27 (heavy):** both kept at their paths as hubs with a § / rule-ID → file table; text moved
  verbatim into `docs/architecture/` (5 files, §1–§11) and `docs/design/` (9 files, §1–§20), largest 155 lines;
  0 of 941 non-blank lines lost (script check), 0 broken relative links, `npm test` green, no Luau touched.
  → recorded in the hubs `docs/ARCHITECTURE.md` / `docs/DESIGN.md` "Where each … lives", rule learnings G3.

### H1 — Rung 3 part 3: where gossip memory lives, and what it does to Reputation — 2026-09-23 16:54 — RESOLVED
- **Resolved 2026-09-23 (heavy):** reputation stays **stored**, but is re-keyed from tribe type to **holder** (a
  village or a group) — derived-from-memory was rejected because memory has to be capped and a reputation derived
  from a capped list *heals when the cap evicts*. Memory is a bounded world-level ring of rumour rows plus a
  `knows[]` of ids per holder: measured at **+9.6 KB** worst case today and **+22.2 KB** at DESIGN §4's caps,
  against **216 KB** for the per-(holder, player) shape §5 had assumed. Save `VERSION` 2 → 3 migrates **in place
  with nothing lost and no world reset**; the player key does **not** bump (a bump discards it). All six questions
  answered → the buildable spec (records with field names, the tick and catch-up hooks, the save step, the 24-site
  edit list, a testable done-when) is in `docs/RUNG3.md` §"Part 3 — Gossip and grudges"; the architectural half is
  in `docs/ARCHITECTURE.md` §11, plus §2's tree, R2's owner table and §5's memory budget. New rules: learnings
  S1, S2, P1, P2, P3, T1. **None of ARCHITECTURE §9's six decisions is touched.**
