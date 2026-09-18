--!nonstrict
-- The living world (DESIGN.md §4): tribes, groups, regions, calamities and players as plain tables in Sim.state,
-- ticked by the server. Nothing here is a sprite. Entities (people and animals) exist as records and are
-- replicated only to players close enough to see them; groups and wildlife collapse back into records when nobody
-- is near. Rung 3 adds persistence: everything it needs to save is under Sim.state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local Movement = require(Shared:WaitForChild("Movement"))
local Rng = require(Shared:WaitForChild("Rng"))
local Names = require(Shared:WaitForChild("Names"))
local Stats = require(Shared:WaitForChild("Stats"))
local Items = require(Shared:WaitForChild("Items"))
local Combat = require(Shared:WaitForChild("Combat"))
local Reputation = require(Shared:WaitForChild("Reputation"))
local Trade = require(Shared:WaitForChild("Trade"))
local Ecology = require(Shared:WaitForChild("Ecology"))
local Calamity = require(Shared:WaitForChild("Calamity"))
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local Families = require(Shared:WaitForChild("Families"))
local Talk = require(Shared:WaitForChild("Talk"))
local Aggression = require(Shared:WaitForChild("Aggression"))
local World = require(script.Parent:WaitForChild("World"))

local Sim = {}

local O = TileTypes.ObjectByName
local G = TileTypes.GroundByName
local HOUR = Config.DAY_SECONDS / 24

-- Wired by Server.server.lua before Sim.start().
Sim.remotes = {} :: { EntityState: RemoteEvent, Notice: RemoteEvent }
Sim.verbose = false -- Debug "verbose 1": log every hit on a player
Sim.frozen = false  -- Debug "freeze 1": NPCs stop thinking and walking (for deterministic tests)

local world: WorldGen.World
local rng: Rng.Rng
local nextId = 0

-- ---------- state ----------
Sim.state = {
	day = 1, dayStart = 0,
	tribes = {},      -- [i] = { village, tribeType, stock, population, walled, surnames, news }
	people = nil,     -- Families.Registry: everyone who was ever born in this world
	regions = nil,    -- Ecology.Regions (+ live counts)
	groups = {},      -- [id] = group record
	entities = {},    -- [id] = entity
	players = {},     -- [userId] = player state
	camps = {},       -- [userId] = { x, y, litUntil, out }
	bags = {},        -- [id] = { x, y, owner, slots, droppedAt }
	calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	lastDailyTick = 1,
}
local S = Sim.state

-- Tile occupancy: index -> entity id or player userId. People and animals never share a tile.
Sim.occupied = {} :: { [number]: any }

local function tidx(x: number, y: number): number
	return WorldGen.index(world, x, y)
end

local function cheb(x1, y1, x2, y2): number
	return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

-- ---------- clock ----------
function Sim.clock(): (number, number)
	local elapsed = os.clock() - S.dayStart
	while elapsed >= Config.DAY_SECONDS do
		elapsed -= Config.DAY_SECONDS
		S.dayStart += Config.DAY_SECONDS
		S.day += 1
	end
	return S.day, elapsed / Config.DAY_SECONDS
end

function Sim.isNight(): boolean
	local _, frac = Sim.clock()
	return DayCycle.nightAlpha(frac) > 0.25
end

-- ---------- replication ----------
local function sendState(ps, ...)
	Sim.remotes.EntityState:FireClient(ps.player, ...)
end

local function notice(ps, kind: string, data: any)
	Sim.remotes.Notice:FireClient(ps.player, kind, data)
end
Sim.notice = notice

function Sim.text(ps, msg: string, color: string?)
	notice(ps, "text", { text = msg, color = color })
end

--- Every player that currently knows entity `e`.
local function broadcastEntity(e, ...)
	for _, ps in pairs(S.players) do
		if ps.known[e.id] then sendState(ps, ...) end
	end
end

local function spawnPacket(e)
	return "spawn", e.id, e.sprite, e.x, e.y, e.facing, e.label, e.hp / e.maxHp, e.kind
end

function Sim.hud(ps)
	-- what was in hand may have been eaten, sold or dropped since it was picked up
	if ps.selected and not ps.inv.slots[ps.selected] then ps.selected = nil end
	notice(ps, "hud", {
		hp = ps.hp, maxHp = ps.maxHp, inv = Items.snapshot(ps.inv), rep = ps.rep,
		rest = ps.restText, dead = ps.dead,
		goal = ps.goal, metSurvivor = ps.metSurvivor, selected = ps.selected,
	})
end

-- ---------- the goal line (docs/qa/rung2-part4.md) ----------
-- One sentence under the clock, set here and changed by what the player does. It is stored on the player record
-- so rung 3 saves it, and it stops for good at the first calamity: a tutorial, not a quest system.
local function goalContext(): Talk.Context
	local hunter, farmer = world.villages[2], world.villages[1]
	return {
		hunterVillage = hunter.name,
		hunterDir = WorldGen.compass(hunter.cx - farmer.cx, hunter.cy - farmer.cy),
	} :: any
end

--- Move the goal line to `stage` (see Talk.GOAL_STAGES), but never backwards and never after it is done.
function Sim.setGoal(ps, stage: number)
	if ps.goalDone or stage <= ps.goalStage then return end
	ps.goalStage = stage
	ps.goal = Talk.goal(stage, goalContext())
	if not ps.goal then ps.goalDone = true end
	Sim.hud(ps)
end

--- Retire the goal line for good (the first calamity: the world has bigger news than the tutorial).
function Sim.clearGoal(ps)
	if ps.goalDone then return end
	ps.goalDone, ps.goal = true, nil
	Sim.hud(ps)
end

-- ---------- entities ----------
local function newEntity(kind: string, x: number, y: number, opts): any
	nextId += 1
	local k = Stats.get(kind)
	local e = {
		id = "e" .. nextId, kind = kind, sprite = opts.sprite or k.sprite, label = opts.label,
		x = x, y = y, facing = opts.facing or "down", hp = k.hp, maxHp = k.hp, atk = k.atk, def = k.def, speed = k.speed,
		name = opts.name, tribe = opts.tribe, group = opts.group, role = opts.role or kind,
		home = { x = x, y = y }, radius = opts.radius or 3,
		state = "idle", nextThink = os.clock() + rng:float(), nextStepAt = 0, path = nil, pathI = 1,
		target = nil, windupAt = nil, cooldownUntil = 0, invulnUntil = 0, fleeUntil = 0,
		region = opts.region, species = opts.species,
		lastPathAt = 0,
	}
	S.entities[e.id] = e
	Sim.occupied[tidx(x, y)] = e.id
	return e
end

local function removeEntity(e, reason: string?)
	if not S.entities[e.id] then return end
	S.entities[e.id] = nil
	if Sim.occupied[tidx(e.x, e.y)] == e.id then Sim.occupied[tidx(e.x, e.y)] = nil end
	for _, ps in pairs(S.players) do
		if ps.known[e.id] then
			ps.known[e.id] = nil
			sendState(ps, if reason == "die" then "die" else "leave", e.id)
		end
	end
	if e.region and e.species then
		local r = S.regions.list[e.region]
		r.live[e.species] = math.max(0, r.live[e.species] - 1)
	end
	if e.group then
		local g = S.groups[e.group]
		if g then
			g.entities[e.id] = nil
			if g.leader == e.id then g.leader = nil end
		end
	end
end
Sim.removeEntity = removeEntity

--- Move an entity one tile (already validated). Occupancy and replication.
local function placeEntity(e, x: number, y: number, facing: string?)
	if Sim.occupied[tidx(e.x, e.y)] == e.id then Sim.occupied[tidx(e.x, e.y)] = nil end
	e.x, e.y = x, y
	if facing then e.facing = facing end
	Sim.occupied[tidx(x, y)] = e.id
	broadcastEntity(e, "move", e.id, x, y, e.facing)
end

local function faceEntity(e, facing: string)
	if e.facing ~= facing then
		e.facing = facing
		broadcastEntity(e, "move", e.id, e.x, e.y, facing)
	end
end
Sim.faceEntity = faceEntity

local function freeTile(x: number, y: number): boolean
	return WorldGen.walkable(world, x, y) and Sim.occupied[tidx(x, y)] == nil
end

--- Nearest free tile around (x, y).
local function nearestFree(x: number, y: number, maxR: number?): WorldGen.Pos?
	for r = 0, maxR or 4 do
		for dy = -r, r do
			for dx = -r, r do
				if math.max(math.abs(dx), math.abs(dy)) == r and freeTile(x + dx, y + dy) then return { x = x + dx, y = y + dy } end
			end
		end
	end
	return nil
end

local function setPath(e, path)
	e.path, e.pathI = path, 1
end

-- Fights end in flight (DESIGN.md §11): the fraction of health at which a fighter breaks and runs for home.
local BREAK = { bandit = 0.4, boar = 0.3, wolf = 0.3, guard = 0.25, caravan_guard = 0.25, hunter = 0.2 }

local function pathTo(e, tx: number, ty: number, maxNodes: number?, roads: boolean?): boolean
	if e.x == tx and e.y == ty then e.path = nil return true end
	local now = os.clock()
	e.lastPathAt = now
	local p = WorldGen.route(world, e.x, e.y, tx, ty, roads, maxNodes or 400)
	if not p then e.path = nil return false end
	setPath(e, p)
	return true
end

--- Take the next step of the entity's path if it is due. Blocked steps wait (and re-path after a moment).
local function followPath(e, now: number)
	if not e.path or now < e.nextStepAt or e.speed <= 0 then return end
	local step = e.path[e.pathI]
	if not step then e.path = nil return end
	if not Movement.canStep(world, e.x, e.y, step.x, step.y, Sim.occupied) then
		-- someone is in the way: wait a beat, then give up on this path so the thinker re-plans
		e.nextStepAt = now + 0.3
		e.blockedCount = (e.blockedCount or 0) + 1
		faceEntity(e, Combat.dirTo(e.x, e.y, step.x, step.y))
		if e.blockedCount > 3 then e.path = nil e.blockedCount = 0 end
		return
	end
	e.blockedCount = 0
	local facing = Combat.dirTo(e.x, e.y, step.x, step.y)
	placeEntity(e, step.x, step.y, facing)
	e.nextStepAt = now + Movement.stepTime(world, step.x, step.y) / e.speed
	e.pathI += 1
	if e.pathI > #e.path then e.path = nil end
end

-- ---------- players ----------
local function nearestPlayer(x: number, y: number, range: number, filter: ((any) -> boolean)?)
	local best, bestD = nil, math.huge
	for _, ps in pairs(S.players) do
		if not ps.dead then
			local d = cheb(x, y, ps.x, ps.y)
			if d <= range and d < bestD and (not filter or filter(ps)) then best, bestD = ps, d end
		end
	end
	return best, bestD
