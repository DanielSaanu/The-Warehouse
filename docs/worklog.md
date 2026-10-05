# Worklog

One dated line per block of work, newest last. Say what changed and where, and cite learnings IDs if a rule was
paid for. The detail belongs in commits and the docs; this is the timeline.

- 2026-09-27 · `refactor/ai-friendly`: docs-only refactor for AI readers. Added `INDEX.md`, `docs/systems/`,
  `docs/REFACTOR-SURVEY.md`, this worklog, the `roblox/src` README hubs. Extended
  `CLAUDE.md` and `docs/learnings.md` (G1, G2, T4). No file moved; the Rojo sourcemap is identical.
- 2026-09-27 · `refactor/ai-friendly` (heavy, H2): split `docs/ARCHITECTURE.md` (517 lines) and `docs/DESIGN.md`
  (597) into hubs at their old paths plus `docs/architecture/` (5 files) and `docs/design/` (9 files), all ≤ 155
  lines, moved verbatim; 0 lines lost, 0 broken links. `RUNG3.md` left whole on purpose. New rule G3.
- 2026-10-05 · `refactor/ai-friendly` (heavy, H3): gossip QA round 1. rekey keeps v2 values; meet by map tile;
  no rumours about animals; hops per holder; absent players' standing owed on the world (`w.owed`), save v3 → v4;
  Grudge split out of Gossip (400-line ceiling). New rules S4, S5, Q2.
- 2026-10-05 · `refactor/ai-friendly` (heavy, H5): gossip QA round 2. A group's arrival tells the village at the
  end it reached, not its own; owed sums clamped; saw-it line before the standing line; rekey → `Save.rekeyRep`. Rule Q3.
- 2026-10-05 · `refactor/ai-friendly`: gossip QA loop, three rounds, 6 → 7 → 7 (`docs/qa/rung3-part3-summary.md`).
  Fixes via H3/H5 (heavy), save v3 → v4. Open: a materialised group walks its route index while its bodies stay put.
  Danzo set DEVELOPMENT mode (H4 open) and asked for expansion notes per system (`ideas/INBOX.md`).
- 2026-10-05 · `refactor/ai-friendly` (heavy, H6): a materialised group's `pos` follows its bodies (`Tick.leaderStep`
  out of Sim, which drops to 1255 lines and the ratchet with it); `arrive` checks the leader is in the village. Rule S6.
- 2026-10-05 · `docs/expansion-notes`: "Expansion: deficits at scale" added to all nine `docs/systems/` files (four
  agents, notes only, no code). Systems hub points at them. CLAUDE.md: `Grid.lua` → `client/Viewport.lua` (Grid was removed in rung 2 part 1).
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: world-expansion plan drawn as a design board (256² map, 16 villages, asset
  list). `docs/art-sources.md` records the free-pack research (licences read, previews not seen) and the gaps to draw.
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: fetched all 15 free packs into `library/` (Kenney ×5, OpenGameArt ×7,
  itch ×5 via its free-download endpoint into `library/local/<code>/`), looked at every sheet, and wrote "Verified
  contents" in `docs/art-sources.md`: 27 have, 61 borrow, 6 check, 31 draw. Kenney fetcher fixed (single-quoted hrefs).
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: drew the 31 DRAW items from `docs/art-sources.md` in the Kenney Tiny palette
  (34 sprites, all `"export": false`, sheet unchanged); `scenes/preview_expansion_art.json` shows them beside Kenney tiles.
