--!strict
-- Server-side world state. One world per server. Rung 2: generated fresh at start; rung 3 adds save + catch-up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))

local World = {}

World.seed = 0
World.world = nil :: WorldGen.World?
World.encoded = nil :: WorldGen.Encoded?

function World.init()
	local seed = Config.WORLD_SEED
	if seed == 0 then seed = math.random(1, 2 ^ 30) end
	local t0 = os.clock()
	local world = WorldGen.generate(seed, Config.WORLD_WIDTH, Config.WORLD_HEIGHT)
	World.seed = seed
	World.world = world
	World.encoded = WorldGen.encode(world)
	local names = {}
	for _, v in ipairs(world.villages) do table.insert(names, ("%s (%s)"):format(v.name, v.tribeType)) end
	print(("[World] seed %d, %dx%d, villages: %s (%.0f ms)"):format(seed, world.width, world.height, table.concat(names, ", "), (os.clock() - t0) * 1000))
end

function World.get(): WorldGen.World
	assert(World.world, "World.init() not called")
	return World.world :: WorldGen.World
end

function World.walkable(x: number, y: number): boolean
	return WorldGen.walkable(World.get(), x, y)
end

return World
