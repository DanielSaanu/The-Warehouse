# QA round 1: rung 3 part 4 phase 1 (ask, ride, arrive)

**SCORE: 7/10** (Opus reviewer, 2026-10-06, Studio played, DevMode)

## Report (verbatim)

SCORE: 7/10

Played in Studio (DevMode, Play started and stopped) and ran every automated check. The ask, the no-lines, the
master waiting, the clean leave and the walk-off −3 all work. One real defect in the pay/credit bookkeeping lets a
rider who joins mid-leg collect a full share and full credit for road they never walked — reproduced live.

**Evidence summary**
- `npm test` 13/13 pass; `node test/luau/run.js` 13/13 ok (incl. belong, steer); `lint:luau` clean. `Sim.lua` 1152
  lines vs ceiling 1153; `Gossip.lua` 396. No client files changed since the phase 1 commit. `exports/view_29_70@5x.png`
  unchanged (no art touched).
- Studio (Output + server/GUI reads): Glenworth master 2nd page `Choice1 = Ask to ride along`; yes = "Walk with us
  to Kenstow. Keep bandits off the carts. Your share's paid when we get there." Squad leader as a stranger: "Earn it
  first. Folk in Kenstow don't know you well enough yet."; re-ask "I gave you my answer." Lag test: rider 8 tiles
  behind, master held at 39,70 ≈20 s facing right (toward me), then walked on. Clean leave in the end pause: "Ride
  with us again." and caravan standing 34→36. Walk-off mid-route: teleported 20 tiles off, after 12 s caravan
  standing 36→33.
- **Bug reproduced:** summoned caravan to route idx 26 (no riders), asked, stood still with the caravan frozen,
  `arrive caravan` → `[Ride] Stifffchoclate paid 7 at Kenstow (rode 25 of 25)`: 7 coin, +4 caravan standing and the
  `rode` rumour for zero tiles walked.

GOALS:
- Ask is a conversation: met - leader-only "ride" (`Ride.lua:83-87`, band excluded); `Belong.ask` order matches the plan (`Belong.lua:40-50`); busy/yes don't spend (`Belong.lua:54-56`); confirmed live.
- Yes line teaches the job: met - names where/what/get (`Talk.lua:184-189`); choices/labels server-side; seen live.
- Rider is scratch: met - riders in `Bands.scratch` (`Bands.lua:70`); `belong.test.luau:156-174` proves identical encode, VERSION 4/PLAYER_VERSION 1.
- Riding (no aggro, blows blocked, leader waits): met - `Sides.lua:270`, `Sim.lua:591`, `Ride.lua:224-232`; wait/face seen live.
- The pot: partial - formula right in `Belong.share`, but `rode/walked` are fed stale data: `g.lastPos`/`g.walked` only update while a group HAS riders (`Ride.lua:142-145,181`), so the first tick after a join credits all road since the last rider (or since creation) to both `walked` and `rode`. Reproduced: rode 25 of 25 while standing still.
- The village hears: partial - mechanism correct (`Ride.lua:205-208`, `Gossip.TRAVELS.rode`, tested), but the same stale-lastPos bug lets a zero-walk rider pass `Belong.heard`.
- Leaving costs only what the plan says: met - clean +2 (0 if no leg ridden), mid-route −3, disconnect/death/collapse free (`Ride.lua:91-101,150-155`); confirmed live (could not read the "Suit yourself." notice on client - faded/located elsewhere).
- Ceilings and purity: met - Belong pure + tested; Sim ceiling lowered to 1153; no client change; Gossip < 400.
- Nothing regresses: met (for what I ran) - all tests green; did not re-run part 0 band/squad Studio checks or the sourcemap diff.

PRESERVE (done well, must survive future iterations):
- Pure `shared/Belong.lua` rules with an adapter `server/Ride.lua`: every rule is testable and the "could an NPC live by this" note keeps the design honest.
- The save-unchanged test (`belong.test.luau:156-174`): guards learnings S7 directly.
- Patience spent only while walking, per leg (`Ride.lua:172`, `Belong.WAIT`): the caravan can never be stalled forever; felt right live (≈20 s hold then on).
- "Not now"/"yes" not spending the ask: a player who asked mid-fight isn't punished.
- Leader-voiced lines (`say()` prefixes the name): no voice-from-nowhere.

