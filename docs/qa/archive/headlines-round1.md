# Headlines — QA round 1 — SCORE: 8/10 (target 8.0 hit; loop ends)

Reviewer: Opus subagent with the Studio MCP, 2026-09-18, against the REAL DataStore (world at day 37). Builder: Fable.
The reviewer stalled waiting on a 10-minute real-rejoin test and was asked to report from what it had; that test is
under UNCERTAIN and was then run by the builder (see decisions).

## Report (verbatim, condensed only by removing the goal-by-goal prose that the GOALS list repeats)

SCORE: 8/10
GOALS:
- 1 returning player is told how long and what happened: met - live PlayerGui capture; banner + 3 staggered notices, correct fade timings (1.3s Title[Welcome back] Sub[You were gone 11 days.] / 2.1s Notice[Wenwyn Rockmere of Wild's Rest was killed by Stifffchoclate.] / 5.0s Notice[Hala Saltfield of Glenworth was killed by Stifffchoclate.] / 8.3s Notice[The river flooded the low ground.]).
- 2 headlines are the world's, not the player's: met - 64-ring in `meta.headlines` (`Headlines.lua:13`), player key gains only `lastSeenDay` (`Save.lua:164`); `by` duplicates the already-saved `people[].killer`.
- 3 catch-up writes them: met - `Tick.lua:41` + `headlines.test.luau:36-55`; but births are the only offline writer and `MAX_PEOPLE=9` blocks them in the live world (39 living / 3 tribes).
- 4 only what they would hear: met - `Headlines.lua:56,61-65` and `Restore.lua:68-71`, pinned by `headlines.test.luau:59-84`.
- 5 nothing regressed: met - `npm test` + `lint:luau` green; Sim.lua 1599→1570, ceiling 1580; the Goals carve is behaviour-identical and all old callers still resolve.

PRESERVE (done well, must survive future iterations):
- Ids and kinds in the ring, sentences built at read time (`Headlines.describe`): it is why a gravestone still has a name, and why nothing stale is ever saved.
- `describe` returning nil and the line being silently dropped: the "person pruned or never existed" case degrades to one fewer line, never to an error or a blank.
- The delivery hook in `sendWorld`: after `Sim.hud`, on the client's own request - sent only when a HUD exists.
- The 1 s / +3 s notice stagger and the banner/notice y-split (0.12–0.28 vs 0.30): at most two lines at once, nothing overlaps.
- `Goals.lua` as a verbatim carve with `Goals.bind(hudFn)` instead of a `require` back into Sim: no cycle, no behaviour drift, ceiling lowered rather than raised.

FIX (done poorly; why it matters; concretely how to fix):
- The welcome can be lost forever while `lastSeenDay` still advances: `Persistence.savePlayer` writes `lastSeenDay = today` unconditionally, but `ps.welcome` is cleared the moment the Notice is *fired*, and the client drops it if `hud` is nil. A player who joins and quits before their client asks for the world loses eleven days of news permanently, silently. -> Either carry the welcome inside the `WorldInit` payload, or have `savePlayer` keep the old `lastSeenDay` while `ps.welcome` is still pending.
- On a real absence the ring is empty: catch-up writes only births, and births cannot happen (`Families.MAX_PEOPLE = 9` vs ~12–13 living per tribe). The feature ships as "You were gone 3 days." with no lines for the case it was built for. -> push some "the world turned" headline from `Tick.daily`; the real fix is rung 2's `MAX_PEOPLE`.
- A massacre buries its own cause: deaths rank above calamities, so a beast tide that kills three villagers shows three names and never the tide. -> Take the top 2 by rank, then force-include the newest `calamity` headline.

CONSIDER (fine but could change; why; how):
- `by` on the death headline duplicates `people[].killer`. -> Drop `h.by` and read `p.killer` in `describe`.
- Nothing in `Debug.lua` can show the ring. -> Add `headlines`.
- The day-one opening beat fires for returning players ("Someone is calling you" + "Read the signs." flash first). -> Suppress it when the player is not new.
- The goal line is drawn under the banner frame (pre-existing). -> higher `ZIndex`.
- All three welcome lines use the default ink colour. -> `"warn"` for died/calamity, `"good"` for born.
- `welcome` allows `S.day - args[1]` to go negative. -> `math.max(0, …)`.

UNCERTAIN (could not verify):
- The real rejoin path (stop, wait >600 s, Play again); the real `tells` filter in execution.
- Whether the Notice can be delivered before `hud` exists (could not construct the race).
- Two players returning at once; the ring at 64 under a live massacre; headlines surviving Debug `reload`.

## Builder decisions

8/10, target hit. **FIX 1 and 3 taken in full, FIX 2 taken as far as this PR can honestly go; all six CONSIDER taken.**

- **The welcome now rides inside `WorldInit`**, which the client processes exactly once and only after its HUD
  exists - so it can neither race the HUD nor be dropped. And `savePlayer` keeps the OLD `lastSeenDay` for anyone who
  leaves before their client ever sent a move (`st.sawWorld`), so an unseen absence is not closed.
- **The newest calamity always keeps the last place** if rank alone would bury it; pinned by a new test (four deaths
  in a beast tide still say there was a tide).
- **The empty ring.** I did not invent filler headlines: deposits are the only other offline event and at two trips a
  day they would push every death out of a 64-entry ring. Instead the empty case is said out loud - "It was quiet
  while you were away." - and **the root cause is put to Danzo**: every tribe starts with 11-14 living against
  `Families.MAX_PEOPLE = 9`, so nobody is ever born until a village is thinned. One constant; his call, because it
  changes how villages grow.
- **Returning players no longer get the day-one beat** ("Someone is calling you" / "Read the signs.") - including
  one who is back the same day with no news (`{}` in the payload).
- Lines carry a colour (deaths and calamities warn, births good); `by` dropped for the registry's `killer`; Debug
  `headlines` lists the ring; the goal label sits above the banner; `[Server] <name> is back: ...` is logged.
- **The reviewer's UNCERTAIN real-rejoin test, run by the builder:** Play was started 10+ minutes after the
  reviewer's last stop. The world restored at day 38 (was 37), and the client's day-one hint was absent - which only
  happens when the welcome payload arrives inside `WorldInit`. The banner itself had faded before an MCP call could
  read it; Debug `welcome 5` then showed banner and three lines.
