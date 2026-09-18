--!strict
-- The generated MAP (ground, objects, villages), one per server, and the encoded copy every joining client is sent.
-- Owns: the WorldGen.World table and `Map.encoded`. Does NOT own the World Record (tribes, people, groups...): that is
-- Sim.state, and docs/ARCHITECTURE.md §2. It was called World.lua until the record needed the word.
--   local world = Map.get()   -- everywhere else on the server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))

local Map = {}

Map.seed = 0
Map.world = nil :: WorldGen.World?
Map.encoded = nil :: WorldGen.Encoded?

function Map.init()
	local seed = Config.WORLD_SEED
	if seed == 0 then seed = math.random(1, 2 ^ 30) end
	local t0 = os.clock()
	local world = WorldGen.generate(seed, Config.WORLD_WIDTH, Config.WORLD_HEIGHT)
	Map.seed = seed
	Map.world = world
	Map.encoded = WorldGen.encode(world)
	local names = {}
	for _, v in ipairs(world.villages) do table.insert(names, ("%s (%s)"):format(v.name, v.tribeType)) end
	local ms = math.floor((os.clock() - t0) * 1000)
	print(("[Map] seed %d, %dx%d, villages: "):format(seed, world.width, world.height) .. table.concat(names, ", ") .. " (" .. ms .. " ms)")
end

function Map.get(): WorldGen.World
	assert(Map.world, "Map.init() not called")
	return Map.world :: WorldGen.World
end

--- A village by id (its index in world.villages). Tribes and people hold the ID, never the table: a reference
--- cannot be saved, and two copies of one village stop being `==` (docs/ARCHITECTURE.md A3).
function Map.village(id: number): WorldGen.Village
	return Map.get().villages[id]
end

function Map.walkable(x: number, y: number): boolean
	return MapGen.walkable(Map.get(), x, y)
end

return Map
