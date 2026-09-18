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
local Tick = require(Shared:WaitForChild("Tick"))
local Headlines = require(Shared:WaitForChild("Headlines"))
local Sides = require(script.Parent:WaitForChild("Sides"))
local Debug = require(script.Parent:WaitForChild("Debug"))
local Restore = require(script.Parent:WaitForChild("Restore"))
local Goals = require(script.Parent:WaitForChild("Goals"))
local Map = require(script.Parent:WaitForChild("Map"))
local State = require(script.Parent:WaitForChild("State"))
local Tiles = require(script.Parent:WaitForChild("Tiles"))
local Calendar = require(script.Parent:WaitForChild("Calendar"))

local Sim = {}

local G = TileTypes.GroundByName
local HOUR = Config.DAY_SECONDS / 24

Sim.remotes = State.remotes -- wired by Server.server.lua before Sim.start()
Sim.verbose = false -- Debug "verbose 1": log every hit on a player
Sim.frozen = false  -- Debug "freeze 1": NPCs stop thinking and walking (for deterministic tests)

local world: WorldGen.World
local rng: Rng.Rng
local nextId = 0

-- The record, occupancy and the client-facing helpers live in server/State.lua. These are the names the rest of
-- this file, and Interact / Sides / Debug / Restore, already use.
Sim.state, Sim.occupied = State.state, State.occupied
local S = State.state
local tidx, cheb = State.tidx, State.cheb

-- ---------- clock ----------
function Sim.clock(): (number, number)
	local day, frac = Calendar.clock()
	S.day = day
	return day, frac
end

function Sim.isNight(): boolean
	local _, frac = Sim.clock()
	return DayCycle.nightAlpha(frac) > 0.25
end

local sendState, notice, broadcastEntity, spawnPacket = State.sendState, State.notice, State.broadcastEntity, State.spawnPacket
Sim.notice, Sim.text, Sim.hud, Sim.restText, Sim.broadcastObject = State.notice, State.text, State.hud, State.restText, State.broadcastObject

-- The goal line lives in server/Goals.lua; these names are what Interact, Debug and the rest of Sim already call.
Sim.setGoal, Sim.clearGoal = Goals.set, Goals.clear

