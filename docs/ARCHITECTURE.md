# Architecture: where the data lives

**Status: Track A is built (2026-09-18, branch `track-a`); Track B is not.** `roblox/src/server/README.md` has the
check-list, and §10 lists where the build departed from this plan and why.

Written 2026-09-18 before rung 3 part 2 (save and catch-up), because the shape of the data decides whether saving is a morning's work or a rewrite. Reviewed for five rounds (7 → 9.0, summary in
`docs/qa/architecture-summary.md`), then re-read end to end and revised by a different model, which changed six
decisions — listed in §9 so nobody re-litigates them by accident. This document states decisions; the history of
how they were reached lives in the summary, not here.

Danzo's brief: *"set it up in a way where the data flows instead of congesting… a village has x amount of people,
those people are split into groups, those groups are split into individuals. Data that affects the group is
applied at the top level, data that applies to a family is at the group level, and so on… the data is in one
place, or several, whatever works, and the systems that rely on it are not directly moving it."*

---

## Where each part lives (split 2026-09-27, handoff H2)

This file is the hub and keeps its path, so every citation of the form `ARCHITECTURE.md R5`, `§2` or `A5` (in
Luau comments, tests and other docs) still starts here. The text moved verbatim into `docs/architecture/`; section
numbers and rule IDs are unchanged. Open only the file the ID points at. Grouping: contiguous § runs that are
read together, one topic per file, each well under the ~300-line cap; no Luau comment changed, because every
citation still lands on this hub (→ learnings G3).

| § | What | Rule IDs | File |
| --- | --- | --- | --- |
| §1 | What is actually wrong today (measured) | — | [architecture/data-model.md](architecture/data-model.md) |
| §2 | The shape: one World Record tree, by tier; what is *not* stored; ids and the serialised form | the tier rule | [architecture/data-model.md](architecture/data-model.md) |
| §3 | The five rules | R1–R5 (R2 = the owner table, R5 = one clock) | [architecture/data-model.md](architecture/data-model.md) |
| §4 | The module map after; `Save.encode` returns a JSON-safe table | — | [architecture/modules-and-limits.md](architecture/modules-and-limits.md) |
| §4b | The codebase has a second reader (line ceilings, one job per file, pure `shared/`) | H1–H9 | [architecture/modules-and-limits.md](architecture/modules-and-limits.md) |
| §5 | Not blowing up the machine: the 4 MB key, pruning, CPU, catch-up cost | — | [architecture/modules-and-limits.md](architecture/modules-and-limits.md) |
| §6 | How we get there: moving-code mechanics, Track A, Track B, the save-blocker table (#1–#11) | A0–A5, B1–B4 | [architecture/tracks.md](architecture/tracks.md) |
| §7 | What this costs, and what could go wrong | — | [architecture/decisions.md](architecture/decisions.md) |
| §8 | Settled questions (§8.1–§8.9) | — | [architecture/decisions.md](architecture/decisions.md) |
| §9 | **What the second reader changed (2026-09-18): the six decisions** | — | [architecture/decisions.md](architecture/decisions.md) |
| §10 | Where the build departed from the plan (Track A) | — | [architecture/as-built.md](architecture/as-built.md) |
| §11 | Rung 3 part 3: gossip, and what it does to this document | — | [architecture/as-built.md](architecture/as-built.md) |
| §12 | Development mode: `Workspace.DevMode`, a save that is never touched (H4) | — | [architecture/as-built.md](architecture/as-built.md) |
| §13 | Rung 3 part 4: a rider is scratch (`g.riders`), not a `members` row (H7/H8) | — | [architecture/as-built.md](architecture/as-built.md) |

**§9's six decisions, by name, so nobody undoes one by accident** (the reasons are in the file): 1. ids stay
numeric and `Save` writes arrays of rows; 2. `mapDiff` is deleted; 3. one clock (`gameSeconds`); 4. Tracks A and B;
5. `Persistence` has a failure policy and a boot order with a door; 6. `genVersion`.
