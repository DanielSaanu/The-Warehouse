--!strict
-- World generation. Pure Luau: no Roblox APIs, so `npm run test:luau` can run it outside Studio and
-- tools/preview-world.js can paint the result with the real tiles.
--
-- Pipeline: noise (elevation, moisture) -> river + lakes -> rocks, caves, forest, tall grass -> three villages
-- from ASCII templates -> roads between them by A* (water becomes ford, trees and rocks get cleared).
local Rng = require(script.Parent.Rng)
local Names = require(script.Parent.Names)
local TileTypes = require(script.Parent.TileTypes)

local WorldGen = {}

export type Pos = { x: number, y: number }
export type Gate = { x: number, y: number, exit: Pos }
export type Village = {
	name: string, tribeType: string, tribeName: string,
	cx: number, cy: number, x0: number, y0: number, x1: number, y1: number,
	spawn: Pos, bed: Pos, stall: Pos, gates: { Gate },
}
export type World = {
	seed: number, width: number, height: number,
	ground: { number }, object: { number },
	villages: { Village }, spawn: Pos,
}

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName

WorldGen.DEFAULT_WIDTH = 96
WorldGen.DEFAULT_HEIGHT = 96

local function idx(w: number, x: number, y: number): number
	return (y - 1) * w + x
end

function WorldGen.inBounds(world: World, x: number, y: number): boolean
	return x >= 1 and y >= 1 and x <= world.width and y <= world.height
end

function WorldGen.ground(world: World, x: number, y: number): number
	if not WorldGen.inBounds(world, x, y) then return G.water.id end
	return world.ground[idx(world.width, x, y)]
end

function WorldGen.object(world: World, x: number, y: number): number
	if not WorldGen.inBounds(world, x, y) then return 0 end
	return world.object[idx(world.width, x, y)]
end

function WorldGen.walkable(world: World, x: number, y: number): boolean
	if not WorldGen.inBounds(world, x, y) then return false end
	local i = idx(world.width, x, y)
	return TileTypes.walkable(world.ground[i], world.object[i])
end

local function setG(world: World, x: number, y: number, id: number)
	if WorldGen.inBounds(world, x, y) then world.ground[idx(world.width, x, y)] = id end
end
local function setO(world: World, x: number, y: number, id: number)
	if WorldGen.inBounds(world, x, y) then world.object[idx(world.width, x, y)] = id end
end

-- ---------- noise ----------
local function makeNoise(rng: Rng.Rng, w: number, h: number, cell: number): (number, number) -> number
	local gw, gh = math.ceil(w / cell) + 2, math.ceil(h / cell) + 2
	local lattice = table.create(gw * gh)
	for i = 1, gw * gh do lattice[i] = rng:float() end
	return function(x: number, y: number): number
		local fx, fy = (x - 1) / cell, (y - 1) / cell
		local i, j = math.floor(fx), math.floor(fy)
		local tx, ty = fx - i, fy - j
		tx = tx * tx * (3 - 2 * tx)
		ty = ty * ty * (3 - 2 * ty)
		local base = j * gw + i + 1
		local v00, v10 = lattice[base], lattice[base + 1]
		local v01, v11 = lattice[base + gw], lattice[base + gw + 1]
		return (v00 * (1 - tx) + v10 * tx) * (1 - ty) + (v01 * (1 - tx) + v11 * tx) * ty
	end
end

-- ---------- village templates ----------
-- '.' clear grass, 'p' path, '@' spawn (path), 'W' wall, 'G' gate, 'H' hut, 'B' burnt hut, 'S' stall, 'b' bed,
-- 'F' farm, 'T' tall grass, 'R' rock. A gate on the template's edge is where a road leaves (see WorldGen.generate).
local TEMPLATES = {
	-- The plundered start: a palisade all round, a gate on the north and east sides (each gets a road), and a
	-- breach in the south-west corner where the raiders broke in.
	farmer = {
		"WWWWWWGWWWWWW",
		"W.....p.....W",
		"W.B...p..H..W",
		"W.....p.....W",
		"W.S...p...b.W",
		"W.....@pppppG",
		"W.....p.....W",
		"W.B...p..B..W",
		"W.....p.....W",
		"W.FF..p..FF.W",
		"W.FF.....FF.W",
		"WW..WWWWWWWWW",
	},
	hunter = {
		"..T...H...T..",
		".H....p....H.",
		"..T...p..T...",
		"pppppp@pppppp",
		".S....p....b.",
		"..H...p..H...",
		"..T.......T..",
	},
	plunderer = {
		".R....H....R.",
		"..H...p..H...",
		"......p......",
		"pppppp@pppppp",
		".b....p....S.",
		"..H.......H..",
		".R.........R.",
	},
}

