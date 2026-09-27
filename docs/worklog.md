# Worklog

One dated line per block of work, newest last. Say what changed and where, and cite learnings IDs if a rule was
paid for. The detail belongs in commits and the docs; this is the timeline.

- 2026-09-27 · `refactor/ai-friendly`: docs-only refactor for AI readers. Added `INDEX.md`, `docs/systems/`,
  `docs/REFACTOR-SURVEY.md`, this worklog, the `roblox/src` README hubs. Extended
  `CLAUDE.md` and `docs/learnings.md` (G1, G2, T4). No file moved; the Rojo sourcemap is identical.
- 2026-09-27 · `refactor/ai-friendly` (heavy, H2): split `docs/ARCHITECTURE.md` (517 lines) and `docs/DESIGN.md`
  (597) into hubs at their old paths plus `docs/architecture/` (5 files) and `docs/design/` (9 files), all ≤ 155
  lines, moved verbatim; 0 lines lost, 0 broken links. `RUNG3.md` left whole on purpose. New rule G3.
