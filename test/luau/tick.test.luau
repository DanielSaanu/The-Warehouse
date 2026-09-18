-- shared/Tick.lua: the world's ticks as pure functions over records (docs/ARCHITECTURE.md A2). Everything here runs
-- with NO entities and NO players, which is exactly the situation catch-up is in.
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Config = __require("Config")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local DayCycle = __require("DayCycle")
local Tick = __require("Tick")

local world = WorldGen.generate(1)
local DAY = Config.DAY_SECONDS

--- A World Record the way Sim.init builds one, minus every body.
local function newRecord(seed: number)
	local rng = Rng.new(seed)
	local w = {
		meta = { gameSeconds = 0, lastDailyTick = 1 }, day = 1,
		tribes = {}, people = Families.new(), regions = Ecology.init(world, rng:fork(1)), groups = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	}
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { tribeType = v.tribeType, stock = Trade.newStock(v.tribeType), population = 10, surnames = { "Ash", "Birch" } }
		for n = 1, 6 do Families.newAdult(w.people, rng, i, i, "villager", 1, nil, if n % 2 == 0 then "f" else "m") end
	end
	local farmer, hunter = world.villages[1], world.villages[2]
	local g = { id = "caravan", kind = "caravan", tribe = 1, pos = 1, dir = 1, acc = 0, speed = 1.5, pauses = { 120, 120 },
		from = { x = farmer.spawn.x, y = farmer.spawn.y }, to = { x = hunter.spawn.x, y = hunter.spawn.y },
		pauseUntil = 30, members = { { kind = "caravan_guard" } }, fullSize = 3, carry = {} }
	Tick.rebuildRoute(g, world)
	w.groups.caravan = g
	return w, rng
end

local function livingCount(w): number
	local n = 0
	for _, p in pairs(w.people.people) do if p.alive then n += 1 end end
	return n
end

-- DayCycle: the calendar is derived from game seconds, and the two directions agree.
do
	local day, frac = DayCycle.fromSeconds(0)
	assert(day == 1 and frac == 0, "second 0 is the start of day 1")
	day, frac = DayCycle.fromSeconds(DAY * 6 + DAY * 0.25)
	assert(day == 7 and math.abs(frac - 0.25) < 1e-9, "day 7, a quarter through")
	assert(DayCycle.toSeconds(7, 0.25) == DAY * 6.25, "toSeconds inverts fromSeconds")
end

