--!strict
-- Villages (the generator's second pass; docs/plans/world-expansion.md "Build order" 2). Pure Luau. Takes the list
-- in WorldPlans.PLANS, scales each sketch position to the real map, nudges it until the footprint sits on dry
-- ground clear of every village already down, then stamps the tier's layout: ground and single tiles straight from
-- the legend, multi-tile buildings by their anchor through Grid.place. Names come from Names.place. Nothing here
-- lays a road or decides what the buildings DO (tax, caravans, hiring: later rungs).
local Grid = require(script.Parent.Grid)
local Names = require(script.Parent.Names)
local Rng = require(script.Parent.Rng)
local TileTypes = require(script.Parent.TileTypes)
local WorldPlans = require(script.Parent.WorldPlans)

local WorldVillages = {}

type World = Grid.World
type Village = Grid.Village
type Pos = Grid.Pos

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName

local MARGIN = 2  -- clear ground kept around a footprint
local APART = 4   -- tiles between one village's cleared ground and the next

local function countWater(world: World, x0: number, y0: number, x1: number, y1: number): number
	local n = 0
	for y = y0, y1 do
		for x = x0, x1 do
			if not Grid.inBounds(world, x, y) or Grid.ground(world, x, y) == G.water.id then n += 1 end
		end
	end
	return n
end

local function overlaps(world: World, x0: number, y0: number, x1: number, y1: number): boolean
	for _, v in ipairs(world.villages) do
		if x0 <= v.x1 + MARGIN + APART and x1 >= v.x0 - MARGIN - APART and y0 <= v.y1 + MARGIN + APART and y1 >= v.y0 - MARGIN - APART then
			return true
		end
	end
	return false
end

--- Top-left corner for a `tw` x `th` layout wanted around (wantX, wantY): nudged (a jitter that grows from 4 to 8
--- tiles, up to 60 tries) until the footprint plus its margin is inside the map, on dry ground and clear of every
--- placed village. If no try is perfect the driest one that is inside the map and clear of villages is used.
local function findSpot(world: World, rng: Rng.Rng, tw: number, th: number, wantX: number, wantY: number): (number, number)
	local hx, hy = math.floor(tw / 2), math.floor(th / 2)
	local cx, cy = wantX, wantY
	local bestX, bestY, bestWater = wantX - hx, wantY - hy, math.huge
	for try = 1, 60 do
		local x0, y0 = cx - hx, cy - hy
		local mx0, my0, mx1, my1 = x0 - MARGIN, y0 - MARGIN, x0 + tw - 1 + MARGIN, y0 + th - 1 + MARGIN
		local inside = mx0 >= 2 and my0 >= 2 and mx1 <= world.width - 1 and my1 <= world.height - 1
		if inside and not overlaps(world, x0, y0, x0 + tw - 1, y0 + th - 1) then
			local water = countWater(world, mx0, my0, mx1, my1)
			if water == 0 then return x0, y0 end
			if water < bestWater then bestX, bestY, bestWater = x0, y0, water end
		end
		local j = 4 + math.floor(try / 15)
		cx = math.clamp(wantX + rng:int(-j, j), hx + MARGIN + 2, world.width - (tw - hx) - MARGIN - 2)
		cy = math.clamp(wantY + rng:int(-j, j), hy + MARGIN + 2, world.height - (th - hy) - MARGIN - 2)
	end
	return bestX, bestY
end

--- Put a layout down with its top-left at (x0, y0). Returns the village record (name and tribe left for the caller).
function WorldVillages.stamp(world: World, rows: { string }, tribe: string, tier: string, x0: number, y0: number): Village
	local tw, th = #rows[1], #rows
	-- Clear the margin: dry grass, nothing standing, roads kept.
	for y = y0 - MARGIN, y0 + th - 1 + MARGIN do
		for x = x0 - MARGIN, x0 + tw - 1 + MARGIN do
			if Grid.inBounds(world, x, y) then
				if Grid.ground(world, x, y) ~= G.path.id then Grid.setG(world, x, y, G.grass.id) end
				Grid.setO(world, x, y, 0)
			end
		end
	end
	local cx, cy = x0 + math.floor(tw / 2), y0 + math.floor(th / 2)
	local v: Village = {
		name = "", tribeType = tribe, tribeName = "", tier = tier,
		cx = cx, cy = cy, x0 = x0, y0 = y0, x1 = x0 + tw - 1, y1 = y0 + th - 1,
		spawn = { x = cx, y = cy }, bed = { x = cx, y = cy }, stall = { x = cx, y = cy }, gates = {},
	}
	for r, row in ipairs(rows) do
		for c = 1, tw do
			local ch = row:sub(c, c)
			local t = WorldPlans.LEGEND[ch]
			local x, y = x0 + c - 1, y0 + r - 1
			if t then
				Grid.setG(world, x, y, if t.ground then G[t.ground].id else G.grass.id)
				local name = WorldPlans.objectName(ch, tribe)
				if name then Grid.place(world, x, y, O[name].id) end
				if t.spawn then v.spawn = { x = x, y = y } end
				if t.bed then v.bed = { x = x, y = y } end
				if t.stall then v.stall = { x = x, y = y } end
				if t.gate then
					local ex, ey = x, y
					if r == 1 then ey -= 1 elseif r == th then ey += 1 elseif c == 1 then ex -= 1 elseif c == tw then ex += 1 end
					table.insert(v.gates, { x = x, y = y, exit = { x = ex, y = ey } })
				end
			end
		end
	end
	return v
end

--- Every village in WorldPlans.PLANS, in that order (the three capitals first: the server reads `villages[1..3]`
--- as the farmers', hunters' and plunderers' homes until step 3). Sets `world.spawn` to the first village's.
function WorldVillages.build(world: World, rng: Rng.Rng)
	local taken: { string } = {}
	local sx, sy = world.width / 256, world.height / 256
	for _, plan in ipairs(WorldPlans.PLANS) do
		local rows = WorldPlans.VILLAGES[plan.tribe][plan.tier]
		local tw, th = #rows[1], #rows
		local x0, y0 = findSpot(world, rng, tw, th, math.floor(plan.x * sx + 0.5), math.floor(plan.y * sy + 0.5))
		local v = WorldVillages.stamp(world, rows, plan.tribe, plan.tier, x0, y0)
		-- a name no other village echoes; Names.place avoids the taken ones, this makes sure of it
		local name = Names.place(rng, plan.tribe, taken)
		for _ = 1, 20 do
			local dup = false
			for _, other in ipairs(taken) do if other == name then dup = true break end end
			if not dup then break end
			name = Names.place(rng, plan.tribe, taken)
		end
		v.name, v.tribeName = name, Names.tribe(name, plan.tribe)
		table.insert(taken, name)
		table.insert(world.villages, v)
	end
	local first = world.villages[1]
	if first then world.spawn = { x = first.spawn.x, y = first.spawn.y } end
end

return WorldVillages
