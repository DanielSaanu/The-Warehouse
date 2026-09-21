# QA summary: the PC stack (villagers' day, births, Track B1, labels)

Goals: `docs/qa/track-b1.md`. Branch `track-b1-bands` (on `villagers-day`, on `main` 986b9cd). Danzo's bar for this
loop was **8.5**, at most three rounds. One Opus reviewer per round, each with Studio; fixes between rounds by the
main session. The loop stopped after round 2, at the bar. The verbatim reports are in `docs/qa/archive/`.

| Round | Score | The round's main finding |
| --- | --- | --- |
| 1 | 8 / 10 | Everything works, but the harvest was deleted every morning by the restock's ceiling, nobody was told about it, and captions smeared exactly where the villagers' day bunches people. |
| 2 | 8.5 / 10 | All eight goals met and zero warnings in Output; the fields ripened in lockstep, the design section the new files cite was missing from main, and "people I have met" had no idea which world it belonged to. |

## What was fixed

**After round 1**
- The restock's ceiling cut farmer food back to 45 every morning, so the harvest was cosmetic. A tribe with fields
  now makes its food from the HARVEST (not from the fields and the abstract restock both), making only tops up,
  and the yield was retuned so a full village earns what the restock used to hand it. A month at full strength
  settles around 72-75 food; the same month with nobody left falls to the trade floor.
- `ev.harvests` had no reader: `Villagers.harvested` logs each harvest and tells a player standing in the village.
- Captions: the trades that come in crowds (villager, hunter, bandit, caravan guard, baby) carry none until met;
  guard, merchant and caravan master keep theirs; met people and the survivor are named. Done on the server
  because `Viewport.lua` and `Client.client.lua` are both at their line ceilings.
- An empty group no longer stands materialised and frozen; `killEntity` removes only the member row it found.
- Pregnant villagers keep their day and their hands; a restore rescans the villages BEFORE catch-up; an obsolete
  save under another server's live lease is left to that server.

**After round 2** (the bar was met; these were done anyway, per the loop's procedure)
- Every plot has its own pace (`Farms.pace`) and a harvest keeps its remainder, so the fields never fall into step:
  something comes in on 30 days of 30, with the plots at different stages on all of them (tested).
- `docs/DESIGN.md` §20 "The world up close is inert" - written on the PC on 2026-09-18 and never pushed - is on
  main's design doc now, with a note on where it stands and the one thing the rebuild changed on purpose.
- The faces a player has met belong to a world: `meta.worldId` (made with the world, saved), written beside `met`
  in the player key; a different world, or none, means nobody is an acquaintance (tested).
- **The squad no longer walks through Wild's Rest.** Round 2's reviewer found the local fix round 1's builder
  missed: `Bands.forestTarget` now rejects a forest whose road passes within 4 tiles of another village. Studio,
  three days with the player standing in Wild's Rest: zero deaths, and the squad came home with 7 hide and 8 food.
  This was a known limitation going in, out of scope, and raised as CONSIDER in both rounds.
- `Villagers.report` counts every villager; the band's "broken off" line prints once; README line counts corrected.

## What was preserved (confirmed across rounds)

- `shared/Farms.lua` as a pure rule over records, which is why catch-up farms for free.
- `Farms.scan` reading through `world.floodBackup`, so a scan made mid-flood cannot shift plot rows off their tiles.
- `Restore.apply` calling `Villagers.reset()` BEFORE `Tick.catchUp`. Do not tidy it to the end.
- `killEntity` removing the row it found, and `Bands.collapse` clearing the body pointer but never the person.
- The v1-obsolete path: no half-migrated world is possible; a save from the future is still left alone.
- `farms.test.luau` and `members.test.luau` as the H5 standard for a rule you can read by its test.

## Tried and reverted

Three targeting rules in `Sides.preysOn` for the squad at Wild's Rest (leave people at home alone; people at home
do not sally out; "fighting" means fighting a person). Each was run in Studio; each still ended in a battle, the
last the worst (9 dead), because the cause was the ROUTE. All three were reverted; `Sides.lua` is identical to main.

## Deferred, and why

- Headlines for harvests (round 1): declined. A harvest most days would push births and deaths out of the 64-entry ring.
- `t.news` is sticky until something overwrites it: a pre-existing pattern for every news writer; gossip (part 3) replaces `news`.
- `Tiles.lua` bag lifetime: `age > 3600` game seconds is 6 in-game days, the comment says "an hour", and
  `BAG_PRIVATE_SECONDS = 600` is a whole day. Carried verbatim from main. **Which number is right is Danzo's call.**
- `Villagers.danger` is a full entity sweep per villager per thought: cheap under the 100-entity cap; a cached
  "hostiles near village i" list is the fix when a measurement says so (ARCHITECTURE §5 is demand-driven on this).
- A village with nobody left still drifts back up to 30 food through `Trade.dailyRestock`'s pull to target: the
  abstract "everyone trades a little". True of every good and every tribe; changing it is an economy decision.
- `Farms.daily` writes `t.stock.food` and `t.news` directly. R2 gives those to `Economy` / `Population`, which do
  not exist yet: put `Farms` in B3's grep.

## Never verified (both rounds)

- Two players at once, and a player leaving mid-move: the MCP drives one client.
- A phone-shaped screen: captures are the 1291x606 Studio viewport. Named people standing together still overlap,
  and that grows as a player meets more people.
- `Farms.drown` in the shipped world: on seed 1 Glenworth's plots are inside the walls and never go under. The
  rule is covered by `farms.test.luau` only.
- The nil caption in the middle of the `spawn` remote's arguments: unlabelled people rendered and animated, but
  nobody proved the argument after the hole arrives intact (`ekind or base` masks it either way).
