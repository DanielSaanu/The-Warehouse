# Handoffs — routine → heavy

**Created:** 2026-09-23 · **Last updated:** 2026-10-06

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

### H11 — Build rung 3 part 4 phase 2: the obvious layer (barks, "what now", road talk) — 2026-10-06 — RESOLVED
- **Trigger:** 1 (a new system with design choices inside an approved plan), 2 (likely a pure module in `shared/`)
- **Doc:** `docs/plans/rung3-part4-belonging.md` "Phase 2" and "Slightly obvious what to do" (the guidance layer)
- **Observed:** phase 1 is through QA (8/10 in round 4, `docs/qa/rung3-part4-p1-ride-summary.md`); Danzo said "phase2".
- **Evidence:** branch `rung3-part4-p2`, cut from `h9-sim-carve` at 3c8360a (not yet merged to main).
- **Routine session's read:** build what the plan's phase 2 says (`Barks.lua` with the first eight facts and the fade,
  `whatnow` on every member, road talk). Fold in the items QA deferred to phase 2 (summary "Deferred"): a "squad
  leader" title on the hunter leader's window, a line when the master's witness flee holds a ride, a walk-off line
  that teaches the −3 ("You walked off on us. Not today." on the re-ask), and a move key closing a choiceless window
  only if the plan's "no client change" no longer holds for phase 2 (ask Danzo if so).
- **Decision needed:** any plan question phase 2 leaves open; bring it back rather than guess.
- **Blocked routine work:** the phase 2 QA loop (`docs/qa/rung3-part4-p2-guidance.md`, written by the builder).
- **Built 2026-10-06 (heavy), Studio checks pending:** `shared/Barks.lua` + `server/RoadTalk.lua`, `whatnow`, the
  walk-off re-ask, the squad leader's title; tests, lint, sourcemap, build green. Stays OPEN until Studio is seen.
  → plan "Phase 2", `docs/qa/rung3-part4-p2-guidance.md` "Builder's calls", learnings S9.
- **Studio 2026-10-07 (routine, PC, DevMode, seed 1):** seen working: "Brilo: Stay by the master. Watch the road."
  after the yes; lag "Keep up!" from the master; "Pelin: Gweno's spooked. We hold here."; road talk ("Glenworth's
  short of tools, they say."); "Nearly at Glenworth." / "Made it." then the pay line (rode 53 of 53, 7 coin); `whatnow`
  on a guard ("About 12 paces yet.") and the master at an end ("We rest here a while, then on to Glenworth."), not on a
  squad hunter when not riding; "You walked off on us. Not today."; "Maren Greenton, squad leader". No Output errors.
  **Open:** (1) a spawned bandit got "Gweno: Bandits! Guard the master!" said BY the master (the hostile speaker does
  not prefer a member); (2) the lag fade x3/short/quiet not counted in Studio (log gaps), unit test only; (3) the
  30-second test needs someone who has not read the plan. **(3) passed 2026-10-07: Danzo rode Glenworth → Kenstow
  himself, "it worked! and i clearly understood what to do".** Minor: a guard barks as "Brilo" but his window says
  "caravan guard"; a spook with no named threat when the fight is outside the 8-tile "seen" range.
- **RESOLVED 2026-10-07 (heavy):** (1) fixed test-first and seen in Studio (a guard says "Guard the master!"; the
  master alone on screen says "Bandits! Stand with us."); (2) and the minors go to the phase 2 QA loop.
  → `docs/qa/rung3-part4-p2-guidance.md` "Builder's calls", learnings S10.

### H12 — The first week has dead air, and the caravan must not be the whole game — 2026-10-07 — OPEN
- **Trigger:** 1 (a design decision with several reasonable options; it adds to `docs/DESIGN.md`), 8 (Danzo's ask
  reshapes what the opening and rung 3's end are for)
- **Doc:** `docs/design/build-rungs.md` (rung 3 / rung 4), `docs/design/long-arc.md`, `docs/PRINCIPLES.md`;
  the opening is `shared/Talk.lua` `Talk.survivor` + `Talk.goal` (GOAL_STAGES survivor → road → guard → sell → shelter)
- **Observed:** Danzo, 2026-10-07, after playing phase 2: "there is a gap between starting and being told to join a
  caravan and after where im just told to be inside for 7 days later which is boring admittedly also i dont want the
  joining the caravan to be the main objective we need more fun things for the player to do and experiment with after
  were done with this rung". Two problems: (a) the opening has dead stretches: nothing points from the survivor's
  lines to the caravan, and after "Sell a hide" the goal line sits on "Be inside walls or by a fire before day 7" for
  days with nothing to do; (b) beyond the caravan the player has too few things to try and play with.
- **Evidence:** `roblox/src/shared/Talk.lua:96-119`; `server/Goals.lua`; rung 3 part 4 phases 3–4 still to build
  (`docs/plans/rung3-part4-belonging.md`).
- **Routine session's read (guess):** (a) is small and belongs now. The goal line could hand off to the caravan as one
  of several things, and the dead days before the calamity need something to do. (b) is a "what comes after rung 3"
  question: a short menu of toys and systems the player can experiment with (sandbox verbs, not more quests), ranked
  by fun per build cost, that reuses what exists (witness/sides, gossip, groups, farms, wildlife, trade).
- **Decision needed:** a proposal Danzo can pick from, NO code: (a) 2–3 options for filling the first week (what the
  goal line and the people say, and what there is to do before day 7), with a recommendation; (b) a ranked list of
  5–8 "fun things to experiment with" for after rung 3 (each: what the player does, why it is fun → PRINCIPLES IDs,
  what existing systems it reuses, rough size, what it risks), and where each fits against rung 4 in `build-rungs.md`.
  Write it as one new doc under `docs/plans/` (under ~300 lines). Do not edit DESIGN or build-rungs until Danzo picks.
- **Blocked routine work:** none. Phase 3 of part 4 can go ahead in parallel.
- **Proposal written 2026-10-07 (heavy):** `docs/plans/first-week-and-toys.md`. (a) recommends option B (the line
  widens into one untried verb at a time, the guard answers "what now", the warning spreads by people from day 5);
  (b) ranks eight toys, top three: bait and lure, say things (tell/warn/lie), the first hireling. Stays OPEN until
  Danzo picks (three questions at the end of the doc).

## Resolved

### H10 — A rider's leg is counted across folded turns, so a natural ride pays a fraction — 2026-10-06 — RESOLVED
- **Resolved 2026-10-06 (heavy):** pure `Belong.legStep` starts a new leg on any change of `dir` (folded turns too) and
  ignores jumps over 6 tiles; test failed first; Studio natural leg after two folded: `rode 54 of 54`, 7 coin, Kenstow
  +2. → `docs/qa/archive/rung3-part4-p1-ride-round2.md` Builder decisions, plan phase 1 "The leg", learnings Q4.

### H9 — A materialised leader stalls in a crowd while its `pos` walks on without it — 2026-10-05 — RESOLVED
- **Danzo decided (2026-10-06):** fix now, by a Sim carve of `groupStep`/`followPath` (only that slice of B2).
- **Resolved 2026-10-06 (heavy):** carved into `server/Walk.lua`; the old side-step could never fire (4-way steps); now a
  leader swaps with its own, bodies detour round crowds, hunts give up (`shared/Steer.lua`), `pos` moves only on where
  the leader stands; Studio-checked. → `docs/systems/population.md` "Walking in a crowd (H9)", learnings S8.

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
