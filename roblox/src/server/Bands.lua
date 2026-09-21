--!nonstrict
-- Groups: the caravan, the hunting squad and the band (docs/ARCHITECTURE.md Track B1). A group is a RECORD with a
-- route (derived from `from`/`to`, never saved) and a position along it. Materialised - a player is near - its
-- members are entities walking the route behind a leader; collapsed, the record's `pos` just advances.
-- Owns: `S.groups` rows - making them (init), their transient half (scratch), bodies in and out (materialise,
-- collapse), the 1 Hz decision of which (tick), and the server's side of turning for home (turn).
-- Does NOT move a collapsed group (shared/Tick.groups: pure, shared with catch-up), steer a materialised one
-- (Sim's groupStep), or decide what a fight does to a group (Sim's killEntity). Carved verbatim out of Sim.lua.
-- Bound, not required, for the entity constructors, which still live in Sim (B2 moves them to Bodies).
--   Bands.init()                                 -- a new world: the three groups
--   local p = Bands.pos(g)                       -- where it is, bodies or not
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Names = require(Shared:WaitForChild("Names"))
local Tick = require(Shared:WaitForChild("Tick"))
local Map = require(script.Parent:WaitForChild("Map"))
local State = require(script.Parent:WaitForChild("State"))
local Calendar = require(script.Parent:WaitForChild("Calendar"))

local Bands = {}

local S = State.state
local world, rng
local newEntity, removeEntity, nearestFree, anyPlayerWithin

function Bands.bind(ctx)
	world, rng = ctx.world, ctx.rng
	newEntity, removeEntity, nearestFree, anyPlayerWithin = ctx.newEntity, ctx.removeEntity, ctx.nearestFree, ctx.anyPlayerWithin
end

-- A group is a record with a route (a list of tiles) and a position along it. Materialised, its members are
-- entities walking the route behind a leader; collapsed, the record's `pos` just advances.
--- Does the road from `from` to `to` pass within `near` tiles of any village but `ownId`? The squad's old forest lay
--- beyond Wild's Rest, its road ran through the middle of the village, and every trip was a battle: the band wiped
--- out, half the garrison dead, before the first daily tick (QA rounds 1 and 2). Targeting rules could not fix it
--- (a village must be allowed to defend itself); not walking through it does.
local function passesVillage(from: WorldGen.Pos, to: WorldGen.Pos, ownId: number, near: number): boolean
	for _, p in ipairs(WorldGen.route(world, from.x, from.y, to.x, to.y, true) or {}) do
		for i, v in ipairs(world.villages) do
			if i ~= ownId and p.x >= v.x0 - near and p.x <= v.x1 + near and p.y >= v.y0 - near and p.y <= v.y1 + near then return true end
		end
	end
	return false
end

local function forestTarget(): WorldGen.Pos
	local best, bestF = nil, -1
	local home = world.villages[2].spawn
	for _, r in ipairs(S.regions.list) do
		if not r.village and r.forest > bestF then
			local x0, y0, x1, y1 = WorldGen.regionBounds(world, r.id)
			local c = WorldGen.nearestWalkable(world, math.floor((x0 + x1) / 2), math.floor((y0 + y1) / 2), 8)
			if c and WorldGen.reachable(world, world.spawn.x, world.spawn.y, c.x, c.y) and not passesVillage(home, c, 2, 4) then best, bestF = c, r.forest end
		end
	end
	return best or world.villages[2].spawn
end

--- The TRANSIENT half of a group: who is materialised, who they are chasing. Never saved; reset on creation and
--- again when a saved group is restored.
function Bands.scratch(g)
	g.entities, g.leader, g.trail, g.materialised = {}, nil, {}, false
	g.target, g.aggroUntil, g.lastSeen = nil, 0, nil
end

local function makeGroup(id: string, kind: string, tribeIdx: number, from: WorldGen.Pos, to: WorldGen.Pos, specs, pauses)
	-- `route` is derived from `from` and `to` (Tick.rebuildRoute), so `to` is what a save keeps
	local g = {
		id = id, kind = kind, tribe = tribeIdx, pos = 1, dir = 1, from = { x = from.x, y = from.y }, to = { x = to.x, y = to.y },
		pauseUntil = Calendar.now() + rng:int(20, 60), pauses = pauses, speed = 1.5, acc = 0,
		members = {}, fullSize = #specs, -- members are PEOPLE (Tick.enlist): the same faces every time they materialise
		carry = {}, retreatUntil = 0,   -- what they are bringing home, and whether they have had enough
	}
	for _, spec in ipairs(specs) do Tick.enlist(S, rng, g, spec.kind, spec.role, S.day) end
	Bands.scratch(g)
	Tick.rebuildRoute(g, world)
	S.groups[id] = g
	return g
end