end

local function anyPlayerWithin(x: number, y: number, range: number): boolean
	for _, ps in pairs(S.players) do
		if cheb(x, y, ps.x, ps.y) <= range then return true end
	end
	return false
end

function Sim.tribeOf(e): string?
	if e.tribe then return S.tribes[e.tribe].tribeType end
	return nil
end

-- ---------- tribes and villagers ----------
--- A named person of a village: a record in the family registry plus a live entity.
local function spawnPerson(kind: string, x: number, y: number, tribeIdx: number, opts)
	local t = S.tribes[tribeIdx]
	local pos = nearestFree(x, y, 3)
	if not pos then return nil end
	local person = opts.person or Families.newAdult(S.people, rng, tribeIdx, t.village.name, opts.role or kind, S.day, opts.surname or rng:pick(t.surnames), opts.sex)
	local o = { tribe = tribeIdx, radius = opts.radius, role = opts.role or person.role, sprite = opts.sprite,
		name = Families.fullName(person), label = opts.label or Families.fullName(person), facing = opts.facing }
	local e = newEntity(kind, pos.x, pos.y, o)
	e.first, e.last, e.person = person.first, person.last, person.id
	person.entity = e.id
	return e
end

--- Replace a person's entity with another kind at the same tile (pregnant, baby, grown up, a new role).
local function morph(e, kind: string, opts)
	local x, y, tribe, person = e.x, e.y, e.tribe, e.person
	local o = opts or {}
	local home, facing = e.home, e.facing
	removeEntity(e)
	local p = S.people.people[person]
	local ne = newEntity(kind, x, y, { tribe = tribe, radius = o.radius or e.radius, role = o.role or kind, sprite = o.sprite,
		name = p and Families.fullName(p) or e.name, label = o.label or (p and Families.fullName(p)) or e.label, facing = facing })
	ne.first, ne.last, ne.person = e.first, e.last, person
	ne.home = home
	ne.homeTile, ne.workTile, ne.farm = e.homeTile, e.workTile, e.farm
	if p then p.entity = ne.id end
	return ne
end

local VILLAGE_SPRITE = { farmer = "villager", hunter = "hunter", plunderer = "bandit" }

--- Give a villager somewhere to sleep and somewhere to work. Farmers get a plot of their own, everyone else a
--- spot near the stall. Before this a villager's entire day was `wanderStep` (DESIGN.md §20).
-- Where the n-th person sleeps relative to their hut door. A village can have more people than standing huts
-- (Glenworth has three burnt and one whole), and only one body fits on a tile, so they bed down around the door
-- rather than four of them walking at the same square all night.
local DOOR_SPREAD = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 1, 1 }, { -1, 1 } }

