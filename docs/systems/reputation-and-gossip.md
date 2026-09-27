# Reputation, gossip, grudges

**What it does.** Every holder (a village `v1`..`v3`, or a group by its id) has a standing with each player, from
−100 to 100, shown as words. Standing fades toward neutral. News of a kill, mercy, an escape or a gift travels as
rumours: groups carry it along roads and swap it when they meet or arrive. A grudge is the lasting scar and fades
over an in-game year.

**Key modules**
- `shared/Reputation.lua` says what a number means (`word`, `willTrade`, `priceMult`), the event deltas, and `fade`.
- `shared/Gossip.lua` holds the rumour ring, `knows` per holder, grudges and exchange. The whole rule is pure.
- `server/Standing.lua` is the server adapter. It maps entities to holder keys and tells the player when news
  changes an opinion.

**Tunables:** `REP_FADE_DAYS` and `GRUDGE_FADE_DAYS` in Config. `Gossip.MAX_RUMOURS`, `HOP_FADE`, `STALE_DAYS`,
`EVERY`, `GRUDGE_MAX`, `GRUDGE_GROUP` and `AMEND_GIFT` at the top of `Gossip.lua`. The full spec is
[`docs/RUNG3.md`](../RUNG3.md) part 3.

**Gotchas**
- Memory is the transport; reputation and grudge are the ledger. Never derive the number from the capped ring
  (→ S1).
- The "already heard" set is keyed per (holder, rumour), not per rumour (→ S3).
- Something the player should notice needs a Studio check that the line appeared, not just a passing test (→ Q1).
