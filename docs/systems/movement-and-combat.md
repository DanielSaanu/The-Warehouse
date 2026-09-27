# Movement and combat

**What it does.** Tile-by-tile movement that the client predicts and the server validates. Fights are melee
swings with cooldowns and knockback, and NPCs telegraph their swings before they land. Onlookers take sides by
one rule: help the side you dislike less, if the gap is worth a fight.

**Key modules**
- `shared/Movement.lua` holds the step protocol and the pace budget. A step is charged the step time of the tile
  being LEFT.
- `shared/Combat.lua` holds damage, facing, knockback and loot, shared by the server (authority) and client (feel).
- `shared/Stats.lua` gives players, people and animals the same stat block.
- `shared/Witness.lua` holds the pure side-taking rule. `server/Sides.lua` applies it to the simulation.

**Tunables:** `MOVE_STEP`, `MOVE_SLACK`, `MOVE_BURST`, `ATTACK_COOLDOWN`, `HIT_INVULN`, `TELEGRAPH` and
`RESPAWN_SECONDS` in Config. Tile speed multipliers are in `TileTypes`.

**Gotchas**
- A rejected move snaps the player back and bumps `epoch`, so moves already in flight are dropped.
- `Sides`, `Debug` and `Restore` never `require` Sim: Sim binds itself into them in `init`. This avoids a require
  cycle and keeps Sim inside Luau's type-inference budget.
- Being killed costs no reputation. Reputation records conduct, not luck (DESIGN §7).
