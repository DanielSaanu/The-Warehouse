-- Game tuning. Safe to edit by hand. See docs/DESIGN.md for what these mean.
local Config = {}

-- Viewport: how many tiles are on screen. The play area keeps this aspect ratio on every device.
Config.COLS = 16
Config.ROWS = 12

-- World
Config.WORLD_SEED = 1          -- 0 = a new random world every server (persistence comes in rung 3)
Config.WORLD_WIDTH = 96
Config.WORLD_HEIGHT = 96

-- Movement: seconds per tile at speed 1. Tiles have their own speed multipliers (TileTypes).
Config.MOVE_STEP = 0.17
Config.MOVE_TOLERANCE = 0.65   -- server accepts steps arriving at >= this fraction of the expected interval

-- Time: one in-game day in real seconds, and the fraction of it that is night.
Config.DAY_SECONDS = 600
Config.NIGHT_FRACTION = 0.3

-- UI
Config.BANNER_SECONDS = 3

return Config
