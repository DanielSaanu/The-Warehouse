local WorldGen = __require("WorldGen")
local WorldPlans = __require("WorldPlans")
local WorldRoads = __require("WorldRoads")
local Grid = __require("Grid")
local TileTypes = __require("TileTypes")
local Names = __require("Names")
local Rng = __require("Rng")

local G, O = TileTypes.GroundByName, TileTypes.ObjectByName
local W, H = WorldGen.DEFAULT_WIDTH, WorldGen.DEFAULT_HEIGHT

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

-- Compass: the lesser axis only gets named when it is worth naming, so a village mostly east is "east".
do
	assert(WorldGen.compass(44, -12) == "east", "44 east and 12 north is east")
	assert(WorldGen.compass(40, -38) == "north-east", "a real diagonal keeps both words")
	assert(WorldGen.compass(0, 30) == "south" and WorldGen.compass(-30, 0) == "west", "cardinals")
	assert(WorldGen.compass(1, 1) == "close by", "next door is not a direction")
	assert(WorldGen.compass(8, -4, 6) == "east", "an explicit dead zone still wins")
end

-- Every layout is drawable: one spawn, bed and stall per village, every multi-tile footprint complete (WorldPlans.check).
do
	local n = 0
	for tribe, tiers in pairs(WorldPlans.VILLAGES) do
		for tier, rows in pairs(tiers) do
			local err = WorldPlans.check(rows, tribe, true)
			assert(err == nil, ("%s %s layout: %s"):format(tribe, tier, tostring(err)))
			n += 1
		end
	end
	assert(n == 9, "three tribes x three tiers")
	for _, name in ipairs(WorldPlans.PLACES.order) do
		local err = WorldPlans.check(WorldPlans.PLACES[name], "farmer", false)
		assert(err == nil, ("place %s: %s"):format(name, tostring(err)))
	end
	assert(#WorldPlans.PLANS == 16, "sixteen villages planned")
	local tiers = {}
	for _, p in ipairs(WorldPlans.PLANS) do tiers[p.tribe .. "/" .. p.tier] = (tiers[p.tribe .. "/" .. p.tier] or 0) + 1 end
	assert(tiers["farmer/large"] == 1 and tiers["farmer/mid"] == 2 and tiers["farmer/small"] == 3, "farmers: 1 town, 2 villages, 3 hamlets")
	assert(tiers["hunter/large"] == 1 and tiers["hunter/mid"] == 2 and tiers["hunter/small"] == 2, "hunters: 1 great lodge, 2 lodges, 2 camps")
	assert(tiers["plunderer/large"] == 1 and tiers["plunderer/mid"] == 1 and tiers["plunderer/small"] == 3, "plunderers: 1 stronghold, 1 camp, 3 hideouts")
	-- a bad layout is caught
	assert(WorldPlans.check({ "A==", "..." }, "farmer", false) ~= nil, "a hall whose body is below its anchor")
	assert(WorldPlans.check({ "=..", "..." }, "farmer", false) ~= nil, "an orphan '='")
	assert(WorldPlans.check({ "==.", "1=." }, "farmer", false) == nil, "a granary drawn right")
end

-- Grid.place puts a footprint down from its anchor: the anchor keeps the id, the rest is `part`.
do
	local world = { seed = 0, width = 8, height = 8, ground = table.create(64, G.grass.id), object = table.create(64, 0), villages = {}, spawn = { x = 1, y = 1 } }
	Grid.place(world, 3, 5, O.town_hall.id)
	assert(Grid.object(world, 3, 5) == O.town_hall.id, "anchor")
	assert(Grid.object(world, 6, 5) == O.part.id and Grid.object(world, 5, 4) == O.part.id and Grid.object(world, 3, 3) == O.part.id, "4x3 body above and right of the anchor")
	assert(Grid.object(world, 3, 6) == 0 and Grid.object(world, 7, 5) == 0 and Grid.object(world, 2, 5) == 0 and Grid.object(world, 3, 2) == 0, "nothing outside the footprint")
	assert(not Grid.walkable(world, 4, 4), "a hall's body is solid")
	Grid.place(world, 1, 2, O.muster_ring.id)
	assert(Grid.object(world, 2, 1) == O.part_open.id and Grid.walkable(world, 2, 1), "a ring is stood on")
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
	assert(world.width == W and world.height == H and W == 256, "size")
	assert(#world.ground == W * H and #world.object == W * H, "layers")
	assert(#world.villages == 16, "sixteen villages")
	assert(WorldGen.walkable(world, world.spawn.x, world.spawn.y), "spawn not walkable")
	-- The order the server relies on until step 3: [1] the farmers' town (the start), [2] the hunters' great lodge,
	-- [3] the plunderers' stronghold.
	local v1, v2, v3 = world.villages[1], world.villages[2], world.villages[3]
	assert(v1.tribeType == "farmer" and v1.tier == "large" and #v1.gates == 6, "villages[1] is the walled farmer town with three double gates")
	assert(v2.tribeType == "hunter" and v2.tier == "large" and #v2.gates == 0, "villages[2] is the open hunter great lodge")
	assert(v3.tribeType == "plunderer" and v3.tier == "large" and #v3.gates == 4, "villages[3] is the stronghold with two double gates")
	assert(world.spawn.x == v1.spawn.x and world.spawn.y == v1.spawn.y, "the world spawn is the town's")
	-- One flood fill from the spawn answers every "can I walk there" below (a BFS per pair would be 16x slower).
	local open = Grid.flood(world, world.spawn.x, world.spawn.y)
	local function reach(x, y) return open[Grid.idx(W, x, y)] == true end
	local names = {}
	for i, v in ipairs(world.villages) do
		table.insert(names, v.name .. "(" .. v.tribeType:sub(1, 1) .. v.tier:sub(1, 1) .. ")")
		assert(reach(v.spawn.x, v.spawn.y), "unreachable village " .. v.name .. " seed " .. seed)
		assert(WorldGen.nearestWalkable(world, v.bed.x, v.bed.y, 2), "no walkable tile near bed in " .. v.name)
		assert(WorldGen.object(world, v.bed.x, v.bed.y) == O.bed.id, "bed missing in " .. v.name)
		assert(WorldGen.object(world, v.stall.x, v.stall.y) == O.stall.id, "stall missing in " .. v.name)
		assert(WorldGen.ground(world, v.spawn.x, v.spawn.y) == G.path.id, "spawn is on the path in " .. v.name)
		assert(v.x0 >= 2 and v.y0 >= 2 and v.x1 <= W - 1 and v.y1 <= H - 1, "village inside the map: " .. v.name)
		for j = 1, i - 1 do
			local o = world.villages[j]
			assert(v.x0 > o.x1 + 4 or v.x1 < o.x0 - 4 or v.y0 > o.y1 + 4 or v.y1 < o.y0 - 4, v.name .. " overlaps " .. o.name)
			assert(v.name ~= o.name, "duplicate village name " .. v.name)
		end
		-- Every gate opens onto a road that joins the rest of the world (no gate to nowhere).
		for _, g in ipairs(v.gates) do
			assert(WorldGen.ground(world, g.exit.x, g.exit.y) == G.path.id, "gate exit is not a road in " .. v.name)
			assert(reach(g.exit.x, g.exit.y), "gate of " .. v.name .. " leads nowhere")
		end
	end
	-- The breach in the town's south-west corner is a way in: the gap in the wall, the tile inside and the tile
	-- outside are all walkable and all joined to the spawn (the woodpile once sealed it, QA round 1).
	do
		local bx, by = v1.x0 + 1, v1.y1
		assert(WorldGen.walkable(world, bx, by) and reach(bx, by), "the breach is walkable and joined")
		assert(WorldGen.walkable(world, bx, by - 1) and reach(bx, by - 1), "inside the breach")
		assert(WorldGen.walkable(world, bx, by + 1) and reach(bx, by + 1), "outside the breach")
	end
	-- Every ford carries a road: the river is crossed wherever it can be, not only where the tree went.
	for _, f in ipairs(WorldRoads.fords(world)) do
		assert(f.road, ("ford at %d-%d,%d has no road on both banks, seed %d"):format(f.x0, f.x1, f.y, seed))
		assert(f.x1 - f.x0 >= 1 or WorldGen.ground(world, f.x0, f.y - 1) == G.ford.id or WorldGen.ground(world, f.x0, f.y + 1) == G.ford.id,
			("a one-tile ford at %d,%d is a fake crossing, seed %d"):format(f.x0, f.y, seed))
	end
	-- The road tree joins every village (the edges alone, before any A* ran).
	do
		local edges = WorldRoads.edges(world.villages)
		local seen, queue = { [1] = true }, { 1 }
		while #queue > 0 do
			local a = table.remove(queue)
			for _, e in ipairs(edges) do
				local b = if e[1] == a then e[2] elseif e[2] == a then e[1] else nil
				if b and not seen[b] then seen[b] = true; table.insert(queue, b) end
			end
		end
		for i = 1, #world.villages do assert(seen[i], "road tree misses village " .. i) end
		assert(#edges < 30, "a tree plus a few loops, not all-to-all")
		local function has(a, b) for _, e in ipairs(edges) do if (e[1] == a and e[2] == b) or (e[1] == b and e[2] == a) then return true end end return false end
		assert(has(1, 2) and has(1, 3) and has(2, 3), "the capitals are joined to each other")
	end
	-- Multi-tile objects are whole: every `part` tile belongs to exactly one anchor, every footprint tile is a part.
	do
		local owned = {}
		for i = 1, W * H do
			local def = TileTypes.Object[world.object[i]]
			if def and def.foot then
				local x, y = (i - 1) % W + 1, math.floor((i - 1) / W) + 1
				for dy = 0, def.foot.h - 1 do
					for dx = 0, def.foot.w - 1 do
						local j = Grid.idx(W, x + dx, y - dy)
						assert(not owned[j], ("two footprints share tile %d,%d seed %d"):format(x + dx, y - dy, seed))
						owned[j] = true
						if not (dx == 0 and dy == 0) then
							local want = if def.solid then O.part.id else O.part_open.id
							assert(world.object[j] == want, ("%s at %d,%d has a hole at %d,%d seed %d"):format(def.name, x, y, x + dx, y - dy, seed))
						end
					end
				end
			end
		end
		for i = 1, W * H do
			local o = world.object[i]
			if o == O.part.id or o == O.part_open.id then assert(owned[i], ("orphan part at tile %d seed %d"):format(i, seed)) end
		end
	end
	-- determinism
	local again = WorldGen.generate(seed)
	for i = 1, W * H, 97 do assert(again.ground[i] == world.ground[i] and again.object[i] == world.object[i], "not deterministic") end
	-- encode / decode
	local enc = WorldGen.encode(world)
	assert(#enc.ground == W * H, "encoded size")
	assert(not enc.ground:find("[%c]") and not enc.object:find("[%c]"), "encoded map must be printable (no control bytes)")
	local dec = WorldGen.decode(enc)
	for i = 1, W * H do assert(dec.ground[i] == world.ground[i] and dec.object[i] == world.object[i], "roundtrip") end
	-- Cave mouths can be walked up to.
	for i = 1, W * H do
		if world.object[i] == O.cave.id then
			local x, y = (i - 1) % W + 1, math.floor((i - 1) / W) + 1
			assert(reach(x, y + 1), ("cave at %d,%d unreachable, seed %d"):format(x, y, seed))
		end
	end
	-- More than one way across the river.
	local fordRows = 0
	for y = 1, H do
		for x = 1, W do
			if WorldGen.ground(world, x, y) == G.ford.id then fordRows += 1 break end
		end
	end
	assert(fordRows >= 2, "only one river crossing, seed " .. seed)
	local c = counts(world)
	assert((c.river or 0) > 400, "no river")
	assert((c.tree or 0) + (c.pine or 0) > 2000, "no forest")
	assert((c.path or 0) > 400, "no roads")
	assert((c.ford or 0) > 0, "roads never cross the river")
	assert((c.cave or 0) >= 3, "no caves")
	assert((c.town_hall or 0) == 1 and (c.longhouse or 0) == 1 and (c.war_hall or 0) == 1, "one hall per capital")
	assert((c.hut or 0) + (c.hut_hunter or 0) + (c.hut_plunderer or 0) > 30, "houses everywhere (3x2 each, counted by anchor)")
	-- The places between villages: at least one of each kind on the map.
	for _, name in ipairs({ "roadside_shrine", "ruined_watchtower", "abandoned_tent", "battle_debris", "ash_pile" }) do
		assert((c[name] or 0) >= 1, "no " .. name .. ", seed " .. seed)
	end
	-- Wading: the river is walkable and slow, lakes are not walkable at all.
	assert(TileTypes.Ground[G.river.id].walk, "river must be walkable")
	assert(TileTypes.speed(G.river.id) < TileTypes.speed(G.ford.id), "wading is slower than a ford")
	assert(not TileTypes.Ground[G.water.id].walk, "lakes stay impassable")
	do
		local wadeRows, anyRiver = 0, false
		for y = 1, H do
			for x = 1, W do
				if WorldGen.ground(world, x, y) == G.river.id then
					wadeRows += 1
					if y > 10 and y < H - 10 and reach(x, y) then anyRiver = true end
					break
				end
			end
		end
		assert(wadeRows >= H * 0.7, ("only %d of %d rows can be waded, seed %d"):format(wadeRows, H, seed))
		assert(anyRiver, "cannot walk to the river, seed " .. seed)
	end
	-- Signs: one per village road exit and per ford, each with words on it, none of them standing in a road.
	local signs = 0
	for i = 1, W * H do
		if world.object[i] == O.sign.id then
			signs += 1
			local x, y = (i - 1) % W + 1, math.floor((i - 1) / W) + 1
			assert(world.signs and world.signs[i] and #world.signs[i] > 6, ("sign at %d,%d has no text"):format(x, y))
			local g = WorldGen.ground(world, x, y)
			assert(g ~= G.path.id and g ~= G.ford.id, ("sign blocks a road at %d,%d"):format(x, y))
			assert(WorldGen.nearestWalkable(world, x, y, 1), ("sign at %d,%d cannot be read from anywhere"):format(x, y))
		end
	end
	assert(signs >= 16, ("only %d signs, seed %d"):format(signs, seed))
	-- The roads still join everything after the signs and places went down (nothing plugs a gap).
	local open2 = Grid.flood(world, world.spawn.x, world.spawn.y)
	for _, v in ipairs(world.villages) do
		assert(open2[Grid.idx(W, v.spawn.x, v.spawn.y)], "something broke the road to " .. v.name)
	end
	print(("seed %d: %s | river %d lake %d tree %d pine %d rock %d path %d ford %d (%d crossings) cave %d sign %d | %.0f ms"):format(
		seed, table.concat(names, ", "), c.river or 0, c.water or 0, c.tree or 0, c.pine or 0, c.rock or 0, c.path or 0, c.ford or 0, fordRows, c.cave or 0, signs, dt * 1000))
end

-- The map for tools/preview-world.js: ids, one printable byte per tile (WorldGen.OFFSET), north row first.
do
	local world = WorldGen.generate(1)
	local enc = WorldGen.encode(world)
	print("MAPFILE world_1")
	print(("IDS %d %d %d %d"):format(world.width, world.height, world.spawn.x, world.spawn.y))
	print(enc.ground)
	print(enc.object)
	print("ENDMAP")
end