-- ---------- entities ----------
local function newEntity(kind: string, x: number, y: number, opts): any
	nextId += 1
	local k = Stats.get(kind)
	local e = {
		id = "e" .. nextId, kind = kind, sprite = opts.sprite or k.sprite, label = opts.label,
		x = x, y = y, facing = opts.facing or "down", hp = k.hp, maxHp = k.hp, atk = k.atk, def = k.def, speed = k.speed,
		name = opts.name, tribe = opts.tribe, group = opts.group, role = opts.role or kind,
		home = { x = x, y = y }, radius = opts.radius or 3,
		state = "idle", nextThink = Calendar.now() + rng:float(), nextStepAt = 0, path = nil, pathI = 1,
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
	local now = Calendar.now()
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
		-- Someone is in the way. Roads are one tile wide, so a single person standing on one used to stop a whole
		-- caravan indefinitely: the route says "next tile", the next tile is occupied, and re-planning returns the
		-- same road. So step around instead — any free neighbour that gets us closer to where the path goes next.
		e.blockedCount = (e.blockedCount or 0) + 1
		faceEntity(e, Combat.dirTo(e.x, e.y, step.x, step.y))
		local goal = e.path[e.pathI + 1] or step
		local best, bestD = nil, math.min(cheb(e.x, e.y, goal.x, goal.y), cheb(step.x, step.y, goal.x, goal.y) + 1)
		for _, d in pairs(Movement.DIRS) do
			local nx, ny = e.x + d[1], e.y + d[2]
			if freeTile(nx, ny) then
				local dd = cheb(nx, ny, goal.x, goal.y)
				if dd < bestD then best, bestD = { x = nx, y = ny }, dd end
			end
		end
		if best and e.blockedCount >= 2 then
			-- slip past them, then carry on to the rest of the route from there
			placeEntity(e, best.x, best.y, Combat.dirTo(e.x, e.y, best.x, best.y))
			e.nextStepAt = now + Movement.stepTime(world, best.x, best.y) / e.speed
			e.blockedCount = 0
			if e.path[e.pathI + 1] then e.pathI += 1 else e.path = nil end
			return
		end
		e.nextStepAt = now + 0.3
		if e.blockedCount > 4 then e.path = nil e.blockedCount = 0 end
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
	local person = opts.person or Families.newAdult(S.people, rng, tribeIdx, t.villageId, opts.role or kind, S.day, opts.surname or rng:pick(t.surnames), opts.sex)
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
	if p then p.entity = ne.id end
	return ne
end

local VILLAGE_SPRITE = { farmer = "villager", hunter = "hunter", plunderer = "bandit" }

-- Who is at home, per tribe type (Danzo, 2026-09-18: the other two villages "should not be so super easy to
-- just walk in and kill everything - people live here"). The walls are the farmers showing off their
-- established might, so the farmers really are better defended; the other two are not soft, they are different.
-- Straight out of ideas/INBOX.md: farmers' strength is coordination and militarisation, hunters are the best
-- fighters one-on-one, plunderers are the weakest tribe but sudden and brutal.
local ROSTER = {
	farmer = { guards = 4, fighters = nil, count = 0, villagers = 8 },
	hunter = { guards = 2, fighters = "hunter", count = 4, villagers = 6 },
	plunderer = { guards = 2, fighters = "bandit", count = 4, villagers = 5 },
} :: { [string]: { guards: number, fighters: string?, count: number, villagers: number } }

local function initTribes()
	for i, v in ipairs(world.villages) do
		local t = {
			villageId = i, -- never the village table itself: Map.village(t.villageId)
			tribeType = v.tribeType, stock = Trade.newStock(v.tribeType),
			population = 30 + rng:int(0, 20), walled = #v.gates > 0,
			surnames = { Names.last(rng), Names.last(rng), Names.last(rng) },
			guard = nil, merchant = nil, survivor = nil, news = nil,
		}
		S.tribes[i] = t
		local sprite = VILLAGE_SPRITE[v.tribeType]
		-- guard just inside the first gate (or by the road for open villages)
		local gx, gy = v.spawn.x + 2, v.spawn.y - 1
		if #v.gates > 0 then
			local g = v.gates[1]
			gx, gy = g.x + (g.x - g.exit.x), g.y + (g.y - g.exit.y)
		end
		local roster = ROSTER[v.tribeType] or ROSTER.farmer
		t.population = math.max(t.population, 20 + roster.guards * 5 + roster.count * 4 + roster.villagers * 2)
		-- the gate guard, then the rest of the watch spread around the place
		local guard = spawnPerson("guard", gx, gy, i, { radius = 1, role = "guard", label = "guard" })
		if guard then t.guard = guard.id end
		for _ = 2, roster.guards do
			spawnPerson("guard", rng:int(v.x0 + 1, v.x1 - 1), rng:int(v.y0 + 1, v.y1 - 1), i,
				{ radius = 3, role = "guard", label = "guard" })
		end
		-- and the tribe's own kind of fighter, at home between jobs
		for _ = 1, roster.count do
			spawnPerson(roster.fighters or "guard", rng:int(v.x0 + 1, v.x1 - 1), rng:int(v.y0 + 1, v.y1 - 1), i,
				{ radius = 3, role = roster.fighters or "guard", sprite = if roster.fighters == "bandit" then "bandit" else nil })
		end
		local m = spawnPerson("merchant", v.stall.x, v.stall.y + 1, i, { radius = 1, role = "merchant", label = "merchant" })
		if m then t.merchant = m.id end
		for n = 1, roster.villagers do
			local x = rng:int(v.x0 + 1, v.x1 - 1)
			local y = rng:int(v.y0 + 1, v.y1 - 1)
			spawnPerson("villager", x, y, i, { radius = 3, role = "villager", sprite = sprite, sex = if n % 2 == 0 then "f" else "m" })
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

--- The TRANSIENT half of a group: who is materialised, who they are chasing. Never saved; reset on creation and
--- again when a saved group is restored.
local function groupScratch(g)
	g.entities, g.leader, g.trail, g.materialised = {}, nil, {}, false
	g.target, g.aggroUntil, g.lastSeen = nil, 0, nil
end

local function makeGroup(id: string, kind: string, tribeIdx: number, from: WorldGen.Pos, to: WorldGen.Pos, members, pauses)
	-- `route` is derived from `from` and `to` (Tick.rebuildRoute), so `to` is what a save keeps
	local g = {
		id = id, kind = kind, tribe = tribeIdx, pos = 1, dir = 1, from = { x = from.x, y = from.y }, to = { x = to.x, y = to.y },
		pauseUntil = Calendar.now() + rng:int(20, 60), pauses = pauses, speed = 1.5, acc = 0,
		members = members, fullSize = #members,
		carry = {}, retreatUntil = 0,   -- what they are bringing home, and whether they have had enough
	}
	groupScratch(g)
	Tick.rebuildRoute(g, world)
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

--- How much a group is hauling.
local function carryTotal(g): number
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
local function groupTurn(g)
	local events = {}
	Tick.groupTurn(S, g, Calendar.now(), events)
	logGroupEvents(events)
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

local function tickGoals()
	Goals.tick(S.players, (Sim.clock()))
end

--- Materialise/collapse decisions, then one second of abstract movement for every group without bodies (the
--- movement is Tick.groups: pure, shared with catch-up). 1 Hz.
local function tickGroups(now: number)
	for _, g in pairs(S.groups) do
		local p = Sim.groupPos(g)
		if g.materialised then
			if not anyPlayerWithin(p.x, p.y, Config.COLLAPSE_RANGE) then collapse(g) end
		elseif #g.members > 0 and anyPlayerWithin(p.x, p.y, Config.MATERIALISE_RANGE) then
			materialise(g)
		end
	end
	logGroupEvents(Tick.groups(S, world, now))
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
	for _, ps in pairs(S.players) do
		if not ps.dead then
			for _, rid in ipairs(regionCenterNear(ps)) do
				local r = S.regions.list[rid]
				for _, sp in ipairs(Ecology.SPECIES) do
					local want = math.min(r[sp], 3)
					if sp == "wolf" and not (night or r.tide) then want = 0 end
					if r.live[sp] < want then spawnAnimal(sp, r, ps) end
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
	-- An NPC kill used to produce nothing. Now it goes into the killer's group to be carried home, and the
	-- killer stops being hungry for a while, which is what stops a hunt being a slaughter.
	if byEntity and e.species then
		local now = Calendar.now()
		byEntity.fedUntil = now + (if byEntity.species then Config.FED_SECONDS else Config.FED_HUNTER)
		local g = byEntity.group and S.groups[byEntity.group]
		if g then
			for item, n in pairs(Combat.loot(e.kind, rng)) do
				if item ~= "coin" then g.carry[item] = (g.carry[item] or 0) + n end
			end
			-- laden: turn for home rather than keep killing
			if g.dir == 1 and carryTotal(g) >= Config.SQUAD_LOAD then
				g.dir, g.pauseUntil = -1, 0
			end
		end
	end
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
		local by = if killer then killer.player.Name else "the wild"
		Families.die(S.people, e.person, S.day, "killed", by)
		if p and e.tribe then Headlines.push(S.meta, { day = S.day, kind = "died", tribe = e.tribe, id = p.id }) end
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
	end
	if e.group then
		local g = S.groups[e.group]
		if g then
			-- the record loses a member; the tribe replaces them at home after a while
			table.remove(g.members, #g.members)
			local now = Calendar.now()
			g.replenishAt = now + Config.DAY_SECONDS
			-- A pack breaks when it has lost more than half, not the moment it loses one (Danzo, 2026-09-18:
			-- "if u encounter a bandit group and kill more than half the rest run away like with wolf packs but
			-- they shouldnt abort instantly once one dies"). Until then they fight, and they are still
			-- individually capable of breaking at their own hp threshold.
			if g.kind == "band" and #g.members * 2 < (g.fullSize or #g.members) then
				g.retreatUntil = now + Config.BAND_RETREAT
				g.target, g.aggroUntil, g.pauseUntil = nil, 0, 0
				g.dir = -1
				for id in pairs(g.entities) do
					local m = S.entities[id]
					if m and m ~= e then m.state, m.target, m.npcTarget, m.windupAt = "idle", nil, nil, nil end
				end
				print("[Sim] the band has broken off and is running for home")
			end
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
	local now = Calendar.now()
	if now < e.invulnUntil then return end
	-- everyone near enough to see it takes a view (docs/RUNG3.md part 1)
	local striker = if attacker then { ps = attacker } elseif byEntity then { e = byEntity } else nil
	if striker then Sides.witnessed(striker, { e = e }, e.x, e.y) end
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
	end
	if attacker and e.tribe and not e.species then
		applyRep(attacker, Reputation.deltas("hit", e.kind, Sim.tribeOf(e), ctx))
		-- Who comes for you is decided by the witness rule above, not by a hard-coded guard: a village that is
		-- family to you still answers for its own, and one that is wary of you may watch.
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

local function dropBag(ps)
	Tiles.dropBag(ps, nearestFree(ps.x, ps.y, 2) or { x = ps.x, y = ps.y })
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
	local now = Calendar.now()
	if ps.dead or now < ps.invulnUntil then return end
	Sides.witnessed({ e = e }, { ps = ps }, ps.x, ps.y)
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
	local now = Calendar.now()
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
		local v = Map.village(S.tribes[e.tribe].villageId)
		-- Scattered by a fight: walk home, with a budget that can actually reach it. Wandering inside the village
		-- bounds from twenty tiles away just fails, and the village stays empty.
		if cheb(e.x, e.y, v.cx, v.cy) > 8 then
			pathTo(e, v.spawn.x, v.spawn.y, 500, true)
			return
		end
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
	if e.tribe and not e.species then return Map.village(S.tribes[e.tribe].villageId).spawn end
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
	if e.kind == "bandit" and Sides.sheltered(ps, e) then
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
--- `nearerThan` is how far away the thing it is already interested in is: a predator with a deer at its feet
--- does not cross the clearing for a person, because the world does not revolve around the player (pillar 1).
local function pickTarget(e, now: number, nearerThan: number?)
	local k = Stats.get(e.kind)
	local range = 0
	local function wants(ps): boolean
		if e.species == "wolf" then return not litCampNear(ps.x, ps.y) end
		if e.kind == "bandit" then
			local g = e.group and S.groups[e.group]
			if g and now < (g.retreatUntil or 0) then return false end
			return ps.rep.plunderer < -10 and not Sides.sheltered(ps, e)
		end
		if e.tribe then return Sides.hostileToPlayer(e, ps) end
		return false
	end
	if e.species == "wolf" then range = 7 elseif e.kind == "bandit" then range = 6 elseif e.kind == "guard" then range = 5 elseif e.kind == "hunter" or e.kind == "caravan_guard" then range = 4 end
	if e.species == "boar" then range = 0 end -- boar only charge when hit
	if range == 0 and not k.hostile then return end
	local ps, psD = nearestPlayer(e.x, e.y, range, wants)
	if ps and psD >= (nearerThan or math.huge) then ps = nil end
	if ps then
		e.state, e.target, e.aggroUntil = "chase", ps.player.UserId, now + 10
		markAggression(e, ps.player.UserId)
		if e.escapeGiven then e.escapeGiven[ps.player.UserId] = nil end
	end
end

--- What this one goes after unprompted: prey if it is a predator, a feud if it is armed.
local function pickNpcTarget(e, now: number)
	if not Sides.canFight(e) and e.species ~= "wolf" then return end
	local range = if e.species == "wolf" then 7 else 5
	local taken = {}
	if e.species then
		for _, o in pairs(S.entities) do
			if o.species and o.npcTarget then taken[o.npcTarget] = (taken[o.npcTarget] or 0) + 1 end
		end
	end
	local best, bestD = nil, range
	for _, o in pairs(S.entities) do
		if o ~= e and now >= o.invulnUntil and not o.broken and (taken[o.id] or 0) < 2 and Sides.preysOn(e, o) then
			local d = cheb(e.x, e.y, o.x, o.y)
			if d < bestD then best, bestD = o, d end
		end
	end
	if best then
		e.npcTarget, e.state = best.id, "hunt"
		-- If what they just went after was coming for a player, that player should know who stepped in.
		local ps = best.target and S.players[best.target]
		if ps and not ps.dead and e.tribe then Sides.tellHelp(ps, e) end
	end
end

local function huntStep(e, now: number)
	local o = S.entities[e.npcTarget]
	if not o or cheb(e.x, e.y, o.x, o.y) > 8 then e.state, e.npcTarget, e.windupAt = "idle", nil, nil return end
	-- Re-read it each tick: a guard who set off after a bandit stops when he sees who the bandit has got hold of,
	-- and a village does not spend blood on someone it likes even less (docs/RUNG3.md part 1).
	if not Sides.preysOn(e, o) then e.state, e.npcTarget, e.windupAt = "idle", nil, nil return end
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
	if g.kind == "band" and g.target and S.players[g.target] and Sides.sheltered(S.players[g.target], e) then
		g.target, g.aggroUntil = nil, 0
	end
	-- Running for home: no aggro, no hunting, just go.
	if now < (g.retreatUntil or 0) then g.target, g.aggroUntil = nil, 0 end
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
				if freeTile(r.x, r.y) then setPath(e, { r }) g.pos = nextI g.stuck = 0
				elseif e.x == r.x and e.y == r.y then g.pos = nextI g.stuck = 0
				else
					-- somebody is standing on the next tile of the route: after a few tries, walk on to the one
					-- after it rather than waiting for them to move
					g.stuck = (g.stuck or 0) + 1
					if g.stuck > 3 then
						g.pos = nextI
						g.stuck = 0
						local after = g.route[nextI + g.dir]
						if after then pathTo(e, after.x, after.y, 200, true) end
					end
				end
			else
				pathTo(e, r.x, r.y, 200, true)
				g.pos = nextI
				g.stuck = 0
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
	if e.state == "alarm" then Sides.alarmStep(e, now) return end
	-- Idle: look for trouble, then go about your business. A predator weighs its prey first and only turns on a
	-- person if they are the nearer meal; everyone else looks for people first.
	local preyD = math.huge
	if e.species then
		pickNpcTarget(e, now)
		local o = e.state == "hunt" and S.entities[e.npcTarget]
		if o then preyD = cheb(e.x, e.y, o.x, o.y) end
	end
	pickTarget(e, now, preyD)
	if e.state == "chase" then return end
	if e.state ~= "hunt" then pickNpcTarget(e, now) end
	if e.state == "hunt" then return end
	if e.species == "deer" then
		local ps = nearestPlayer(e.x, e.y, 4)
		if ps then e.state, e.fleeUntil, e.threat = "flee", now + 2, { x = ps.x, y = ps.y } fleeStep(e) return end
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

-- Camps and bags live in server/Tiles.lua; these are the names Interact, Debug and the rest of this file use.
Sim.placeCamp, Sim.bagAt, Sim.takeBag = Tiles.placeCamp, Tiles.bagAt, Tiles.takeBag
local destroyCamp, tickCamps = Tiles.destroyCamp, Tiles.tick

-- ---------- calamities ----------
--- A calamity BEGINS: once per calamity, from tickCalamity (or Debug). Everything here is a one-time consequence -
--- the end date, the food lost, the wolves arriving, bodies shoved, camps destroyed, the notices. The part a load
--- has to put back (the water, the tide flag) is Calamity.applyOverlay, and a load calls ONLY that: run this twice
--- and the tribes lose their food twice and the calamity never ends.
local function startCalamity(kind: string)
	local c = S.calamity
	c.kind, c.active, c.day = kind, true, S.day
	c.flood = Calamity.applyOverlay(world, S.regions, kind) -- transient: sent to clients, never saved
	Headlines.push(S.meta, { day = S.day, kind = "calamity", what = kind })
	if kind == "flood" then
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
		for _, t in ipairs(S.tribes) do t.stock.food = math.floor(t.stock.food * 0.7) end
	else
		Ecology.wolfSurge(S.regions)
		for _, t in ipairs(S.tribes) do
			local v = Map.village(t.villageId)
			local r = Ecology.at(S.regions, world, v.cx, v.cy)
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
--- Give bodies to what Tick.families did to the records: a mother who is on the map changes sprite, a baby appears
--- beside her. The records are already complete whether or not any of these bodies exist.
local function applyFamilyEvents(ev)
	for _, mother in ipairs(ev.conceived) do
		local me = mother.entity and S.entities[mother.entity]
		if me then morph(me, "pregnant", { role = "pregnant", radius = 2 }) end
	end
	for _, baby in ipairs(ev.born) do
		local mother = S.people.people[baby.mother]
		local me = mother and mother.entity and S.entities[mother.entity]
		if me then
			local mx, my = me.x, me.y
			local ne = morph(me, "villager", { role = "villager", radius = 3, sprite = VILLAGE_SPRITE[S.tribes[baby.tribe].tribeType] })
			ne.home = { x = mx, y = my }
			local pos = nearestFree(mx, my, 3)
			if pos then
				local be = newEntity("baby", pos.x, pos.y, { tribe = baby.tribe, radius = 0, role = "baby", name = Families.fullName(baby), label = baby.first })
				be.first, be.last, be.person = baby.first, baby.last, baby.id
				baby.entity = be.id
			end
		end
	end
	for _, grown in ipairs(ev.grown) do
		local be = grown.entity and S.entities[grown.entity]
		if be then morph(be, "villager", { role = "villager", radius = 3, sprite = VILLAGE_SPRITE[S.tribes[grown.tribe].tribeType] }) end
	end
end

--- Births, growing up, couples, on demand (the Debug "birth" command).
local function tickFamilies()
	applyFamilyEvents(Tick.families(S, rng, S.day))
end

local function dailyTick()
	local ev = Tick.daily(S, rng, S.day, Calendar.now())
	applyFamilyEvents(ev)
	for _, ps in pairs(S.players) do
		for tribe, v in pairs(ps.rep) do ps.rep[tribe] = Reputation.fade(v, 1) end
	end
	print(("[Sim] day %d: deer %d boar %d wolf %d"):format(S.day, ev.totals.deer, ev.totals.boar, ev.totals.wolf))
end

-- ---------- players ----------
--- `saved` is the player's own key, or nil for somebody new: Restore.player lays it over the fresh record.
function Sim.addPlayer(player: Player, x: number, y: number, snapFn, saved)
	local uid = player.UserId
	local ps = {
		player = player, x = x, y = y, facing = "down", epoch = 0, budget = Movement.newBudget(os.clock()), lastWorldInit = -math.huge,
		hp = Stats.get("player").hp, maxHp = Stats.get("player").hp, inv = Items.dayOneKit(), rep = Reputation.newTable(),
		rest = { kind = "village", village = 1 }, restText = "", dead = false, lastAttack = -math.huge, invulnUntil = 0,
		known = {}, dialogue = nil, snap = snapFn,
		-- the first five minutes: which goal line they are on, whether the survivor has been found, and which
		-- inventory slot is in hand (all on the record, so rung 3 saves them with everything else)
		goalStage = 0, goal = nil, goalDone = false, metSurvivor = false, selected = nil,
	}
	if saved then
		x, y = Restore.player(ps, saved, x, y)
		Goals.rebuild(ps)
	end
	local free = nearestFree(x, y, 3) or WorldGen.nearestWalkable(world, x, y, 6) or world.spawn
	ps.x, ps.y = free.x, free.y
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
--- ONE of two constructors: generate, or restore `saved` after `slept` real seconds. false, why = it would not go in.
function Sim.init(saved, slept: number?): (boolean, string?)
	world = Map.get()
	rng = Rng.new(world.seed * 31 + 7)
	Calendar.bind(S.meta)
	Goals.bind(Sim.hud)
	S.people = Families.new()
	S.regions = Ecology.init(world, rng:fork(1))
	for _, r in ipairs(S.regions.list) do r.live = { deer = 0, boar = 0, wolf = 0 } end
	Sides.bind({ state = S, world = world, faceEntity = faceEntity, markAggression = markAggression, pathTo = pathTo,
		text = Sim.text })
	Debug.bind({ Sim = Sim, S = S, world = world, cheb = cheb, collapse = collapse, endCalamity = endCalamity,
		hitEntity = hitEntity, killPlayer = killPlayer, morph = morph, nearestFree = nearestFree, newEntity = newEntity,
		startCalamity = startCalamity, tickFamilies = tickFamilies, tidx = tidx })
	Restore.bind({ playerRestPoint = Sim.playerRestPoint, notice = notice, S = S, world = world, spawnPerson = spawnPerson, removeEntity = removeEntity,
		groupScratch = groupScratch, getRng = function() return rng end })
	if saved then
		local ok, why = Restore.apply(saved, slept)
		if ok then return true, nil end
		warn("[Sim] the save would not restore (" .. tostring(why) .. "): generating a new world instead")
		initTribes()
		initGroups()
		return false, why
	end
	initTribes()
	initGroups()
	local n = 0
	for _ in pairs(S.entities) do n += 1 end
	print(("[Sim] %d villagers, %d groups, %d regions"):format(n, 3, #S.regions.list))
	return true, nil
end

function Sim.start()
	-- 10 Hz: walking and thinking
	task.spawn(function()
		local lastInterest, lastWild = 0, 0
		while true do
			task.wait(0.1)
			local now = Calendar.now()
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
			local now = Calendar.now()
			local day = Sim.clock()
			for _, f in ipairs({ tickGroups, tickCamps, tickCalamity, tickGoals }) do
				local ok, err = pcall(f, now)
				if not ok then warn("[Sim] tick: " .. tostring(err)) end
			end
			if day > S.meta.lastDailyTick then
				S.meta.lastDailyTick = day
				local ok, err = pcall(dailyTick)
				if not ok then warn("[Sim] daily: " .. tostring(err)) end
			end
		end
	end)
end

-- ---------- debug hook ----------
-- The commands themselves live in server/Debug.lua (test-only code, and Sim.lua is at Luau's inference budget).
function Sim.debug(cmd: string, ...): any
	return Debug.run(cmd, ...)
end

function Sim.world(): WorldGen.World
	return world
end

return Sim
