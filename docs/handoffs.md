# Handoffs — routine → heavy

**Created:** 2026-09-23 · **Last updated:** 2026-09-23

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

*(none)*

## Resolved

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
