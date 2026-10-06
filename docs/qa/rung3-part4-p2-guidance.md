# QA goals: rung 3 part 4, phase 2 (the obvious layer)

Branch: `rung3-part4-p2` (cut from `h9-sim-carve` at 3c8360a). Plan: [`docs/plans/rung3-part4-belonging.md`](../plans/rung3-part4-belonging.md)
"Phase 2" and "Slightly obvious what to do". Handoff H11. Review the phase 2 commit's diff, with the new files as
they stand: `shared/Barks.lua`, `server/RoadTalk.lua`, `test/luau/barks.test.luau`. Phase 1's loop:
[`rung3-part4-p1-ride-summary.md`](rung3-part4-p1-ride-summary.md).

The question for this loop: **once you ride with a group, do the people around you make it obvious what to do,
by talking to you, with no log, no arrow and no new UI?** The plan's own test is the **30-second test**: a fresh
tester joins the caravan and, within 30 s and without asking, can say where they are going and what they are guarding.

## Goals

1. **Barks are people talking** (plan "Barks"). Short (at most 7 words; a short form at most 4), a name in front
   ("Bera: Wolves, east!"), said only to riders, as the ordinary text notice (fades after 4 s, 3 at most). The
   speaker is a living member **on the rider's screen** (within `Config.COLS/2` x `ROWS/2`), nearest to what the bark
   is about; nobody on screen, no bark. Never modal; nothing while a talk window is open.
2. **The first facts.** The plan's eight: joined, you lag, hostile seen (wolf, bandit not of this group), prey seen
   (squad: deer), end near, arrived, member down, you hurt. Plus `spooked` (the leader's witness flee holds the ride,
   deferred from phase 1) and `road` (road talk after 45 s of quiet, e.g. "Kenstow's short of food, they say.").
3. **The three rules, pure and tested** (`Barks.pick`): the most specific line wins (the rule matching most of the
   fact's fields: a wolf is "Wolves!", bandits seen by the caravan are "Guard the master!"); nothing said twice in a
   row; a teaching line is said 3 times a session, then its short form 3 times, then never. One bark at a time per
   rider, at least 3 s apart; each fact has its own gap; the most urgent fact that can be said wins.
4. **"What now"** is a talk-window choice on everyone in your group while you ride (the leader also offers "leave").
   The leader says where, how far ("About 40 paces yet.") and the job; a member says what the boss told them; at an
   end, "We rest here a while, then on to <next>". Nobody outside your group offers it.
5. **Phase 1's deferred talk.** The re-ask after a mid-route walk-off says "You walked off on us. Not today." (not
   "I gave you my answer."). The squad leader's window is titled "<name>, squad leader". A witness flee that holds the
   ride gets a line from a member ("Bram's spooked. We hold here.").
6. **Nothing saved, nothing new on the client.** `ps.barks` (the fade) and `ps.leftOn` are session scratch, `g.talk`
   is group scratch; `belong.test.luau` shows a player with all of them encodes exactly as one without, and a ridden
   group as an unridden one. `Save.VERSION` 4, `PLAYER_VERSION` 1. No client file changes; `Sim.lua` untouched.
7. **Ceilings and purity.** `Barks.lua` is pure Luau with a test per rule. The sourcemap differs from 3c8360a only
   by two new ModuleScripts (`Shared/Barks`, `Server/RoadTalk`). `Ride.lua` stays well under 400 (phase 3 needs room).
8. **Nothing regresses**: `npm test`, `npm run lint:luau`, `npm run test:luau`; phase 1's play-through still holds.

## Studio play-through (DevMode on, nothing saves)

1. **The 30-second test** with someone who has not read the plan: at Glenworth, F the caravan master, ride along,
   close the window. Within 30 s, unprompted, can they say where they are going and what they guard?
2. After the yes window closes, a member (not the master) says a "joined" line. Every bark has a speaker on screen.
3. Lag 5+ tiles: the master stops, faces you, and someone says "Keep up!". Do it 7 times in a session: full lines
   3 times, the short form, then quiet.
4. Meet a wolf or the band on the road: a member names it and the way it is ("Bandits, east! Guard the master!").
5. F a caravan guard while riding: "Ask what now". F the master: "Ask what now" and "Tell them you're leaving".
6. Near Kenstow: "Kenstow's close now." Arrive: a member's "Kenstow. Made it.", then the master's pay line.
7. Walk off mid-route, ask again: "You walked off on us. Not today." Ask the squad's leader: "<name>, squad leader".

## Out of scope (do not penalise absence)

Phase 3 (the band's ask, others reading you as the group, desertion, betrayal, `ctx.withGroup`), phase 4 (first to
spot it: the halt-and-bunch and the spotter's share; phase 2's "hostile seen" is only a line). A HUD "riding with"
line (Q8: only if the 30-second test fails). A move key closing a choiceless window (part 4 promised no client change).

## Builder's calls (inside the plan, made the cheap way; argue with any of them)

- **Urgency order:** down, hurt, spooked, hostile, prey, lag, joined, near, arrived, road. Gaps (s): hostile, prey,
  hurt 8; lag 10; spooked 12; road 45 of quiet; the rest 0 (each is news once: `g.talk` remembers a seen wolf, the end
  near, the crew, until the next leg).
- **The fade counts only lines that showed**: a fact with no face on screen, or one that would repeat, is dropped
  before the pick and costs nothing. Teaching facts: joined, lag, hostile, prey, spooked, hurt. News never fades.
- **"Never twice in a row"** is against the last line said to that player. A line whose blank the fact cannot fill
  ("Wolves, {dir}!" with no direction) is skipped for the next variant.
- **Barks wait while a window is open**, and `joined` waits until it is actually said (the yes window is open the
  second after the yes: clearing it on the attempt lost it, caught in review → learnings S9).
- **The lag bark** is said by whoever is nearest the leader on your screen: the leader when you can see him (a rider
  up to 12 tiles back may not).
- **"Seen"** is within 8 tiles of the leader. Bandits of another group are hostile to the caravan and the squad.
- **Speakers** prefer a member over the leader for joined, near, arrived, road and spooked (the master does not
  call himself spooked).

## Known limitations going in

- Every server-side piece (RoadTalk, the `whatnow` routing, the squad leader's title, the walk-off re-ask) was checked
  by tests, lint and an adversarial read only, **not yet in Studio**.
- "Member down" is a body leaving `g.entities` while materialised; it fires for a death. If anything else removes a
  body mid-ride, it would read as a death (none known).
- The direction in a bark is from the rider ("close by" within 3 tiles), not from the speaker.

## Useful Debug commands

`group caravan|squad`, `summon <group>`, `teleport x y`, `state`, `day`, `strike <entityId> [dmg]`.
`summon` collapses a materialised group first, which silently ends any ride with it (a Debug artifact).