-- Unobserved births FINISH: every baby the registry gains is matched by the tribe's population and its news.
-- (Before A2 a birth only completed if the mother had a body on the map, so a world nobody watched drifted.)
do
	local w, rng = newRecord(11)
	local born = 0
	local before = {}
	for i, t in ipairs(w.tribes) do before[i] = t.population end
	for day = 2, 29 do
		local ev = Tick.daily(w, rng, day, (day - 1) * DAY)
		born += #ev.born
		local last = {} -- two births in one tribe on one day: the later one is the news
		for _, baby in ipairs(ev.born) do last[baby.tribe] = baby end
		for tribe, baby in pairs(last) do
			assert(w.tribes[tribe].news and w.tribes[tribe].news:find(baby.first, 1, true), "a birth is the tribe's news")
		end
	end
	assert(born > 0, "four weeks of couples produce at least one birth (got " .. born .. ")")
	local gained = 0
	for i, t in ipairs(w.tribes) do gained += t.population - before[i] end
	-- population also drifts +1 a day per tribe (capped at 60; these start at 10, so the cap is never reached)
	assert(gained == born + 28 * #w.tribes, ("population heard about every birth: gained %d, born %d"):format(gained, born))
	assert(livingCount(w) == 18 + born, "the registry holds the adults plus every baby")
end

-- Groups: a collapsed caravan walks its route, turns at the far end, pauses, and comes home.
do
	local w = newRecord(5)
	local g = w.groups.caravan
	assert(#g.route > 20, "the caravan has a real road to walk")
	for now = 1, 29 do Tick.groups(w, world, now) end
	assert(g.pos == 1, "paused until its first departure")
	local turned = false
	for now = 30, 30 + #g.route do
		Tick.groups(w, world, now)
		if g.dir == -1 then turned = true break end
	end
	assert(turned and g.pos == #g.route, "it reached the far end and turned for home")
	-- home with goods: the deposit lands in the tribe's stock and is reported as an event, not printed
	g.carry = { hide = 3 }
	local stockBefore = w.tribes[1].stock.hide
	local deposited = nil
	for now = g.pauseUntil, g.pauseUntil + #g.route + 5 do
		for _, ev in ipairs(Tick.groups(w, world, now)) do if ev.kind == "deposit" then deposited = ev end end
		if deposited then break end
	end
	assert(deposited and deposited.text == "3 hide", "the walk home ends in a deposit event")
	assert(w.tribes[1].stock.hide == stockBefore + 3, "and the hides are in the village's stock")
end

-- A flood holds caravans; a materialised group is the server's business, not the pure tick's.
do
	local w = newRecord(5)
	local g = w.groups.caravan
	w.calamity.active, w.calamity.kind = true, "flood"
	for now = 30, 60 do Tick.groups(w, world, now) end
	assert(g.pos == 1, "no caravan sets out in a flood")
	w.calamity.active = false
	g.materialised = true
	for now = 61, 90 do Tick.groups(w, world, now) end
	assert(g.pos == 1, "a group with bodies is not moved abstractly")
end

-- The band's late target: after the grace days it retargets, and `to` moves with it - so a route rebuilt from
-- from/to after a load is the NEW ambush, not the day-one one.
do
	local w = newRecord(5)
	local plunderer, farmer = world.villages[3], world.villages[1]
	local road = WorldGen.route(world, plunderer.spawn.x, plunderer.spawn.y, farmer.spawn.x, farmer.spawn.y, true)
	local near, far = road[math.floor(#road * 0.18)], road[math.floor(#road * 0.55)]
	local b = { id = "band", kind = "band", tribe = 3, pos = 1, dir = 1, acc = 0, speed = 2, pauses = { 60, 150 },
		from = { x = plunderer.spawn.x, y = plunderer.spawn.y }, to = { x = near.x, y = near.y }, lateTarget = { x = far.x, y = far.y },
		pauseUntil = 0, members = {}, fullSize = 4, carry = {} }
	Tick.rebuildRoute(b, world)
	w.groups.band = b
	local shortRoute = #b.route
	Tick.groups(w, world, DAY * Config.GRACE_DAYS - 1)
	assert(b.lateTarget, "still in its grace days")
	local events = Tick.groups(w, world, DAY * Config.GRACE_DAYS + 1)
	assert(b.lateTarget == nil and b.to.x == far.x and b.to.y == far.y, "retargeted, and `to` is the new ambush")
	assert(#b.route > shortRoute, "the new route is the longer one")
	local saw = false
	for _, ev in ipairs(events) do if ev.kind == "retarget" then saw = true end end
	assert(saw, "the retarget is reported as an event")
	-- what a load does: throw the route away and rebuild it from the record
	local len = #b.route
	b.route = nil
	Tick.rebuildRoute(b, world)
	assert(#b.route == len, "a rebuilt route is the retargeted one")
end

-- Catch-up IS live ticking: n seconds of catch-up leave the record exactly where n live steps do. This is the
-- guard against anybody "optimising" catch-up into hourly lumps (one lump = one leg; live ticking = eleven).
do
	local a, rngA = newRecord(9)
	local b, rngB = newRecord(9)
	local seconds = DAY * 3 + 77
	local t0 = os.clock()
	local report = Tick.catchUp(a, world, rngA, seconds)
	local ms = (os.clock() - t0) * 1000
	local now = 0
	for _ = 1, seconds do
		now += 1
		local day = DayCycle.fromSeconds(now)
		if day > b.meta.lastDailyTick then
			b.meta.lastDailyTick = day
			Tick.daily(b, rngB, day, now)
		end
		Tick.groups(b, world, now)
	end
	assert(report.seconds == seconds and report.days == 3, "three day boundaries were crossed")
	assert(a.meta.gameSeconds == seconds and a.day == 4 and a.meta.lastDailyTick == 4, "the calendar moved, and the daily ticks are accounted for")
	assert(a.groups.caravan.pos == b.groups.caravan.pos and a.groups.caravan.dir == b.groups.caravan.dir, "groups are where live ticking leaves them")
	assert(a.people.nextId == b.people.nextId and a.tribes[2].population == b.tribes[2].population, "and so are people")
	local ta, tb = Ecology.totals(a.regions), Ecology.totals(b.regions)
	assert(ta.deer == tb.deer and ta.wolf == tb.wolf, "and the ecosystem")
	print(("    catch-up: %d s of world time in %.1f ms"):format(seconds, ms))
end

-- The cap, and calamities: a running one EXPIRES during catch-up, none BEGINS, and time past the cap never happened.
do
	local w, rng = newRecord(3)
	w.calamity.active, w.calamity.kind, w.calamity.day = true, "flood", 1
	local t0 = os.clock()
	local report = Tick.catchUp(w, world, rng, Tick.CATCHUP_CAP * 10)
	local ms = (os.clock() - t0) * 1000
	assert(report.seconds == Tick.CATCHUP_CAP and w.meta.gameSeconds == Tick.CATCHUP_CAP, "capped at four in-game weeks")
	assert(w.day == 29 and report.days == 28, "28 daily ticks")
	assert(w.calamity.active == false, "the flood that was running ended on schedule")
	assert(w.calamity.warnedDay == w.day, "and the warning clock is current")
	print(("    catch-up at the cap: %d s (28 days) in %.0f ms"):format(report.seconds, ms))
end

print("tick ok")
