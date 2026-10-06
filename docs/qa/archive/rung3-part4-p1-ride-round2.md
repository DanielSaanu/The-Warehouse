# QA round 2: rung 3 part 4 phase 1 (ask, ride, arrive)

**SCORE: 6/10** (Opus reviewer, 2026-10-06, Studio played, DevMode, a natural leg without Debug `arrive`)

## Report (verbatim)

SCORE: 6/10

The round-1 fix brought in a worse bug. `Ride.tick` now adds each second's road to `g.walked` for every group, but
only `Ride.arrive` resets it, and `Ride.arrive` runs only when a materialised leader turns
(`roblox/src/server/Walk.lua:94`, Debug `arrive`). A folded group turns in `Tick.groups` → `Tick.groupTurn`
(`roblox/src/shared/Tick.lua:229`), and that path never resets `walked`. So every leg the caravan walks while nobody
is near piles up in `g.walked`. Groups are folded most of the time, so a player who rides a whole leg in normal play
gets a fraction of the pay and no `rode` rumour.

**What I saw in Studio** (DevMode, no Debug `arrive`):
- I teleported the player to 76,10 so the caravan folded, and used `jump` to skip its pauses. It walked two legs
  folded: Glenworth → Kenstow → Glenworth.
- Back at Glenworth I pressed F on Gweno Deepmere and got the real dialogue: "There are bandits afoot…" then the
  "Ask to ride along" button. Clicking it gave "Walk with us to Kenstow. Keep bandits off the carts. Your share's paid
  when we get there."
- I unfroze and stayed one tile behind the leader for the whole leg (a server loop teleported the player onto the
  tile the leader had just left). The caravan walked pos 1 → 56 and turned at Kenstow by itself.
- Output: `[Ride] Stifffchoclate paid 2 at Kenstow (rode 53 of 163)`.
- Coin went 0 → 2; with a correct 56-tile `walked` the share is 30/4 = 7.
- Kenstow standing stayed `v2 0`. `gossip` showed "0 rumours in flight" and "v2 [Kenstow] knows nothing", because
  53/163 is under `HEARD_HALF`.

