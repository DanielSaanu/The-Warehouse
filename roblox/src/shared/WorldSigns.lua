--!strict
-- Signs (the generator's last pass). Pure Luau. Wooden signs are how a stranger learns where the roads go without a
-- human telling them (docs/qa/rung2-part4.md). They are placed by rule, not by hand: one at every gate or road exit
-- of a village, naming the village that way and its direction; one at every ford, naming the nearest village on each
-- bank. The words live in `world.signs` (tile index -> text) on the server; only the sign object travels to clients.
local Grid = require(script.Parent.Grid)
local TileTypes = require(script.Parent.TileTypes)
local WorldRoads = require(script.Parent.WorldRoads)

local WorldSigns = {}

type World = Grid.World
type Pos = Grid.Pos
type Village = Grid.Village

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName
local idx = Grid.idx

-- Wooden signs are how a stranger learns where the roads go without a human telling them (docs/qa/rung2-part4.md).
-- They are placed by rule, not by hand: one at every gate or road exit of a village, one at every river crossing.
local TRIBE_LINE = { farmer = "Farmers.", hunter = "Hunters.", plunderer = "Raiders. Keep clear." } :: { [string]: string }

local function signSpot(world: World, x: number, y: number): boolean
	if not Grid.inBounds(world, x, y) then return false end
	local g = Grid.ground(world, x, y)
	if Grid.object(world, x, y) ~= 0 then return false end
	if Grid.object(world, x, y - 1) == O.cave.id then return false end -- never on a cave's doorstep
	if g ~= G.grass.id and g ~= G.grass_2.id and g ~= G.tall_grass.id and g ~= G.farm.id then return false end
	local open = 0
	for dy = -1, 1 do
		for dx = -1, 1 do
			if not (dx == 0 and dy == 0) and Grid.walkable(world, x + dx, y + dy) then open += 1 end
		end
	end
	return open >= 5
end

--- Put a sign on the best free tile near (x, y). Returns true if one went up. The same words within six tiles
--- (two exits of one village pointing the same way) are one sign, not two.
local recent: { { x: number, y: number, text: string } } = {}
local function putSign(world: World, x: number, y: number, text: string): boolean
	for _, p in ipairs(recent) do
		if p.text == text and math.abs(p.x - x) + math.abs(p.y - y) <= 6 then return false end
	end
	for r = 1, 2 do
		for dy = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dy)) == r and signSpot(world, x + dx, y + dy) then
					local i = idx(world.width, x + dx, y + dy)
					world.object[i] = O.sign.id
					local signs = world.signs
					if signs then signs[i] = text end
					table.insert(recent, { x = x + dx, y = y + dy, text = text })
					return true
				end
			end
		end
	end
	return false
end

--- Where roads leave a village: its gates, or (for an open village) the path tiles on the ring just outside its
--- footprint. Exits closer than 3 tiles to one already found are the same road and are skipped.
local function villageExits(world: World, v: Village): { Pos }
	local out: { Pos } = {}
	local function add(x: number, y: number)
		for _, p in ipairs(out) do
			if math.abs(p.x - x) + math.abs(p.y - y) < 3 then return end
		end
		table.insert(out, { x = x, y = y })
	end
	if #v.gates > 0 then
		for _, g in ipairs(v.gates) do add(g.exit.x, g.exit.y) end
		return out
	end
	for x = v.x0 - 1, v.x1 + 1 do
		if Grid.ground(world, x, v.y0 - 1) == G.path.id then add(x, v.y0 - 1) end
		if Grid.ground(world, x, v.y1 + 1) == G.path.id then add(x, v.y1 + 1) end
	end
	for y = v.y0 - 1, v.y1 + 1 do
		if Grid.ground(world, v.x0 - 1, y) == G.path.id then add(v.x0 - 1, y) end
		if Grid.ground(world, v.x1 + 1, y) == G.path.id then add(v.x1 + 1, y) end
	end
	return out
end

--- The village this road exit leads to: walk the road tiles from the exit (never back through `v`) and name the
--- first other village the road touches. A road that reaches nowhere else names the village nearest in the
--- direction it leaves in.
local function signpostTarget(world: World, v: Village, exit: Pos): Village?
	local w = world.width
	local seen: { [number]: boolean } = { [idx(w, exit.x, exit.y)] = true }
	local queue, head = { exit }, 1
	while head <= #queue do
		local c = queue[head]
		head += 1
		local here = Grid.villageAt(world, c.x, c.y, 1)
		if here and here ~= v then return here end
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, ny = c.x + d[1], c.y + d[2]
			local g = Grid.ground(world, nx, ny)
			local i = idx(w, nx, ny)
			if (g == G.path.id or g == G.ford.id) and not seen[i] and not (Grid.villageAt(world, nx, ny, 0) == v) then
				seen[i] = true
				table.insert(queue, { x = nx, y = ny })
			end
		end
	end
	local ex, ey = exit.x - v.cx, exit.y - v.cy
	local elen = math.max(1, math.sqrt(ex * ex + ey * ey))
	local best: Village? = nil
	local bestScore = -math.huge
	for _, o in ipairs(world.villages) do
		if o ~= v then
			local ox, oy = o.cx - v.cx, o.cy - v.cy
			local olen = math.max(1, math.sqrt(ox * ox + oy * oy))
			local score = (ox * ex + oy * ey) / (elen * olen) - olen / (4 * world.width)
			if score > bestScore then best, bestScore = o, score end
		end
	end
	return best
end

function WorldSigns.build(world: World, compass: (number, number) -> string)
	world.signs = {}
	recent = {}
	for _, v in ipairs(world.villages) do
		for _, exit in ipairs(villageExits(world, v)) do
			local o = signpostTarget(world, v, exit)
			if o then
				local dir: string = compass(o.cx - v.cx, o.cy - v.cy)
				local line: string = TRIBE_LINE[o.tribeType] or ""
				putSign(world, exit.x, exit.y, o.name .. ", " .. dir .. ". " .. line)
			end
		end
	end
	-- One sign per crossing, naming the nearest village on each bank, so a stranger knows what the water leads to.
	for _, f in ipairs(WorldRoads.fords(world)) do
		local fx0: number, fx1: number, fy: number = f.x0, f.x1, f.y
		local function nearest(side: number): Village?
			local best: Village? = nil
			local bestD = math.huge
			for _, v in ipairs(world.villages) do
				local d = math.abs(v.cx - fx0) + math.abs(v.cy - fy)
				if (v.cx - fx0) * side > 0 and d < bestD then best, bestD = v, d end
			end
			return best
		end
		local east, west = nearest(1), nearest(-1)
		local parts = { "Ford." }
		if east then table.insert(parts, "East bank: " .. east.name .. " (" .. compass(east.cx - fx1, east.cy - fy) .. ").") end
		if west then table.insert(parts, "West bank: " .. west.name .. " (" .. compass(west.cx - fx0, west.cy - fy) .. ").") end
		table.insert(parts, "Wolves at night.")
		putSign(world, fx0, fy, table.concat(parts, " "))
	end
end

return WorldSigns
