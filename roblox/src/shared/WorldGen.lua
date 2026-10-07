--!strict
-- World generation, the hub. Pure Luau: no Roblox APIs, so `npm run test:luau` runs it outside Studio and
-- tools/preview-world.js paints the result with the real tiles.
--
-- Owns: the generation ORDER (`generate`), the map's wire form (`encode` / `decode`), the compass words, the flood
-- overlay and the debug `ascii`. Everything else is re-exported from the module that does the work, under the
-- names the rest of the game has always used, so no caller changed when this file was split (ARCHITECTURE B4):
--   Grid           the tile grid: bounds, lookups, flood fill, regions, nearestWalkable, villageAt, reachable
--   WorldLand      noise, river, lakes, marsh, hills, forest; later the fords, the caves, the wadeable river
--   WorldPlans     the village layouts and place stamps as ASCII, with their legend (pure data)
--   WorldVillages  where the sixteen villages go and how a layout is stamped
--   WorldRoads     A*, the road tree, a road onto every ford; `route` for everything that walks
--   WorldPlaces    the shrine, the burnt village, the ruins between villages
--   WorldSigns     a sign at every village exit and every ford
local Rng = require(script.Parent.Rng)
local TileTypes = require(script.Parent.TileTypes)
local Grid = require(script.Parent.Grid)
local WorldLand = require(script.Parent.WorldLand)
local WorldVillages = require(script.Parent.WorldVillages)
local WorldRoads = require(script.Parent.WorldRoads)
local WorldPlaces = require(script.Parent.WorldPlaces)
local WorldSigns = require(script.Parent.WorldSigns)

local WorldGen = {}
-- Bump when generate() would grow a DIFFERENT map from the same seed: Save.decode refuses saves from another one.
-- 2 (2026-10-07): the 256 x 256 map with sixteen villages (docs/plans/world-expansion.md).
WorldGen.GEN_VERSION = 2

export type Pos = Grid.Pos
export type Gate = Grid.Gate
export type Village = Grid.Village
export type World = Grid.World

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName

WorldGen.DEFAULT_WIDTH = 256
WorldGen.DEFAULT_HEIGHT = 256

-- ---------- the grid, under its old names ----------
WorldGen.index = function(world: World, x: number, y: number): number return Grid.idx(world.width, x, y) end
WorldGen.inBounds = Grid.inBounds
WorldGen.ground = Grid.ground
WorldGen.object = Grid.object
WorldGen.walkable = Grid.walkable
WorldGen.nearestWalkable = Grid.nearestWalkable
WorldGen.villageAt = Grid.villageAt
WorldGen.reachable = Grid.reachable
WorldGen.REGION = Grid.REGION
WorldGen.regionCols = Grid.regionCols
WorldGen.regionRows = Grid.regionRows
WorldGen.regionOf = Grid.regionOf
WorldGen.regionBounds = Grid.regionBounds
--- Walking route over walkable tiles from (sx, sy) to (tx, ty): the tiles to step onto, in order (start excluded).
--- `preferRoads` makes NPC groups keep to the roads. `maxNodes` bounds the search for tap-to-move. nil if unreachable.
WorldGen.route = WorldRoads.route

--- The direction (dx, dy) points in, in words. An offset smaller than `dead` does not count. Without a `dead`
--- the cut is relative: the lesser axis has to be worth at least two fifths of the greater one to be named, so
--- a village 44 tiles east and 12 north is "east" rather than "north-east".
function WorldGen.compass(dx: number, dy: number, dead: number?): string
	local m = dead or math.max(3, 0.4 * math.max(math.abs(dx), math.abs(dy)))
	local ns = if dy < -m then "north" elseif dy > m then "south" else ""
	local ew = if dx > m then "east" elseif dx < -m then "west" else ""
	if ns ~= "" and ew ~= "" then return ns .. "-" .. ew end
	if ns == "" and ew == "" then return "close by" end
	return ns .. ew
end

-- ---------- generation ----------
--- Grow the world from a seed. The order matters and is the same for every seed: land, then the villages (so they
--- sit on dry ground), then the fords (so the roads spread across them), the roads, the places along the roads,
--- the caves (after the roads cleared the rocks), the river turning wadeable, and last the signs.
function WorldGen.generate(seed: number, width: number?, height: number?): World
	local w, h = width or WorldGen.DEFAULT_WIDTH, height or WorldGen.DEFAULT_HEIGHT
	local rng = Rng.new(seed)
	local world: World = { seed = seed, width = w, height = h, ground = table.create(w * h, G.grass.id), object = table.create(w * h, 0), villages = {}, spawn = { x = 2, y = 2 } }
	local land = WorldLand.build(world, rng)
	WorldVillages.build(world, rng:fork(9))
	WorldLand.fords(world, rng:fork(10), land.riverX)
	WorldRoads.build(world)
	WorldPlaces.build(world, rng:fork(11))
	WorldLand.caves(world, rng:fork(8))
	WorldLand.finishRiver(world, land.riverTiles)
	WorldSigns.build(world, WorldGen.compass)
	return world
end

