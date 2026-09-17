-- Game tuning. Safe to edit by hand. See docs/DESIGN.md for what these mean.
local Config = {}

-- Viewport: how many tiles are on screen. ROWS is fixed; COLS grows with the screen's aspect ratio between
-- COLS and MAX_COLS so wide phones get more world instead of black bars.
Config.COLS = 16
Config.MAX_COLS = 22
Config.ROWS = 12

-- World
Config.WORLD_SEED = 1          -- 0 = a new random world every server (persistence comes in rung 3)
Config.WORLD_WIDTH = 96
Config.WORLD_HEIGHT = 96
Config.REGION = 16             -- regions are REGION x REGION tiles (wildlife counts, territory)

-- Movement: seconds per tile at speed 1. Tiles have their own speed multipliers (TileTypes).
Config.MOVE_STEP = 0.17
-- Server pace check (shared/Movement.lua): real time earns credit up to MOVE_BURST seconds, each step spends
-- MOVE_SLACK x its step time. Slack < 1 absorbs frame timing; the burst absorbs network jitter (bunched packets).
Config.MOVE_SLACK = 0.85
Config.MOVE_BURST = 0.35

-- Time: one in-game day in real seconds, and the fraction of it that is night.
Config.DAY_SECONDS = 600
Config.NIGHT_FRACTION = 0.3
Config.NIGHT_RAMP = 0.06       -- fraction of the day spent fading into night (dusk) and out of it (dawn)
Config.NIGHT_ALPHA = 0.55      -- darkness of the night tint
Config.WEEK_DAYS = 7

-- Combat (shared/Combat.lua)
Config.ATTACK_COOLDOWN = 0.4   -- seconds between player swings
Config.HIT_INVULN = 0.6        -- seconds of invulnerability after being hit
Config.TELEGRAPH = 0.5         -- seconds an NPC winds up before its swing lands
Config.RESPAWN_SECONDS = 3
Config.BAG_PRIVATE_SECONDS = 600 -- a dropped bag is only visible to its owner for this long

-- Interest management: entities are replicated to a player within this many tiles (dx, dy).
Config.VIEW_DX = 13
Config.VIEW_DY = 10
Config.MATERIALISE_RANGE = 22  -- groups and wildlife become sprites when a player is this close (tiles)
Config.COLLAPSE_RANGE = 30     -- and fold back into records when every player is this far

-- Camp
Config.CAMPFIRE_HOURS = 4      -- in-game hours the fire burns
Config.CAMPFIRE_RADIUS = 3     -- wolves keep this far from a lit fire

-- Calamities: one per week, starting this fraction into the calamity day. The warning shows the day before.
Config.CALAMITY_START = 0.3

-- Reputation
Config.REP_FADE_DAYS = 30      -- half the distance to neutral every this many in-game days

-- UI
Config.BANNER_SECONDS = 3

return Config
