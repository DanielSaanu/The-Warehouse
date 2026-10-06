# QA round 3: rung 3 part 4 phase 1 (ask, ride, arrive)

**SCORE: 7/10** (Opus reviewer, 2026-10-06, Studio played at e7c19ee, DevMode; Studio sources checked equal by length)

## Report (verbatim)

**Score: 7/10.** The H10 fix is clean and well tested. I reproduced the "leader stood still" report in Studio and
found the cause: a player who leaves the yes window open is fined −3 for a walk-off they never made.

**Sources checked.** Before Play I compared lengths in Studio against the local files. All six match: Ride 11735,
Belong 6670, Talk 12320, Walk 5887, Debug 17925, Bands 11787. DevMode was on and Play was stopped at the end.

**Tests.** `npm test` and `npm run lint:luau` passed with no failures; every lint line was "ok". `node test/luau/run.js`
passed, including the new belong leg block. I looked at `exports/view_29_70@5x.png` and it renders fine; no art changed
this round.

**What I saw in Studio** (seed 1, Glenworth, `freeze 1`, actions sent through `Remotes.Action` from the Client datamodel):
- **Talking to the master:** "We run Glenworth to Kenstow and back..." over 3 pages (`More: (1/3)`), with the ride choice on the last page.
- **Asking to ride:** "Walk with us to Kenstow. Keep bandits off the goods. Your share's paid when we get there." Output: `[Ride] Stifffchoclate rides with the caravan`.
- **Open-window question (unfrozen, window left open, player at 26,69):** master e56 went to 30,70, then 31,70, and stood there "idle" from about t6 to t21 s; it moved on at about t24 s (32,70); the caravan then folded away and reached pos 50/56; Debug `player` showed caravan standing 17 (most likely 20 − 3, inferred); the window was still open the whole time: "Dialogue.More = F / click: close".
- **Cause, from the code:** while any panel is open the client blocks all movement (`Client.client.lua:604`, `blocked = me.dead or hud:anyOpen()`; also `:570`), so walking away cannot close the window. The server counts that frozen rider as lagging; the leader holds for `Belong.WAIT` = 20 s, walks on, and the group folds while the rider has `farSince` set. That ends the ride as "left" (`finish`, `away = false`): −3 with the group and the day's ask spent. No server code holds a leader because of a talk window, so the builder's stop was this 20 s rider-wait, not a bug in Walk.
- **Asking the caravan again** after that, via a summon: "I gave you my answer."
- **Squad leader Maren Greenton as a stranger:** her opening line is "Squad's out for deer. Want to walk with us? Ask the one in charge." Asking to ride then gives "Earn it first. Folk in Kenstow don't know you well enough yet."

SCORE: 7/10
GOALS:
- 1 Ask is a conversation: met - choices only on the leader (`Ride.choices`); Studio yes, a no with a reason, "I gave you my answer."
- 2 Yes line teaches the job: met - names Kenstow, the job ("off the goods") and the pay; labels come from the server (`Talk.lua:171`).
- 3 Rider is scratch: met - the save test encodes the same with `lastDir` set; VERSION 4 / PLAYER_VERSION 1 asserted.
- 4 Riding (no aggro, blows blocked, leader waits): partial - the wait works (about 15–18 s idle at 31,70), but it also fires on a rider who cannot move because the window is open; I did not test blows in Studio.
- 5 Pot and per-leg share: met - `Belong.legStep` resets on any change of `dir`; the test gives "rode 55 of 55" = 7 and a late joiner 25 of 55; the builder saw "rode 54 of 54".
- 6 Village hears: met (code and tests) - `Standing.event("rode")` runs before `Bands.turn` (`Walk.lua:94`); I did not see an arrival myself.
- 7 Leaving costs: partial - walk-off gives −3 and spends the ask, as designed, but a player reading the yes window is charged it too.
- 8 Ceilings and purity: met - Belong is pure (127 lines) and the structure test passes.
- 9 No regressions: met for tests and lint; sourcemap not checked because there is no `rojo.exe` on this Mac.

PRESERVE (done well, must survive future iterations):
- `Belong.legStep` (pure, `JUMP` = 6, `lastDir` kept on the group): the leg depends only on `dir` and `pos`, folded or not, and fixes the root of H10 with a test that drives three legs.
- Debug `summon` setting `lastPos`, and `Bands.scratch` setting `lastDir`: a fresh record or a teleport is not counted as road.
- Patience spent only while walking, the leader turning to face a lagging rider, leader-voiced lines, the save-unchanged test and the thin Ride adapter.

FIX (done poorly; why it matters; concretely how to fix):
- The open yes window turns into a −3 walk-off: the window freezes all movement (`Client.client.lua:604`); a new player reading it, or tabbing away, has the leader wait 20 s, walk off and fold, and the ride ends "left": −3 and no second ask today (reproduced; standing 17). -> In `Ride.tickGroup`, treat a rider whose `ps.dialogue` is open as present (no `farSince`, no `waitLeft` spent); or grade "away" when the group folds with the dialogue open; better still the client closes a choiceless dialogue on a move key (a client change; phase 1 promised none).
- The squad leader says "Ask the one in charge.": `Talk.groupLine("hunter")` (`Talk.lua:218`) is given to every hunter, including the leader offering the ride button. -> Pass whether this one is the leader into `groupLine`; the leader says "Squad's out for deer. Want to walk with us?"; the others name the leader.

CONSIDER (fine but could change; why; how):
- "I gave you my answer." after a mid-route walk-off reads oddly because the answer was yes. -> When `ps.asked` was set by a "left" leave, a different no: "You walked off on us. Not today."
- `Interact.topic` needs `ps.dialogue.e`, but `dialogue()` (`Interact.lua:77`) rebuilds `ps.dialogue` without it, so a second topic in the same window is silently dropped; harmless today, will bite phase 2's follow-up topics. -> Keep `e` in `dialogue()`.
- A turn's own second of movement is dropped (`legStep` returns 0 on a new leg). Consistent for rider and leg, so pay is unaffected; document it.

UNCERTAIN (could not verify):
- A full natural Glenworth → Kenstow arrival this round (payout line, `rode` rumour, Kenstow standing); the builder reports "paid 7 at Kenstow (rode 54 of 54)"; not repeated.
- Blows on your own group being blocked, and loot going into the pot, in Studio.
- Sourcemap equality: there is no `rojo.exe` on this Mac.
- Whether the starting caravan standing was exactly 20, so that 17 is precisely the −3.

## Builder decisions

- **FIX open window = walk-off: done (server only).** `Ride.tickGroup` treats a rider with `ps.dialogue` open as
  present: `farSince` is cleared and they are not a lagger, so no wait is spent on them and a fold while reading is
  "away" (free). The server clears `ps.dialogue` on the client's `close` (`Interact.close`). The client-side "a move
  key closes a choiceless window" is deferred: phase 1 promised no client change.
- **FIX squad leader's line: done.** `Talk.groupLine(kind, ctx, boss?)`: a hunter who is not the leader says
  "Squad's out for deer. Ask <leader's first name> if you want to walk with us."; the leader says "… Want to walk
  with us?". The name is passed from `Interact` (no pronoun guessed).
- **CONSIDER `ps.dialogue.e` lost after a topic: done.** `Interact` puts it back after the topic's reply.
- **CONSIDER "You walked off on us": deferred.** It needs a new answer in `Belong.ask`; phase 2 owns the talk.
- **CONSIDER document the turn's dropped second: deferred** to the summary (pay is unaffected).
- Not Studio-checked by the builder this round (tests and lint only); the loop ends here.
