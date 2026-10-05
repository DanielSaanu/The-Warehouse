# Talking, trade and the F key

**What it does.** F acts on whatever is in front of the player: talk (a villager line, guard topics, the survivor,
the caravan master), trade at a merchant or stall, rest at a bed or camp, place a camp, pick up a bag. Four goods
and coin; prices move with stock and with standing. A goal line under the clock tutors the first steps.

**Key modules**
- `server/Interact.lua` is the F key on the server, and it is the authority. The client builds its prompt from the
  same rules (`promptFor` in `Client.client.lua`).
- `shared/Talk.lua` holds every line, built from a context the server assembles from live state.
- `shared/Trade.lua` holds prices, restock and quotes. `shared/Items.lua` holds item definitions and the 10-slot
  inventory.
- `server/Goals.lua` holds the goal line. It stops for good at the first calamity.
- `server/Tiles.lua` handles camps and bags, and it is the only runtime writer of the map's object layer.
- `server/Ride.lua` answers a group leader's `ride` / `leave` topics (rung 3 part 4). The caravan master and the
  squad's leader offer them; the band does from phase 3. The answer is `Belong.ask` (pure); the lines are
  `Talk.joinYes` / `joinNo` / `arrival` / `leave`. Labels travel in `Talk.TOPIC_LABELS`, so the client is unchanged.

**Tunables:** `CAMPFIRE_HOURS`, `BAG_PRIVATE_SECONDS` and `BAG_LIFETIME_SECONDS` in Config. Item stats are in
`Items.lua`.

**Gotchas**
- Camp and bag tiles are derived from their rows and never saved. `Tiles.stampAll()` puts them back after a load.
- The two bag timers are the only ones set in player-session time rather than world time.

## Expansion: deficits at scale

Notes for the map/village/NPC expansion, not decisions. Checked against the code on 2026-10-05. Targets: DESIGN §4
(a couple of dozen villages, 40 groups) and §5 (size tiers per tribe).

- **Three villages by index**, `Interact.lua:65-67`, `Goals.lua:23,57`. Hard limit. The context treats
  `world.villages[1..3]` as THE farmer, hunter and plunderer village; `Talk.Context` has one slot each
  (`Talk.lua:18-22`), and so do the guard's tribes line (`Talk.lua:135`) and the caravan master's route
  (`Talk.lua:155`). Probably "nearest village of a type" and the master's own route, from live state.
- **One band**, `Interact.lua:43-51`. Hard limit. `banditHint` reads the fixed id `S.groups.band`; with more bands
  only one is ever reported. Probably the nearest band.
- **Stock, merchant and survivor live on the tribe**, `Interact.lua:53,56,91,173,227-228,288-312`, saved per tribe
  (`Save.lua:91`). Hard limit. Several villages of one tribe would share one store and one merchant. Probably stock
  per village: a save change (trigger 3).
- **Tribe index = village index**, `Interact.lua:81-88` (`tribeAt` maps a village back to one tribe). Hard limit.
- **`ps.rest.village` means two things**, `Sim.lua:562-565`, `State.lua:122`, `Restore.lua:72`. Hard limit. It
  indexes `world.villages` and is read as a tribe index by `Standing.tribe`; the fallbacks hard-code 1
  (`Tiles.lua:50`, `Sim.lua:562,1130`). It is in the player key, so fixing it is a save change.
- **Survivor fallback name**, `Interact.lua:70`. Hard-codes `S.tribes[1]`.
- **Lines are per tribe TYPE**, `Talk.lua:46-65`. Tuning (content). Every farmer village says the same lines, and some
  name today's map ("up north", "Five of them"). At two dozen villages it reads canned.
- **Four goods, targets per type**, `Items.lua:21`, `Trade.lua:11-19`. Tuning. No size tier in `TARGET`, so small and
  large villages price alike. The client mirrors `Items.GOODS` (`Client.client.lua:170`).
- **`WorldGen.villageAt` is linear over villages**, `WorldGen.lua:811-817`. Soft limit. Called per F by `tribeAt`,
  by the client's `promptFor` (`Client.client.lua:188`), and per player per tick by `Goals.lua:57`. Probably a
  tile→village lookup.
- **Camp sweep is camps × entities**, `Tiles.lua:56-70`, at 1 Hz: each unlit camp scans every entity for wolves. Soft
  limit. Camps never expire on their own (only wolves, flood or a new camp clear one), so `S.camps` and the world key
  gain a row per player who ever camped. Guess: confirm nothing else clears them.
- **`Tiles.bagAt` is linear**, `Tiles.lua:89-94`. Tuning. Bounded by the bag lifetime; fine unless players are many.
- **Context rebuilt per F press**, `Interact.lua:39-74`, including `Standing.heard` (a `knows` × ring scan, see
  reputation-and-gossip). Tuning. Fine per press; watch it if NPCs start talking to each other.
- **Line ceiling**, `Interact.lua` is 348 of 400 (`test/structure.test.js:17`). Soft limit. A multi-village context
  likely pushes it over; probably split the context builder out first.
- **Tests pin today's numbers**, `test/luau/sim.test.luau:27` (10 slots), `:84` (camper set 15, plunderers sell none).
  Tuning. Expect to update them with any economy change.

Measure first: `villageAt` calls per second at the target village and player count; `Tiles.tick` time at the target
entity count with one camp per player ever seen; camp bytes in the world key after many players.