local TEMPLATE_TILES = {
	["."] = { G.grass.id, 0 }, ["p"] = { G.path.id, 0 }, ["@"] = { G.path.id, 0 },
	["W"] = { G.grass.id, O.wall.id }, ["G"] = { G.path.id, O.gate.id },
	["H"] = { G.grass.id, O.hut.id }, ["B"] = { G.grass.id, O.hut_burnt.id },
	["S"] = { G.grass.id, O.stall.id }, ["b"] = { G.grass.id, O.bed.id },
	["F"] = { G.farm.id, 0 }, ["T"] = { G.tall_grass.id, 0 }, ["R"] = { G.grass.id, O.rock.id },
}

local function countWater(world: World, x0: number, y0: number, x1: number, y1: number): number
	local n = 0
	for y = y0, y1 do
		for x = x0, x1 do
			if not WorldGen.inBounds(world, x, y) or WorldGen.ground(world, x, y) == G.water.id then n += 1 end
		end
	end
	return n
end

local function placeVillage(world: World, rng: Rng.Rng, tribeType: string, wantX: number, wantY: number, taken: { string }): Village
	local rows = TEMPLATES[tribeType]
	local tw, th = #rows[1], #rows
	local hx, hy = math.floor(tw / 2), math.floor(th / 2)
	local cx, cy = wantX, wantY
	-- Nudge until the footprint (plus a margin) has no water and is inside the map.
	for _ = 1, 40 do
		local x0, y0, x1, y1 = cx - hx - 2, cy - hy - 2, cx - hx + tw + 1, cy - hy + th + 1
		if x0 >= 2 and y0 >= 2 and x1 <= world.width - 1 and y1 <= world.height - 1 and countWater(world, x0, y0, x1, y1) == 0 then break end
		cx = math.max(hx + 3, math.min(world.width - (tw - hx) - 3, cx + rng:int(-4, 4)))
		cy = math.max(hy + 3, math.min(world.height - (th - hy) - 3, cy + rng:int(-4, 4)))
	end
	local x0, y0 = cx - hx, cy - hy
	-- Clear a margin of 2 around the footprint.
	for y = y0 - 2, y0 + th + 1 do
		for x = x0 - 2, x0 + tw + 1 do
			if WorldGen.inBounds(world, x, y) then
				if WorldGen.ground(world, x, y) == G.water.id then setG(world, x, y, G.grass.id) end
				if WorldGen.ground(world, x, y) ~= G.path.id then setG(world, x, y, G.grass.id) end
				setO(world, x, y, 0)
			end
		end
	end
	local v: Village = {
		name = Names.place(rng, tribeType, taken), tribeType = tribeType, tribeName = "",
		cx = cx, cy = cy, x0 = x0, y0 = y0, x1 = x0 + tw - 1, y1 = y0 + th - 1,
		spawn = { x = cx, y = cy }, bed = { x = cx, y = cy }, stall = { x = cx, y = cy }, gates = {},
	}
	table.insert(taken, v.name)
	v.tribeName = Names.tribe(v.name, tribeType)
	for r, row in ipairs(rows) do
		for c = 1, #row do
			local ch = row:sub(c, c)
			local x, y = x0 + c - 1, y0 + r - 1
			local t = TEMPLATE_TILES[ch]
			if t then
				setG(world, x, y, t[1])
				setO(world, x, y, t[2])
			end
			if ch == "@" then v.spawn = { x = x, y = y }
			elseif ch == "b" then v.bed = { x = x, y = y }
			elseif ch == "S" then v.stall = { x = x, y = y }
			elseif ch == "G" then
				local ex, ey = x, y
				if r == 1 then ey -= 1 elseif r == th then ey += 1 elseif c == 1 then ex -= 1 elseif c == tw then ex += 1 end
				table.insert(v.gates, { x = x, y = y, exit = { x = ex, y = ey } })
			end
		end
	end
	return v
