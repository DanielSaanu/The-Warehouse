-- Game tuning. Safe to edit by hand.
local Config = {}

Config.COLS = 16          -- play area width in tiles
Config.ROWS = 12          -- play area height in tiles
Config.TILE_PX = 16       -- source sprite size (informational; the UI scales tiles to fit the screen)

Config.CYCLE_SECONDS = 90 -- dry time before rain
Config.RAIN_SECONDS = 20  -- how long the rain lasts
Config.MOVE_TWEEN = 0.08  -- seconds per tile step

return Config
