# Reputation, gossip, grudges

**What it does.** Every holder (a village `v1`..`v3`, or a group by its id) has a standing with each player, from
−100 to 100, shown as words. Standing fades toward neutral. News of a kill, mercy, an escape or a gift travels as
rumours: groups carry it along roads and swap it when they meet or arrive. A grudge is the lasting scar and fades
over an in-game year.

**Key modules**
- `shared/Reputation.lua` says what a number means (`word`, `willTrade`, `priceMult`), the event deltas, and `fade`.
- `shared/Gossip.lua` holds the rumour ring, `knows` + `hops` per holder, `owed` (what absent players have
  coming) and exchange. `shared/Grudge.lua` holds the scar (re-exported by Gossip). Both are pure.
- `server/Standing.lua` is the server adapter. It maps entities to holder keys and tells the player when news
  changes an opinion.

**Tunables:** `REP_FADE_DAYS` and `GRUDGE_FADE_DAYS` in Config. `Gossip.MAX_RUMOURS`, `HOP_FADE`, `STALE_DAYS`,
`EVERY`, `OWED_MIN` at the top of `Gossip.lua`; `MAX`, `GROUP`, `AMEND_GIFT` at the top of `Grudge.lua`. The full spec is
[`docs/RUNG3.md`](../RUNG3.md) part 3.

**Gotchas**
- Memory is the transport; reputation and grudge are the ledger. Never derive the number from the capped ring
  (→ S1).
- A rumour is applied at a holder the moment that holder hears it (or owed to an absent player then), so
  `knows` is the only dedupe set. Hops live per holder, never on the shared row (→ S3, S4).
- Something the player should notice needs a Studio check that the line appeared, not just a passing test (→ Q1).

## Expansion: deficits at scale

Notes for the map/village/NPC expansion, not decisions. From the round 3 list in
[`rung3-part3-summary.md`](../qa/rung3-part3-summary.md), line numbers re-checked 2026-10-05. Targets: DESIGN §4
(40 groups, a couple of dozen villages) and ARCHITECTURE §5 (43 holders).

- **Village key is a tribe index**, `Gossip.lua:42-50,133-135`. Hard limit. The save builds one village per tribe
  (`Save.lua:140-141`) and `Save.rekeyRep` assumes village i = tribe i (`Save.lua:246-253`). Several villages per
  tribe breaks every key in `ps.rep`, `knows` and `owed`. Probably key by village id: a save migration (trigger 3).
- **Fixed group ids**, `Bands.lua:85-103` (`caravan`, `squad`, `band`). Hard limit. Every `ps.rep` key and `knows`
  row hangs off them. Probably generated ids from a `meta` counter.
- **Grudge and deltas keyed by tribe TYPE**, `Grudge.lua:6-7,16-24`, `Reputation.lua:58-90`. Hard limit. Two farmer
  tribes would share one scar, and a killing in one would move every farmer holder that hears it. HUD standing is
  keyed the same way and would overwrite (`Standing.lua:75`). Probably a design question (trigger 1).
- **The ring of 64**, `Gossip.lua:25`. Tuning. With many more NPCs and players it evicts news within minutes, before
  it travels. Probably size it to the event rate, or one ring per region. Guess: the rate is unmeasured.
- **`compact` walks every holder per eviction**, `Gossip.lua:142-151`, and `holders` re-sorts all groups (`:84-101`).
  Soft limit: holders × knows, on every eviction, and evictions get frequent (above).
- **Quadratic exchange**, `Gossip.lua:297-307`. Soft limit. Each id goes through `tell`, which scans `knows`
  (`:246-248`) and the ring via `find` (`:167-172`): O(K × (K + R)) per swap. `latest` does the same on every talk
  (`:389-392`). Probably a derived id set per holder and an id→rumour map (never saved).
- **`villageAt` is linear over tribes**, `Gossip.lua:311-317`, twice per `arrive` (`:324,327`). Soft limit. Probably a
  tile→village lookup built with the map.
- **Meet buckets are 2×2 tiles**, `Gossip.lua:350`. Tuning. Groups crossing on a long road between 60 s slots miss
  each other; the sweep also sorts every group each slot (`:344-357`). Probably a road-segment index.
- **Catch-up runs `meet` every simulated second**, `Tick.lua:199` inside `Tick.catchUp` (`:238-245`), up to
  `CATCHUP_CAP` (`:22`, four in-game weeks). Most seconds stop at the slot gate (`Gossip.lua:342`); every slot is a
  full sweep. Cost grows with groups × slots.
- **`ps.rep` keys are never pruned**, `Gossip.lua:117-129,215`. Soft limit. Dead groups' ids stay in the player key
  and in the daily fade (`Standing.lua:146,155`). Probably drop keys whose holder is gone.
- **`w.owed` grows with absent players × holders**, `Gossip.lua:222-236`. Soft limit, bounded only by `OWED_MIN`
  fading (`:185-189`), and it lives in the world key. The test pins 32 players, < 256 B each at 6 holders
  (`test/luau/gossip.test.luau:559,568`); guess: at ~40 B a holder that assert fails near 43 holders.
- **Byte test pinned at 6 holders**, `test/luau/gossip.test.luau:545-549` (< 40 KB, < 2 KB a holder). Tuning.
  ARCHITECTURE §5's 22.2 KB at 43 holders is the last estimate; re-measure at the real count.
- **Line ceiling**, `Gossip.lua` is 396 of 400 (`test/structure.test.js:17`). Hard limit. Any index or re-keying
  needs a split first (trigger 2).

Measure first: rumours seeded per in-game day at the target NPC and player count (against 64 and `STALE_DAYS`);
the time of one `meet` slot with 40 groups and full rings; `owed` bytes at the real holder count × absent players.
