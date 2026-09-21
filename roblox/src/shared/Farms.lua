--!nonstrict
-- Farms: the plots a village works, as a PURE rule over records (docs/ARCHITECTURE.md H9; DESIGN.md §20).
-- Owns: the rule. A tribe row carries `plots = { { growth, tended } }`, one per farm tile inside its village, in
-- scan order. WHERE the plots and the hut doors are is derived from the map (R4) and never saved: Farms.scan.
-- The rule counts RECORDS, not bodies: every living adult villager works one plot a day, so a village that loses
-- its people stops feeding itself, and catch-up farms exactly as a watched day does. The walk out to the plot in
-- the morning is a projection of this (server/Villagers.lua) and changes no number here.
-- Does NOT move anybody, touch the map, or print. Returns events; the adapter tells people.
--   Farms.ensure(t, #site.plots)                -- an old save, or a new world: give the tribe its plot rows
--   local ev = Farms.daily(w, i, day)           -- { harvested = 2, food = 6 } or nil
local WorldGen = require(script.Parent.WorldGen)
local TileTypes = require(script.Parent.TileTypes)

local Farms = {}

Farms.GROW_PER_DAY = 0.5 -- a worked plot comes in every second day
Farms.WEEDS_PER_DAY = 0.15 -- a plot nobody touched goes back
Farms.FOOD_PER_PLOT = 3

local G, O = TileTypes.GroundByName, TileTypes.ObjectByName

--- The hut doors people sleep at and the farm tiles they work, read off the map inside a village's bounds.
function Farms.scan(world, v): { huts: { WorldGen.Pos }, plots: { WorldGen.Pos } }
	local huts, plots = {}, {}
	local hutIds = { [O.hut.id] = true, [O.hut_hunter.id] = true, [O.hut_plunderer.id] = true }
	for y = v.y0, v.y1 do
		for x = v.x0, v.x1 do
			if hutIds[WorldGen.object(world, x, y)] then
				local door = WorldGen.nearestWalkable(world, x, y + 1, 2)
				if door then table.insert(huts, door) end
			else
				-- the ground UNDER a flood, if there is one: water must not change how many plots a village has,
				-- or a scan made mid-flood would shift every plot row off its tile
				local backup = world.floodBackup
				local ground = (backup and backup[WorldGen.index(world, x, y)]) or WorldGen.ground(world, x, y)
				if ground == G.farm.id then table.insert(plots, { x = x, y = y }) end
			end
		end
	end
	return { huts = huts, plots = plots }
end

--- Make `t.plots` exactly `n` rows long, keeping what is there. Staggered starts, and no rng: the same world
--- always starts with the same fields, and the sim's random sequence is not disturbed by a save that predates farms.
function Farms.ensure(t, n: number)
	t.plots = t.plots or {}
	for i = #t.plots + 1, n do t.plots[i] = { growth = ((i * 37) % 50) / 100, tended = 0 } end
	for i = #t.plots, n + 1, -1 do t.plots[i] = nil end
end

--- The living adult villagers of tribe `i`: the people who farm.
function Farms.workers(w, i: number): number
	local n = 0
	for _, p in pairs(w.people.people) do
		if p.alive and p.tribe == i and p.role == "villager" and p.stage == "adult" then n += 1 end
	end
	return n
end

--- One day on tribe `i`'s plots. The ripest plots are worked first, one per worker; a ripe plot is harvested
--- into the tribe's food; the rest go to weeds. Returns { harvested, food } when something came in, else nil.
function Farms.daily(w, i: number, day: number)
	local t = w.tribes[i]
	if not t.plots or #t.plots == 0 then return nil end
	local order = {}
	for k in ipairs(t.plots) do order[k] = k end
	table.sort(order, function(a, b)
		if t.plots[a].growth ~= t.plots[b].growth then return t.plots[a].growth > t.plots[b].growth end
		return a < b
	end)
	local hands, harvested = Farms.workers(w, i), 0
	for n, k in ipairs(order) do
		local plot = t.plots[k]
		if n <= hands then
			plot.growth = math.min(1, plot.growth + Farms.GROW_PER_DAY)
			plot.tended = day
			if plot.growth >= 1 then
				plot.growth = 0
				harvested += 1
			end
		else
			plot.growth = math.max(0, plot.growth - Farms.WEEDS_PER_DAY)
		end
	end
	if harvested == 0 then return nil end
	local food = harvested * Farms.FOOD_PER_PLOT
	t.stock.food = (t.stock.food or 0) + food
	if not t.news and harvested >= 2 then
		t.news = ("The plots came in well. %d loads of food in the store."):format(food)
	end
	return { harvested = harvested, food = food }
end

--- A flood: every plot whose tile `under(x, y)` says is under water loses the season on it. Returns how many.
function Farms.drown(t, plots: { WorldGen.Pos }, under: (number, number) -> boolean): number
	local drowned = 0
	for k, pos in ipairs(plots) do
		local plot = t.plots and t.plots[k]
		if plot and plot.growth > 0 and under(pos.x, pos.y) then
			plot.growth, plot.tended = 0, 0
			drowned += 1
		end
	end
	if drowned > 0 then t.news = ("The water took %d of our plots."):format(drowned) end
	return drowned
end

return Farms
