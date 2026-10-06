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
- 2026-10-05 · `dev` (heavy, H4): development mode. `Workspace.DevMode` in Studio (not set = on): no DataStore at all,
  Debug console, a DEV notice; unticked = the real save, no Debug; forced off outside Studio. `shared/DevMode.lua` +
  `server/Dev.lua`, gated in Persistence, Debug and Server. Studio-checked both ways. ARCHITECTURE §12, learnings P4.
- 2026-10-05 · `dev`: three research agents for rung 3 part 4 (belonging): `docs/research/belonging-joining.md`,
  `-guidance.md`, `-activities.md` (other games, what worked and why, shortcomings, sources). Plan → heavy (H7).
- 2026-10-05 · `dev` (heavy, H7): rung 3 part 4 plan, no code: `docs/plans/rung3-part4-belonging.md`. Ask the
  leader (7 checks, pure `Belong.ask`), riders as scratch not `members` (no save change), pay at each arrival from a
  pot cut by losses, graded leaving, barks + "what now", then "first to spot it". Phases 0–4; phase 0 un-parks one
  Track B slice. H7 stays OPEN on Q1–Q4. Learnings S7.
- 2026-10-05 · `dev` (heavy, H7 resolved): Danzo approved the part 4 plan, all ten questions as recommended; the
  phase 0 Track B slice is un-parked (server README). Goals file `docs/qa/rung3-part4-p0-room.md`. Phase 0's code
  move was NOT made: the edit to `Sim.lua` was refused by the session's permission check, left for Danzo.
- 2026-10-05 · `dev` (heavy): part 4 phase 0. `killEntity`'s two group halves moved verbatim to `Bands.carryKill` /
  `Bands.lose`; `Sim.lua` 1255 → 1225 (ceiling kept at 1255 for phase 1), `Bands.lua` 194 → 233. Tree identical, tests +
  lint green; Studio (DevMode): band broke at 3 of 4 lost, squad laden at 9 turned home and banked, band refilled.
- 2026-10-05 · `dev`: QA loop on part 4 phase 0, one round, **9/10** (`docs/qa/rung3-part4-p0-room-summary.md`). Fixed
  the server README sizes and the Bands row, Bands' header lists `carryKill`/`lose`, data-model notes Restore's bulk write.
- 2026-10-05 · `dev` (heavy, H8): part 4 phase 1, ask / ride / arrive. `shared/Belong.lua` (pure, 105 lines,
  `test/luau/belong.test.luau`), `server/Ride.lua` (249), hooks in Sim (+3, ceiling 1255 → 1228), Interact, Sides, Bands,
  Talk, Reputation (`rode`), Config `RIDERS_MAX`, Debug `arrive`; no save change. A leader beside a taken end tile
  now turns. Studio: ask/yes/no/cooldown, wait and face, −3 for walking off, pot, 7-coin pay. Leader stall → H9. T5.
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: world-expansion plan drawn as a design board (256² map, 16 villages, asset
  list). `docs/art-sources.md` records the free-pack research (licences read, previews not seen) and the gaps to draw.
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: fetched all 15 free packs into `library/` (Kenney ×5, OpenGameArt ×7,
  itch ×5 via its free-download endpoint into `library/local/<code>/`), looked at every sheet, and wrote "Verified
  contents" in `docs/art-sources.md`: 27 have, 61 borrow, 6 check, 31 draw. Kenney fetcher fixed (single-quoted hrefs).
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: drew the 31 DRAW items from `docs/art-sources.md` in the Kenney Tiny palette
  (34 sprites, all `"export": false`, sheet unchanged); `scenes/preview_expansion_art.json` shows them beside Kenney tiles.
- 2026-10-05 · `claude/nifty-pascal-3ryiwv`: every borrowed item is now a crop scene (89, outlined to match Kenney Tiny);
  7 more drawn (palisade + gate, cage, ruined watchtower, roadside shrine, bridge, battle debris). All export:false, sheet unchanged.
- 2026-10-06 · `h9-sim-carve` (heavy, H9): `groupStep`/`followPath` carved into `server/Walk.lua` (Sim 1227 → 1152); a leader
  swaps with its own, bodies detour round crowds, hunts give up (`shared/Steer.lua`); `pos` moves only on where the leader
  stands (`Tick.leaderStep`). 12 test blocks (10 failed on the old code first; 2 are guards); Studio-checked. → `docs/systems/population.md`, learnings S8.
- 2026-10-06 — qa round 1 (7/10) on rung3-part4-p1-ride: a late joiner no longer gets paid for road they never walked (Ride counts every group's leg), a walk-out spends the day's ask, a far rider at arrival gets a line, squad line points at the leader.
- 2026-10-06 — H10 (heavy, qa round 2 fix) on h9-sim-carve: a ride's leg resets on any turn, folded or not (pure `Belong.legStep`, jumps over 6 tiles are not road); test failed first; Studio natural leg `rode 54 of 54`, 7 coin, Kenstow +2; "off the goods". → `docs/qa/archive/rung3-part4-p1-ride-round2.md`, learnings Q4.
- 2026-10-06 — qa round 3 (7/10) on rung3-part4-p1-ride: a rider reading a talk window is not counted as lagging or walking off; squad members name their leader; the leader keeps the window after a topic.
- 2026-10-06 — qa summary rung3-part4-p1-ride: 7 / 6 / 7, target 8 not reached; rounds archived. → `docs/qa/rung3-part4-p1-ride-summary.md`.
- 2026-10-06 — qa round 4 (8/10, Danzo's extra round) on rung3-part4-p1-ride: a rider reading a window is waited for and the ride never ends silently; "1 hide". → `docs/qa/rung3-part4-p1-ride-summary.md`.
- 2026-10-06 — H11 (heavy) on rung3-part4-p2: phase 2 built, the obvious layer: pure `shared/Barks.lua` (most specific wins, never twice in a row, teach x3 then short then quiet; test failed first), `server/RoadTalk.lua` (ten facts, a speaker on the rider's screen), `whatnow` on your group, the walk-off re-ask, the squad leader's title; no save/client/Sim change; Studio pending. → plan phase 2, `docs/qa/rung3-part4-p2-guidance.md`, learnings S9.