end

-- ---------- A* roads ----------
local function stepCost(world: World, x: number, y: number): number
	local g, o = WorldGen.ground(world, x, y), WorldGen.object(world, x, y)
	if o == O.hut.id or o == O.hut_burnt.id or o == O.wall.id or o == O.stall.id or o == O.bed.id or o == O.cave.id then return math.huge end
	if g == G.path.id or g == G.ford.id or o == O.gate.id then return 0.85 end -- roads reuse roads a little, not always
	if g == G.water.id then return 9 end
	if o == O.rock.id then return 12 end
	if o == O.tree.id then return 3 end
	if g == G.farm.id then return 6 end
	if g == G.tall_grass.id then return 1.2 end
	return 1
end

-- Binary min-heap keyed on f.
local function heapPush(heap: { { number } }, node: { number })
	table.insert(heap, node)
	local i = #heap
	while i > 1 do
		local p = math.floor(i / 2)
		if heap[p][1] <= heap[i][1] then break end
		heap[p], heap[i] = heap[i], heap[p]
		i = p
	end
end
local function heapPop(heap: { { number } }): { number }?
	local n = #heap
	if n == 0 then return nil end
	local top = heap[1]
	heap[1] = heap[n]
	heap[n] = nil
	n -= 1
	local i = 1
	while true do
		local l, r, s = i * 2, i * 2 + 1, i
		if l <= n and heap[l][1] < heap[s][1] then s = l end
		if r <= n and heap[r][1] < heap[s][1] then s = r end
		if s == i then break end
		heap[s], heap[i] = heap[i], heap[s]
		i = s
	end
	return top
end

--- A* over road costs. Tiles inside any of `avoid`'s footprints are off limits (roads go around walled villages and
--- enter only through their gates).
local function findPath(world: World, sx: number, sy: number, tx: number, ty: number, avoid: { Village }?): { number }?
	local w = world.width
	local start, goal = idx(w, sx, sy), idx(w, tx, ty)
	local gScore: { [number]: number } = { [start] = 0 }
	local cameFrom: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local heap: { { number } } = {}
	heapPush(heap, { math.abs(sx - tx) + math.abs(sy - ty), start })
	while true do
		local cur = heapPop(heap)
		if not cur then return nil end
		local ci = cur[2]
		if ci == goal then
			local path = { ci }
			while cameFrom[ci] do ci = cameFrom[ci]; table.insert(path, 1, ci) end
			return path
		end
		if not closed[ci] then
			closed[ci] = true
			local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local nx, ny = cx + d[1], cy + d[2]
				if WorldGen.inBounds(world, nx, ny) then
					local cost = stepCost(world, nx, ny)
					if avoid and not (nx == tx and ny == ty) then
						for _, v in ipairs(avoid) do
							if nx >= v.x0 and nx <= v.x1 and ny >= v.y0 and ny <= v.y1 then cost = math.huge break end
						end
					end
					if cost < math.huge then
						local ni = idx(w, nx, ny)
						local ng = gScore[ci] + cost
						if gScore[ni] == nil or ng < gScore[ni] then
							gScore[ni] = ng
							cameFrom[ni] = ci
							heapPush(heap, { ng + 0.5 * (math.abs(nx - tx) + math.abs(ny - ty)), ni })
						end
					end
				end
			end
		end
	end
end

local function carveRoad(world: World, path: { number })
	for _, i in ipairs(path) do
		local g, o = world.ground[i], world.object[i]
		if o == O.tree.id or o == O.rock.id then world.object[i] = 0 end
		if g == G.water.id then world.ground[i] = G.ford.id
		elseif g ~= G.ford.id and o ~= O.gate.id then world.ground[i] = G.path.id end
	end
end

--- Every tile reachable on foot from (sx, sy), as a set of tile indices.
local function flood(world: World, sx: number, sy: number): { [number]: boolean }
	local w = world.width
	local seen: { [number]: boolean } = {}
	if not WorldGen.walkable(world, sx, sy) then return seen end
	seen[idx(w, sx, sy)] = true
	local queue = { idx(w, sx, sy) }
	local head = 1
	while head <= #queue do
		local ci = queue[head]
		head += 1
		local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, ny = cx + d[1], cy + d[2]
			if WorldGen.walkable(world, nx, ny) then
				local ni = idx(w, nx, ny)
				if not seen[ni] then seen[ni] = true; table.insert(queue, ni) end
			end
		end
	end
	return seen
