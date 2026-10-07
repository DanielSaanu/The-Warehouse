--!strict
-- The land (the generator's first pass; docs/plans/world-expansion.md). Pure Luau. Noise for elevation and
-- moisture with a lean per quarter of the map (farmland south-west, forest east, hills north, so each tribe's
-- country looks like its own), then the river, lakes and marsh, hills, forest, tall grass and flowers; later the
-- fords, the caves, and the river turning wadeable once everything is built. Villages, roads and the places between
-- them are the other passes (WorldVillages, WorldRoads, WorldPlaces); WorldGen.generate runs them in order.
local Grid = require(script.Parent.Grid)
local Rng = require(script.Parent.Rng)
local TileTypes = require(script.Parent.TileTypes)

local WorldLand = {}

type World = Grid.World
type Pos = Grid.Pos
local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName
local idx = Grid.idx
local setG, setO = Grid.setG, Grid.setO

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

export type Land = { riverX: { number }, riverTiles: { number } }

--- Ground and the wild objects. Returns what the later passes need to know about the river.
function WorldLand.build(world: World, rng: Rng.Rng): Land
	local w, h = world.width, world.height
	local elev1, elev2, elev3 = makeNoise(rng:fork(1), w, h, 18), makeNoise(rng:fork(2), w, h, 7), makeNoise(rng:fork(3), w, h, 3)
	local moist1, moist2 = makeNoise(rng:fork(4), w, h, 14), makeNoise(rng:fork(5), w, h, 5)
	local detail = rng:fork(6)
	local elevation = table.create(w * h, 0)
	local moisture = table.create(w * h, 0)
	for y = 1, h do
		for x = 1, w do
			local i = idx(w, x, y)
			local fx, fy = (x - 1) / (w - 1), (y - 1) / (h - 1)
			-- the lean: north rises into hills, the east is wetter (forest), the south-west is low and dry (fields)
			elevation[i] = 0.6 * elev1(x, y) + 0.3 * elev2(x, y) + 0.1 * elev3(x, y) + 0.14 * (1 - fy) - 0.07 * (1 - fx) * fy
			moisture[i] = 0.7 * moist1(x, y) + 0.3 * moist2(x, y) + 0.12 * fx - 0.06
		end
	end

	-- River: top to bottom, two tiles wide (three on a big map), wandering. riverX[y] is its left column on row y.
	-- Every tile it carves is remembered: at the end of generation the ones still water become `river`, which is
	-- wadeable. Lakes (cut by the moisture pass below) are never in this set and stay impassable.
	local riverX: { number } = {}
	local riverTiles: { number } = {}
	do
		local rrng = rng:fork(7)
		local x = rrng:int(math.floor(w * 0.4), math.floor(w * 0.6))
		local drift = 0
		local wide = if w >= 192 then 1 else 0
		local function carve(cx: number, cy: number)
			if not Grid.inBounds(world, cx, cy) then return end
			setG(world, cx, cy, G.water.id)
			local i = idx(w, cx, cy)
			table.insert(riverTiles, i)
		end
		for y = 1, h do
			if rrng:chance(0.35) then drift = rrng:int(-1, 1) end
			x = math.max(4, math.min(w - 4, x + drift))
			riverX[y] = x
			for dx = 0, 1 + wide do carve(x + dx, y) end
			if rrng:chance(0.2) then carve(x - 1, y) end
		end
	end
	-- Lakes, marsh, hills, forest, tall grass, flowers.
	for y = 1, h do
		for x = 1, w do
			local i = idx(w, x, y)
			local e, m = elevation[i], moisture[i]
			if world.ground[i] ~= G.water.id then
				if e < 0.28 and m > 0.62 then
					world.ground[i] = G.water.id
				elseif e < 0.36 and m > 0.57 then
					-- marsh: pools, reeds in the tall grass
					if detail:chance(0.22) then world.ground[i] = G.water.id
					else
						world.ground[i] = G.tall_grass.id
						if detail:chance(0.35) then world.object[i] = O.reeds.id end
					end
				elseif e > 0.62 then
					-- the hills: stony ground you walk over, boulders and dead trees standing sparse on it, and small crags
					-- of solid rock only at the very top (where the cave mouths go)
					world.ground[i] = G.rocky.id
					local r = detail:float()
					if e > 0.84 then world.object[i] = O.rock.id
					elseif r < 0.05 then world.object[i] = O.boulder.id
					elseif r < 0.08 then world.object[i] = O.boulder_mossy.id
					elseif r < 0.18 then world.object[i] = if detail:chance(0.5) then O.rocks_grey.id else O.rocks_brown.id
					elseif r < 0.20 then world.object[i] = O.dead_tree.id
					elseif r < 0.21 then world.object[i] = O.dead_tree_tall.id end
				elseif m > 0.56 and e > 0.3 then
					-- the forest: its floor says "forest"; the trees stand on a spaced lattice (never two side by side), so a
					-- forest is dense to look at and always walkable, like a wood you weave through
					world.ground[i] = G.forest_floor.id
					-- no tree beside another (the lattice) and none diagonal to one above (checked, since rows go north
					-- to south), so no line of trees ever walls the way; the crowns of the 32-tall pines still touch
					local upL, upR = Grid.object(world, x - 1, y - 1), Grid.object(world, x + 1, y - 1)
					local function isTree(o: number): boolean return o == O.tree.id or o == O.pine.id or o == O.pine_tall.id or o == O.tree_autumn.id end
					if (x + 2 * y) % 3 == 0 and not isTree(upL) and not isTree(upR) and detail:chance(0.7 + (m - 0.56) * 2) then
						local r = detail:float()
						local pineOdds = if e > 0.5 then 0.45 else 0.18
						world.object[i] = if r < pineOdds then (if detail:chance(0.3) then O.pine_tall.id else O.pine.id)
							elseif r < pineOdds + 0.08 then O.tree_autumn.id else O.tree.id
					elseif detail:chance(0.05) then
						world.object[i] = O.mushrooms.id
					elseif detail:chance(0.02) then
						world.object[i] = O.bush.id
					end
				elseif m > 0.50 and e > 0.3 then
					-- the forest's edge: bushes, berries, stumps, a fallen log
					local r = detail:float()
					if r < 0.05 then world.object[i] = O.bush.id
					elseif r < 0.07 then world.object[i] = O.berry_bush.id
					elseif r < 0.09 then world.object[i] = O.stump.id
					elseif r < 0.10 then world.object[i] = O.fallen_log.id
					elseif r < 0.13 then world.object[i] = O.mushrooms.id
					elseif m > 0.47 and detail:chance(0.5) then world.ground[i] = G.tall_grass.id end
				elseif m > 0.47 and detail:chance(0.6) then
					world.ground[i] = G.tall_grass.id
				elseif detail:chance(0.12) then
					world.ground[i] = G.grass_2.id
				elseif detail:chance(0.025) then
					local r = detail:float()
					world.object[i] = if r < 0.4 then O.flower_red.id elseif r < 0.7 then O.flower_purple.id else O.flower_white.id
				elseif detail:chance(0.006) then
					world.object[i] = O.bush.id
				end
			end
		end
	end
	-- Crags: solid rock in blocks bigger than a dozen tiles is a wall of identical boulders. Thin every big block to
	-- scattered rocks and boulders on the stony ground, so the hills stay walkable and read as hills. Twice, so what
	-- the first pass leaves standing is checked again (QA round 3: a hash that kept whole rows).
	for _ = 1, 2 do
		local seen: { [number]: boolean } = {}
		for y = 2, h - 1 do
			for x = 2, w - 1 do
				local i0 = idx(w, x, y)
				if world.object[i0] == O.rock.id and not seen[i0] then
					local comp: { number } = { i0 }
					seen[i0] = true
					local head = 1
					while head <= #comp do
						local ci = comp[head]
						head += 1
						local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
						for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
							local nx, ny = cx + d[1], cy + d[2]
							if nx > 1 and ny > 1 and nx < w and ny < h then
								local ni = idx(w, nx, ny)
								if world.object[ni] == O.rock.id and not seen[ni] then seen[ni] = true; table.insert(comp, ni) end
							end
						end
					end
					if #comp > 12 then
						for _, ci in ipairs(comp) do
							local cx, cy = (ci - 1) % w + 1, math.floor((ci - 1) / w) + 1
							local keep = (cx * 31 + cy * 17 + cx * cy) % 9 == 0
							if not keep then
								local r = detail:float()
								world.object[ci] = if r < 0.25 then O.boulder.id elseif r < 0.4 then O.rocks_grey.id else 0
							end
						end
					end
				end
			end
		end
	end
	-- Map edge: rock ring so the world has a visible border.
	for x = 1, w do setO(world, x, 1, O.rock.id); setO(world, x, h, O.rock.id) end
	for y = 1, h do setO(world, 1, y, O.rock.id); setO(world, w, y, O.rock.id) end
	return { riverX = riverX, riverTiles = riverTiles }
end

--- Fords: natural crossings far apart along the river, carved before the roads so the roads spread across them
--- instead of all sharing one. A crossing is a row where the river is at most 3 tiles wide with dry banks.
function WorldLand.fords(world: World, frng: Rng.Rng, riverX: { number })
	local w, h = world.width, world.height
	local want = math.max(3, math.floor(h / 64))
	local fordRows: { number } = {}
	local rows: { number } = {}
	for y = 8, h - 7 do table.insert(rows, y) end
	for i = #rows, 2, -1 do
		local j = frng:int(1, i)
		rows[i], rows[j] = rows[j], rows[i]
	end
	local added = 0
	for _, y in ipairs(rows) do
		if added >= want then break end
		local farEnough = true
		for _, fy in ipairs(fordRows) do
			if math.abs(fy - y) < 20 then farEnough = false break end
		end
		local rx = riverX[y]
		if farEnough and rx and Grid.ground(world, rx, y) == G.water.id then
			local x0, x1 = rx, rx
			while Grid.ground(world, x0 - 1, y) == G.water.id and rx - x0 < 4 do x0 -= 1 end
			while Grid.ground(world, x1 + 1, y) == G.water.id and x1 - rx < 4 do x1 += 1 end
			local wx, ex = x0 - 1, x1 + 1
			if x1 - x0 + 1 <= 3 and wx > 1 and ex < w
				and Grid.ground(world, wx, y) ~= G.water.id and Grid.ground(world, ex, y) ~= G.water.id then
				for x = x0, x1 do setG(world, x, y, G.ford.id) end
				-- Clear trees and rocks off the banks so the crossing can be reached.
				for _, bx in ipairs({ wx - 1, wx, ex, ex + 1 }) do
					local o = Grid.object(world, bx, y)
					if bx > 1 and bx < w and o ~= 0 and (o == O.tree.id or o == O.rock.id or TileTypes.Object[o].decor) then setO(world, bx, y, 0) end
				end
				table.insert(fordRows, y)
				added += 1
			end
		end
	end
end

--- Cave mouths: a small crag (a 3 x 2 mound of rock) with the cave in the middle of its south face, on the stony
--- ground of the hills, with open ground south of it that the player can walk to from the spawn. Placed after the
--- roads and the places. Collect every spot the mound fits, then pick a few far apart.
function WorldLand.caves(world: World, crng: Rng.Rng)
	local w, h = world.width, world.height
	local want = math.max(3, math.floor(w * h / 13000))
	local open = Grid.flood(world, world.spawn.x, world.spawn.y)
	local candidates: { Pos } = {}
	for y = 4, h - 3 do
		for x = 3, w - 2 do
			-- the mouth and the two tiles south of it are open and reached from the south, so the mound's own rock never
			-- closes the only way in
			if Grid.ground(world, x, y) == G.rocky.id and Grid.object(world, x, y + 1) == 0 and Grid.ground(world, x, y + 1) ~= G.water.id
				and Grid.ground(world, x, y + 1) ~= G.path.id and open[idx(w, x, y + 1)] and open[idx(w, x, y + 2)]
				and Grid.object(world, x - 1, y + 1) == 0 and Grid.object(world, x + 1, y + 1) == 0 and not Grid.villageAt(world, x, y, 4) then
				local clear = true
				for dy = -1, 0 do
					for dx = -1, 1 do
						local o = Grid.object(world, x + dx, y + dy)
						local g = Grid.ground(world, x + dx, y + dy)
						if g == G.path.id or g == G.water.id or (o ~= 0 and o ~= O.rock.id and not TileTypes.Object[o].decor and o < O.pine.id) then clear = false end
					end
				end
				if clear then table.insert(candidates, { x = x, y = y }) end
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
		if #placed >= want then break end
		local farEnough = true
		for _, p in ipairs(placed) do
			if math.abs(p.x - c.x) + math.abs(p.y - c.y) < 14 then farEnough = false break end
		end
		if farEnough then
			for dx = -1, 1 do setO(world, c.x + dx, c.y - 1, O.rock.id); setO(world, c.x + dx, c.y, O.rock.id) end
			setO(world, c.x, c.y, O.cave.id)
			table.insert(placed, c)
		end
	end
end

--- The river becomes wadeable. Last, so village placement, fords, roads and caves all saw the same map they
--- always did: only the tiles the river itself carved, and only where nothing has since been built over them.
function WorldLand.finishRiver(world: World, riverTiles: { number })
	for _, i in ipairs(riverTiles) do
		if world.ground[i] == G.water.id then world.ground[i] = G.river.id end
	end
end

return WorldLand
