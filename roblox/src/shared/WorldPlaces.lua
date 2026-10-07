--!strict
-- The places between villages (the generator's fourth pass, after the roads; docs/plans/world-expansion.md "The
-- map"): a roadside shrine, a burnt village, a ruined watchtower, an abandoned camp, an old battlefield, stamped
-- from WorldPlans.PLACES a few tiles off a road, far from every village and from each other. They are scenery for
-- now: nothing here gives them behaviour. Caves stay in WorldLand. Pure Luau.
local Grid = require(script.Parent.Grid)
local Rng = require(script.Parent.Rng)
local TileTypes = require(script.Parent.TileTypes)
local WorldPlans = require(script.Parent.WorldPlans)

local WorldPlaces = {}

type World = Grid.World
type Pos = Grid.Pos

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName

-- What a place may be stamped over: the wild things. Anything else standing there (a sign, a cave, a building) keeps its tile.
local CLEARABLE: { [number]: boolean } = {}
for _, name in ipairs({ "tree", "rock", "pine", "pine_tall", "tree_autumn", "dead_tree", "dead_tree_tall", "boulder", "boulder_mossy",
	"bush", "berry_bush", "stump", "fallen_log" }) do
	local def = O[name]
	if def then CLEARABLE[def.id] = true end
end
for id = 1, 127 do
	local def = TileTypes.Object[id]
	if def and def.decor then CLEARABLE[id] = true end
end

local FROM_VILLAGE = 8  -- a road tile this close to a village is the village's own approach, not the wilds
local APART = 30        -- tiles between two places
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

--- Can this stamp go down with its top-left at (x0, y0)? Dry open ground only: no water, no road or ford, nothing
--- built or placed by a rule (a sign, a cave), no village within two tiles. Trees, rocks and decor are cleared.
--- The ring of tiles around the stamp may be road (the shrine stands right beside one) but nothing else.
local function fits(world: World, x0: number, y0: number, tw: number, th: number): boolean
	for y = y0 - 1, y0 + th do
		for x = x0 - 1, x0 + tw do
			if x < 2 or y < 2 or x > world.width - 1 or y > world.height - 1 then return false end
			local ring = x < x0 or y < y0 or x >= x0 + tw or y >= y0 + th
			local g, o = Grid.ground(world, x, y), Grid.object(world, x, y)
			if g ~= G.grass.id and g ~= G.grass_2.id and g ~= G.tall_grass.id and not (ring and g == G.path.id) then return false end
			if o ~= 0 and not CLEARABLE[o] then return false end
			if Grid.villageAt(world, x, y, 2) then return false end
		end
	end
	return true
end

local function stamp(world: World, rows: { string }, x0: number, y0: number)
	local tw = #rows[1]
	for r, row in ipairs(rows) do
		for c = 1, tw do
			local ch = row:sub(c, c)
			local t = WorldPlans.LEGEND[ch]
			local x, y = x0 + c - 1, y0 + r - 1
			if t then
				if t.ground then Grid.setG(world, x, y, G[t.ground].id) end
				if not t.body then Grid.setO(world, x, y, 0) end
				local name = WorldPlans.objectName(ch, "farmer")
				if name then Grid.place(world, x, y, O[name].id) end
			end
		end
	end
end

--- Lay the places along the roads: max(5, number of villages) of them, cycling WorldPlans.PLACES.order.
function WorldPlaces.build(world: World, rng: Rng.Rng)
	local w, h = world.width, world.height
	local roads: { Pos } = {}
	for y = 2, h - 1 do
		for x = 2, w - 1 do
			if world.ground[Grid.idx(w, x, y)] == G.path.id and not Grid.villageAt(world, x, y, FROM_VILLAGE) then
				table.insert(roads, { x = x, y = y })
			end
		end
	end
	for i = #roads, 2, -1 do
		local j = rng:int(1, i)
		roads[i], roads[j] = roads[j], roads[i]
	end
	local want = math.max(5, #world.villages)
	local order = WorldPlans.PLACES.order :: { string }
	local placed: { Pos } = {}
	local kind = 1
	for _, road in ipairs(roads) do
		if #placed >= want then break end
		local farEnough = true
		for _, p in ipairs(placed) do
			if math.abs(p.x - road.x) + math.abs(p.y - road.y) < APART then farEnough = false break end
		end
		if farEnough then
			local name = order[(kind - 1) % #order + 1]
			local rows = WorldPlans.PLACES[name] :: { string }
			local tw, th = #rows[1], #rows
			local off = if name == "shrine" then 1 else rng:int(2, 5)
			local d0 = rng:int(1, 4)
			for k = 0, 3 do
				local d = DIRS[(d0 + k - 1) % 4 + 1]
				-- the stamp's near edge sits `off` tiles from the road, centred on the road tile along the other axis
				local x0 = if d[1] > 0 then road.x + off elseif d[1] < 0 then road.x - off - tw + 1 else road.x - math.floor(tw / 2)
				local y0 = if d[2] > 0 then road.y + off elseif d[2] < 0 then road.y - off - th + 1 else road.y - math.floor(th / 2)
				if fits(world, x0, y0, tw, th) then
					stamp(world, rows, x0, y0)
					table.insert(placed, { x = road.x, y = road.y })
					kind += 1
					break
				end
			end
		end
	end
end

return WorldPlaces