end

-- ---------- generation ----------
function WorldGen.generate(seed: number, width: number?, height: number?): World
	local w, h = width or WorldGen.DEFAULT_WIDTH, height or WorldGen.DEFAULT_HEIGHT
	local rng = Rng.new(seed)
	local world: World = { seed = seed, width = w, height = h, ground = table.create(w * h, G.grass.id), object = table.create(w * h, 0), villages = {}, spawn = { x = 2, y = 2 } }

	local elev1, elev2, elev3 = makeNoise(rng:fork(1), w, h, 18), makeNoise(rng:fork(2), w, h, 7), makeNoise(rng:fork(3), w, h, 3)
	local moist1, moist2 = makeNoise(rng:fork(4), w, h, 14), makeNoise(rng:fork(5), w, h, 5)
	local detail = rng:fork(6)
	local elevation = table.create(w * h, 0)
	local moisture = table.create(w * h, 0)
	for y = 1, h do
		for x = 1, w do
			local i = idx(w, x, y)
			elevation[i] = 0.6 * elev1(x, y) + 0.3 * elev2(x, y) + 0.1 * elev3(x, y)
			moisture[i] = 0.7 * moist1(x, y) + 0.3 * moist2(x, y)
		end
	end

	-- River: top to bottom, two tiles wide, wandering. riverX[y] is its left column on row y.
	local riverX: { number } = {}
	do
		local rrng = rng:fork(7)
		local x = rrng:int(math.floor(w * 0.4), math.floor(w * 0.6))
		local drift = 0
		for y = 1, h do
			if rrng:chance(0.35) then drift = rrng:int(-1, 1) end
			x = math.max(4, math.min(w - 4, x + drift))
			riverX[y] = x
			setG(world, x, y, G.water.id)
			setG(world, x + 1, y, G.water.id)
			if rrng:chance(0.2) then setG(world, x - 1, y, G.water.id) end
		end
	end
	-- Lakes and rocks, forest, tall grass.
	for y = 1, h do
		for x = 1, w do
			local i = idx(w, x, y)
			local e, m = elevation[i], moisture[i]
			if world.ground[i] ~= G.water.id then
				if e < 0.28 and m > 0.62 then
					world.ground[i] = G.water.id
				elseif e > 0.70 then
					world.object[i] = O.rock.id
				elseif m > 0.56 and e > 0.3 then
					if detail:chance(0.45 + (m - 0.56) * 2) then world.object[i] = O.tree.id end
				elseif m > 0.47 and detail:chance(0.6) then
					world.ground[i] = G.tall_grass.id
				elseif detail:chance(0.12) then
					world.ground[i] = G.grass_2.id
				end
			end
		end
	end
	-- Map edge: rock ring so the world has a visible border.
	for x = 1, w do setO(world, x, 1, O.rock.id); setO(world, x, h, O.rock.id) end
	for y = 1, h do setO(world, 1, y, O.rock.id); setO(world, w, y, O.rock.id) end
	-- Villages: farmers south-west (the plundered start), hunters east, plunderers north (the bandits came from the north).
	local vrng = rng:fork(9)
	local taken: { string } = {}
	local farmer = placeVillage(world, vrng, "farmer", math.floor(w * 0.28) + vrng:int(-5, 5), math.floor(h * 0.72) + vrng:int(-4, 4), taken)
	local hunter = placeVillage(world, vrng, "hunter", math.floor(w * 0.76) + vrng:int(-5, 5), math.floor(h * 0.60) + vrng:int(-4, 4), taken)
	local plunderer = placeVillage(world, vrng, "plunderer", math.floor(w * 0.52) + vrng:int(-6, 6), math.floor(h * 0.18) + vrng:int(-3, 3), taken)
	world.villages = { farmer, hunter, plunderer }
	world.spawn = { x = farmer.spawn.x, y = farmer.spawn.y }

	-- Fords: three natural crossings far apart along the river, carved before the roads so the roads spread across
	-- them instead of all sharing one. A crossing is a row where the river is at most 3 tiles wide with dry banks.
	do
		local frng = rng:fork(10)
		local fordRows: { number } = {}
		for y = 1, h do
			for x = 1, w do
				if world.ground[idx(w, x, y)] == G.ford.id then table.insert(fordRows, y) break end
			end
		end
		local rows: { number } = {}
		for y = 8, h - 7 do table.insert(rows, y) end
		for i = #rows, 2, -1 do
			local j = frng:int(1, i)
			rows[i], rows[j] = rows[j], rows[i]
		end
		local added = 0
		for _, y in ipairs(rows) do
			if added >= 3 then break end
			local farEnough = true
			for _, fy in ipairs(fordRows) do
				if math.abs(fy - y) < 20 then farEnough = false break end
			end
			local rx = riverX[y]
			if farEnough and rx and WorldGen.ground(world, rx, y) == G.water.id then
				local x0, x1 = rx, rx
				while WorldGen.ground(world, x0 - 1, y) == G.water.id and rx - x0 < 4 do x0 -= 1 end
				while WorldGen.ground(world, x1 + 1, y) == G.water.id and x1 - rx < 4 do x1 += 1 end
				local wx, ex = x0 - 1, x1 + 1
				if x1 - x0 + 1 <= 3 and wx > 1 and ex < w
					and WorldGen.ground(world, wx, y) ~= G.water.id and WorldGen.ground(world, ex, y) ~= G.water.id then
					for x = x0, x1 do setG(world, x, y, G.ford.id) end
					-- Clear trees and rocks off the banks so the crossing can be reached.
					for _, bx in ipairs({ wx - 1, wx, ex, ex + 1 }) do
						local o = WorldGen.object(world, bx, y)
						if bx > 1 and bx < w and (o == O.tree.id or o == O.rock.id) then setO(world, bx, y, 0) end
					end
					table.insert(fordRows, y)
					added += 1
				end
			end
		end
	end
	-- Roads. A road leaves (or enters) a walled village through the gate on the side facing the other village and
	-- never cuts back through the village it leaves. A gate no road chose still gets a road out to the network, so no
	-- gate opens onto nothing.
	local function facingGate(from: Village, tx: number, ty: number): Gate?
		local best: Gate? = nil
		local bestScore = -math.huge
		local dx, dy = tx - from.spawn.x, ty - from.spawn.y
		local len = math.max(1, math.sqrt(dx * dx + dy * dy))
		for _, g in ipairs(from.gates) do
			local gx, gy = g.exit.x - from.spawn.x, g.exit.y - from.spawn.y
			local score = (gx * dx + gy * dy) / (len * math.max(1, math.sqrt(gx * gx + gy * gy)))
			if score > bestScore then best, bestScore = g, score end
		end
		return best
	end
	local walled: { Village } = {}
	for _, v in ipairs(world.villages) do if #v.gates > 0 then table.insert(walled, v) end end
	local usedGates: { [Gate]: boolean } = {}
	local function endpoint(v: Village, toward: Village): Pos
		local g = facingGate(v, toward.spawn.x, toward.spawn.y)
		if not g then return v.spawn end
		usedGates[g] = true
		return g.exit
	end
	for _, pair in ipairs({ { farmer, hunter }, { farmer, plunderer }, { hunter, plunderer } }) do
		local a, b = pair[1], pair[2]
		local s0, t0 = endpoint(a, b), endpoint(b, a)
		local path = findPath(world, s0.x, s0.y, t0.x, t0.y, walled)
		if path then carveRoad(world, path) end
	end
	for _, v in ipairs(world.villages) do
		for _, g in ipairs(v.gates) do
			if not usedGates[g] then
				-- Join the nearest road tile outside every village.
				local bx, by, bestD = 0, 0, math.huge
				for y = 2, h - 1 do
					for x = 2, w - 1 do
						local d = math.abs(x - g.exit.x) + math.abs(y - g.exit.y)
						if d > 0 and d < bestD and world.ground[idx(w, x, y)] == G.path.id and not WorldGen.villageAt(world, x, y, 0) then
							bx, by, bestD = x, y, d
						end
					end
				end
				local path = if bestD < math.huge then findPath(world, g.exit.x, g.exit.y, bx, by, walled) else nil
				if path then carveRoad(world, path) end
			end
			setG(world, g.exit.x, g.exit.y, G.path.id)
		end
	end

	-- Cave mouths: rock tiles flanked by rock with open ground directly south that the player can walk to from the
	-- spawn. Placed after the roads (which clear rocks). Collect every candidate, then pick up to 3 far apart.
	do
		local crng = rng:fork(8)
		local open = flood(world, world.spawn.x, world.spawn.y)
		local candidates: { Pos } = {}
		for y = 3, h - 3 do
			for x = 3, w - 2 do
				if WorldGen.object(world, x, y) == O.rock.id and WorldGen.object(world, x, y + 1) == 0 and WorldGen.ground(world, x, y + 1) ~= G.water.id
					and WorldGen.object(world, x - 1, y) == O.rock.id and WorldGen.object(world, x + 1, y) == O.rock.id
					and open[idx(w, x, y + 1)] then
					table.insert(candidates, { x = x, y = y })
				end
			end
		end
		-- Fisher-Yates so the pick is seed-dependent but exhaustive.
		for i = #candidates, 2, -1 do
			local j = crng:int(1, i)
			candidates[i], candidates[j] = candidates[j], candidates[i]
		end
		local placed: { Pos } = {}
		for _, c in ipairs(candidates) do
			if #placed >= 3 then break end
			local farEnough = true
			for _, p in ipairs(placed) do
				if math.abs(p.x - c.x) + math.abs(p.y - c.y) < 14 then farEnough = false break end
			end
			if farEnough then
				setO(world, c.x, c.y, O.cave.id)
				table.insert(placed, c)
			end
		end
	end

	return world
