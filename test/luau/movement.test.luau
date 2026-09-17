local WorldGen = __require("WorldGen")
local Movement = __require("Movement")
local DayCycle = __require("DayCycle")
local Config = __require("Config")

local world = WorldGen.generate(1)
local sx, sy = world.spawn.x, world.spawn.y

-- canStep: adjacent + walkable only
assert(Movement.canStep(world, sx, sy, sx, sy - 1), "north of spawn is the village path")
assert(not Movement.canStep(world, sx, sy, sx, sy), "standing still is not a step")
assert(not Movement.canStep(world, sx, sy, sx + 1, sy + 1), "no diagonals")
assert(not Movement.canStep(world, sx, sy, sx, sy - 2), "no two-tile jumps")
assert(not Movement.canStep(world, 1, 1, 2, 1), "map border rock is solid")

-- stepTime follows tile speed: roads faster than grass, fords slower
local function findGround(name)
	local id = __require("TileTypes").GroundByName[name].id
	for i = 1, world.width * world.height do
		if world.ground[i] == id then return (i - 1) % world.width + 1, math.floor((i - 1) / world.width) + 1 end
	end
	error("no " .. name)
end
local px, py = findGround("path")
local fx, fy = findGround("ford")
local gx, gy = findGround("grass")
assert(Movement.stepTime(world, px, py) < Movement.stepTime(world, gx, gy), "road should be faster than grass")
assert(Movement.stepTime(world, fx, fy) > Movement.stepTime(world, gx, gy), "ford should be slower than grass")
local rx, ry = findGround("river")
assert(Movement.stepTime(world, rx, ry) > Movement.stepTime(world, fx, fy), "wading should be slower than a ford")
assert(Movement.canStep(world, rx, ry, rx, ry + 1) or Movement.canStep(world, rx, ry, rx + 1, ry) or Movement.canStep(world, rx, ry, rx - 1, ry), "the river can be walked out of")

-- An honest walker can wade, slow as it is: the pace budget must never price a tile out of reach.
do
	local step = Movement.stepTime(world, rx, ry)
	assert(step > Config.MOVE_BURST, "this test is only interesting while a wade costs more than the burst window")
	local b = Movement.newBudget(0)
	local rejected = 0
	local seedW = 777
	local function jitter() seedW = (seedW * 1103515245 + 12345) % 2147483648; return (seedW / 2147483648) * 0.12 - 0.06 end
	for n = 1, 50 do
		if not Movement.spend(b, n * step + jitter(), step) then rejected += 1 end
	end
	assert(rejected == 0, ("a wading player was rejected %d times out of 50"):format(rejected))
	-- Walking off grass into the river and out again, paced exactly as the client paces it: the gap before each
	-- move is the step time of the tile being left, which is what the server charges.
	local grass = Movement.stepTime(world, gx, gy)
	local walk = { grass, grass, grass, step, step, grass, grass }
	local mixed = Movement.newBudget(0)
	local t, bad = 0, 0
	for i = 1, #walk - 1 do
		t += walk[i]
		if not Movement.spend(mixed, t, walk[i]) then bad += 1 end
	end
	assert(bad == 0, ("walking into and out of the river was rejected %d times"):format(bad))

	-- and it is still a pace check: fifty wades in an instant is not on
	local hack = Movement.newBudget(0)
	local ok = 0
	for _ = 1, 50 do if Movement.spend(hack, 0.01, step) then ok += 1 end end
	assert(ok <= 1, ("speed hack waded %d tiles with no time passing"):format(ok))
end

-- Budget: an honest client stepping exactly on time is never rejected, even with network jitter.
do
	local step = Movement.stepTime(world, gx, gy)
	local b = Movement.newBudget(0)
	local seedJ = 12345
	local function jitter() seedJ = (seedJ * 1103515245 + 12345) % 2147483648; return (seedJ / 2147483648) * 0.12 end
	local rejected = 0
	for n = 1, 2000 do
		local sent = n * step
		if not Movement.spend(b, sent + jitter(), step) then rejected += 1 end
	end
	assert(rejected == 0, ("honest walker rejected %d times"):format(rejected))
end

-- Budget: bunched packets (two arriving together after a lag spike) are accepted.
do
	local step = Config.MOVE_STEP
	local b = Movement.newBudget(0)
	for n = 1, 10 do assert(Movement.spend(b, n * step, step), "steady") end
	assert(Movement.spend(b, 10 * step + 0.2, step), "late packet")
	assert(Movement.spend(b, 10 * step + 0.2, step), "bunched packet right behind it")
end

-- Budget: a speed hack is capped near 1/MOVE_SLACK of normal speed.
do
	local step = Config.MOVE_STEP
	local b = Movement.newBudget(0)
	local accepted, t = 0, 0
	for _ = 1, 600 do
		t += step / 2 -- trying to walk twice as fast for ~51 s
		if Movement.spend(b, t, step) then accepted += 1 end
	end
	local honest = t / step
	assert(accepted <= honest / Config.MOVE_SLACK + 3, ("speed hack got %d steps vs honest %d"):format(accepted, honest))
	print(("speed hack: %d steps accepted in %.1f s (honest walker: %d)"):format(accepted, t, honest))
end

-- Day cycle: phases in order and a tint that ramps smoothly both ways.
do
	assert(DayCycle.nightAlpha(0) == 0 and DayCycle.nightAlpha(0.3) == 0, "day is not tinted")
	assert(math.abs(DayCycle.nightAlpha(0.8) - Config.NIGHT_ALPHA) < 1e-9, "night is fully tinted")
	local prev = DayCycle.nightAlpha(0)
	local maxJump = 0
	for i = 1, 6000 do
		local a = DayCycle.nightAlpha(i / 6000)
		maxJump = math.max(maxJump, math.abs(a - prev))
		prev = a
	end
	assert(maxJump < 0.01, "tint jumps: " .. maxJump)
	local dusk = Config.NIGHT_RAMP * Config.DAY_SECONDS
	print(("day cycle: dusk and dawn each fade over %.0f s; phases %s %s %s %s %s"):format(dusk,
		DayCycle.phase(0.1), DayCycle.phase(0.5), DayCycle.phase(0.67), DayCycle.phase(0.8), DayCycle.phase(0.97)))
end