FIX (done poorly; why it matters; concretely how to fix):
- Stale `lastPos`/`walked`: joining a caravan one tile from Kenstow pays the full share, +4 standing and seeds a `rode` rumour, breaking goal 5's "scaled by how much of the leg they actually walked" and goal 6's half-leg rule. Happens naturally whenever the caravan walked part of a leg riderless; the Glenworth Studio test missed it only because it started at pos 1. -> In `Ride.tick`, update `g.walked`/`g.lastPos` for every materialised group each tick (not only those with riders) so `walked` is the leg so far and a late joiner's rode/walked is honest; at minimum set `g.lastPos = g.pos` on a yes in `Ride.ask`. Add a server-side assertion or Debug path, since `belong.test.luau` can't see this.

CONSIDER (fine but could change; why; how):
- Squad member line: the ordinary squad member says "Walk with us if you like" (`Talk.lua:218`) then the leader says "Earn it first" to a stranger - a mixed message for a new player. -> point at the leader and the condition, e.g. "Ask Maren if you want to walk with us."
- Leave-and-rejoin: a rider can leave mid-route (−3) then re-ask immediately for a fresh yes (yes spends nothing). -> consider spending the ask on a "left" leave.
- `heardKill` only fires if the NEWEST rumour about you is a kill (`Ride.lua:72-79`); any later rumour (a gift) hides it. Possibly intended ("amends") but reads looser than goal 1's "a killing … they have heard about". -> document the choice, or scan for any unforgiven kill.
- Silent payout when far: a rider >12 tiles from the leader at arrival gets nothing and no line (`Ride.lua:202`); I hit this live at Glenworth. -> one "You weren't with us at the end." line teaches the rule.
- Ride end on summon: Debug `summon` collapses the group, silently ending the ride; fine for debug, worth one note in the goals' Debug list.

UNCERTAIN (could not verify):
- Client-side text of "Suit yourself." for the walk-off and the arrival coin notice (saw standing change and Output print, not the on-screen line).
- A full natural Glenworth → Kenstow ride with H9 pathing (the leg I saw ran Kenstow-ward pos 12 → Glenworth fine, but I did not walk a full leg).
- Kenstow's own standing rising from the `rode` rumour on arrival (village 2 stayed 0 in my session, but my arrival was a Debug `arrive`, so village hearing it was not exercised).
- Part 0 band/squad checks, sourcemap diff (not re-run).
- A stray camp: during input injection my player's `camper_set` was used ("rest":"your camp") - likely an F press with no one in front, i.e. my test artifact, not a bug.

## Builder decisions

- **FIX stale `walked`: done.** `Ride.tick` now counts each group's road every second whether or not it has riders
  (`g.lastPos`/`g.walked`), so `walked` is the leg so far and a late joiner starts at `rode = 0` against it. The
  per-rider work moved into `tickGroup(g, now, step)`. Not covered by a Luau test (server adapter); round 2 should
  repeat the summon-to-26 repro, which should now print `rode 0 of 25` and pay nothing.
- **CONSIDER squad line: done.** "Squad's out for deer. Want to walk with us? Ask the one in charge." (`shared/Talk.lua`,
  text only).
- **CONSIDER leave-and-rejoin: done.** A "left" leave (mid-route, asked or walked off) spends the day's ask, so the
  re-ask is "I gave you my answer."
- **CONSIDER silent payout when far: done.** A rider who is too far at the arrival gets "You weren't with them at the
  end. No share for you."
- **CONSIDER `heardKill` newest-only: deferred.** It is the "amends" reading (a later deed outweighs an older kill),
  the same newest-rumour rule `Gossip.latest` uses everywhere; changing it is a design call, not a fix.
- **CONSIDER summon note: done** in the goals' Debug list.
