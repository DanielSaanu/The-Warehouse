# Design: Lowlands

A 2D top-down pixel-art Roblox game about surviving in a living overworld. Tribes trade, raid and remember you.
Wildlife breeds and starves without you. The world is shared by everyone on the server and keeps living while
you are away. "Rain World energy" on a tile grid.

Source of truth for gameplay decisions. `ideas/INBOX.md` is the scratchpad; things that get agreed move here.

## Where each section lives (split 2026-09-27, handoff H2)

This file is the hub and keeps its path, so every citation of the form `DESIGN.md §7` (in Luau comments, tests and
other docs) still starts here. The text moved verbatim into `docs/design/`; section numbers are unchanged. Open only
the file the § points at. Grouping: contiguous § runs that are read together, one topic per file, each well under
the ~300-line cap; no Luau comment changed, because every citation still lands on this hub (→ learnings G3).

| § | What | File |
| --- | --- | --- |
| §1 | Pillars (1–6: the world does not need you … the main story is the compass) | [design/pillars.md](design/pillars.md) |
| §2 | Decisions made (view, controls, death, rest, kit, time, names …) | [design/pillars.md](design/pillars.md) |
| §3 | The session loop | [design/pillars.md](design/pillars.md) |
| §4 | The world is numbers; the grid is a window (tiers, caps, data budget) | [design/world-and-tribes.md](design/world-and-tribes.md) |
| §5 | Tribes: farmers, hunter-gatherers, plunderers, size tiers, healing | [design/world-and-tribes.md](design/world-and-tribes.md) |
| §6 | Trade, tribute, tax | [design/world-and-tribes.md](design/world-and-tribes.md) |
| §7 | Reputation, grudges, gossip | [design/reputation-and-talk.md](design/reputation-and-talk.md) |
| §8 | Talking: knowledge banks and role NPCs | [design/reputation-and-talk.md](design/reputation-and-talk.md) |
| §9 | Wildlife, ecosystem, migration | [design/wildlife-time-player.md](design/wildlife-time-player.md) |
| §10 | Time, night, calamities | [design/wildlife-time-player.md](design/wildlife-time-player.md) |
| §11 | Player, controls, combat (break points, camp, rest, death) | [design/wildlife-time-player.md](design/wildlife-time-player.md) |
| §12 | The first five minutes; the elder is the compass | [design/long-arc.md](design/long-arc.md) |
| §13 | The long arc: becoming a power; hirelings; chiefs and heirs | [design/long-arc.md](design/long-arc.md) |
| §14 | Persistence and multiplayer | [design/persistence-and-names.md](design/persistence-and-names.md) |
| §15 | Names and families | [design/persistence-and-names.md](design/persistence-and-names.md) |
| §16 | Build rungs 1–5; going public; money | [design/build-rungs.md](design/build-rungs.md) |
| §17 | Asset plan for rung 2 | [design/build-rungs.md](design/build-rungs.md) |
| §18 | Code layout (Rojo), as first planned | [design/build-rungs.md](design/build-rungs.md) |
| §19 | Open questions | [design/open-questions.md](design/open-questions.md) |
| §20 | The world up close is inert (found in play, 2026-09-18) | [design/world-up-close.md](design/world-up-close.md) |