local function assignDay(e, t, n: number)
	local door = (#t.huts > 0 and t.huts[(n - 1) % #t.huts + 1]) or { x = e.x, y = e.y }
	local off = DOOR_SPREAD[(n - 1) % #DOOR_SPREAD + 1]
	local cand = { x = door.x + off[1], y = door.y + off[2] }
	e.homeTile = if WorldGen.walkable(world, cand.x, cand.y) then cand else door
	if #t.farms > 0 then
		local f = t.farms[(n - 1) % #t.farms + 1]
		e.farm = f
		e.workTile = { x = f.x, y = f.y }
	else
		local st = t.village.stall
		e.workTile = WorldGen.nearestWalkable(world, st.x + (n % 3) - 1, st.y + 1, 3) or { x = e.x, y = e.y }
	end
end

--- The huts people sleep in and the plots they work. Scanned once from the tiles, because the village record on
--- the wire only carries spawn, bed, stall and gates, and this is server business: the map format is untouched.
local function scanVillage(t, v)
	t.huts, t.farms = {}, {}
	local hutIds = { [O.hut.id] = true, [O.hut_hunter.id] = true, [O.hut_plunderer.id] = true }
	for y = v.y0, v.y1 do
		for x = v.x0, v.x1 do
			local obj, ground = WorldGen.object(world, x, y), WorldGen.ground(world, x, y)
			if hutIds[obj] then
				local door = WorldGen.nearestWalkable(world, x, y + 1, 2)
				if door then table.insert(t.huts, door) end
			elseif ground == G.farm.id and WorldGen.walkable(world, x, y) then
				table.insert(t.farms, { x = x, y = y, growth = rng:float() * 0.5, tended = 0 })
			end
		end
	end
end

local function initTribes()
	for i, v in ipairs(world.villages) do
		local t = {
			village = v, tribeType = v.tribeType, stock = Trade.newStock(v.tribeType),
			population = 30 + rng:int(0, 20), walled = #v.gates > 0,
			surnames = { Names.last(rng), Names.last(rng), Names.last(rng) },
			guard = nil, merchant = nil, survivor = nil, news = nil,
		}
		S.tribes[i] = t
		scanVillage(t, v)
		local sprite = VILLAGE_SPRITE[v.tribeType]
		-- guard just inside the first gate (or by the road for open villages)
		local gx, gy = v.spawn.x + 2, v.spawn.y - 1
		if #v.gates > 0 then
			local g = v.gates[1]
			gx, gy = g.x + (g.x - g.exit.x), g.y + (g.y - g.exit.y)
		end
		local guard = spawnPerson("guard", gx, gy, i, { radius = 1, role = "guard", label = "guard" })
		if guard then t.guard = guard.id end
		local m = spawnPerson("merchant", v.stall.x, v.stall.y + 1, i, { radius = 1, role = "merchant", label = "merchant" })
		if m then t.merchant = m.id end
		for n = 1, 4 do
			local x = rng:int(v.x0 + 1, v.x1 - 1)
			local y = rng:int(v.y0 + 1, v.y1 - 1)
			local ve = spawnPerson("villager", x, y, i, { radius = 3, role = "villager", sprite = sprite, sex = if n % 2 == 0 then "f" else "m" })
			if ve then assignDay(ve, t, n) end
		end
		t.news = nil
		Families.formCouples(S.people, i, S.day)
		if i == 1 then
			-- the survivor: a named relative, a step west of where you wake, facing the road
			local sv = spawnPerson("survivor", v.spawn.x - 1, v.spawn.y, i, { radius = 0, role = "survivor", surname = t.surnames[1], facing = "right" })
			if sv then t.survivor = sv.id end
		end
	end
end

-- ---------- groups ----------
-- A group is a record with a route (a list of tiles) and a position along it. Materialised, its members are
-- entities walking the route behind a leader; collapsed, the record's `pos` just advances.
local function forestTarget(): WorldGen.Pos
	local best, bestF = nil, -1
	for _, r in ipairs(S.regions.list) do
		if not r.village and r.forest > bestF then
			local x0, y0, x1, y1 = WorldGen.regionBounds(world, r.id)
			local c = WorldGen.nearestWalkable(world, math.floor((x0 + x1) / 2), math.floor((y0 + y1) / 2), 8)
			if c and WorldGen.reachable(world, world.spawn.x, world.spawn.y, c.x, c.y) then best, bestF = c, r.forest end
		end
	end
	return best or world.villages[2].spawn
end

local function makeGroup(id: string, kind: string, tribeIdx: number, from: WorldGen.Pos, to: WorldGen.Pos, members, pauses)
	local route = WorldGen.route(world, from.x, from.y, to.x, to.y, true) or {}
	table.insert(route, 1, { x = from.x, y = from.y })
	local g = {
		id = id, kind = kind, tribe = tribeIdx, route = route, pos = 1, dir = 1, from = { x = from.x, y = from.y },
		pauseUntil = os.clock() + rng:int(20, 60), pauses = pauses, speed = 1.5, acc = 0,
		members = members, entities = {}, leader = nil, trail = {}, materialised = false,
		target = nil, aggroUntil = 0, lastSeen = nil,
	}
	S.groups[id] = g
	return g
end

local function initGroups()
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

function Sim.groupPos(g): WorldGen.Pos
	if g.materialised and g.leader and S.entities[g.leader] then
		local l = S.entities[g.leader]
		return { x = l.x, y = l.y }
	end
	return g.route[math.clamp(g.pos, 1, #g.route)]
end

local function groupAtEnd(g): boolean
	return (g.dir == 1 and g.pos >= #g.route) or (g.dir == -1 and g.pos <= 1)
end

local function groupTurn(g)
	g.dir = -g.dir
	g.pauseUntil = os.clock() + (if g.dir == 1 then g.pauses[1] else g.pauses[2])
end

local function materialise(g)
	local p = Sim.groupPos(g)
	local t = S.tribes[g.tribe]
	local first = true
	for _, m in ipairs(g.members) do
		local pos = nearestFree(p.x, p.y, 4)
		if pos then
			local fname, lname = Names.person(rng, rng:pick(t.surnames))
			local label = if m.role == "caravan_master" then fname .. " " .. lname elseif m.kind == "bandit" then "bandit" elseif m.kind == "hunter" then fname .. " " .. lname else "caravan guard"
			local e = newEntity(m.kind, pos.x, pos.y, { tribe = g.tribe, group = g.id, role = m.role or m.kind, name = fname .. " " .. lname, label = label, sprite = if m.kind == "bandit" then "bandit" else nil })
			e.first, e.last = fname, lname
			g.entities[e.id] = true
			if first then g.leader = e.id first = false end
		end
	end
	g.materialised = true
	g.trail = {}
end

local function collapse(g)
	local p = Sim.groupPos(g)
	-- record where the leader got to on the route
	local bestI, bestD = g.pos, math.huge
	for i, r in ipairs(g.route) do
		local d = math.abs(r.x - p.x) + math.abs(r.y - p.y)
		if d < bestD then bestI, bestD = i, d end
	end
	g.pos = bestI
	for id in pairs(g.entities) do
		local e = S.entities[id]
		if e then removeEntity(e) end
	end
	g.entities = {}
	g.leader = nil
	g.materialised = false
end

--- The goal line follows the player around: walking into the hunter village is what finishes the road goal, and
--- from day 6 the only thing being asked is that they are somewhere safe when the week turns.
local function tickGoals()
	local day = Sim.clock()
	for _, ps in pairs(S.players) do
		if not ps.goalDone and not ps.dead then
			if ps.goalStage == 2 and WorldGen.villageAt(world, ps.x, ps.y, 1) == world.villages[2] then
				Sim.setGoal(ps, 3)
			end
			if day >= Config.WEEK_DAYS - 1 then Sim.setGoal(ps, 5) end
		end
	end
end

--- Abstract movement for collapsed groups and materialise/collapse decisions. 1 Hz.
local function tickGroups(now: number)
	local floodOn = S.calamity.active and S.calamity.kind == "flood"
	for _, g in pairs(S.groups) do
		local p = Sim.groupPos(g)
		local near = anyPlayerWithin(p.x, p.y, Config.MATERIALISE_RANGE)
		if g.materialised then
			if not anyPlayerWithin(p.x, p.y, Config.COLLAPSE_RANGE) then collapse(g) end
		elseif near and #g.members > 0 then
			materialise(g)
		end
		if g.lateTarget and S.day > Config.GRACE_DAYS and not g.materialised then
			-- grace is over: the band takes up its real ambush, part way down the road to the farmers
			local from, to = g.from, g.lateTarget
			local route = WorldGen.route(world, from.x, from.y, to.x, to.y, true)
			if route then
				table.insert(route, 1, { x = from.x, y = from.y })
				g.route, g.pos, g.dir, g.acc = route, 1, 1, 0
				g.pauseUntil = now + 5
				print("[Sim] the band has moved down the road")
			end
			g.lateTarget = nil
		end
		if not g.materialised and now >= g.pauseUntil and not (floodOn and g.kind == "caravan") then
			-- whole tiles only: `pos` indexes the route
			g.acc += g.speed
			local steps = math.floor(g.acc)
			g.acc -= steps
			g.pos = math.clamp(g.pos + g.dir * steps, 1, #g.route)
			if groupAtEnd(g) then groupTurn(g) end
		end
	end
end

-- ---------- wildlife ----------
local function regionCenterNear(ps): { number }
	local r = WorldGen.regionOf(world, ps.x, ps.y)
	local rg = S.regions
	local reg = rg.list[r]
	local out = {}
	for dy = -1, 1 do
		for dx = -1, 1 do
			local c, w = reg.col + dx, reg.row + dy
			if c >= 1 and c <= rg.cols and w >= 1 and w <= rg.rows then table.insert(out, (w - 1) * rg.cols + c) end
		end
	end
	return out
end

local function spawnAnimal(species: string, r, ps): boolean
	local x0, y0, x1, y1 = WorldGen.regionBounds(world, r.id)
	for _ = 1, 8 do
		local x, y = rng:int(x0, x1), rng:int(y0, y1)
		if freeTile(x, y) and not WorldGen.villageAt(world, x, y, 2) and cheb(x, y, ps.x, ps.y) >= 7 and cheb(x, y, ps.x, ps.y) <= Config.MATERIALISE_RANGE then
			local ok = true
			for _, o in pairs(S.players) do
				if cheb(x, y, o.x, o.y) < 6 then ok = false break end
			end
			if ok then
				newEntity(species, x, y, { region = r.id, species = species, radius = 4, facing = if rng:chance(0.5) then "left" else "right" })
				r.live[species] += 1
				return true
			end
		end
	end
	return false
end

local function tickWildlife()
	local night = Sim.isNight()
	-- DESIGN.md §4 caps the sprites, and nothing enforced it: a beast tide would happily materialise the whole
	-- north around one player. Over the cap, the rest of the region stays a number, which is what §4 says to do.
	local animals = 0
	for _, e in pairs(S.entities) do
		if e.species then animals += 1 end
	end
	for _, ps in pairs(S.players) do
		if not ps.dead and animals < Config.MAX_ANIMALS then
			for _, rid in ipairs(regionCenterNear(ps)) do
				local r = S.regions.list[rid]
				for _, sp in ipairs(Ecology.SPECIES) do
					local want = math.min(r[sp], 3)
					if sp == "wolf" and not (night or r.tide) then want = 0 end
					if r.live[sp] < want and animals < Config.MAX_ANIMALS then
						if spawnAnimal(sp, r, ps) then animals += 1 end
					end
				end
			end
		end
	end
	-- fold back animals nobody is near, and wolves at daybreak
	for _, e in pairs(S.entities) do
		if e.species then
			local far = not anyPlayerWithin(e.x, e.y, Config.COLLAPSE_RANGE)
			local dayWolf = e.species == "wolf" and not night and not S.regions.list[e.region].tide and not anyPlayerWithin(e.x, e.y, 9)
			if far or dayWolf then removeEntity(e) end
		end
	end
end

-- ---------- combat ----------
local function lootTo(ps, loot)
	local got = {}
	for item, n in pairs(loot) do
		if item == "coin" then
			ps.inv.coin += n
			table.insert(got, n .. " coin")
		else
			local added = Items.add(ps.inv, item, n)
			if added > 0 then table.insert(got, added .. " " .. Items.def(item).label) end
			if added < n then Sim.text(ps, "No room for the rest.", "warn") end
		end
	end
	if #got > 0 then Sim.text(ps, "You take " .. table.concat(got, ", ") .. ".") end
end

local function applyRep(ps, deltas)
	local changed = false
	for tribe, d in pairs(deltas) do
		local before = ps.rep[tribe]
		Reputation.apply(ps.rep, { [tribe] = d })
		if Reputation.word(before) ~= Reputation.word(ps.rep[tribe]) then
			changed = true
			Sim.text(ps, ("The %ss now think of you as %s."):format(tribe, Reputation.word(ps.rep[tribe])), "rep")
		end
	end
	return changed
end

local function killEntity(e, killer, ctx, byEntity)
	if killer then
		lootTo(killer, Combat.loot(e.kind, rng))
		applyRep(killer, Reputation.deltas("kill", e.kind, Sim.tribeOf(e), ctx))
		if e.tribe and not e.species then
			S.tribes[e.tribe].population = math.max(0, S.tribes[e.tribe].population - 1)
		end
		Sim.hud(killer)
	end
	-- the family tree keeps the dead, and a role passes to a relative
	if e.person then
		local p = S.people.people[e.person]
		local by = if killer then killer.player.Name
			elseif byEntity then (byEntity.name or Stats.get(byEntity.kind).label)
			else "the wild"
		Families.die(S.people, e.person, S.day, "killed", by)
		local t = e.tribe and S.tribes[e.tribe]
		if p and t and (e.role == "guard" or e.role == "merchant") then
			local heir = Families.successor(S.people, p)
			local he = heir and heir.entity and S.entities[heir.entity]
			if heir and he then
				heir.role = e.role
				local ne = morph(he, e.role, { role = e.role, label = e.role, radius = 1 })
				ne.home = { x = e.home.x, y = e.home.y }
				if e.role == "guard" then t.guard = ne.id else t.merchant = ne.id end
				t.news = ("%s %s has taken up the %s's post."):format(heir.first, heir.last, tostring(e.role))
			end
		end
	end
	if e.region and e.species then
		local r = S.regions.list[e.region]
		r[e.species] = math.max(0, r[e.species] - 1)
		-- a predator's meal is booked here so Ecology's daily tick does not charge for the same deer twice
		if byEntity and byEntity.species == "wolf" then Ecology.noteKill(r, e.species) end
	end
	-- DESIGN.md §5: plunderers live off what they take. A kill by a bandit moves goods from the victim's tribe
	-- into theirs, which is what makes a raid cost the farmers something real.
	if byEntity and byEntity.kind == "bandit" and byEntity.tribe and e.tribe and e.tribe ~= byEntity.tribe then
		local from, to = S.tribes[e.tribe], S.tribes[byEntity.tribe]
		for _, good in ipairs(Items.GOODS) do
			local take = math.min(from.stock[good] or 0, 2)
			if take > 0 then
				from.stock[good] -= take
				to.stock[good] = (to.stock[good] or 0) + take
			end
		end
	end
	if e.group then
		local g = S.groups[e.group]
		if g then
			-- the record loses a member; the tribe replaces them at home after a while
			table.remove(g.members, #g.members)
			g.replenishAt = os.clock() + Config.DAY_SECONDS
		end
	end
	local t = e.tribe and S.tribes[e.tribe]
	if t then
		if t.guard == e.id then t.guard = nil end
		if t.merchant == e.id then t.merchant = nil end
		if t.survivor == e.id then t.survivor = nil end
	end
	removeEntity(e, "die")
end

--- The story of a fight as reputation sees it: did this creature attack the player first, is it running.
--- A creature the player struck first is never the aggressor toward that player, however hard it fights back.
local function fightContext(e, ps)
	local uid = ps and ps.player.UserId
	local aggressor = uid ~= nil and e.attacked ~= nil and e.attacked[uid] == true and not (e.provokedBy and e.provokedBy[uid])
	return { aggressor = aggressor, fleeing = e.state == "flee" and e.broken or false }
end

--- Mark that a creature went for a player on its own (not in return for a blow).
local function markAggression(e, uid)
	if e.provokedBy and e.provokedBy[uid] then return end
	e.attacked = e.attacked or {}
	e.attacked[uid] = true
end
Sim.markAggression = markAggression

--- Damage to an entity from (ax, ay). Flash, knockback, death. Fighters break and run at their break point.
local function hitEntity(e, dmg: number, ax: number, ay: number, attacker, byEntity)
	local now = os.clock()
	if now < e.invulnUntil then return end
	local ctx = fightContext(e, attacker)
	if attacker and not (e.attacked and e.attacked[attacker.player.UserId]) then
		e.provokedBy = e.provokedBy or {}
		e.provokedBy[attacker.player.UserId] = true
	end
	e.hp -= dmg
	e.invulnUntil = now + Config.HIT_INVULN
	e.path = nil
	broadcastEntity(e, "hit", e.id, math.max(0, e.hp) / e.maxHp)
	if e.hp <= 0 then
		killEntity(e, attacker, ctx, byEntity)
		return
	end
	local kx, ky = Combat.knockbackTile(ax, ay, e.x, e.y)
	if freeTile(kx, ky) then placeEntity(e, kx, ky) end
	-- react
	local k = Stats.get(e.kind)
	local breakAt = BREAK[e.kind]
	if k.flees or e.broken or (breakAt and e.hp / e.maxHp <= breakAt) then
		e.state, e.fleeUntil = "flee", now + 30
		e.threat = { x = ax, y = ay }
		e.windupAt, e.target = nil, nil
		if breakAt or e.broken then e.broken = true end
		if attacker then e.beatenBy = attacker.player.UserId end
	elseif attacker then
		e.state, e.target, e.aggroUntil = "chase", attacker.player.UserId, now + 12
	elseif byEntity and S.entities[byEntity.id] then
		-- struck by another creature. Before this the whole branch was `elseif attacker`, so anything hit by an
		-- NPC simply stood there: a boar took a hunter's spear without ever charging him (DESIGN.md §20).
		e.state, e.npcTarget, e.target = "hunt", byEntity.id, nil
	end
	if attacker and e.tribe and not e.species then
		applyRep(attacker, Reputation.deltas("hit", e.kind, Sim.tribeOf(e), ctx))
		-- the village guard takes notice
		local t = S.tribes[e.tribe]
		local guard = t.guard and S.entities[t.guard]
		if guard and guard ~= e and not guard.broken and cheb(guard.x, guard.y, e.x, e.y) <= 8 then
			guard.state, guard.target, guard.aggroUntil = "chase", attacker.player.UserId, now + 15
			markAggression(guard, attacker.player.UserId) -- the guard comes at you for what you did: that is still their move
		end
	end
	if e.group then
		local g = S.groups[e.group]
		if g and attacker then g.target, g.aggroUntil = attacker.player.UserId, now + 15 end
	end
end

function Sim.playerRestPoint(ps): (WorldGen.Pos, string?)
	local why = nil
	if ps.rest.kind == "camp" then
		local c = S.camps[ps.player.UserId]
		if c then
			local p = WorldGen.nearestWalkable(world, c.x, c.y, 2)
			if p then return p, nil end
		end
		why = "Your camp is gone."
		ps.rest = { kind = "village", village = 1 }
	end
	local v = world.villages[ps.rest.village or 1]
	local t = S.tribes[ps.rest.village or 1]
	if not Reputation.allowsRest(ps.rep[t.tribeType]) then
		why = ("%s will not have you any more."):format(v.name)
		for i, tt in ipairs(S.tribes) do
			if Reputation.allowsRest(ps.rep[tt.tribeType]) then
				ps.rest = { kind = "village", village = i }
				v = world.villages[i]
				break
			end
		end
	end
	local p = WorldGen.nearestWalkable(world, v.bed.x, v.bed.y, 3) or world.spawn
	return p, why
end

function Sim.restText(ps): string
	if ps.rest.kind == "camp" then return "your camp" end
	return world.villages[ps.rest.village or 1].name
end

local function dropBag(ps)
	local slots = Items.dropAll(ps.inv)
	if #slots == 0 then return end
	local pos = nearestFree(ps.x, ps.y, 2) or { x = ps.x, y = ps.y }
	if WorldGen.object(world, pos.x, pos.y) ~= 0 then return end
	nextId += 1
	local id = "b" .. nextId
	S.bags[id] = { id = id, x = pos.x, y = pos.y, owner = ps.player.UserId, slots = slots, droppedAt = os.clock() }
	world.object[tidx(pos.x, pos.y)] = O.bag.id
	sendState(ps, "object", pos.x, pos.y, O.bag.id)
end

local function killPlayer(ps, killer)
	if ps.dead then return end
	print(("[Sim] %s died to %s"):format(ps.player.Name, if killer then killer.kind .. " " .. tostring(killer.id) else "nothing"))
	ps.dead = true
	ps.hp = 0
	local tribe = killer and Sim.tribeOf(killer)
	if tribe then applyRep(ps, Reputation.deltas("died_to", killer.kind, tribe)) end
	dropBag(ps)
	local by = if killer then (killer.label or killer.kind) else "something"
	notice(ps, "died", { by = by, seconds = Config.RESPAWN_SECONDS, at = Sim.restText(ps) })
	Sim.hud(ps)
	for _, o in pairs(S.players) do
		if o ~= ps then sendState(o, "die", ps.player.UserId) end
	end
	task.delay(Config.RESPAWN_SECONDS, function()
		if not S.players[ps.player.UserId] then return end
		local p, why = Sim.playerRestPoint(ps)
		local free = nearestFree(p.x, p.y, 3) or p
		ps.dead = false
		ps.hp = ps.maxHp
		ps.inv = Items.new()
		Items.add(ps.inv, "knife", 1)
		ps.restText = Sim.restText(ps)
		Sim.occupied[tidx(ps.x, ps.y)] = nil
		ps.x, ps.y, ps.facing = free.x, free.y, "down"
		Sim.occupied[tidx(ps.x, ps.y)] = ps.player.UserId
		ps.snap(ps)
		if why then Sim.text(ps, why, "warn") end
		Sim.text(ps, "You wake at " .. Sim.restText(ps) .. ". Your bag is where you fell.")
		for _, o in pairs(S.players) do
			if o ~= ps then sendState(o, "spawn", ps.player.UserId, "player", ps.x, ps.y, ps.facing, ps.player.DisplayName, 1, "player") end
		end
		Sim.hud(ps)
	end)
end

--- An NPC's swing lands on a player.
local function hitPlayer(ps, e)
	local now = os.clock()
	if ps.dead or now < ps.invulnUntil then return end
	local dmg = Combat.damage(e.atk, 0)
	ps.hp -= dmg
	ps.invulnUntil = now + Config.HIT_INVULN
	if Sim.verbose then print(("[Sim] %s hit by %s (%s) for %d -> hp %d at %.2f"):format(ps.player.Name, e.kind, e.id, dmg, ps.hp, now)) end
	for _, o in pairs(S.players) do sendState(o, "hit", ps.player.UserId, math.max(0, ps.hp) / ps.maxHp) end
	if ps.hp <= 0 then
		killPlayer(ps, e)
		return
	end
	local kx, ky = Combat.knockbackTile(e.x, e.y, ps.x, ps.y)
	if freeTile(kx, ky) then
		Sim.occupied[tidx(ps.x, ps.y)] = nil
		ps.x, ps.y = kx, ky
		Sim.occupied[tidx(kx, ky)] = ps.player.UserId
		ps.snap(ps)
		for _, o in pairs(S.players) do
			if o ~= ps then sendState(o, "move", ps.player.UserId, kx, ky, ps.facing) end
		end
	end
	Sim.hud(ps)
end

--- The player swings at the tile they face.
function Sim.attack(ps, facing: string)
	local now = os.clock()
	if ps.dead or now < ps.lastAttack + Config.ATTACK_COOLDOWN then return end
	ps.lastAttack = now
	ps.facing = facing
	local tx, ty = Combat.facingTile(ps.x, ps.y, facing)
	for _, o in pairs(S.players) do
		if o ~= ps then sendState(o, "attack", ps.player.UserId, facing) end
	end
	local id = Sim.occupied[tidx(tx, ty)]
	local e = id and S.entities[id]
	if not e then return end
	local dmg = Combat.damage(Stats.get("player").atk + Items.weaponAtk(ps.inv), e.def)
	hitEntity(e, dmg, ps.x, ps.y, ps)
end

-- ---------- thinking ----------
local function wanderStep(e, now: number)
	if e.radius <= 0 then return end
	if rng:chance(0.5) then return end
	local tx, ty = e.home.x + rng:int(-e.radius, e.radius), e.home.y + rng:int(-e.radius, e.radius)
	if e.tribe and not e.group and not e.species then
		local v = S.tribes[e.tribe].village
		tx, ty = math.clamp(tx, v.x0 + 1, v.x1 - 1), math.clamp(ty, v.y0 + 1, v.y1 - 1)
	end
	if freeTile(tx, ty) then pathTo(e, tx, ty, 120) end
end

--- Where a broken fighter runs to: its group's leader, its village, or (animals) away from the threat.
local function homeTile(e): WorldGen.Pos?
	if e.group then
		local g = S.groups[e.group]
		local leader = g and g.leader and S.entities[g.leader]
		if leader and leader ~= e then return { x = leader.x, y = leader.y } end
		if g then return Sim.groupPos(g) end
	end
	if e.tribe and not e.species then return S.tribes[e.tribe].village.spawn end
	return nil
end

--- A beaten fighter that got away: the player who beat it earns mercy, once.
local function grantMercy(e)
	local uid = e.beatenBy
	if not uid or e.mercyGiven then return end
	local ps = S.players[uid]
	e.mercyGiven = true
	if ps and e.tribe and not e.species then
		applyRep(ps, Reputation.deltas("mercy", e.kind, Sim.tribeOf(e)))
		Sim.text(ps, ("%s got away. Word of that will travel."):format(e.label or e.kind), "rep")
		Sim.hud(ps)
	end
end

local function fleeStep(e)
	local t = e.threat
	if not t then return end
	local best, bestD = nil, cheb(e.x, e.y, t.x, t.y)
	for _, d in pairs(Movement.DIRS) do
		local nx, ny = e.x + d[1], e.y + d[2]
		if freeTile(nx, ny) then
			local dd = math.abs(nx - t.x) + math.abs(ny - t.y)
			if dd > bestD then best, bestD = { x = nx, y = ny }, dd end
		end
	end
	if best then setPath(e, { best }) end
end

--- Bandits do not follow anyone in under a roof: a new player who runs for a village is safe there (goal 4 of
--- docs/qa/rung2-part4.md). The footprint plus one tile, so standing in a gateway counts.
local function inVillage(x: number, y: number): boolean
	return WorldGen.villageAt(world, x, y, 1) ~= nil
end

local function litCampNear(x: number, y: number): boolean
	for _, c in pairs(S.camps) do
		if not c.out and cheb(x, y, c.x, c.y) <= Config.CAMPFIRE_RADIUS then return true end
	end
	return false
end

--- Chase state: close on the target player and swing when adjacent, with a telegraph first.
local function chaseStep(e, now: number)
	local ps = S.players[e.target]
	if ps then markAggression(e, e.target) end
	if not ps or ps.dead or now > e.aggroUntil or cheb(e.x, e.y, ps.x, ps.y) > 14 then
		-- the band lost you: they respect what they could not catch
		if ps and not ps.dead and e.kind == "bandit" then
			e.escapeGiven = e.escapeGiven or {}
			if not e.escapeGiven[e.target] then
				e.escapeGiven[e.target] = true
				applyRep(ps, Reputation.deltas("escape", e.kind, Sim.tribeOf(e)))
				Sim.hud(ps)
			end
		end
		e.state, e.target, e.windupAt = "idle", nil, nil
		return
	end
	if e.species == "wolf" and litCampNear(ps.x, ps.y) then
		e.state, e.target = "idle", nil
		return
	end
	if e.kind == "bandit" and inVillage(ps.x, ps.y) then
		e.state, e.target, e.windupAt = "idle", nil, nil
		return
	end
	if Combat.adjacent(e.x, e.y, ps.x, ps.y) then
		e.path = nil
		faceEntity(e, Combat.dirTo(e.x, e.y, ps.x, ps.y))
		if e.windupAt then
			if now >= e.windupAt then
				e.windupAt = nil
				e.cooldownUntil = now + 1.0
				broadcastEntity(e, "attack", e.id, e.facing)
				hitPlayer(ps, e)
			end
		elseif now >= e.cooldownUntil then
			e.windupAt = now + Config.TELEGRAPH
			broadcastEntity(e, "telegraph", e.id)
		end
	else
		e.windupAt = nil
		if not e.path or now - e.lastPathAt > 1 then
			-- step next to the player, not onto them
			local best, bestD = nil, math.huge
			for _, d in pairs(Movement.DIRS) do
				local nx, ny = ps.x + d[1], ps.y + d[2]
				if freeTile(nx, ny) or (nx == e.x and ny == e.y) then
					local dd = math.abs(nx - e.x) + math.abs(ny - e.y)
					if dd < bestD then best, bestD = { x = nx, y = ny }, dd end
				end
			end
			if best then pathTo(e, best.x, best.y, 300) end
		end
	end
end

--- Should this entity go for a player? Hostility depends on kind and the player's standing with its tribe.
--- `npcD` is how far away the prey it has already picked is: the player has to be nearer than that to win.
local function pickTarget(e, now: number, npcD: number?)
	local k = Stats.get(e.kind)
	local range = 0
	local function wants(ps): boolean
		if e.species == "wolf" then return not litCampNear(ps.x, ps.y) end
		if e.kind == "bandit" then return ps.rep.plunderer < -10 and not inVillage(ps.x, ps.y) end
		if e.kind == "guard" or e.kind == "caravan_guard" or e.kind == "hunter" then return Reputation.hostile(ps.rep[Sim.tribeOf(e)]) end
		return false
	end
	if e.species == "wolf" then range = 7 elseif e.kind == "bandit" then range = 6 elseif e.kind == "guard" then range = 5 elseif e.kind == "hunter" or e.kind == "caravan_guard" then range = 4 end
	if e.species == "boar" then range = 0 end -- boar only charge when hit
	if range == 0 and not k.hostile then return end
	local ps, d = nearestPlayer(e.x, e.y, range, wants)
	if ps and d < (npcD or math.huge) then
		e.state, e.target, e.npcTarget, e.aggroUntil = "chase", ps.player.UserId, nil, now + 10
		markAggression(e, ps.player.UserId)
		if e.escapeGiven then e.escapeGiven[ps.player.UserId] = nil end
	end
end

--- Describe an entity the way Aggression sees it.
local function actorOf(e): Aggression.Actor
	return { kind = e.kind, species = e.species, tribeType = Sim.tribeOf(e),
		inVillage = inVillage(e.x, e.y), flees = Stats.get(e.kind).flees }
end

--- Look for something to fight that is not a player. The rule itself lives in shared/Aggression.lua.
local function pickNpcTarget(e, now: number)
	local range = Aggression.RANGE[e.kind]
	if e.broken or not range then return end
	local me = actorOf(e)
	local tide = (e.region ~= nil and S.regions.list[e.region].tide) or false
	local best, bestD = nil, range + 1
	for _, o in pairs(S.entities) do
		-- the distance test comes first on purpose: it is cheap, and it keeps actorOf off the hot path
		if o ~= e and now >= o.invulnUntil and not o.broken then
			local d = cheb(e.x, e.y, o.x, o.y)
			if d < bestD and Aggression.wants(me, actorOf(o), tide) then best, bestD = o, d end
		end
	end
	if best then e.npcTarget, e.state = best.id, "hunt" end
end

--- The nearest thing that eats this one, within `range`.
local function nearestPredator(e, range: number)
	local best, bestD = nil, range + 1
	for _, o in pairs(S.entities) do
		if o ~= e and not o.broken and (o.species == "wolf" or o.kind == "hunter") then
			local d = cheb(e.x, e.y, o.x, o.y)
			if d < bestD then best, bestD = o, d end
		end
	end
	return best
end

local function huntStep(e, now: number)
	local o = S.entities[e.npcTarget]
	if not o or cheb(e.x, e.y, o.x, o.y) > 8 then e.state, e.npcTarget, e.windupAt = "idle", nil, nil return end
	if Combat.adjacent(e.x, e.y, o.x, o.y) then
		e.path = nil
		faceEntity(e, Combat.dirTo(e.x, e.y, o.x, o.y))
		if e.windupAt then
			if now >= e.windupAt then
				e.windupAt = nil
				e.cooldownUntil = now + 1.0
				broadcastEntity(e, "attack", e.id, e.facing)
				hitEntity(o, Combat.damage(e.atk, o.def), e.x, e.y, nil, e)
			end
		elseif now >= e.cooldownUntil then
			e.windupAt = now + Config.TELEGRAPH
			broadcastEntity(e, "telegraph", e.id)
		end
	elseif not e.path or now - e.lastPathAt > 1 then
		local best, bestD = nil, math.huge
		for _, d in pairs(Movement.DIRS) do
			local nx, ny = o.x + d[1], o.y + d[2]
			if freeTile(nx, ny) then
				local dd = math.abs(nx - e.x) + math.abs(ny - e.y)
				if dd < bestD then best, bestD = { x = nx, y = ny }, dd end
			end
		end
		if best then pathTo(e, best.x, best.y, 200) end
	end
end

--- Group members: the leader walks the route; the others follow the leader's trail.
local function groupStep(e, g, now: number)
	if g.kind == "band" and g.target and S.players[g.target] and inVillage(S.players[g.target].x, S.players[g.target].y) then
		g.target, g.aggroUntil = nil, 0
	end
	if g.target and now < g.aggroUntil and S.players[g.target] and not S.players[g.target].dead and not e.broken then
		e.state, e.target, e.aggroUntil = "chase", g.target, g.aggroUntil
		markAggression(e, g.target)
		return
	end
	if e.id == g.leader then
		if now < g.pauseUntil or (S.calamity.active and S.calamity.kind == "flood" and g.kind == "caravan") then
			wanderStep(e, now)
			return
		end
		local nextI = g.pos + g.dir
		if nextI < 1 or nextI > #g.route then groupTurn(g) return end
		local r = g.route[nextI]
		if not e.path then
			if Combat.adjacent(e.x, e.y, r.x, r.y) or (e.x == r.x and e.y == r.y) then
				if freeTile(r.x, r.y) then setPath(e, { r }) g.pos = nextI
				elseif e.x == r.x and e.y == r.y then g.pos = nextI end
			else
				pathTo(e, r.x, r.y, 200, true)
				g.pos = nextI
			end
		end
	else
		local leader = S.entities[g.leader]
		if not leader then
			-- promote
			g.leader = e.id
			return
		end
		-- keep within 2 tiles of the leader
		if cheb(e.x, e.y, leader.x, leader.y) > 2 and (not e.path or now - e.lastPathAt > 1) then
			local spot = nearestFree(leader.x, leader.y, 2)
			if spot then pathTo(e, spot.x, spot.y, 200) end
		elseif not e.path and rng:chance(0.2) then
			e.home = { x = leader.x, y = leader.y }
			e.radius = 2
			wanderStep(e, now)
		end
	end
end

--- Broken: run home (or away), then rest and heal; no fighting until healed.
local function brokenStep(e, now: number)
	local t = e.threat
	local beater = e.beatenBy and S.players[e.beatenBy]
	local threatNear = (beater and not beater.dead and cheb(e.x, e.y, beater.x, beater.y) <= 2) or (t and cheb(e.x, e.y, t.x, t.y) <= 1)
	if threatNear then fleeStep(e) return end
	local home = homeTile(e)
	local safe = (beater == nil or beater.dead or cheb(e.x, e.y, beater.x, beater.y) >= 10) or (home and cheb(e.x, e.y, home.x, home.y) <= 2)
	if safe then
		grantMercy(e)
		e.state = "idle"
		e.path = nil
		return
	end
	if not e.path or now - e.lastPathAt > 2 then
		if home and not pathTo(e, home.x, home.y, 300, true) then fleeStep(e) end
		if not home then fleeStep(e) end
	end
end

-- ---------- a villager's day (DESIGN.md §20) ----------
--- Work the plot you are standing on. Growth is slow on purpose: a plot wants most of a day of somebody's
--- attention, so a village that loses its people stops feeding itself.
local function tendFarm(e, now: number)
	local f = e.farm
	if not f or now < (e.nextTendAt or 0) then return end
	e.nextTendAt = now + 5
	f.growth = math.min(1, f.growth + 0.07)
	f.tended = S.day
end

--- A wolf, or a bandit from somewhere else. Not their own tribe's hunters, who are the neighbours.
local function villagerDanger(e)
	for _, o in pairs(S.entities) do
		if (o.species == "wolf" or (o.kind == "bandit" and o.tribe ~= e.tribe)) and cheb(e.x, e.y, o.x, o.y) <= 6 then
			return o
		end
	end
	return nil
end

--- Out to the plot in the morning, home at night, and straight home when something is hunting. A villager's
--- whole day used to be `wanderStep`; this is the rest of it.
local function villagerStep(e, now: number)
	local danger = villagerDanger(e)
	local home = danger ~= nil or Sim.isNight()
	local want = if home then e.homeTile else e.workTile
	if not want then
		if not e.path then wanderStep(e, now) end
		return
	end
	-- A plot has to be stood on to be worked, but a doorway does not: only one person fits on a tile, and
	-- Glenworth has three burnt huts and one standing, so its four survivors all sleep around the same door.
	-- Insisting on the exact tile left three of them re-pathing to an occupied one for the rest of the night.
	local reach = if home or not e.farm then 1 else 0
	if cheb(e.x, e.y, want.x, want.y) <= reach then
		e.path = nil
		if not danger and not Sim.isNight() and e.farm then tendFarm(e, now) end
		return
	end
	if not e.path and now >= (e.nextRouteAt or 0) then
		e.nextRouteAt = now + (if danger then 0.6 else 2.5)
		-- nowhere to go (walled in, or the way is blocked): mill about rather than stand rigid
		if not pathTo(e, want.x, want.y, 300) then wanderStep(e, now) end
	end
end

local function think(e, now: number)
	if e.state == "flee" then
		if e.broken then brokenStep(e, now) return end
		if now > e.fleeUntil then e.state = "idle" else fleeStep(e) return end
	end
	if e.broken then
		-- healing at home, one hp an hour; a healed fighter forgets the fight
		if now >= (e.nextHeal or 0) then
			e.nextHeal = now + HOUR
			e.hp = math.min(e.maxHp, e.hp + 1)
			if e.hp >= e.maxHp * 0.7 then e.broken, e.beatenBy, e.mercyGiven = false, nil, nil end
		end
		if not e.path and rng:chance(0.3) then wanderStep(e, now) end
		return
	end
	if e.state == "chase" then chaseStep(e, now) return end
	if e.state == "hunt" then huntStep(e, now) return end
	-- Idle: look for trouble, then go about your business. Prey is chosen first and the player only takes
	-- priority if he is actually nearer. Running pickTarget first and returning on a hit is what made the
	-- player the only thing a wolf would ever go for while he was anywhere on the map (DESIGN.md §20): it
	-- would walk past a deer at arm's length to reach him.
	pickNpcTarget(e, now)
	local npcD = math.huge
	if e.state == "hunt" and e.npcTarget then
		local o = S.entities[e.npcTarget]
		if o then npcD = cheb(e.x, e.y, o.x, o.y) else e.state, e.npcTarget = "idle", nil end
	end
	pickTarget(e, now, npcD)
	if e.state == "chase" then return end
	if e.state == "hunt" then return end
	if e.species == "deer" then
		-- A deer watches for wolves and hunters, not only for the player: a deer bolting across a meadow is the
		-- ecosystem made visible, and it is the cue that something is out there.
		local threat = nil
		local ps = nearestPlayer(e.x, e.y, 4)
		if ps then threat = { x = ps.x, y = ps.y } end
		if not threat then
			local p = nearestPredator(e, 6)
			if p then threat = { x = p.x, y = p.y } end
		end
		-- A bolt, then a blown breath. A deer outruns a wolf (1.3 against 1.25) and would never be caught by
		-- anything at all without this beat -- which also means nobody could ever hunt one.
		if threat and now >= (e.nextFleeAt or 0) then
			e.nextFleeAt = now + 3.2
			e.state, e.fleeUntil, e.threat = "flee", now + 2, threat
			fleeStep(e)
			return
		end
	end
	if e.group then
		local g = S.groups[e.group]
		if g then groupStep(e, g, now) return end
	end
	if e.kind == "baby" then return end
	if e.role == "survivor" then
		-- faces whoever is standing next to them
		local ps = nearestPlayer(e.x, e.y, 1)
		if ps then faceEntity(e, Combat.dirTo(e.x, e.y, ps.x, ps.y)) end
		return
	end
	if e.role == "villager" and (e.homeTile or e.workTile) then villagerStep(e, now) return end
	if not e.path then wanderStep(e, now) end
end

-- ---------- interest management ----------
local function tickInterest()
	for _, ps in pairs(S.players) do
		for id, e in pairs(S.entities) do
			local visible = math.abs(e.x - ps.x) <= Config.VIEW_DX and math.abs(e.y - ps.y) <= Config.VIEW_DY
			if visible and not ps.known[id] then
				ps.known[id] = true
				sendState(ps, spawnPacket(e))
			elseif not visible and ps.known[id] then
				ps.known[id] = nil
				sendState(ps, "leave", id)
			end
		end
	end
end

-- ---------- camps and bags ----------
function Sim.placeCamp(ps, x: number, y: number)
	local uid = ps.player.UserId
	local old = S.camps[uid]
	if old then
		world.object[tidx(old.x, old.y)] = 0
		Sim.broadcastObject(old.x, old.y, 0)
	end
	S.camps[uid] = { x = x, y = y, litUntil = os.clock() + Config.CAMPFIRE_HOURS * HOUR, out = false, owner = uid }
	world.object[tidx(x, y)] = O.camp_lit.id
	Sim.broadcastObject(x, y, O.camp_lit.id)
	ps.rest = { kind = "camp" }
	ps.restText = Sim.restText(ps)
end

function Sim.broadcastObject(x: number, y: number, objectId: number)
	for _, ps in pairs(S.players) do sendState(ps, "object", x, y, objectId) end
end

local function destroyCamp(uid: number, why: string)
	local c = S.camps[uid]
	if not c then return end
	S.camps[uid] = nil
	if world.object[tidx(c.x, c.y)] == O.camp_lit.id or world.object[tidx(c.x, c.y)] == O.camp_out.id then
		world.object[tidx(c.x, c.y)] = 0
		Sim.broadcastObject(c.x, c.y, 0)
	end
	local ps = S.players[uid]
	if ps then
		if ps.rest.kind == "camp" then ps.rest = { kind = "village", village = 1 } ps.restText = Sim.restText(ps) end
		Sim.text(ps, why, "warn")
		Sim.hud(ps)
	end
end

local function tickCamps(now: number)
	for uid, c in pairs(S.camps) do
		if not c.out and now >= c.litUntil then
			c.out = true
			world.object[tidx(c.x, c.y)] = O.camp_out.id
			Sim.broadcastObject(c.x, c.y, O.camp_out.id)
			local ps = S.players[uid]
			if ps then Sim.text(ps, "Your fire has gone out.") end
		end
		-- wolves at an unlit camp trample it
		if c.out then
			for _, e in pairs(S.entities) do
				if e.species == "wolf" and cheb(e.x, e.y, c.x, c.y) <= 1 then destroyCamp(uid, "Wolves have torn up your camp.") break end
			end
		end
	end
	-- bags go public after a while and vanish after an hour
	for id, b in pairs(S.bags) do
		local age = now - b.droppedAt
		if age > Config.BAG_PRIVATE_SECONDS and not b.public then
			b.public = true
			for _, ps in pairs(S.players) do
				if ps.player.UserId ~= b.owner then sendState(ps, "object", b.x, b.y, O.bag.id) end
			end
		end
		if age > 3600 then
			S.bags[id] = nil
			world.object[tidx(b.x, b.y)] = 0
			Sim.broadcastObject(b.x, b.y, 0)
		end
	end
end

function Sim.bagAt(x: number, y: number)
	for _, b in pairs(S.bags) do
		if b.x == x and b.y == y then return b end
	end
	return nil
end

function Sim.takeBag(ps, b)
	local got = {}
	local left = {}
	for _, s in ipairs(b.slots) do
		local added = Items.add(ps.inv, s.item, s.n)
		if added > 0 then table.insert(got, added .. " " .. Items.def(s.item).label) end
		if added < s.n then table.insert(left, { item = s.item, n = s.n - added }) end
	end
	if #left > 0 then
		b.slots = left
		Sim.text(ps, "You take " .. table.concat(got, ", ") .. ". The rest will not fit.", "warn")
	else
		S.bags[b.id] = nil
		world.object[tidx(b.x, b.y)] = 0
		Sim.broadcastObject(b.x, b.y, 0)
		Sim.text(ps, if #got > 0 then "You take " .. table.concat(got, ", ") .. "." else "The bag is empty.")
	end
	Sim.hud(ps)
end

-- ---------- calamities ----------
local function startCalamity(kind: string)
	local c = S.calamity
	c.kind, c.active, c.day = kind, true, S.day
	if kind == "flood" then
		local tiles = WorldGen.floodTiles(world)
		WorldGen.setFlood(world, tiles)
		c.flood = tiles
		-- everything standing in the water gets shoved to dry ground
		for _, e in pairs(S.entities) do
			if not WorldGen.walkable(world, e.x, e.y) then
				local p = nearestFree(e.x, e.y, 4)
				if p then placeEntity(e, p.x, p.y) else removeEntity(e) end
			end
		end
		for _, ps in pairs(S.players) do
			if not WorldGen.walkable(world, ps.x, ps.y) then
				local p = nearestFree(ps.x, ps.y, 5)
				if p then
					Sim.occupied[tidx(ps.x, ps.y)] = nil
					ps.x, ps.y = p.x, p.y
					Sim.occupied[tidx(ps.x, ps.y)] = ps.player.UserId
					ps.snap(ps)
				end
			end
		end
		for uid, camp in pairs(S.camps) do
			if WorldGen.ground(world, camp.x, camp.y) == G.flood.id then destroyCamp(uid, "The flood took your camp.") end
		end
		for _, t in ipairs(S.tribes) do
			t.stock.food = math.floor(t.stock.food * 0.7)
			-- a plot under water loses the season on it, which is the part of a flood a farmer actually feels
			local drowned = 0
			for _, f in ipairs(t.farms) do
				if WorldGen.ground(world, f.x, f.y) == G.flood.id and f.growth > 0 then
					f.growth, f.tended = 0, 0
					drowned += 1
				end
			end
			if drowned > 0 then t.news = ("The water took %d of our plots."):format(drowned) end
		end
	else
		Ecology.beastTide(S.regions)
		for _, t in ipairs(S.tribes) do
			local r = Ecology.at(S.regions, world, t.village.cx, t.village.cy)
			if r.tide and not t.walled then t.population = math.max(5, t.population - rng:int(1, 3)) end
		end
	end
	for _, ps in pairs(S.players) do
		notice(ps, "calamity", { kind = kind, phase = "start", text = Calamity.notice(kind), flood = c.flood })
		Sim.clearGoal(ps) -- the week turned: the tutorial line has said everything it had to say
	end
	print("[Sim] calamity: " .. kind)
end

local function endCalamity()
	local c = S.calamity
	if not c.active then return end
	if c.kind == "flood" then WorldGen.clearFlood(world) end
	Ecology.endTide(S.regions)
	for _, ps in pairs(S.players) do
		notice(ps, "calamity", { kind = c.kind, phase = "end", text = Calamity.over(c.kind) })
	end
	c.active, c.flood = false, nil
end
Sim.startCalamity = startCalamity

function Sim.calamityWarning(): string?
	local day = S.day
	if Calamity.isWarningDay(day) then return Calamity.warning(Calamity.pick(world.seed, Calamity.weekOf(day + 1))) end
	return nil
end

local function tickCalamity()
	local day, frac = Sim.clock()
	local c = S.calamity
	if c.active and day > c.day then endCalamity() end
	if Calamity.isWarningDay(day) and c.warnedDay ~= day then
		c.warnedDay = day
		local kind = Calamity.pick(world.seed, Calamity.weekOf(day + 1))
		for _, ps in pairs(S.players) do notice(ps, "calamity", { kind = kind, phase = "warning", text = Calamity.warning(kind) }) end
	end
	if not c.active and Calamity.shouldStart(day, frac, c.day == day) then
		startCalamity(Calamity.pick(world.seed, Calamity.weekOf(day)))
	end
end

-- ---------- daily ----------
--- Births, growing up, couples. Runs on the daily tick and on the Debug "birth" command.
local function tickFamilies()
	for i, t in ipairs(S.tribes) do
		Families.formCouples(S.people, i, S.day)
		if S.day % Config.WEEK_DAYS == 1 then
			for _, mother in ipairs(Families.weeklyConceive(S.people, rng, i, S.day)) do
				local me = mother.entity and S.entities[mother.entity]
				if me then morph(me, "pregnant", { role = "pregnant", radius = 2 }) end
			end
		end
	end
	local r = Families.daily(S.people, rng, S.day)
	for _, baby in ipairs(r.born) do
		local mother = S.people.people[baby.mother]
		local me = mother and mother.entity and S.entities[mother.entity]
		if me then
			local t = S.tribes[baby.tribe]
			local sprite = VILLAGE_SPRITE[t.tribeType]
			local mx, my = me.x, me.y
			local ne = morph(me, "villager", { role = "villager", radius = 3, sprite = sprite })
			ne.home = { x = mx, y = my }
			local pos = nearestFree(mx, my, 3)
			if pos then
				local be = newEntity("baby", pos.x, pos.y, { tribe = baby.tribe, radius = 0, role = "baby", name = Families.fullName(baby), label = baby.first })
				be.first, be.last, be.person = baby.first, baby.last, baby.id
				baby.entity = be.id
			end
			t.news = Families.describeBirth(baby, mother)
			t.population += 1
		end
	end
	for _, grown in ipairs(r.grown) do
		local be = grown.entity and S.entities[grown.entity]
		if be then morph(be, "villager", { role = "villager", radius = 3, sprite = VILLAGE_SPRITE[S.tribes[grown.tribe].tribeType] }) end
	end
end

local function dailyTick()
	Ecology.dailyTick(S.regions, rng)
	tickFamilies()
	for _, t in ipairs(S.tribes) do
		Trade.dailyRestock(t.stock, t.tribeType)
		t.population = math.min(60, t.population + 1)
		-- Farms: a plot that was worked yesterday comes in as food, and a plot nobody touched goes back to weeds.
		-- This is what makes a raid on a farmer village cost them something, and what makes the farmers' whole
		-- reason for existing visible instead of a label on a tribe (DESIGN.md §20).
		local harvest = 0
		for _, f in ipairs(t.farms) do
			if f.growth >= 1 then
				harvest += 1
				f.growth = 0
			elseif f.tended < S.day - 1 then
				f.growth = math.max(0, f.growth - 0.15)
			end
		end
		if harvest > 0 then
			t.stock.food = (t.stock.food or 0) + harvest * 3
			if not t.news and harvest >= 2 then
				t.news = ("The plots came in well. %d loads of food in the store."):format(harvest * 3)
			end
		end
	end
	for _, ps in pairs(S.players) do
		for tribe, v in pairs(ps.rep) do ps.rep[tribe] = Reputation.fade(v, 1) end
	end
	local now = os.clock()
	for _, g in pairs(S.groups) do
		if g.replenishAt and now >= g.replenishAt and not g.materialised then
			local full = if g.kind == "caravan" then 3 else 4
			while #g.members < full do
				table.insert(g.members, { kind = if g.kind == "caravan" then "caravan_guard" elseif g.kind == "squad" then "hunter" else "bandit" })
			end
			g.replenishAt = nil
		end
	end
	local t = Ecology.totals(S.regions)
	print(("[Sim] day %d: deer %d boar %d wolf %d"):format(S.day, t.deer, t.boar, t.wolf))
end

-- ---------- players ----------
function Sim.addPlayer(player: Player, x: number, y: number, snapFn)
	local uid = player.UserId
	local free = nearestFree(x, y, 3) or { x = x, y = y }
	local ps = {
		player = player, x = free.x, y = free.y, facing = "down", epoch = 0, budget = Movement.newBudget(os.clock()), lastWorldInit = -math.huge,
		hp = Stats.get("player").hp, maxHp = Stats.get("player").hp, inv = Items.dayOneKit(), rep = Reputation.newTable(),
		rest = { kind = "village", village = 1 }, restText = "", dead = false, lastAttack = -math.huge, invulnUntil = 0,
		known = {}, dialogue = nil, snap = snapFn,
		-- the first five minutes: which goal line they are on, whether the survivor has been found, and which
		-- inventory slot is in hand (all on the record, so rung 3 saves them with everything else)
		goalStage = 0, goal = nil, goalDone = false, metSurvivor = false, selected = nil,
	}
	ps.restText = Sim.restText(ps)
	S.players[uid] = ps
	Sim.occupied[tidx(ps.x, ps.y)] = uid
	Sim.setGoal(ps, 1)
	return ps
end

function Sim.removePlayer(player: Player)
	local ps = S.players[player.UserId]
	if not ps then return end
	if Sim.occupied[tidx(ps.x, ps.y)] == player.UserId then Sim.occupied[tidx(ps.x, ps.y)] = nil end
	S.players[player.UserId] = nil
end

--- Called by the server after it accepts a move, to keep occupancy right.
function Sim.playerMoved(ps, fromX: number, fromY: number)
	if Sim.occupied[tidx(fromX, fromY)] == ps.player.UserId then Sim.occupied[tidx(fromX, fromY)] = nil end
	Sim.occupied[tidx(ps.x, ps.y)] = ps.player.UserId
end

-- ---------- init and loops ----------
function Sim.init()
	world = World.get()
	rng = Rng.new(world.seed * 31 + 7)
	S.dayStart = os.clock()
	S.people = Families.new()
	S.regions = Ecology.init(world, rng:fork(1))
	for _, r in ipairs(S.regions.list) do r.live = { deer = 0, boar = 0, wolf = 0 } end
	initTribes()
	initGroups()
	local n = 0
	for _ in pairs(S.entities) do n += 1 end
	print(("[Sim] %d villagers, %d groups, %d regions"):format(n, 3, #S.regions.list))
end

function Sim.start()
	-- 10 Hz: walking and thinking
	task.spawn(function()
		local lastInterest, lastWild = 0, 0
		while true do
			task.wait(0.1)
			local now = os.clock()
			for _, e in pairs(S.entities) do
				if Sim.frozen then break end
				if now >= e.nextThink then
					e.nextThink = now + (if e.state == "chase" or e.state == "hunt" or e.state == "flee" then 0.15 else 0.6 + rng:float() * 0.4)
					local ok, err = pcall(think, e, now)
					if not ok then warn("[Sim] think " .. e.kind .. ": " .. tostring(err)) e.state = "idle" e.path = nil end
				end
				followPath(e, now)
			end
			if now - lastInterest > 0.25 then lastInterest = now tickInterest() end
			if now - lastWild > 1 then
				lastWild = now
				local ok, err = pcall(tickWildlife)
				if not ok then warn("[Sim] wildlife: " .. tostring(err)) end
			end
		end
	end)
	-- 1 Hz: the world clock, groups, calamities, camps
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			local day = Sim.clock()
			for _, f in ipairs({ tickGroups, tickCamps, tickCalamity, tickGoals }) do
				local ok, err = pcall(f, now)
				if not ok then warn("[Sim] tick: " .. tostring(err)) end
			end
			if day > S.lastDailyTick then
				S.lastDailyTick = day
				local ok, err = pcall(dailyTick)
				if not ok then warn("[Sim] daily: " .. tostring(err)) end
			end
		end
	end)
end

-- ---------- debug hook (ServerStorage.Debug, see docs/qa/rung2-part2.md) ----------
function Sim.debug(cmd: string, ...): any
	local args = { ... }
	local ps
	for _, p in pairs(S.players) do ps = p break end
	if cmd == "state" then
		local n, g = 0, 0
		for _ in pairs(S.entities) do n += 1 end
		for _, gr in pairs(S.groups) do g += 1 end
		local t = Ecology.totals(S.regions)
		local out = { day = S.day, entities = n, groups = g, deer = t.deer, boar = t.boar, wolf = t.wolf, calamity = S.calamity.kind, active = S.calamity.active }
		for id, gr in pairs(S.groups) do
			local live = 0
			for _ in pairs(gr.entities) do live += 1 end
			out[id] = ("%d members (%d visible) at %d,%d, route %d/%d"):format(#gr.members, live, Sim.groupPos(gr).x, Sim.groupPos(gr).y, gr.pos, #gr.route)
		end
		return out
	elseif cmd == "hunt" then
		-- put the nearest wolf onto the nearest deer, so a reviewer does not have to wait for nightfall and luck
		local wolf, deer, bestD = nil, nil, math.huge
		for _, w in pairs(S.entities) do
			if w.species == "wolf" then
				for _, o in pairs(S.entities) do
					if o.species == "deer" or o.species == "boar" then
						local dd = cheb(w.x, w.y, o.x, o.y)
						if dd < bestD then wolf, deer, bestD = w, o, dd end
					end
				end
			end
		end
		if not wolf or not deer then return "need a wolf and a deer materialised: try at night, or spawn one" end
		wolf.npcTarget, wolf.state = deer.id, "hunt"
		return ("%s at %d,%d is going for the %s at %d,%d (%d tiles)"):format(wolf.id, wolf.x, wolf.y, deer.species, deer.x, deer.y, bestD)
	elseif cmd == "raid" then
		-- Stage the fight §5 describes but the map rarely produces: the band and the caravan are usually on
		-- opposite sides of the world, and a group is only entities while a player stands near it. Bandits are
		-- moved next to the caravan and set on it. Everything after that is the ordinary rules.
		local band, caravan = S.groups.band, S.groups.caravan
		if not band or not caravan then return "no band or no caravan" end
		local victims = {}
		for oid in pairs(caravan.entities) do
			local o = S.entities[oid]
			if o then table.insert(victims, o) end
		end
		if #victims == 0 then
			local cp = Sim.groupPos(caravan)
			return ("the caravan is at %d,%d and is only a record from here: walk to it first"):format(cp.x, cp.y)
		end
		if inVillage(victims[1].x, victims[1].y) then
			return ("the caravan is inside a village at %d,%d, where bandits will not follow: catch it on the road"):format(victims[1].x, victims[1].y)
		end
		local raiders = {}
		for id in pairs(band.entities) do
			local e = S.entities[id]
			if e then table.insert(raiders, e) end
		end
		local staged = 0
		if #raiders == 0 then
			-- the band is elsewhere entirely: real bandits of the plunderer tribe, stood up on the spot
			for _, off in ipairs({ { 2, 0 }, { -2, 0 }, { 0, 2 } }) do
				local p = nearestFree(victims[1].x + off[1], victims[1].y + off[2], 3)
				if p then
					table.insert(raiders, newEntity("bandit", p.x, p.y, { tribe = 3, radius = 4 }))
					staged += 1
				end
			end
		end
		if #raiders == 0 then return "nowhere free to put a bandit" end
		for i, e in ipairs(raiders) do
			local o = victims[(i - 1) % #victims + 1]
			local p = nearestFree(o.x + (if i % 2 == 0 then 2 else -2), o.y + (i % 3) - 1, 3)
			if p then placeEntity(e, p.x, p.y) end
			e.npcTarget, e.state, e.path = o.id, "hunt", nil
		end
		return ("%d bandits (%d of them staged) on the caravan at %d,%d"):format(#raiders, staged, victims[1].x, victims[1].y)
	elseif cmd == "village" then
		local idx = args[1] or 1
		local t = S.tribes[idx]
		if not t then return "no such village" end
		local out: { [string]: any } = { name = t.village.name, tribe = t.tribeType, population = t.population,
			huts = #t.huts, plots = #t.farms, night = Sim.isNight() }
		for _, e in pairs(S.entities) do
			if e.tribe == idx and not e.species then
				local where = "wandering"
				if e.workTile and cheb(e.x, e.y, e.workTile.x, e.workTile.y) <= (if e.farm then 0 else 1) then where = "at work"
				elseif e.homeTile and cheb(e.x, e.y, e.homeTile.x, e.homeTile.y) <= 1 then where = "at home"
				elseif e.path then where = "walking" end
				out[e.id] = ("%s %s: %s at %d,%d%s"):format(tostring(e.role), tostring(e.name), where, e.x, e.y, if e.broken then " (broken)" else "")
			end
		end
		return out
	elseif cmd == "region" then
		-- the numbers behind the animals you can see, including what predators have taken today
		local x = args[1] or (ps and ps.x) or world.spawn.x
		local y = args[2] or (ps and ps.y) or world.spawn.y
		local r = S.regions.list[WorldGen.regionOf(world, x, y)]
		local live = { deer = 0, boar = 0, wolf = 0 }
		for _, e in pairs(S.entities) do
			if e.species and e.region == r.id then live[e.species] += 1 end
		end
		return { id = r.id, col = r.col, row = r.row, deer = r.deer, boar = r.boar, wolf = r.wolf,
			grass = math.round(r.grass * 100) / 100, eaten = r.eaten, tide = r.tide, village = r.village,
			visible = ("%d deer, %d boar, %d wolf"):format(live.deer, live.boar, live.wolf) }
	elseif cmd == "farms" then
		local out: { [string]: any } = {}
		for _, t in ipairs(S.tribes) do
			local grown, ready = 0, 0
			for _, f in ipairs(t.farms) do
				grown += f.growth
				if f.growth >= 1 then ready += 1 end
			end
			out[t.village.name] = ("%d plots, %.2f grown, %d ready, %d food in store"):format(#t.farms, grown, ready, t.stock.food or 0)
		end
		return out
	elseif cmd == "calamity" then
		endCalamity()
		startCalamity(args[1] or "flood")
		return "started " .. (args[1] or "flood")
	elseif cmd == "teleport" and ps then
		local p = nearestFree(args[1], args[2], 4)
		if not p then return "no free tile there" end
		Sim.occupied[tidx(ps.x, ps.y)] = nil
		ps.x, ps.y = p.x, p.y
		Sim.occupied[tidx(ps.x, ps.y)] = ps.player.UserId
		ps.snap(ps)
		return ("at %d,%d"):format(p.x, p.y)
	elseif cmd == "give" and ps then
		if args[1] == "coin" then ps.inv.coin += args[2] or 10 else Items.add(ps.inv, args[1], args[2] or 1) end
		Sim.hud(ps)
		return "ok"
	elseif cmd == "rep" and ps then
		local t = S.tribes[args[1] or 1]
		ps.rep[t.tribeType] = args[2] or 0
		Sim.hud(ps)
		return t.tribeType .. " = " .. tostring(ps.rep[t.tribeType])
	elseif cmd == "night" then
		S.dayStart = os.clock() - Config.DAY_SECONDS * (1 - Config.NIGHT_FRACTION + 0.01)
		return "dusk"
	elseif cmd == "jump" then
		-- set the calendar: `jump 6` = morning of day 6 (the warning), `jump 7 0.29` = a moment before the calamity
		local day, frac = args[1] or 7, args[2] or 0.1
		S.day = day
		S.dayStart = os.clock() - Config.DAY_SECONDS * frac
		S.lastDailyTick = day -- one jump does not run six days of births and breeding
		return ("day %d, %.0f%% through it"):format(day, frac * 100)
	elseif cmd == "day" then
		S.dayStart = os.clock() - Config.DAY_SECONDS * (args[1] or 0.1)
		return "morning"
	elseif cmd == "hurt" and ps then
		ps.hp = math.max(1, ps.hp - (args[1] or 4))
		Sim.hud(ps)
		return ps.hp
	elseif cmd == "kill" and ps then
		killPlayer(ps, nil)
		return "dead"
	elseif cmd == "group" then
		local g = S.groups[args[1] or "band"]
		if not g then return "no such group" end
		local p = Sim.groupPos(g)
		return ("%s at %d,%d dir %d pos %d/%d%s"):format(g.id, p.x, p.y, g.dir, g.pos, #g.route, if g.materialised then " visible" else "")
	elseif cmd == "summon" and ps then
		-- bring a group next to the player
		local g = S.groups[args[1] or "band"]
		if not g then return "no such group" end
		if g.materialised then collapse(g) end
		local bestI, bestD = 1, math.huge
		for i, r in ipairs(g.route) do
			local d = cheb(r.x, r.y, ps.x, ps.y)
			if d < bestD then bestI, bestD = i, d end
		end
		g.pos = bestI
		g.pauseUntil = 0
		return ("%s moved to route index %d (%d tiles away)"):format(g.id, bestI, bestD)
	elseif cmd == "freeze" then
		Sim.frozen = (args[1] or 1) ~= 0
		return "frozen " .. tostring(Sim.frozen)
	elseif cmd == "spawn" and ps then
		local p = nearestFree(args[2] or (ps.x + 3), args[3] or ps.y, 3)
		if not p then return "no room" end
		local kind = args[1] or "wolf"
		local r = Ecology.at(S.regions, world, p.x, p.y)
		local e = newEntity(kind, p.x, p.y, { species = if Stats.get(kind).animal then kind else nil, region = if Stats.get(kind).animal then r.id else nil, radius = 4 })
		if e.species then r.live[kind] += 1 r[kind] += 1 end
		return e.id
	elseif cmd == "entity" then
		local e = S.entities[args[1]]
		if not e then return "no entity " .. tostring(args[1]) end
		local tgt = e.npcTarget and S.entities[e.npcTarget]
		return { id = e.id, kind = e.kind, hp = e.hp, x = e.x, y = e.y, state = e.state, target = tostring(e.target),
			facing = e.facing, group = e.group, region = e.region, label = e.label,
			-- who it is going for and how far off it is: without this a hunt that never lands looks like a wander
			npcTarget = tostring(e.npcTarget), npcAt = tgt and ("%s %d,%d (%d away)"):format(tgt.kind, tgt.x, tgt.y, cheb(e.x, e.y, tgt.x, tgt.y)) or "none",
			pathLeft = if e.path then #e.path - e.pathI + 1 else 0, broken = e.broken or false }
	elseif cmd == "list" then
		local out = {}
		for id, e in pairs(S.entities) do
			if not args[1] or e.kind == args[1] or e.role == args[1] then
				table.insert(out, ("%s %s hp%d @%d,%d %s%s"):format(id, e.kind, e.hp, e.x, e.y, e.state, if e.target then " ->" .. tostring(e.target) else ""))
			end
		end
		table.sort(out)
		return out
	elseif cmd == "player" and ps then
		local slots = {}
		for _, sl in ipairs(ps.inv.slots) do table.insert(slots, sl.item .. "x" .. sl.n) end
		return { x = ps.x, y = ps.y, hp = ps.hp, facing = ps.facing, dead = ps.dead, coin = ps.inv.coin, inv = table.concat(slots, ","), rep = ps.rep, rest = ps.restText, epoch = ps.epoch }
	elseif cmd == "verbose" then
		Sim.verbose = (args[1] or 1) ~= 0
		return "verbose " .. tostring(Sim.verbose)
	elseif cmd == "strike" and ps then
		-- the player's blow lands on an entity through the real path (contexts, break points, mercy)
		local e = S.entities[args[1]]
		if not e then return "no entity " .. tostring(args[1]) end
		e.invulnUntil = 0
		hitEntity(e, args[2] or 3, ps.x, ps.y, ps)
		local live = S.entities[e.id]
		return if live then ("%s hp %d state %s broken %s beatenBy %s"):format(e.id, e.hp, e.state, tostring(e.broken), tostring(e.beatenBy)) else e.id .. " dead"
	elseif cmd == "people" then
		local out = {}
		for i, t in ipairs(S.tribes) do
			if not args[1] or args[1] == i then
				for _, p in ipairs(Families.villagers(S.people, i)) do
					table.insert(out, ("%d %s %s (%s, %s, %s%s%s) %s"):format(p.id, p.first, p.last, p.sex, p.role, p.stage,
						if p.spouse then ", spouse " .. p.spouse else "", if p.father then ", child of " .. p.father else "", tostring(p.entity)))
				end
			end
		end
		return out
	elseif cmd == "family" then
		local p = S.people.people[args[1]]
		if not p then return "no person " .. tostring(args[1]) end
		local rel = {}
		for _, o in ipairs(Families.relatives(S.people, p)) do table.insert(rel, o.first .. " " .. o.last) end
		return { name = Families.fullName(p), alive = p.alive, cause = p.cause, killer = p.killer, born = p.born, spouse = p.spouse, father = p.father, mother = p.mother, children = table.concat(p.children, ","), relatives = table.concat(rel, ", ") }
	elseif cmd == "birth" then
		-- force: the first couple in the player's village (or village 1) conceives and gives birth now
		local ti = args[1] or 1
		local made = 0
		Families.formCouples(S.people, ti, S.day)
		for _, p in ipairs(Families.villagers(S.people, ti, true)) do
			if p.sex == "f" and p.spouse then
				p.stage, p.role, p.due = "pregnant", "pregnant", S.day
				local me = p.entity and S.entities[p.entity]
				if me then morph(me, "pregnant", { role = "pregnant", radius = 2 }) end
				made += 1
				break
			end
		end
		if made == 0 then return "no couple in village " .. ti end
		if args[2] == "now" then tickFamilies() return "born" end
		return "pregnant, due now: run `birth " .. ti .. " now` or wait for the daily tick"
	elseif cmd == "goal" and ps then
		-- `goal` reads the tutorial line, `goal 3` jumps to a stage, `goal 0` retires it
		if args[1] ~= nil then
			if args[1] == 0 then Sim.clearGoal(ps) else ps.goalStage = args[1] - 1 Sim.setGoal(ps, args[1]) end
		end
		return { stage = ps.goalStage, goal = ps.goal, done = ps.goalDone, metSurvivor = ps.metSurvivor, held = ps.selected }
	elseif cmd == "camp" and ps then
		return tostring(S.camps[ps.player.UserId] and (S.camps[ps.player.UserId].x .. "," .. S.camps[ps.player.UserId].y .. (if S.camps[ps.player.UserId].out then " out" else " lit")) or "none")
	end
	return "unknown command " .. tostring(cmd)
end

function Sim.world(): WorldGen.World
	return world
end

return Sim
