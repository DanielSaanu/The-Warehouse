--!nonstrict
-- The world's ticks as PURE functions over the World Record (docs/ARCHITECTURE.md A2, H9). No entities, no players,
-- no Roblox: only records. The server runs these live and turns the events they RETURN into bodies, prints and
-- notices; catch-up runs the very same functions for the time the server was down, which is why they live here,
-- where `npm test` can run them, and why they must finish their work whether or not anybody is watching.
-- Owns no data. `w` is any table shaped like Sim.state: { meta, day, tribes, people, regions, groups, calamity }.
-- Does NOT materialise or collapse groups, spawn anything, or fade player reputation: those are the adapter's.
--   local ev = Tick.daily(S, rng, day, now)     -- then the server morphs the mothers in ev.born, if they have bodies
--   Tick.catchUp(S, world, rng, 3600)           -- an hour passed while nobody was here
local Config = require(script.Parent.Config)
local WorldGen = require(script.Parent.WorldGen)
local DayCycle = require(script.Parent.DayCycle)
local Ecology = require(script.Parent.Ecology)
local Families = require(script.Parent.Families)
local Trade = require(script.Parent.Trade)
local Farms = require(script.Parent.Farms)
local Headlines = require(script.Parent.Headlines)
local Gossip = require(script.Parent.Gossip)

local Tick = {}

Tick.CATCHUP_CAP = 4 * Config.WEEK_DAYS * Config.DAY_SECONDS -- DESIGN §14: four IN-GAME weeks; past it the world slept

-- ---------- families ----------
--- Couples, the weekly conception roll, births and growing up, for every tribe. The RECORDS are always finished
--- here: a birth raises the tribe's population and becomes its news even if the mother has no body right now.
--- Returns { conceived = {Person}, born = {Person}, grown = {Person} } for the adapter to give bodies to.
function Tick.families(w, rng, day: number)
	local conceived = {}
	for i in ipairs(w.tribes) do
		Families.formCouples(w.people, i, day)
		if day % Config.WEEK_DAYS == 1 then
			for _, mother in ipairs(Families.weeklyConceive(w.people, rng, i, day, w.tribes[i].tribeType)) do table.insert(conceived, mother) end
		end
	end
	local r = Families.daily(w.people, rng, day)
	for _, baby in ipairs(r.born) do
		local t = w.tribes[baby.tribe]
		local mother = w.people.people[baby.mother]
		if t then
			t.population += 1
			if mother then t.news = Families.describeBirth(baby, mother) end
			Headlines.push(w.meta, { day = day, kind = "born", tribe = baby.tribe, id = baby.id }) -- catch-up writes these too
		end
	end
	return { conceived = conceived, born = r.born, grown = r.grown }
end

-- ---------- the daily tick ----------
--- Group sizes when a broken group is made whole again.
local function fullCrew(g): (number, string)
	if g.kind == "caravan" then return 3, "caravan_guard" end
	return 4, if g.kind == "squad" then "hunter" else "bandit"
end

--- A new named member for a group: a PERSON of the tribe (so they can be known, mourned and gossiped about) who
--- is on the road rather than in the village (`Person.group`). Used for a new world's groups and for replacements.
function Tick.enlist(w, rng, g, kind: string, role: string?, day: number)
	local t = w.tribes[g.tribe]
	local surname = if t.surnames and #t.surnames > 0 then rng:pick(t.surnames) else nil
	local p = Families.newAdult(w.people, rng, g.tribe, t.villageId or g.tribe, role or kind, day, surname)
	p.group = g.id
	local m = { kind = kind, role = role, person = p.id }
	table.insert(g.members, m)
	return m
end