function Bands.init()
	local farmer, hunter, plunderer = world.villages[1], world.villages[2], world.villages[3]
	makeGroup("caravan", "caravan", 1, farmer.spawn, hunter.spawn,
		{ { kind = "caravan_master", role = "caravan_master" }, { kind = "caravan_guard", role = "caravan_guard" }, { kind = "caravan_guard", role = "caravan_guard" } },
		{ 120, 120 })
	makeGroup("squad", "squad", 2, hunter.spawn, forestTarget(),
		{ { kind = "hunter" }, { kind = "hunter" }, { kind = "hunter" }, { kind = "hunter" } },
		{ 60, 90 })
	-- The band lies in wait part way down the road from its village toward the farmers. Not on day one: for the
	-- first GRACE_DAYS it stays up near its own village, so a new player walking out of the burnt village does not
	-- meet four bandits with a knife and no idea (docs/qa/rung2-part4.md goal 4).
	local toFarm = WorldGen.route(world, plunderer.spawn.x, plunderer.spawn.y, farmer.spawn.x, farmer.spawn.y, true) or {}
	local function alongRoad(frac: number): WorldGen.Pos
		return toFarm[math.max(1, math.floor(#toFarm * frac))] or farmer.spawn
	end
	makeGroup("band", "band", 3, plunderer.spawn, alongRoad(0.18),
		{ { kind = "bandit" }, { kind = "bandit" }, { kind = "bandit" }, { kind = "bandit" } },
		{ 60, 150 })
	S.groups.band.lateTarget = alongRoad(0.55)
	S.groups.band.speed = 2
	S.groups.squad.speed = 2
end

function Bands.pos(g): WorldGen.Pos
	if g.materialised and g.leader and S.entities[g.leader] then
		local l = S.entities[g.leader]
		return { x = l.x, y = l.y }
	end
	return g.route[math.clamp(g.pos, 1, #g.route)]
end

--- How much a group is hauling.
function Bands.carryTotal(g): number
	local n = 0
	for _, v in pairs(g.carry) do n += v end
	return n
end

--- What the pure group tick reports, for the server log.
local function logGroupEvents(events)
	for _, ev in ipairs(events) do
		if ev.kind == "deposit" then
			print(("[Sim] the %s %s came home with %s"):format(Map.village(S.tribes[ev.tribe].villageId).name, ev.group, ev.text))
		elseif ev.kind == "retarget" then
			print("[Sim] the " .. ev.group .. " has moved down the road")
		end
	end
end

--- Turn around at the end of the route; home with the kill, the hides and meat go into the village's stock
--- (Danzo, 2026-09-18: "they dont seem like they hunt and return back with theyre materials"). The rule itself is
--- Tick.groupTurn, shared with the abstract tick and catch-up.
function Bands.turn(g)
	local events = {}
	Tick.groupTurn(S, g, Calendar.now(), events)
	logGroupEvents(events)
end

local function materialise(g)
	local p = Bands.pos(g)
	local t = S.tribes[g.tribe]
	local first = true
	for _, m in ipairs(g.members) do
		local pos = nearestFree(p.x, p.y, 4)
		if pos then
			local person = m.person and S.people.people[m.person]
			local fname, lname
			if person then fname, lname = person.first, person.last else fname, lname = Names.person(rng, rng:pick(t.surnames)) end
			local label = if m.role == "caravan_master" then fname .. " " .. lname elseif m.kind == "bandit" then "bandit" elseif m.kind == "hunter" then fname .. " " .. lname else "caravan guard"
			local e = newEntity(m.kind, pos.x, pos.y, { tribe = g.tribe, group = g.id, role = m.role or m.kind, name = fname .. " " .. lname, label = label, sprite = if m.kind == "bandit" then "bandit" else nil })
			e.first, e.last = fname, lname
			if person then e.person, person.entity = person.id, e.id end
			g.entities[e.id] = true
			if first then g.leader = e.id first = false end
		end
	end
	g.materialised = true
	g.trail = {}
end

function Bands.collapse(g)
	local p = Bands.pos(g)
	-- record where the leader got to on the route
	local bestI, bestD = g.pos, math.huge
	for i, r in ipairs(g.route) do
		local d = math.abs(r.x - p.x) + math.abs(r.y - p.y)
		if d < bestD then bestI, bestD = i, d end
	end
	g.pos = bestI
	for id in pairs(g.entities) do
		local e = S.entities[id]
		local person = e and e.person and S.people.people[e.person]
		if person then person.entity = nil end -- the person goes on; only the body is put away
		if e then removeEntity(e) end
	end
	g.entities = {}
	g.leader = nil
	g.materialised = false
end

--- Materialise/collapse decisions, then one second of abstract movement for every group without bodies (the
--- movement is Tick.groups: pure, shared with catch-up). 1 Hz.
function Bands.tick(now: number)
	for _, g in pairs(S.groups) do
		local p = Bands.pos(g)
		if g.materialised then
			-- nobody left alive is also a reason: Tick.groups skips a materialised group, so an empty one stood frozen
			if #g.members == 0 or not anyPlayerWithin(p.x, p.y, Config.COLLAPSE_RANGE) then Bands.collapse(g) end
		elseif #g.members > 0 and anyPlayerWithin(p.x, p.y, Config.MATERIALISE_RANGE) then
			materialise(g)
		end
	end
	logGroupEvents(Tick.groups(S, world, now))
end

return Bands