So goals 5 and 6 fail on any natural ride except the very first leg after server start. Studio steps 2–3 ("Kenstow's
number goes up") also fail.

GOALS:
- 1 The ask is a conversation: met - Studio: master's third page shows the "Ask to ride along" button; `Belong.ask` order is right (`Belong.lua:37-47`); "not now"/"yes" don't spend the ask (`spendsAsk`).
- 2 The yes line teaches the job: met - Studio text: "Walk with us to Kenstow. Keep bandits off the carts. Your share's paid when we get there." No client change.
- 3 A rider is scratch, never saved: met - `g.riders`/`ps.ride` live only in `Bands.scratch`; save.test.luau passes.
- 4 Riding (no aggro, blocked blows, leader waits): partial - code reads right (`Ride.blocks`, `tickGroup` holding only outside pauses), but my test kept the player beside the leader, so the wait and face were not seen.
- 5 The pot: not met in natural play - `rode 53 of 163`, paid 2 instead of 7 for a full leg; `walked` includes legs walked while folded.
- 6 The village hears: not met in natural play - same cause; 53/163 < 0.5, so no `rode` rumour and Kenstow stays at 0.
- 7 Leaving costs: met (code) - `finish` sets `ps.asked` on "left" (`Ride.lua:96`); "away" costs nothing. Not exercised in Studio.
- 8 Ceilings and purity: met - Belong is pure and tested, Gossip.lua is 396 lines (under 400), structure test passes.
- 9 Nothing regresses: partial - `npm test` (13 node tests pass, every Luau suite ok) and `lint:luau` are clean, but the round-1 fix regressed goal 5/6 behaviour and no test covers it.

PRESERVE (done well, must survive future iterations):
- H9 pathing: the caravan walked Glenworth → Kenstow materialised and turned without Debug `arrive`. That is the first real end-to-end leg.
- Pure `Belong` plus the thin `Ride` adapter, and lines in the leader's voice through `say()`.
- Talk lines: "I heard about the %s. No.", "Earn it first. Folk in %s don't know you well enough yet.", and the arrival line with its pointer onward. They are short, they come from the world, and they teach.
- Patience is spent only while the group would be walking (`g.holding` is gated on `pauseUntil`). A walk-out spends the day's ask.
- Riders are scratch, and the save-unchanged test.

FIX (done poorly; why it matters; concretely how to fix):
- `g.walked` piles up across folded turns (`Ride.lua:200-208`). This is the core reward and the village hearing about you, and it fails in ordinary play. -> Reset the leg at every turn, not only at a materialised arrival. In `Ride.tick`, track `g.lastDir`: when `g.dir ~= g.lastDir`, set `g.walked = 0`, set each rider's `r.rode = 0`, and set `g.lastDir = g.dir`, before adding `step`. Then a folded `Tick.groupTurn` (and catch-up) resets the leg too. Also skip the jump when `Bands.collapse` snaps `pos` to the nearest route index, or ignore steps larger than `ceil(speed)+1`. Add a test for this; the cleanest is to move the leg accounting into a pure `Belong.legStep(g)` and test that 2 legs folded + 1 ridden gives `rode == walked`.
- No regression test caught this. The belong tests cover `share`/`heard` arithmetic but not how `walked` is kept. -> Add the test above, then repeat the Studio check: fold for two legs, ride one, and expect `rode ~55 of ~55`, 7 coin, and Kenstow +2.

CONSIDER (fine but could change; why; how):
- "Keep bandits off the carts": there are no carts on screen (Danzo's own wagon note is in the inbox). -> Say "off the goods" until a wagon sprite exists.
- Debug `summon`'s `pos` jump is also counted as road walked. That is harmless for QA, but it is why the requested round-1 repro (`rode 0 of N`) passes trivially. -> Set `g.lastPos = g.pos` in `summon`.
- The talk window kept showing the yes line for the whole ride while the player was teleported along (possibly a teleport artefact, not seen with real walking). -> Check that walking away closes the dialogue.
- The caravan master is drawn with the `merchant` sprite. A player may read "trader", not "someone I can join". -> A distinct sprite or label later.

UNCERTAIN (could not verify):
- The lag wait/face (4 to 12 tiles behind, 20 s cap) and the mid-route walk-off (−3, one line) in live play. Both read correct in code.
- Whether the arrival notice toast displayed. The text had already faded by the time I read the GUI. The Output line and the coin change (0 → 2) confirm the payout.
- Squad ask as a stranger, and "I gave you my answer." on a second ask. Not exercised this round; logic in `Ride.ask` and `Belong.spendsAsk` is right.
- Part 0 checks (band breaks at half, squad banks hides). Output did show "[Sim] the Kenstow squad came home with 4 hide, 5 food".

Play is stopped. No tracked files were modified (only the regenerated `exports/` previews, which are untracked).

## Builder decisions

- **The FIX is my round 1 regression** (→ T5-style slip: a fix tested only on the path the repro used). The proper
  fix wants a pure leg-accounting rule in `shared/Belong.lua` with a test, which is CLAUDE.md trigger 2 (and 4, since
  my first attempt failed), so it is escalated as **H10** to the heavy agent rather than patched again here.
- **H10 fix (heavy agent, 2026-10-06).** The leg is now a pure rule, `Belong.legStep(leg, pos, dir)`, called by
  `Ride.tick` once a second for every group. **A change of `dir` is a new leg**, wherever the turn happened: a folded
  `Tick.groupTurn`, a materialised `Bands.turn`, a squad turning for home laden (`Bands.addCarry`), Debug `turn`.
  On a new leg `walked` is 0 and `Ride.tick` zeroes each rider's `rode`. Keying on `dir` rather than on a turn hook
  means no shared tick (`Tick.groups`, catch-up) has to know riding exists. `Ride.arrive` still resets after paying
  (harmless; the next tick sees the turn and resets again). `Bands.scratch` sets `g.lastDir = g.dir`, so a server
  start is not a turn. All scratch: `save.test.luau` asserts the world key is unchanged with `lastDir` set; no
  version bump.
- **A jump is not road.** A move of more than `Belong.JUMP = 6` route tiles in one second (a materialised leader can
  legitimately catch up `Tick.CATCH_UP` = 4 at once) counts 0: Debug `summon`, a `Bands.collapse` snap. Debug
  `summon` also sets `g.lastPos` now (the CONSIDER), so a short summon is not road either.
- **Test first** (`belong.test.luau`, "the leg (H10)"): two folded legs out and back on a 56-tile route at 1-2 tiles a
  second, then a ridden leg → `rode 55 of 55`, heard, 7 coin; the round-1 goal (a joiner 30 tiles in is paid 25 of
  55, not the whole leg); a 39-tile summon jump is 0; a 6-tile catch-up is road; a turn mid-route resets; a fresh
  record is not a turn. It failed on the old code (no leg rule to call; the old accounting gave `walked` 165 for the
  same three legs). `npm test` (13 node, every Luau suite) and `lint:luau` clean.
- **Studio (DevMode, no Debug `arrive`):** the player stood at 76,10 while the caravan walked two legs folded
  (turned at Kenstow at 40 s, back at Glenworth at 79 s; `jump` past pauses). Asked Gweno Deepmere through the real
  `interact` + `topic ride` actions: "Walk with us to Kenstow. Keep bandits off the goods. …". Followed one tile
  behind (the tile the leader had just left, → T5); the caravan walked pos 1 → 56 and turned by itself. Output:
  `[Ride] Stifffchoclate paid 7 at Kenstow (rode 54 of 54)`; coin 0 → 7; `gossip`: "#1 day 4 rode caravan",
  "v2 [Kenstow] knows #1"; standing v2 0 → 2.25, caravan 24. (54, not 55: the first and last second of a leg fall
  either side of a tick.)
- **"off the carts" → "off the goods"** (Talk and the plan), until a wagon is drawn.
- **Seen once, not explained (for round 3):** on a first Studio run I left the talk window open after the yes and
  the leader stopped dead off the road at 26,76 (pos 17, idle, guards idle) for over 30 s while the rest of the
  world moved; no Output warning. On the second run I closed the window after the yes and the leg walked cleanly.
  The open window may be holding the leader (the reviewer's CONSIDER saw the yes line stay up for a whole ride),
  but that is a guess: check whether `ps.dialogue` with a leader holds it, and whether walking away closes it.
- Slip: the round-1 fix was checked only on the path its repro used (Debug `summon` + `arrive`, which reset the leg
  by hand), never on a group that turned while folded → learnings **Q4**.
