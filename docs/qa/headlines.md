# Headlines: "You were gone eleven days."

Branch `headlines`. Builder: Fable. The visible half of save and catch-up: the world moves while you are away
(Track A), and now it tells you what it did.

## Goals

1. **A returning player is told how long they were gone and what happened.** On join, after at least one in-game
   day away: a banner "Welcome back / You were gone N days." and up to three one-line headlines, shown one at a
   time so they can be read. Not gone a day: nothing. A brand-new player: nothing.
2. **The headlines are the world's, not the player's.** One ring of 64 in `meta.headlines` (ids and kinds, never
   sentences - the words are made at read time from the registry, so a gravestone still has a name). The player's
   key holds only `lastSeenDay`. No per-player data enters the world key.
3. **Catch-up writes them.** Births are pushed by the pure tick, so a world that ticked with nobody in it still has
   news. Deaths and calamities are pushed by Sim where they happen.
4. **Only what they would hear.** Newer than `lastSeenDay`; a death outranks a calamity outranks a birth, newest
   first; from the village they sleep in and any tribe that is not wary of them. A calamity is everybody's news.
5. **Nothing regressed**, including Track A: headlines survive `reload` and a save; `Sim.lua` did not grow - the
   goal line was carved verbatim into `server/Goals.lua` to make room, and its ceiling in
   `test/structure.test.js` dropped from 1600 to 1580.

## Out of scope

- Births do not actually occur in a fresh world: every tribe starts with more living people than
  `Families.MAX_PEOPLE = 9`, so nobody conceives until somebody dies. That is rung 2's balance, not this PR - but
  it means the headline you will see most is a calamity or a death. Noted for Danzo.
- Gossip (part 3), Track B. A "+N more" line (the count is computed and unused on the client).

## How to test

Debug `welcome <days>` sends the connected player the welcome they would get after that many days away (every
tribe tells them). To make news first: `calamity flood` then `calamity none`; kill a villager; or `reload 12000`
(20 days of sleep). The real path: play, stop, wait 10+ minutes (a day is 600 s), play again - needs Studio API
access on, which it now is on Danzo's machine.