-- ---------- the flood (Calamity) ----------
--- Tiles a flood covers: dry ground within 2 tiles of river or lake water, outside village footprints. Fords and
--- the river itself go under too, so the river cannot be crossed at all until the water drops. Returns tile indices.
function WorldGen.floodTiles(world: World): { number }
	local w, h = world.width, world.height
	local out: { number } = {}
	local function wet(x: number, y: number): boolean
		local g = Grid.ground(world, x, y)
		return g == G.water.id or g == G.river.id
	end
	for y = 2, h - 1 do
		for x = 2, w - 1 do
			local g = Grid.ground(world, x, y)
			if g ~= G.water.id and g ~= G.flood.id and Grid.object(world, x, y) == 0 and not Grid.villageAt(world, x, y, 0) then
				local near = false
				for dy = -2, 2 do
					for dx = -2, 2 do
						if wet(x + dx, y + dy) then near = true break end
					end
					if near then break end
				end
				if near then
					local i = Grid.idx(w, x, y)
					table.insert(out, i)
				end
			end
		end
	end
	return out
end

--- Put the flood on the map (ground becomes `flood`, remembered so it can be lifted). Idempotent.
function WorldGen.setFlood(world: World, tiles: { number })
	if world.floodBackup then WorldGen.clearFlood(world) end
	local backup: { [number]: number } = {}
	for _, i in ipairs(tiles) do
		backup[i] = world.ground[i]
		world.ground[i] = G.flood.id
	end
	world.floodBackup = backup
end

function WorldGen.clearFlood(world: World)
	local backup = world.floodBackup
	if not backup then return end
	for i, g in pairs(backup) do world.ground[i] = g end
	world.floodBackup = nil
end

-- ---------- serialisation (one printable byte per tile) ----------
-- Ids are offset by 33 so the strings are printable ('!'..) and never contain NUL: safe over remotes and in logs.
-- 33, not 48: object ids reach 83, and 83 + 48 is past the printable range (TileTypes: an id must stay under 94).
WorldGen.OFFSET = 33
local OFFSET = WorldGen.OFFSET
local function packBytes(t: { number }): string
	local parts = {}
	local n = #t
	local i = 1
	local chunk: { number } = table.create(4096)
	while i <= n do
		local j = math.min(n, i + 4095)
		for k = i, j do chunk[k - i + 1] = t[k] + OFFSET end
		for k = j - i + 2, #chunk do chunk[k] = nil end
		table.insert(parts, string.char(table.unpack(chunk, 1, j - i + 1)))
		i = j + 1
	end
	return table.concat(parts)
end
local function unpackBytes(s: string): { number }
	local out: { number } = table.create(#s)
	local n = #s
	local i = 1
	while i <= n do
		local j = math.min(n, i + 4095)
		local bytes = { string.byte(s, i, j) }
		for k = 1, #bytes do out[i + k - 1] = bytes[k] - OFFSET end
		i = j + 1
	end
	return out
end

export type Encoded = { seed: number, width: number, height: number, ground: string, object: string, villages: { Village }, spawn: Pos }

function WorldGen.encode(world: World): Encoded
	return { seed = world.seed, width = world.width, height = world.height, ground = packBytes(world.ground), object = packBytes(world.object), villages = world.villages, spawn = world.spawn }
end

function WorldGen.decode(e: Encoded): World
	return { seed = e.seed, width = e.width, height = e.height, ground = unpackBytes(e.ground), object = unpackBytes(e.object), villages = e.villages, spawn = e.spawn }
end

-- ---------- debug ----------
local ASCII_G = { [G.grass.id] = " ", [G.grass_2.id] = " ", [G.tall_grass.id] = ",", [G.path.id] = ".", [G.water.id] = "~", [G.river.id] = "-", [G.ford.id] = "=", [G.farm.id] = "#", [G.flood.id] = "%", [G.scorched.id] = ":", [G.forest_floor.id] = "_", [G.rocky.id] = "`" }
local ASCII_O = { [O.tree.id] = "T", [O.rock.id] = "^", [O.cave.id] = "O", [O.hut.id] = "H", [O.hut_burnt.id] = "B", [O.wall.id] = "W", [O.gate.id] = "G", [O.stall.id] = "S", [O.bed.id] = "b",
	[O.hut_hunter.id] = "h", [O.hut_plunderer.id] = "n", [O.totem.id] = "L", [O.skull_post.id] = "X", [O.camp_lit.id] = "c", [O.camp_out.id] = "c", [O.bag.id] = "g", [O.sign.id] = "!",
	[O.part.id] = "+", [O.part_open.id] = "+", [O.palisade.id] = "P", [O.palisade_gate.id] = "Q", [O.pine.id] = "T", [O.pine_tall.id] = "T", [O.tree_autumn.id] = "T", [O.dead_tree.id] = "t", [O.dead_tree_tall.id] = "t" }

--- One character per tile, for a quick look in a log. Unlisted solid objects are `*`, decor `'`, footprint bodies `+`.
function WorldGen.ascii(world: World): string
	local lines = {}
	for y = 1, world.height do
		local row = {}
		for x = 1, world.width do
			local i = Grid.idx(world.width, x, y)
			local o = world.object[i]
			local ch = ASCII_O[o] or ASCII_G[world.ground[i]] or "?"
			if o ~= 0 and not ASCII_O[o] then
				local def = TileTypes.Object[o]
				ch = if def and def.decor then "'" elseif def then "*" else "?"
			end
			if x == world.spawn.x and y == world.spawn.y then ch = "@" end
			row[x] = ch
		end
		lines[y] = table.concat(row)
	end
	return table.concat(lines, "\n")
end

return WorldGen
