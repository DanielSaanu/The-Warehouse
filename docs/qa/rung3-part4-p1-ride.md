# QA goals: rung 3 part 4, phase 1 (ask, ride, arrive)

Branch: `dev`. Plan: [`docs/plans/rung3-part4-belonging.md`](../plans/rung3-part4-belonging.md) "Phase 1", approved
by Danzo 2026-10-05 with Q1–Q10 decided. Handoff H8. Review the phase 1 commit's diff, with the new files as they
stand: `shared/Belong.lua`, `server/Ride.lua`, `test/luau/belong.test.luau`.

The question for this loop: **can a player ask a caravan master or a hunter to ride along, walk the route with
them, get paid on arrival and have the village hear about it, under the same rules an NPC member lives by, with
nothing new in the save?**

## Goals

1. **The ask is a conversation** (plan "Joining"). The caravan master and the squad's leader offer "Ask to ride
   along" in the talk window; nobody else does, and the band does not yet (its ask rules are phase 3). The answer
   is `Belong.ask`, pure, checks in the plan's order, the first that fires wins: not now (fighting, retreating),
   asked today, full (`Config.RIDERS_MAX` = 2), grudge, a killing of their tribe they have heard about (the reason
   names it), standing (the lower of the group's number and its village's, Q5), else yes. A "not now" does not
   spend the day's ask.
2. **The yes line teaches the job** in one breath: where (the village at the end the group is walking to, or the
   wood for the squad), what you do, what you get. No client change: the choices and labels come from the server.
3. **A rider is scratch, never saved** (Q3, learnings S7). `g.riders[userId]` and `ps.ride`; not a row in
   `g.members`; `Save.VERSION` stays 4 and `PLAYER_VERSION` 1. A test shows a ridden group encodes exactly as an
   unridden one.
4. **Riding.** Your own group never goes for you on sight, and your blows on its members are blocked with a line
   (every blow in phase 1; the second-blow betrayal is phase 3). The leader stops and faces you when you fall more
   than 4 tiles behind, at most 20 s per leg, then walks on.
5. **The pot** (Q6). While you ride, the goods from your kills go into the group's `carry`, coin stays yours. At
   each arrival the leader pays coin: the caravan a wage per leg (`Belong.CARAVAN_POT`), plus the value of the carry
   at the home end for every kind. The pot is cut by `alive / fullSize`, split by shares (living members plus
   riders), and each rider's share is scaled by how much of the leg they actually walked with the group.
6. **The village hears.** A rider who walked at least half the leg gets a `rode` rumour seeded at the group (hop 0)
   before `Tick.groupTurn`, so `Gossip.arrive` tells the village at that end, one hop weaker. `rode` is a new value
   in the rumour's existing `event` field, not a format change.
7. **Leaving costs only what the plan says.** Asking "leave" during a pause at an end, or walking off then: clean,
   a small plus with the group. Mid-route (asking, or more than 12 tiles from the leader for 10 s): a −3 with the
   group only and one line, no failure notice. A disconnect, a death or the group collapsing: nothing (Q1).
8. **Ceilings and purity.** `Belong.lua` is pure Luau with a test for every rule. `Sim.lua` grows only by the
   hooks and its ceiling is lowered to the new count. No client file changes. `Gossip.lua` stays under 400.
9. **Nothing regresses**: `npm test`, `npm run lint:luau`, `npm run test:luau`; the sourcemap differs only by the
   two new ModuleScripts; the part 0 Studio checks (band breaks at half, squad banks its hides) still hold.

## Studio play-through (DevMode on, nothing saves)

1. At Glenworth, F the caravan master: "Ask to ride along". The yes names Kenstow, the job and the pay.
2. Walk with the caravan; lag behind and watch the master stop and face you; catch up.
3. Arrive at Kenstow: a coin line from the master, and Kenstow's number for you goes up (Debug, or the standing panel).
4. Ask the squad as a stranger: a "no" with a reason. Ask the master twice in a day: "I gave you my answer."
5. Walk away from the caravan mid-route: one line, −3 with the caravan, no failure.

## Out of scope (do not penalise absence)

Phase 2 (barks, "what now", road talk), phase 3 (riding with the band, others reading you as the group,
desertion, betrayal, `ctx.withGroup`), phase 4 (first to spot it). The squad's carry growing after it turns home
(deferred from phase 0).

## Known limitations going in

- Nobody else reads you as part of the group yet: the band attacks a caravan rider only by its own opinion of
  you, not because you walk with the caravan. That is phase 3.
- A rider's standing line appears only when the WORD changes (`Standing.announce`); a +2 at Kenstow is visible in
  the standing panel and in the master's arrival line, not as its own notice.
- Coin is minted at payout, as trade and loot already are.
- **Fixed before this loop (handoff H9, 2026-10-06, branch `h9-sim-carve`): a leader stalled in a crowd while its
  `pos` ran on.** `followPath`/`groupStep` are now `server/Walk.lua`: a leader swaps with its own idle people, any body
  detours round a crowd (`shared/Steer.lua`), `pos` moves only on where the leader stands (`Tick.leaderStep`), and a
  hunt on an unreachable quarry gives up. Detail: `docs/systems/population.md` "Walking in a crowd (H9)". A full
  Glenworth → Kenstow ride should now work without Debug `arrive`; a player (or anyone) standing still in a village
  GATE still holds the caravan, by design. Do not park the harness on the leader's next tile (→ T5).
- Fixed on the way: a leader beside a TAKEN end tile now turns (`Tick.leaderStep`; tested in `belong.test.luau`).

## Useful Debug commands

`group caravan|squad`, `summon <group>`, `teleport x y`, `state`, `day`, `strike <entityId> [dmg]`.
