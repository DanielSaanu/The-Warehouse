--!strict
-- The tile grid: the World record's shape, bounds, lookups and writes, flood fill, regions, "nearest walkable" and
-- "which village is this". Pure Luau (ARCHITECTURE B4: WorldGen split into generate / query / encode; this is the
-- QUERY half). WorldGen re-exports everything here under its old names, so nothing else requires Grid directly
-- except the generator's own modules (WorldLand, WorldVillages, WorldRoads, WorldPlaces), which would otherwise
-- need WorldGen and be required by it: a cycle.
local TileTypes = require(script.Parent.TileTypes)

local Grid = {}

export type Pos = { x: number, y: number }
export type Gate = { x: number, y: number, exit: Pos }
export type Village = {
	name: string, tribeType: string, tribeName: string,
	tier: string,                   -- "large" | "mid" | "small" (docs/plans/world-expansion.md)
	cx: number, cy: number, x0: number, y0: number, x1: number, y1: number,
	spawn: Pos, bed: Pos, stall: Pos, gates: { Gate },
}
export type World = {
	seed: number, width: number, height: number,
	ground: { number }, object: { number },
	villages: { Village }, spawn: Pos,
	floodBackup: { [number]: number }?,
	signs: { [number]: string }?,   -- tile index -> what the sign says (server side; the object id travels in `object`)
}

local G = TileTypes.GroundByName

function Grid.idx(w: number, x: number, y: number): number
	return (y - 1) * w + x
end

function Grid.inBounds(world: World, x: number, y: number): boolean
	return x >= 1 and y >= 1 and x <= world.width and y <= world.height
end

function Grid.ground(world: World, x: number, y: number): number
	if not Grid.inBounds(world, x, y) then return G.water.id end
	return world.ground[Grid.idx(world.width, x, y)]
end

function Grid.object(world: World, x: number, y: number): number
	if not Grid.inBounds(world, x, y) then return 0 end
	return world.object[Grid.idx(world.width, x, y)]
end

function Grid.walkable(world: World, x: number, y: number): boolean
	if not Grid.inBounds(world, x, y) then return false end
	local i = Grid.idx(world.width, x, y)
	return TileTypes.walkable(world.ground[i], world.object[i])
end

function Grid.setG(world: World, x: number, y: number, id: number)
	if Grid.inBounds(world, x, y) then world.ground[Grid.idx(world.width, x, y)] = id end
end

function Grid.setO(world: World, x: number, y: number, id: number)
	if Grid.inBounds(world, x, y) then world.object[Grid.idx(world.width, x, y)] = id end
end

--- Put a multi-tile object down with its ANCHOR at (x, y), the bottom-left tile of its footprint: the rest of the
--- footprint gets `part` (solid) or `part_open`, so every tile knows it is taken and the renderer draws one sprite
--- from the anchor. A 1x1 object is just setO.
function Grid.place(world: World, x: number, y: number, id: number)
	local def = TileTypes.Object[id]
	local foot = def and def.foot
	if not foot then Grid.setO(world, x, y, id) return end
	local part = if def.solid then TileTypes.ObjectByName.part.id else TileTypes.ObjectByName.part_open.id
	for dy = 0, foot.h - 1 do
		for dx = 0, foot.w - 1 do
			Grid.setO(world, x + dx, y - dy, if dx == 0 and dy == 0 then id else part)
		end
	end
end

--- Nearest walkable tile to (x, y), searching outward. Used to spawn things next to beds, stalls, etc.
function Grid.nearestWalkable(world: World, x: number, y: number, maxR: number?): Pos?
	for r = 0, maxR or 6 do
		for dy = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dy)) == r and Grid.walkable(world, x + dx, y + dy) then
					return { x = x + dx, y = y + dy }
				end
			end
		end
	end
	return nil
end

function Grid.villageAt(world: World, x: number, y: number, margin: number?): Village?
	local m = margin or 3
	for _, v in ipairs(world.villages) do
		if x >= v.x0 - m and x <= v.x1 + m and y >= v.y0 - m and y <= v.y1 + m then return v end
	end
	return nil
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

--- Every tile reachable on foot from (sx, sy), as a set of tile indices (4-connected BFS over walkable tiles).
function Grid.flood(world: World, sx: number, sy: number): { [number]: boolean }
	local w = world.width
	local seen: { [number]: boolean } = {}
	if not Grid.walkable(world, sx, sy) then return seen end
	seen[Grid.idx(w, sx, sy)] = true
	local queue = { Grid.idx(w, sx, sy) }
	local head = 1
	while head <= #queue do
		local ci = queue[head]
		head += 1
		local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
		for _, d in ipairs(DIRS) do
			local nx, ny = cx + d[1], cy + d[2]
			if Grid.walkable(world, nx, ny) then
				local ni = Grid.idx(w, nx, ny)
				if not seen[ni] then seen[ni] = true; table.insert(queue, ni) end
			end
		end
	end
	return seen
end

--- Can (tx, ty) be walked to from (sx, sy)? Stops as soon as the goal is seen.
function Grid.reachable(world: World, sx: number, sy: number, tx: number, ty: number): boolean
	if not Grid.walkable(world, sx, sy) or not Grid.walkable(world, tx, ty) then return false end
	local w = world.width
	local goal = Grid.idx(w, tx, ty)
	local seen: { [number]: boolean } = { [Grid.idx(w, sx, sy)] = true }
	local queue = { Grid.idx(w, sx, sy) }
	local head = 1
	while head <= #queue do
		local ci = queue[head]; head += 1
		if ci == goal then return true end
		local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
		for _, d in ipairs(DIRS) do
			local nx, ny = cx + d[1], cy + d[2]
			if Grid.walkable(world, nx, ny) then
				local ni = Grid.idx(w, nx, ny)
				if not seen[ni] then seen[ni] = true; table.insert(queue, ni) end
			end
		end
	end
	return false
end

--- Regions: the map cut into REGION x REGION squares, numbered row-major from 1.
Grid.REGION = 16
function Grid.regionCols(world: World): number
	return math.ceil(world.width / Grid.REGION)
end
function Grid.regionRows(world: World): number
	return math.ceil(world.height / Grid.REGION)
end
function Grid.regionOf(world: World, x: number, y: number): number
	local rc = Grid.regionCols(world)
	local cx = math.clamp(math.floor((x - 1) / Grid.REGION), 0, rc - 1)
	local cy = math.clamp(math.floor((y - 1) / Grid.REGION), 0, Grid.regionRows(world) - 1)
	return cy * rc + cx + 1
end
--- Tile bounds of a region: x0, y0, x1, y1.
function Grid.regionBounds(world: World, r: number): (number, number, number, number)
	local rc = Grid.regionCols(world)
	local cx, cy = (r - 1) % rc, math.floor((r - 1) / rc)
	local R = Grid.REGION
	return cx * R + 1, cy * R + 1, math.min(world.width, (cx + 1) * R), math.min(world.height, (cy + 1) * R)
end

return Grid