end

-- ---------- queries ----------
--- 4-connected reachability over walkable tiles (BFS). Used by tests and later by NPC routing sanity checks.
function WorldGen.reachable(world: World, sx: number, sy: number, tx: number, ty: number): boolean
	if not WorldGen.walkable(world, sx, sy) or not WorldGen.walkable(world, tx, ty) then return false end
	local w = world.width
	local goal = idx(w, tx, ty)
	local seen: { [number]: boolean } = { [idx(w, sx, sy)] = true }
	local queue = { idx(w, sx, sy) }
	local head = 1
	while head <= #queue do
		local ci = queue[head]; head += 1
		if ci == goal then return true end
		local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, ny = cx + d[1], cy + d[2]
			if WorldGen.walkable(world, nx, ny) then
				local ni = idx(w, nx, ny)
				if not seen[ni] then seen[ni] = true; table.insert(queue, ni) end
			end
		end
	end
	return false
end

--- Nearest walkable tile to (x, y), searching outward. Used to spawn things next to beds, stalls, etc.
function WorldGen.nearestWalkable(world: World, x: number, y: number, maxR: number?): Pos?
	for r = 0, maxR or 6 do
		for dy = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dy)) == r and WorldGen.walkable(world, x + dx, y + dy) then
					return { x = x + dx, y = y + dy }
				end
			end
		end
	end
	return nil
