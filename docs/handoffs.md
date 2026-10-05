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

### H4 — A development-mode switch: easy testing, one flag back to an ordinary player — 2026-10-05 — OPEN
- **Trigger:** 1 (new project-wide mode), 2 (`shared/Config.lua`), 3 (decides whether a dev server loads or writes the DataStore)
- **Doc:** `docs/architecture/` (persistence section) and `CLAUDE.md` (record the policy); `roblox/src/server/README.md`
- **Observed:** Danzo, 2026-10-05: "project wide we are in DEVELOPMENT mode as such we need to not worry about my personal
  save or player character or progression and we need to be easily able to test things and also it should be easily
  turned off so that we can have testing from the perspective of an ordinary player."
- **Evidence:** what exists today: `Config.SAVE_WORLD` (Persistence.lua:77 → NO-SAVE), `ps.noSave`, the Debug command
  set in `server/Debug.lua` (`savetest` gated by `RunService:IsStudio()`, `jump`, `farms`, `gossip`).
- **Routine session's read (guess):** one switch, e.g. `Config.DEV`, on by default for now. When on: saves are
  disposable (fresh or throwaway world, or a separate DataStore key so the real one is never touched), Debug commands
  available, maybe a dev HUD line saying DEV. When off: exactly what an ordinary player gets. That means no Debug
  commands, the real save, and no dev text. Must default safe for a published game (Studio-only, or off outside Studio?).
- **Decision needed:** the shape of the switch (one flag vs flag + `IsStudio`), what each mode changes, where saves go in
  dev, and how Danzo flips it (one line in Config, or a Studio attribute). Record the policy in CLAUDE.md so every
  session knows dev saves are disposable. Do not touch Studio while a QA reviewer may be using it.
- **Blocked routine work:** none. Runs after the gossip QA loop, so it doesn't change code under review.

## Resolved

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
