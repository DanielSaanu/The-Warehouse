--!strict
-- Roads (the generator's third pass; docs/plans/world-expansion.md "Build order" 2). Pure Luau.
-- A* over the tile grid with a cost per tile, a road TREE between villages (every village joined to its neighbours,
-- not all to all: at 16 villages all-to-all is 120 roads), a road out of every gate no tree edge chose, and a road
-- onto both banks of every ford. The signs are WorldSigns (they read the finished roads).
local Grid = require(script.Parent.Grid)
local TileTypes = require(script.Parent.TileTypes)

local WorldRoads = {}

type World = Grid.World
type Pos = Grid.Pos
type Village = Grid.Village
type Gate = Grid.Gate
type Cost = (World, number, number) -> number

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName
local idx = Grid.idx

-- ---------- A* ----------
--- What laying a road through this tile costs. Anything built (a hut, a wall) is never crossed; decor is cleared.
local function stepCost(world: World, x: number, y: number): number
	local g, o = Grid.ground(world, x, y), Grid.object(world, x, y)
	local od = TileTypes.Object[o]
	if od and not (o == O.tree.id or o == O.rock.id or o == O.gate.id or od.decor) then return math.huge end
	if g == G.path.id or g == G.ford.id or o == O.gate.id then return 0.85 end -- roads reuse roads a little, not always
	if g == G.water.id then return 9 end
	if o == O.rock.id then return 12 end
	if o == O.tree.id then return 3 end
	if g == G.farm.id then return 6 end
	if g == G.tall_grass.id then return 1.2 end
	return 1
end

local function walkCost(world: World, x: number, y: number): number
	if not Grid.walkable(world, x, y) then return math.huge end
	return if Grid.ground(world, x, y) == G.river.id then 3 else 1
end

--- A caravan keeps to the roads: off the road costs five times a road tile, so it leaves one only to cut a real
--- corner, and it does not wade when there is a ford.
local function roadCost(world: World, x: number, y: number): number
	if not Grid.walkable(world, x, y) then return math.huge end
	local g = Grid.ground(world, x, y)
	if g == G.path.id or g == G.ford.id then return 0.5 end
	if g == G.river.id then return 8 end
	if g == G.tall_grass.id then return 3 end
	return 2.5
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

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

--- A* from (sx, sy) to (tx, ty). `avoid` villages are never entered (except at the target tile). `box` keeps the
--- search inside a rectangle {x0, y0, x1, y1}: a road between two villages has no business on the far side of the
--- map, and on a 256-wide map that is what makes eighteen roads cost a fraction of a second rather than many.
--- `maxNodes` bounds the search for tap-to-move. Returns tile indices, start included, or nil.
function WorldRoads.astar(world: World, sx: number, sy: number, tx: number, ty: number, cost: Cost, avoid: { Village }?, maxNodes: number?, box: { number }?): { number }?
	local w = world.width
	local budget = maxNodes or math.huge
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
			budget -= 1
			if budget < 0 then return nil end
			local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
			for _, d in ipairs(DIRS) do
				local nx, ny = cx + d[1], cy + d[2]
				if Grid.inBounds(world, nx, ny) and (not box or (nx >= box[1] and ny >= box[2] and nx <= box[3] and ny <= box[4])) then
					local c = cost(world, nx, ny)
					if avoid and not (nx == tx and ny == ty) then
						for _, v in ipairs(avoid) do
							if nx >= v.x0 and nx <= v.x1 and ny >= v.y0 and ny <= v.y1 then c = math.huge break end
						end
					end
					if c < math.huge then
						local ni = idx(w, nx, ny)
						local ng = gScore[ci] + c
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

--- Walking route for things that walk (WorldGen.route): `preferRoads` keeps NPC groups to the roads.
function WorldRoads.route(world: World, sx: number, sy: number, tx: number, ty: number, preferRoads: boolean?, maxNodes: number?): { Pos }?
	if not Grid.walkable(world, tx, ty) then return nil end
	local path = WorldRoads.astar(world, sx, sy, tx, ty, if preferRoads then roadCost else walkCost, nil, maxNodes)
	if not path then return nil end
	local out: { Pos } = {}
	local w = world.width
	for i = 2, #path do
		local ci = path[i]
		table.insert(out, { x = (ci - 1) % w + 1, y = math.floor((ci - 1) / w) + 1 })
	end
	return out
end

local PAD = 28
local function findPath(world: World, sx: number, sy: number, tx: number, ty: number, avoid: { Village }?): { number }?
	local box = { math.max(1, math.min(sx, tx) - PAD), math.max(1, math.min(sy, ty) - PAD), math.min(world.width, math.max(sx, tx) + PAD), math.min(world.height, math.max(sy, ty) + PAD) }
	return WorldRoads.astar(world, sx, sy, tx, ty, stepCost, avoid, nil, box)
		or WorldRoads.astar(world, sx, sy, tx, ty, stepCost, avoid) -- the box was too tight (a lake in the way): the whole map
end

local function carveTile(world: World, i: number)
	local g, o = world.ground[i], world.object[i]
	local od = TileTypes.Object[o]
	if o == O.tree.id or o == O.rock.id or (od and od.decor) then world.object[i] = 0 end
	if g == G.water.id then world.ground[i] = G.ford.id
	elseif g ~= G.ford.id and o ~= O.gate.id and o ~= O.palisade_gate.id then world.ground[i] = G.path.id end
end

--- Lay a road two tiles wide: the A* tile and, beside it, the tile east of a north-south step or south of an
--- east-west step (both at a turn). The second tile is skipped where something built stands, or inside a village:
--- a road widens through the wilds, not through a wall.
local function carveRoad(world: World, path: { number })
	local w = world.width
	for k, i in ipairs(path) do
		carveTile(world, i)
		local x, y = (i - 1) % w + 1, math.floor((i - 1) / w) + 1
		local nxt = path[k + 1] or path[k - 1]
		if nxt then
			local nx = (nxt - 1) % w + 1
			local sx, sy = if nx == x then x + 1 else x, if nx == x then y else y + 1
			if Grid.inBounds(world, sx, sy) and sx < w and sy < world.height and not Grid.villageAt(world, sx, sy, 0) then
				local o = Grid.object(world, sx, sy)
				local od = TileTypes.Object[o]
				if o == 0 or o == O.tree.id or o == O.rock.id or (od and od.decor) then carveTile(world, idx(w, sx, sy)) end
			end
		end
	end
end

-- ---------- the road network ----------
--- The gate on the side facing (tx, ty), or nil for an open village.
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

local function dist(a: Village, b: Village): number
	return math.sqrt((a.cx - b.cx) ^ 2 + (a.cy - b.cy) ^ 2)
end

--- Which villages to join: a minimum spanning tree over their centres (Prim), plus a few short extra edges so the
--- map has loops to walk and no hamlet hangs off a single road. Returns index pairs.
function WorldRoads.edges(villages: { Village }): { { number } }
	local n = #villages
	local out: { { number } } = {}
	if n < 2 then return out end
	local inTree: { [number]: boolean } = { [1] = true }
	local joined: { [string]: boolean } = {}
	local function key(a: number, b: number): string return math.min(a, b) .. ":" .. math.max(a, b) end
	for _ = 2, n do
		local bi, bj, bd = 0, 0, math.huge
		for i = 1, n do
			if inTree[i] then
				for j = 1, n do
					if not inTree[j] then
						local d = dist(villages[i], villages[j])
						if d < bd then bi, bj, bd = i, j, d end
					end
				end
			end
		end
		inTree[bj] = true
		table.insert(out, { bi, bj })
		joined[key(bi, bj)] = true
	end
	-- extras: the shortest unjoined pairs, as long as both ends are still lightly connected
	local degree: { [number]: number } = {}
	for _, e in ipairs(out) do degree[e[1]] = (degree[e[1]] or 0) + 1; degree[e[2]] = (degree[e[2]] or 0) + 1 end
	type Cand = { a: number, b: number, d: number }
	local candidates: { Cand } = {}
	for i = 1, n do
		for j = i + 1, n do
			if not joined[key(i, j)] then table.insert(candidates, { a = i, b = j, d = dist(villages[i], villages[j]) }) end
		end
	end
	table.sort(candidates, function(a: Cand, b: Cand) return a.d < b.d end)
	local extras = math.max(0, math.floor(n / 6))
	for _, c in ipairs(candidates) do
		if extras <= 0 then break end
		if (degree[c.a] or 0) <= 2 and (degree[c.b] or 0) <= 2 and c.d < 90 then
			table.insert(out, { c.a, c.b })
			degree[c.a] += 1; degree[c.b] += 1
			extras -= 1
		end
	end
	return out
end

--- Lay the roads. A road leaves a walled village through the gate facing where it is going and never cuts through
--- a third village. Then every gate no road chose gets a road out to the nearest road tile, so no gate opens onto
--- nothing. Finally every gate's exit tile is road.
function WorldRoads.build(world: World)
	local villages = world.villages
	local usedGates: { [Gate]: boolean } = {}
	local function endpoint(v: Village, toward: Village): Pos
		local g = facingGate(v, toward.spawn.x, toward.spawn.y)
		if not g then return v.spawn end
		usedGates[g] = true
		return g.exit
	end
	for _, e in ipairs(WorldRoads.edges(villages)) do
		local a, b = villages[e[1]], villages[e[2]]
		local avoid: { Village } = {}
		for i, v in ipairs(villages) do if i ~= e[1] and i ~= e[2] then table.insert(avoid, v) end end
		local s0, t0 = endpoint(a, b), endpoint(b, a)
		local path = findPath(world, s0.x, s0.y, t0.x, t0.y, avoid)
		if path then carveRoad(world, path) end
	end
	local w, h = world.width, world.height
	for vi, v in ipairs(villages) do
		for _, g in ipairs(v.gates) do
			if not usedGates[g] then
				-- Join the nearest road tile outside every village; the search box keeps it local.
				local bx, by, bestD = 0, 0, math.huge
				for y = math.max(2, g.exit.y - 40), math.min(h - 1, g.exit.y + 40) do
					for x = math.max(2, g.exit.x - 40), math.min(w - 1, g.exit.x + 40) do
						local d = math.abs(x - g.exit.x) + math.abs(y - g.exit.y)
						if d > 0 and d < bestD and world.ground[idx(w, x, y)] == G.path.id and not Grid.villageAt(world, x, y, 0) then
							bx, by, bestD = x, y, d
						end
					end
				end
				local avoid: { Village } = {}
				for i, o in ipairs(villages) do if i ~= vi then table.insert(avoid, o) end end
				local path = if bestD < math.huge then findPath(world, g.exit.x, g.exit.y, bx, by, avoid) else nil
				if path then carveRoad(world, path) end
			end
			Grid.setG(world, g.exit.x, g.exit.y, G.path.id)
		end
	end
	WorldRoads.fordRoads(world)
end

--- The ford clusters: touching ford tiles are one crossing. Each is { x0, x1, y } for its widest row (the row whose
--- banks the road should meet) and `road`, true when any tile of the crossing has a road beside it, in map order.
export type Ford = { x0: number, x1: number, y: number, road: boolean }
function WorldRoads.fords(world: World): { Ford }
	local w, h = world.width, world.height
	local seen: { [number]: boolean } = {}
	local out: { Ford } = {}
	for y = 2, h - 1 do
		for x = 2, w - 1 do
			local i = idx(w, x, y)
			if world.ground[i] == G.ford.id and not seen[i] then
				local queue, head = { { x = x, y = y } }, 1
				local rows: { [number]: { number } } = {}
				local road = false
				seen[i] = true
				while head <= #queue do
					local c = queue[head]
					head += 1
					local r = rows[c.y]
					if not r then rows[c.y] = { c.x, c.x } else r[1] = math.min(r[1], c.x); r[2] = math.max(r[2], c.x) end
					for _, d in ipairs(DIRS) do
						if Grid.ground(world, c.x + d[1], c.y + d[2]) == G.path.id then road = true end
					end
					for dy = -1, 1 do
						for dx = -1, 1 do
							local nx, ny = c.x + dx, c.y + dy
							if Grid.inBounds(world, nx, ny) then
								local ni = idx(w, nx, ny)
								if world.ground[ni] == G.ford.id and not seen[ni] then
									seen[ni] = true
									table.insert(queue, { x = nx, y = ny })
								end
							end
						end
					end
				end
				local best: Ford = { x0 = x, x1 = x, y = y, road = road }
				for ry, r in pairs(rows) do
					if r[2] - r[1] > best.x1 - best.x0 or (r[2] - r[1] == best.x1 - best.x0 and ry < best.y) then best = { x0 = r[1], x1 = r[2], y = ry, road = road } end
				end
				table.insert(out, best)
			end
		end
	end
	return out
end

--- The nearest road tile to (x, y) on one side of the river (`side` < 0: west of x, > 0: east), outside any village.
local function nearestRoad(world: World, x: number, y: number, side: number, reach: number): Pos?
	local w, h = world.width, world.height
	local bx, by, bestD = 0, 0, math.huge
	for yy = math.max(2, y - reach), math.min(h - 1, y + reach) do
		for xx = math.max(2, x - reach), math.min(w - 1, x + reach) do
			local d = math.abs(xx - x) + math.abs(yy - y)
			if d > 0 and d < bestD and (xx - x) * side > 0 and world.ground[idx(w, xx, yy)] == G.path.id and not Grid.villageAt(world, xx, yy, 0) then
				bx, by, bestD = xx, yy, d
			end
		end
	end
	return if bestD < math.huge then { x = bx, y = by } else nil
end

--- Every natural ford gets a road on both banks, joined to the nearest road on that side: the river is crossed
--- wherever it can be, not only where the tree happened to go, so a walk to the next village is not a march to the
--- far north and back (QA round 1).
function WorldRoads.fordRoads(world: World)
	local avoid = world.villages
	for _, f in ipairs(WorldRoads.fords(world)) do
		if not f.road then
			for _, bank in ipairs({ { x = f.x0 - 1, side = -1 }, { x = f.x1 + 1, side = 1 } }) do
				local road = nearestRoad(world, bank.x, f.y, bank.side, 60)
				local path = if road then findPath(world, bank.x, f.y, road.x, road.y, avoid) else nil
				if path then carveRoad(world, path) end
			end
		end
	end
end

return WorldRoads