end

function WorldGen.villageAt(world: World, x: number, y: number, margin: number?): Village?
	local m = margin or 3
	for _, v in ipairs(world.villages) do
		if x >= v.x0 - m and x <= v.x1 + m and y >= v.y0 - m and y <= v.y1 + m then return v end
	end
	return nil
end

-- ---------- serialisation (one printable byte per tile) ----------
-- Ids are offset by 48 so the strings are printable ('0'..) and never contain NUL: safe over remotes and in logs.
local OFFSET = 48
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
local ASCII_G = { [G.grass.id] = " ", [G.grass_2.id] = " ", [G.tall_grass.id] = ",", [G.path.id] = ".", [G.water.id] = "~", [G.ford.id] = "=", [G.farm.id] = "#" }
local ASCII_O = { [O.tree.id] = "T", [O.rock.id] = "^", [O.cave.id] = "O", [O.hut.id] = "H", [O.hut_burnt.id] = "B", [O.wall.id] = "W", [O.gate.id] = "G", [O.stall.id] = "S", [O.bed.id] = "b" }

function WorldGen.ascii(world: World): string
	local lines = {}
	for y = 1, world.height do
		local row = {}
		for x = 1, world.width do
			local i = idx(world.width, x, y)
			local ch = ASCII_O[world.object[i]] or ASCII_G[world.ground[i]] or "?"
			if x == world.spawn.x and y == world.spawn.y then ch = "@" end
			row[x] = ch
		end
		lines[y] = table.concat(row)
	end
	return table.concat(lines, "\n")
end

return WorldGen
