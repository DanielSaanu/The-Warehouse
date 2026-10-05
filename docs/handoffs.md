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

### H9 — A materialised leader stalls in a crowd while its `pos` walks on without it — 2026-10-05 — OPEN
- **Trigger:** 4 (Studio behaviour the session could not fix in one honest attempt), 2 (`shared/Tick.lua`), 6 (Sim's AI)
- **Doc:** `docs/qa/rung3-part4-p1-ride.md` "Known limitations"; `docs/systems/population.md`
- **Observed (Studio, DevMode, 2026-10-05, phase 1 play-through):** the caravan master boxed in at Glenworth's and
  Kenstow's squares (own guards, villagers, the merchant, a player beside him) stood still for 60–110 s while
  `group caravan` showed `pos` running 1 → 56 (and once 56 → 1). The squad's four hunters stood on `hunt` toward a
  boar 4 tiles away for minutes (`e107`, unreachable), its pos oscillating 27 ↔ 29. Leaving the squad did not unjam it,
  so it is not Ride. Cause read from the code: `Tick.leaderStep` sets `g.pos = nextI` when a path is PLANNED, and
  `followPath` drops a path after 4 blocked steps, so each think plans again and `pos` advances with no step (S6).
- **Evidence:** I tried "advance `pos` only when beside the tile" with a test that failed without it; in Studio the
  boxed leader then stood still for 90 s instead of drifting (my harness stood beside it, so this is confounded, → T5).
  The drift may be what eventually un-sticks a boxed leader, so I reverted it rather than ship an unproven change.
- **Heavy agent's read:** the real fix is in the body, not the record: `followPath`'s side-step only takes a strictly
  closer tile, so a leader ringed by its own followers (who keep within 2 tiles) never gets out. That is Sim's AI
  (Track B2, parked), and Sim has 0 lines of headroom. It also makes part 4 rides flaky to test (Debug `arrive`).
- **Decision needed:** whether to fix it now (where: a Sim carve of `groupStep`/`followPath`, i.e. more of B2) or
  after part 4; and whether the record should stop on a planned path once the body can move.
- **Blocked routine work:** nothing hard-blocked; a full Glenworth → Kenstow ride in Studio is luck until fixed.

## Resolved

### H8 — Build rung 3 part 4 phase 1: ask, ride, arrive — 2026-10-05 — RESOLVED
- **Resolved 2026-10-05 (heavy):** built: `shared/Belong.lua` (pure, `belong.test.luau`), `server/Ride.lua`, hooks in
  Sim (+3, ceiling 1228), Interact, Sides, Bands, Talk, Reputation (`rode`), Debug `arrive`; no save change; a taken
  end tile now arrives (`Tick.leaderStep`). Studio saw all but Kenstow hearing it (test only; the leader stalled, H9).
  → `docs/plans/rung3-part4-belonging.md` phase 1, `docs/qa/rung3-part4-p1-ride.md`, ARCHITECTURE §13, learnings T5.

### H7 — Rung 3 part 4, belonging: the plan (join a group, know what to do, what groups do) — 2026-10-05 — RESOLVED
- **Resolved 2026-10-05 (heavy):** plan written and approved by Danzo, all ten questions as recommended (a disconnect is
  stepping away; at most 2 riders; rides never saved; un-park the phase 0 Track B slice only). →
  `docs/plans/rung3-part4-belonging.md`, `roblox/src/server/README.md` Track B, learnings S7.

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
