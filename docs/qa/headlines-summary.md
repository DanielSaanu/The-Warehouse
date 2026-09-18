# Headlines — QA summary: one round, 8/10

Goals: `docs/qa/headlines.md`. Builder: Fable. Reviewer: one Opus subagent, in Studio against the real DataStore.
Verbatim report and decisions: `docs/qa/archive/headlines-round1.md`.

| Round | Score | Main finding |
| --- | --- | --- |
| 1 | 8.0 | All five goals met. The welcome could be lost for good if a player quit before their client drew the world; and on a real absence the ring is usually empty, because births cannot happen |

**Fixed:** the welcome rides inside `WorldInit` (cannot race the HUD or be dropped) and an unseen absence does not
advance `lastSeenDay`; the newest calamity is never buried by the deaths it caused; returning players skip the
day-one beat; lines are coloured; the killer comes from the registry; Debug `headlines`; the goal label sits above
the banner.

**Preserved:** ids-and-kinds in the ring with sentences made at read time; a missing person costs one line, never an
error; the staggered notices; `Goals.lua` as a verbatim carve.

**Deferred, and it is Danzo's call:** `Families.MAX_PEOPLE = 9` against 11-14 living per tribe means nobody is born
until a village is thinned, so after a quiet absence the welcome says "It was quiet while you were away." - which is
true, and a little sad. Raising the constant above the starting rosters (16 fits DESIGN §4's 60-NPC cap) makes
villages grow and gives catch-up something to report.

## What to look for (Danzo)

1. Play, stop, wait 10+ minutes, Play. Output: `[Server] <you> is back: You were gone a day. (1 lines)`. On screen:
   "Welcome back / You were gone a day.", then a line. No "Someone is calling you", no "Read the signs."
2. `workspace:SetAttribute("Debug", "headlines")` lists the ring. Two entries are the reviewer's doing: it killed
   Hala Saltfield of Glenworth and Wenwyn Rockmere of Wild's Rest **in your saved world** while testing.
3. `workspace:SetAttribute("Debug", "welcome 30")` shows the full banner-and-three-lines beat on demand.
