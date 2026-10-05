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

**Tunables:** `CAMPFIRE_HOURS`, `BAG_PRIVATE_SECONDS` and `BAG_LIFETIME_SECONDS` in Config. Item stats are in
`Items.lua`.

**Gotchas**
- Camp and bag tiles are derived from their rows and never saved. `Tiles.stampAll()` puts them back after a load.
- The two bag timers are the only ones set in player-session time rather than world time.
