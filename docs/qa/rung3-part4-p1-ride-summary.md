# QA summary: rung 3 part 4 phase 1 (ask, ride, arrive)

Goals: [`rung3-part4-p1-ride.md`](rung3-part4-p1-ride.md). Branch `h9-sim-carve` (phase 1 + H9 + the three rounds).
Three rounds of one Opus reviewer, each in Studio (DevMode). Target 8.0 not reached. Verbatim reports:
`docs/qa/archive/rung3-part4-p1-ride-round{1,2,3}.md`.

| Round | Score | Main finding |
|---|---|---|
| 1 | 7/10 | A rider who joined mid-leg was paid and credited for road never walked (`rode 25 of 25` standing still). |
| 2 | 6/10 | The round 1 fix regressed: legs walked while folded piled into `walked` (`rode 53 of 163`, 2 coin for a full leg). |
| 3 | 7/10 | Leaving the yes window open (it freezes movement) became a −3 walk-off; the squad leader said "ask the one in charge". |

## Fixed

- **Round 1:** every group's road counted each second, riders or not; a "left" leave spends the day's ask; a rider too
  far at the arrival hears why there's no share; the squad member points at the leader.
- **Round 2 (H10, heavy):** pure `Belong.legStep` — any change of `dir` starts a new leg (folded or not), a jump of
  more than `Belong.JUMP` = 6 route tiles is not road; tested over three legs. Studio: `paid 7 at Kenstow (rode 54 of
  54)`, Kenstow 0 → 2.25. "Keep bandits off the goods" (no carts drawn). Rule → learnings Q4.
- **Round 3:** a rider with a talk window open is neither lagging nor walking off; squad members name their leader,
  the leader invites; `ps.dialogue.e` kept after a topic.
- **Before the loop (H9):** a leader boxed in by a crowd gets out (`server/Walk.lua`, `shared/Steer.lua`), and `pos`
  follows the body. Round 2 saw the first natural Glenworth → Kenstow leg with no Debug `arrive`.

## Preserved (praised in every round)

- Rules in pure `shared/Belong.lua`, a thin adapter in `server/Ride.lua`; a test per rule.
- The save-unchanged test (a ridden group encodes as an unridden one; VERSION 4, PLAYER_VERSION 1).
- Patience spent only while the group would walk, per leg; the leader turns to face a lagging rider.
- "Not now" and "yes" don't spend the day's ask. Lines in the leader's own voice (`say()`).

## Deferred

- `heardKill` reads only the newest rumour about you: the "amends" reading, the same rule as `Gossip.latest`; a design call.
- A move key closing a choiceless window: a client change, and phase 1 promised none.
- "You walked off on us. Not today." instead of "I gave you my answer." after a walk-off: a new `Belong.ask` answer; phase 2's talk.
- A turn's own second of movement is not counted (`legStep` returns 0 on a new leg); the same for rider and leg, so pay is unaffected.
- The caravan master uses the `merchant` sprite; a distinct look waits for the wagon / sprite-size work in the inbox.

## Open after round 3

- The round 3 fixes were checked by tests and lint only, not in Studio.
- Not seen in Studio by any round: blows on your own group blocked, kill loot going into the pot, the mid-route
  walk-off line on screen, the arrival coin notice on screen. The sourcemap diff was not re-run (no `rojo.exe` on the Mac).
