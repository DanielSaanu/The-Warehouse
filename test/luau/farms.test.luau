-- shared/Farms.lua: the plots a village works, as a pure rule over records (DESIGN.md §20). No bodies anywhere in
-- this file, which is the point: a village farms the same whether or not anybody is there to watch it.
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Config = __require("Config")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local Farms = __require("Farms")
local Tick = __require("Tick")
local Save = __require("Save")

local world = WorldGen.generate(1)

local function newRecord(villagers: number)
	local rng = Rng.new(5)
	local w = {
		meta = { gameSeconds = 0, lastDailyTick = 1, nextBagId = 0 }, day = 1,
		tribes = {}, people = Families.new(), regions = Ecology.init(world, rng:fork(1)), groups = {}, camps = {}, bags = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	}
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { tribeType = v.tribeType, villageId = i, stock = Trade.newStock(v.tribeType), population = 10, surnames = { "Ash" } }
		for n = 1, villagers do Families.newAdult(w.people, rng, i, i, "villager", 1, nil, if n % 2 == 0 then "f" else "m") end
		Farms.ensure(w.tribes[i], #Farms.scan(world, v).plots)
	end
	return w, rng
end

-- The farmer village has fields and hut doors; the scan is the same under a flood.
local farmer = world.villages[1]
local site = Farms.scan(world, farmer)
assert(#site.plots >= 2, "the farmer village has plots: " .. #site.plots)
assert(#site.huts >= 1, "and at least one standing hut with a door")
do
	local tiles = {}
	for _, p in ipairs(site.plots) do table.insert(tiles, WorldGen.index(world, p.x, p.y)) end
	WorldGen.setFlood(world, tiles)
	assert(#Farms.scan(world, farmer).plots == #site.plots, "a flood does not change how many plots a village has")
	local w = newRecord(4)
	for _, plot in ipairs(w.tribes[1].plots) do plot.growth = 0.4 end
	local G = __require("TileTypes").GroundByName
	local n = Farms.drown(w.tribes[1], site.plots, function(x, y) return WorldGen.ground(world, x, y) == G.flood.id end)
	assert(n == #site.plots and w.tribes[1].plots[1].growth == 0, "every plot under water loses its season")
	assert(w.tribes[1].news and w.tribes[1].news:find("water"), "and the village says so")
	WorldGen.clearFlood(world)
end

-- ensure: keeps what is there, grows and shrinks to fit, and never starts two worlds differently.
do
	local t = { plots = { { growth = 0.9, tended = 3 } } }
	Farms.ensure(t, 3)
	assert(#t.plots == 3 and t.plots[1].growth == 0.9, "ensure keeps existing rows")
	Farms.ensure(t, 1)
	assert(#t.plots == 1, "and trims rows the map no longer has")
end

-- A worked village eats; an empty one does not, and its fields go to weeds.
do
	local w = newRecord(6)
	local before = w.tribes[1].stock.food
	local food = 0
	for day = 2, 9 do
		local ev = Farms.daily(w, 1, day)
		if ev then food += ev.food end
	end
	assert(food > 0 and w.tribes[1].stock.food == before + food, "eight days of farming put food in the store: " .. food)

	local empty = newRecord(0)
	for day = 2, 9 do assert(Farms.daily(empty, 1, day) == nil, "nobody to farm, nothing comes in") end
	for _, plot in ipairs(empty.tribes[1].plots) do assert(plot.growth == 0, "an unworked plot goes back to weeds") end

	-- fewer hands than plots: only that many plots are ever worked in a day
	local few = newRecord(1)
	local ev = nil
	for day = 2, 4 do ev = Farms.daily(few, 1, day) or ev end
	assert(ev == nil or ev.harvested <= 1, "one villager brings in at most one plot a day")
	print(("    farms: %d plots, 6 hands, %d food in 8 days"):format(#w.tribes[1].plots, food))
end

-- The harvest stays in the store (QA round 1: the restock's ceiling deleted it the next morning), and a farming tribe
-- is not fed twice: its food comes from the fields, not from the abstract restock as well.
do
	local w, rng = newRecord(8)
	local t = w.tribes[1]
	t.stock.food = 80 -- a good season, well over the old 45 ceiling
	Trade.dailyRestock(t.stock, t.tribeType, true)
	assert(t.stock.food >= 70, "a full store is traded down a little, never cut to the ceiling: " .. t.stock.food)
	local unfarmed, farmed = Trade.newStock("farmer"), Trade.newStock("farmer")
	unfarmed.food, farmed.food = 10, 10
	Trade.dailyRestock(unfarmed, "farmer", false)
	Trade.dailyRestock(farmed, "farmer", true)
	assert(unfarmed.food > farmed.food, "without fields a tribe still makes its good; with fields the harvest is the making")
	-- thirty days of a full village: the store grows past the old ceiling and then settles, it does not run away
	for day = 2, 31 do Tick.daily(w, rng, day, day * Config.DAY_SECONDS) end
	local full = w.tribes[1].stock.food
	assert(full > 45 and full < 120, "a full village's store settles above the old ceiling: " .. full)
	-- the same month with nobody left to farm
	local e, rng2 = newRecord(0)
	e.tribes[1].stock.food = full
	for day = 2, 31 do Tick.daily(e, rng2, day, day * Config.DAY_SECONDS) end
	assert(e.tribes[1].stock.food < full, "a village that has lost its people eats into the store: " .. e.tribes[1].stock.food)
	print(("    farms: a month at full strength -> %d food; the same month empty -> %d"):format(full, e.tribes[1].stock.food))
end

-- The fields do not fall into lockstep (QA round 2: one shared rate and a reset to zero made every plot ripen on the
-- same morning for ever). Over a month a full village brings something in on most days, and on any given day the
-- plots are at different stages.
do
	local w = newRecord(8)
	local harvestDays, spreadDays = 0, 0
	for day = 2, 31 do
		if Farms.daily(w, 1, day) then harvestDays += 1 end
		local lo, hi = math.huge, -math.huge
		for _, plot in ipairs(w.tribes[1].plots) do lo, hi = math.min(lo, plot.growth), math.max(hi, plot.growth) end
		if hi - lo > 0.2 then spreadDays += 1 end
	end
	assert(harvestDays >= 20, "a working farm brings something in most days, not everything every other day: " .. harvestDays)
	assert(spreadDays >= 25, "and its plots are at different stages: " .. spreadDays)
	for _, plot in ipairs(w.tribes[1].plots) do assert(plot.growth >= 0 and plot.growth < 1, "growth stays in [0, 1)") end
	print(("    farms: something harvested on %d of 30 days, plots out of step on %d"):format(harvestDays, spreadDays))
end

-- A pregnant villager still works her plot.
do
	local w = newRecord(3)
	for _, p in pairs(w.people.people) do
		if p.tribe == 1 then p.stage, p.role = "pregnant", "pregnant" break end
	end
	assert(Farms.workers(w, 1) == 3, "expecting a child does not take a pair of hands off the fields")
end

-- The dead do not farm.
do
	local w = newRecord(3)
	assert(Farms.workers(w, 1) == 3)
	for _, p in pairs(w.people.people) do
		if p.tribe == 1 then Families.die(w.people, p.id, 2, "killed", "a bandit") break end
	end
	assert(Farms.workers(w, 1) == 2, "a killed villager is a pair of hands the fields have lost")
end

-- Catch-up farms: a sleeping world comes back with its harvests in, and the plots survive a save.
do
	local w, rng = newRecord(6)
	local growth0 = w.tribes[1].plots[1].growth
	local data = Save.encode(w, { seed = 1, rngState = 1, savedAt = 0 })
	assert(Save.check(data))
	local back = Save.decode(data)
	assert(#back.tribes[1].plots == #w.tribes[1].plots and back.tribes[1].plots[1].growth == growth0, "plots round-trip through a save")

	local tended = 0
	Tick.catchUp(w, world, rng, 6 * Config.DAY_SECONDS)
	for _, plot in ipairs(w.tribes[1].plots) do tended = math.max(tended, plot.tended) end
	assert(tended >= 6, "the fields were worked while nobody was watching (last tended day " .. tended .. ")")
end

print("    farms ok")
