# Making it fun: research behind the world expansion

Written 2026-10-07 for handoff H13 and the branch `world-expansion` (plan: [`../../plans/world-expansion.md`](../../plans/world-expansion.md)).
Danzo asked for "more elements that make the world entertaining to be in". Before building, six questions were
researched against other games, their developers' own talks, and the measured literature where any exists. These
are **not decisions**: candidates, judged against [PRINCIPLES](../../PRINCIPLES.md) and the controls (move, left
click attack, F interact, phone-first Roblox). Every claim carries a tag ([measured], [dev], [opinion]) and a link;
the links are collected in [07-sources](07-sources.md); each doc ends with its own "Gaps".

| Doc | Question | One-line answer |
|---|---|---|
| [01-feel](01-feel.md) | Why does a hit feel flat? | Stack small redundant cues on every hit, scale them to the hit, fudge timing in the player's favour; on touch, auto-face the nearest hostile. Lowlands has the skeleton, not the stacking or the sound. |
| [02-exploration](02-exploration.md) | Is 256 x 256 with 16 villages too big? | No: it is Hoenn-density. The risk is empty screens, not distance. Build a 16-node road graph, let forest and marsh eat the area, fill *time* not tiles. |
| [03-stories](03-stories.md) | Why do the simulated stories go unseen? | The simulation runs but never copies into the player's head. Add a surfacing layer (faces, lines, marks, a sifter), not more simulation. |
| [04-roblox](04-roblox.md) | What does the platform demand? | Fun inside five minutes, a loop you can read in a minute, progress while away, timed events. Half of sessions end before minute seven. |
| [05-goals](05-goals.md) | Why is the first week dead air? | No new pattern to learn for 25–70 minutes. Hand out one untried thing at a time through people, never a quest log. |
| [06-liveliness](06-liveliness.md) | What makes a place feel alive? | Many small things that move on their own, one memorable detail per place, a clock that at least three systems key off, a calamity telegraphed in stages. |

## What this round takes from it

The plan builds the map and the buildings first (Danzo's call). From the research, the map pass should carry:

- **Density over size** (02): a road tree, roads with bends, forest, marsh and hills eating most of the area, one tall
  thing per village visible a screen early, one landmark per village-to-village leg (the "places between villages").
- **Marks of history** (06): the burnt village, the ruined watchtower, the battlefield are not scenery, they are
  stories the world tells without a line of text. Each needs a tell that reads at 16 x 16.
- **Three palettes, sixteen hooks** (02): every village must look like its tribe from a screen away and have one
  detail no other village has.
- **Secrets with tells** (02): a cave or a shrine off the road is only a reward if something near the road hints at it.

The rest (feel, surfacing, the first fifteen minutes, the clock) feeds H12 and the later rungs: see
[`../../plans/first-week-and-toys.md`](../../plans/first-week-and-toys.md). Nothing here changes
[ARCHITECTURE](../../ARCHITECTURE.md) or [DESIGN](../../DESIGN.md); anything that would is trigger 1.
