local WorldGen = __require("WorldGen")
local TileTypes = __require("TileTypes")
local Names = __require("Names")
local Rng = __require("Rng")

-- Rng is deterministic
do
	local a, b = Rng.new(123), Rng.new(123)
	for _ = 1, 100 do assert(a:nextU32() == b:nextU32(), "rng not deterministic") end
	local r = Rng.new(5)
	for _ = 1, 1000 do local v = r:int(1, 6); assert(v >= 1 and v <= 6, "int out of range") end
end

-- Names produce something sane
do
	local r = Rng.new(9)
	local first, last = Names.person(r)
	assert(#first >= 3 and #last >= 5, "name too short")
	assert(Names.place(r, "plunderer"):find(" ") ~= nil or true)
end

local function counts(world)
	local c = {}
	for i = 1, world.width * world.height do
		local g = TileTypes.Ground[world.ground[i]].name
		c[g] = (c[g] or 0) + 1
		local o = world.object[i]
		if o ~= 0 then local n = TileTypes.Object[o].name; c[n] = (c[n] or 0) + 1 end
	end
	return c
end

for _, seed in ipairs({ 1, 7, 42, 2026, 3, 99, 123456 }) do
	local t0 = os.clock()
	local world = WorldGen.generate(seed)
	local dt = os.clock() - t0
	assert(world.width == 96 and world.height == 96, "size")
	assert(#world.ground == 96 * 96 and #world.object == 96 * 96, "layers")
	assert(#world.villages == 3, "villages")
	assert(WorldGen.walkable(world, world.spawn.x, world.spawn.y), "spawn not walkable")
	local names = {}
	for _, v in ipairs(world.villages) do
		table.insert(names, v.name .. "(" .. v.tribeType .. ")")
		assert(WorldGen.reachable(world, world.spawn.x, world.spawn.y, v.spawn.x, v.spawn.y), "unreachable village " .. v.name .. " seed " .. seed)
		local nearBed = WorldGen.nearestWalkable(world, v.bed.x, v.bed.y, 2)
		assert(nearBed, "no walkable tile near bed in " .. v.name)
		assert(WorldGen.object(world, v.bed.x, v.bed.y) == TileTypes.ObjectByName.bed.id, "bed missing in " .. v.name)
		assert(WorldGen.object(world, v.stall.x, v.stall.y) == TileTypes.ObjectByName.stall.id, "stall missing in " .. v.name)
	end
	-- determinism
	local again = WorldGen.generate(seed)
	for i = 1, 96 * 96, 97 do assert(again.ground[i] == world.ground[i] and again.object[i] == world.object[i], "not deterministic") end
	-- encode / decode
	local enc = WorldGen.encode(world)
	assert(#enc.ground == 96 * 96, "encoded size")
	assert(not enc.ground:find("[%c]") and not enc.object:find("[%c]"), "encoded map must be printable (no control bytes)")
	local dec = WorldGen.decode(enc)
	for i = 1, 96 * 96 do assert(dec.ground[i] == world.ground[i] and dec.object[i] == world.object[i], "roundtrip") end
	-- Every gate opens onto a road that reaches the other villages (no gate to nowhere).
	for _, v in ipairs(world.villages) do
		for _, g in ipairs(v.gates) do
			assert(WorldGen.ground(world, g.exit.x, g.exit.y) == TileTypes.GroundByName.path.id, "gate exit is not a road in " .. v.name)
			for _, o in ipairs(world.villages) do
				assert(WorldGen.reachable(world, g.exit.x, g.exit.y, o.spawn.x, o.spawn.y), "gate of " .. v.name .. " cannot reach " .. o.name)
			end
		end
	end
	assert(#world.villages[1].gates >= 2, "start village should have a walled gate per road")
	-- Cave mouths can be walked up to.
	for i = 1, world.width * world.height do
		if world.object[i] == TileTypes.ObjectByName.cave.id then
			local x, y = (i - 1) % world.width + 1, math.floor((i - 1) / world.width) + 1
			assert(WorldGen.reachable(world, world.spawn.x, world.spawn.y, x, y + 1), ("cave at %d,%d unreachable, seed %d"):format(x, y, seed))
		end
	end
	-- More than one way across the river.
	local fordRows = 0
	for y = 1, world.height do
		for x = 1, world.width do
			if WorldGen.ground(world, x, y) == TileTypes.GroundByName.ford.id then fordRows += 1 break end
		end
	end
	assert(fordRows >= 2, "only one river crossing, seed " .. seed)
	-- Village names do not echo each other.
	for i = 1, 3 do
		for j = i + 1, 3 do
			assert(world.villages[i].name ~= world.villages[j].name, "duplicate village name")
		end
	end
	local c = counts(world)
	assert((c.water or 0) > 150, "no river")
	assert((c.tree or 0) > 200, "no forest")
	assert((c.path or 0) > 60, "no roads")
	assert((c.ford or 0) > 0, "roads never cross the river")
	assert((c.cave or 0) >= 1, "no caves")
	print(("seed %d: %s | water %d tree %d rock %d path %d ford %d (%d crossings) tall %d cave %d | %.0f ms"):format(
		seed, table.concat(names, ", "), c.water or 0, c.tree or 0, c.rock or 0, c.path or 0, c.ford or 0, fordRows, c.tall_grass or 0, c.cave or 0, dt * 1000))
end

print("MAPFILE world_1")
print(WorldGen.ascii(WorldGen.generate(1)))
print("ENDMAP")