--- One in-game day: the ecosystem, families, stock, population, and groups that have licked their wounds.
--- `now` is game seconds (Calendar.now()). Returns the family events plus `harvests[tribe]` and `totals` for the log.
function Tick.daily(w, rng, day: number, now: number)
	Ecology.dailyTick(w.regions, rng)
	local ev = Tick.families(w, rng, day)
	ev.harvests = {}
	for i, t in ipairs(w.tribes) do
		Trade.dailyRestock(t.stock, t.tribeType, t.plots ~= nil and #t.plots > 0)
		t.population = math.min(60, t.population + 1)
		ev.harvests[i] = Farms.daily(w, i, day) -- after the restock, so a harvest is food on top of the day's trade
	end
	for _, g in pairs(w.groups) do
		if g.replenishAt and now >= g.replenishAt and not g.materialised then
			local full, kind = fullCrew(g)
			while #g.members < full do Tick.enlist(w, rng, g, kind, nil, day) end -- new faces: the dead stay dead
			g.replenishAt = nil
		end
	end
	Gossip.dropStale(w, day) -- old news stops travelling
	ev.totals = Ecology.totals(w.regions)
	return ev
end

-- ---------- groups ----------
--- A group's route is DERIVED from where it started and where it is going, so it is never saved: this rebuilds it
--- (on creation, on a retarget, and after a load) and keeps `pos` inside it.
function Tick.rebuildRoute(g, world)
	local route = WorldGen.route(world, g.from.x, g.from.y, g.to.x, g.to.y, true) or {}
	table.insert(route, 1, { x = g.from.x, y = g.from.y })
	g.route = route
	g.pos = math.clamp(g.pos or 1, 1, #route)
end

local function atEnd(g): boolean
	return (g.dir == 1 and g.pos >= #g.route) or (g.dir == -1 and g.pos <= 1)
end

--- Home with the kill: what the group carried goes into its village's stock. Returns the event, or nil.
local function deposit(w, g)
	local t = w.tribes[g.tribe]
	local parts = {}
	for item, n in pairs(g.carry) do
		if n > 0 and t.stock[item] ~= nil then
			t.stock[item] += n
			table.insert(parts, ("%d %s"):format(n, item))
		end
	end
	g.carry = {}
	if #parts == 0 then return nil end
	table.sort(parts)
	return { kind = "deposit", group = g.id, tribe = g.tribe, text = table.concat(parts, ", ") }
end

--- Turn around at either end of the route. dir -1 is the walk home, so turning then means they have arrived.
function Tick.groupTurn(w, g, now: number, events)
	if g.dir == -1 then
		local ev = deposit(w, g)
		if ev and events then table.insert(events, ev) end
	end
	-- Gossip's main channel (docs/RUNG3.md part 3): they are standing at one end of their route, so the holder there
	-- is known without a search. The bandit tells his band, the caravan tells the village it just reached.
	Gossip.arrive(w, g)
	g.dir = -g.dir
	g.pauseUntil = now + (if g.dir == 1 then g.pauses[1] else g.pauses[2])
end

--- One second of abstract movement for every group that has no bodies right now (`g.materialised` is the
--- adapter's flag; records that were never materialised simply lack it). Returns a list of events.
function Tick.groups(w, world, now: number)
	local events = {}
	local day = DayCycle.fromSeconds(now)
	-- Meeting on the road. Gated on a slot computed from `now` alone, so n live seconds and catchUp(n) produce the
	-- identical sequence of exchanges - it is a schedule, NOT a second movement granularity (ARCHITECTURE §9).
	Gossip.meet(w, now)
	local floodOn = w.calamity.active and w.calamity.kind == "flood"
	for _, g in pairs(w.groups) do
		if not g.materialised then
			if g.lateTarget and day > Config.GRACE_DAYS then
				-- grace is over: the band takes up its real ambush. `to` moves with it, or a reload would send it back.
				g.to = { x = g.lateTarget.x, y = g.lateTarget.y }
				g.lateTarget = nil
				g.pos, g.dir, g.acc = 1, 1, 0
				Tick.rebuildRoute(g, world)
				g.pauseUntil = now + 5
				table.insert(events, { kind = "retarget", group = g.id })
			end
			if now >= g.pauseUntil and not (floodOn and g.kind == "caravan") then
				-- whole tiles only: `pos` indexes the route
				g.acc += g.speed
				local steps = math.floor(g.acc)
				g.acc -= steps
				g.pos = math.clamp(g.pos + g.dir * steps, 1, #g.route)
				if atEnd(g) then Tick.groupTurn(w, g, now, events) end
			end
		end
	end
	return events
end

-- ---------- catch-up ----------
--- The time the server was down, replayed on the records: every second the groups move, at every day boundary the
--- daily tick runs. ONE granularity on purpose - a lump of an hour moves a group one leg where live ticking moves
--- it eleven. A calamity that was running EXPIRES on schedule; none BEGINS (the world slept through it). Seconds
--- beyond CATCHUP_CAP did not happen. Returns { seconds, days, events } for the log.
function Tick.catchUp(w, world, rng, seconds: number)
	seconds = math.floor(math.clamp(seconds, 0, Tick.CATCHUP_CAP))
	local events, days = {}, 0
	local now = w.meta.gameSeconds
	for _ = 1, seconds do
		now += 1
		local day = DayCycle.fromSeconds(now)
		if day > w.meta.lastDailyTick then
			w.meta.lastDailyTick = day
			w.day = day
			days += 1
			Tick.daily(w, rng, day, now)
			local c = w.calamity
			if c.active and day > c.day then c.active, c.flood = false, nil end
		end
		for _, ev in ipairs(Tick.groups(w, world, now)) do table.insert(events, ev) end
	end
	w.meta.gameSeconds = now
	w.day = DayCycle.fromSeconds(now)
	w.calamity.warnedDay = w.day
	return { seconds = seconds, days = days, events = events }
end

return Tick
