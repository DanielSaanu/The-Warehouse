# Design §14–§15: persistence and multiplayer, names and families

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 14. Persistence and multiplayer

- One shared world per server. Reputation, grudge and memory are per player. Gossip carries player names.
  Confirmed by Danzo 2026-09-18 and no longer an open question: a private copy per player would make "everything
  remembers" hollow, and the caravan you joined has to be the caravan somebody else robbed.
- No PvP damage for now. Tribes judge players individually: one player's massacre is that player's problem.
- The world state (tribes, groups, villages, regions, calamity clock) is saved to DataStore every 2 minutes and
  on server shutdown. Player state is saved separately on leave.
- **Catch-up**: on load, the server runs the simulation for the missed time at coarse steps (one step per
  in-game hour, capped at 4 weeks), so caravans arrive, tribes breed, the ecosystem drifts. Players are not
  simulated while offline.
- If two servers run the same world (Roblox can start a second server when the first is full), the second loads
  the last save and diverges. v1 accepts this. Later: one world per server slot.

## 15. Names

Every entity gets a random first name and last name: NPCs, players' NPC relatives, animals that get notable
(the wolf that ate your caravan), villages and tribes (from a different generator). Children born in the
simulation keep the father's last name, so a family you wronged stays recognisable across generations. Names are
how gossip refers to people and how grudges stay attached to someone.

**Families (from rung 2).** Every person is a record with parents, children, birth day and, when it comes,
death day and cause (who, or what). That is the family tree, and it is the spine of grudges and gossip later:
"you killed my father" is a lookup. The human clock runs on the in-game calendar and is much slower than the
beasts', which breed on the daily ecology tick:
- Three stages, no in-betweens, one sprite each (Danzo, 2026-09-17): a **pregnant** woman (her own sprite) for
  one in-game week (70 real minutes), then a **baby** (its own sprite, it stays where it is put, by the parents'
  hut) for two weeks, then an **adult** villager (the sprite that exists). Villagers carry a sex; there is no
  separate adult woman sprite yet.
- A village with room under its visible cap (9 named people) and at least one couple conceives about once an
  in-game week. The baby takes the father's surname and its own first name. Killing a baby or a pregnant woman is
  the worst thing you can do to a village (-40).
- Couples form between two unrelated adults of the same village; widows and widowers may re-pair after a month.
- Villages lose people to fights, calamities and (later) raids; they refill by births, not by respawning, so a
  village you emptied stays empty for weeks and its neighbours notice. This is what keeps the population loop
  from becoming murder, respawn, repeat.
- Ideas box: villagers are named, but their roles are what the world sees. See §8.
