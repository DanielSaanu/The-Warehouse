--!nonstrict
-- Sim.state <-> a saved record (docs/ARCHITECTURE.md A4). snapshot() is what a save writes; apply() is the RESTORE
-- path: it lays a decoded record over Sim.state and rebuilds everything that is deliberately NOT saved - bodies for
-- the living, routes, camp and bag tiles on the map, the calamity's overlay, the map the clients are sent.
-- Owns nothing durable. The shape of the save is shared/Save.lua's; the DataStore is Persistence.lua's (A5).
-- It does not `require` Sim: like Sides and Debug it is bound in from Sim.init, because it needs Sim's innards.
-- Generating a NEW world is still Sim.init's initTribes/initGroups; this is the other constructor, and a world is
-- built by exactly one of the two - run both and every boot adds 39 duplicate villagers to the registry.
--   local data = Restore.snapshot()          -- a JSON-safe table (Save.check passes)
--   local ok, why = Restore.apply(data)      -- the running world becomes the saved one
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rng = require(Shared:WaitForChild("Rng"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Ecology = require(Shared:WaitForChild("Ecology"))
local Calamity = require(Shared:WaitForChild("Calamity"))
local Tick = require(Shared:WaitForChild("Tick"))
local Save = require(Shared:WaitForChild("Save"))
local Reputation = require(Shared:WaitForChild("Reputation"))
local Headlines = require(Shared:WaitForChild("Headlines"))
local Map = require(script.Parent:WaitForChild("Map"))
local Calendar = require(script.Parent:WaitForChild("Calendar"))

local Restore = {}

local O = TileTypes.ObjectByName
local VILLAGE_SPRITE = { farmer = "villager", hunter = "hunter", plunderer = "bandit" }

local S, world
local spawnPerson, removeEntity, groupScratch, getRng, playerRestPoint, notice

function Restore.bind(ctx)
	S, world = ctx.S, ctx.world
	spawnPerson, removeEntity, groupScratch, getRng = ctx.spawnPerson, ctx.removeEntity, ctx.groupScratch, ctx.getRng
	playerRestPoint, notice = ctx.playerRestPoint, ctx.notice
end

--- The world as a save would write it, stamped with the wall time (the ONE durable use of os.time: on load,
--- `os.time() - savedAt` is how long the world slept).
function Restore.snapshot()
	Calendar.now() -- fold the wall time since the last tick into gameSeconds before it is copied
	return Save.encode(S, { seed = world.seed, rngState = getRng().s, savedAt = os.time() })
end

-- ---------- a returning player ----------
--- Lay a player's own key over their fresh live record, and say where they should stand: where they left (the
--- caller still finds the nearest FREE tile - that one may be a wall, a flood or a campfire by now), or their rest
--- point if they left dead. Standing fades once for the days they were away: the daily tick only fades players who
--- are online, so without this an absent player would never be forgiven anything.
function Restore.player(ps, saved, x: number, y: number): (number, number)
	local sx, sy = Save.applyPlayer(ps, saved)
	if sx and sy then
		x, y = sx, sy
	elseif saved.version == Save.PLAYER_VERSION then
		local p = playerRestPoint(ps)
		x, y = p.x, p.y
	end
	local lastSeen = saved.lastSeenDay or S.day
	local away = math.max(0, S.day - lastSeen)
	if away > 0 then
		for tribe, v in pairs(ps.rep) do ps.rep[tribe] = Reputation.fade(v, away) end
	end
	-- "You were gone eleven days": the world's headlines since they left, from the tribes that would tell them -
	-- the village they sleep in, and anyone who is not wary of them. The server sends it once the client can show it.
	local names = {}
	for i, t in ipairs(S.tribes) do names[i] = Map.village(t.villageId).name end
	ps.welcome = Headlines.welcome(S.meta, S.people, lastSeen, S.day, function(tribe: number): boolean
		if ps.rest.kind == "village" and ps.rest.village == tribe then return true end
		return Reputation.allowsRest(ps.rep[S.tribes[tribe].tribeType] or 0)
	end, names)
	return x, y
end

-- ---------- bodies ----------
--- Where, and as what, a living person stands when the world is rebuilt. Bodies are projections (R1): nobody's
--- tile is saved, so everyone is simply at home, doing their job.
local function placeBody(p, v, place: Rng.Rng, firstGuard: boolean)
	local inside = function() return place:int(v.x0 + 1, v.x1 - 1), place:int(v.y0 + 1, v.y1 - 1) end
	local x, y = inside()
	if p.stage == "baby" then
		return spawnPerson("baby", x, y, p.tribe, { person = p, role = "baby", radius = 0, label = p.first })
	elseif p.stage == "pregnant" then
		return spawnPerson("pregnant", x, y, p.tribe, { person = p, role = "pregnant", radius = 2 })
	elseif p.role == "guard" then
		if firstGuard then
			-- the gate guard stands just inside the first gate (or by the road for open villages), as in initTribes
			x, y = v.spawn.x + 2, v.spawn.y - 1
			if #v.gates > 0 then
				local g = v.gates[1]
				x, y = g.x + (g.x - g.exit.x), g.y + (g.y - g.exit.y)
			end
		end
		return spawnPerson("guard", x, y, p.tribe, { person = p, role = "guard", radius = if firstGuard then 1 else 3, label = "guard" })
	elseif p.role == "merchant" then
		return spawnPerson("merchant", v.stall.x, v.stall.y + 1, p.tribe, { person = p, role = "merchant", radius = 1, label = "merchant" })
	elseif p.role == "survivor" then
		return spawnPerson("survivor", v.spawn.x - 1, v.spawn.y, p.tribe, { person = p, role = "survivor", radius = 0, facing = "right" })
	elseif p.role == "hunter" or p.role == "bandit" then
		return spawnPerson(p.role, x, y, p.tribe, { person = p, role = p.role, radius = 3, sprite = if p.role == "bandit" then "bandit" else nil })
	end
	return spawnPerson("villager", x, y, p.tribe, { person = p, role = "villager", radius = 3, sprite = VILLAGE_SPRITE[S.tribes[p.tribe].tribeType] })
end

local function restoreBodies()
	local place = Rng.new(world.seed * 13 + 5) -- where people stand is not the world's business: its own stream
	local living = {}
	for _, p in pairs(S.people.people) do
		p.entity = nil
		if p.alive then table.insert(living, p) end
	end
	table.sort(living, function(a, b) return a.id < b.id end)
	local n = 0
	for _, p in ipairs(living) do
		local t = S.tribes[p.tribe]
		local e = placeBody(p, Map.village(t.villageId), place, p.role == "guard" and t.guard == nil)
		if e then
			n += 1
			-- re-point the tribe's role holders: entity ids are never saved, so these are always rebuilt
			if p.role == "guard" and not t.guard then t.guard = e.id end
			if p.role == "merchant" and not t.merchant then t.merchant = e.id end
			if p.role == "survivor" then t.survivor = e.id end
		end
	end
	return n, #living
end

-- ---------- apply ----------
--- Make the running world the saved one. Everything live is thrown away first (bodies, overlay, stamped tiles),
--- then the record goes in and the projections are rebuilt from it. Players stay where they are: their state is
--- their own key's business. `slept` is how many real seconds the world was down: that much game time (capped at
--- four in-game weeks) is caught up ON THE RECORDS, before anything gets a body or the map gets its overlay.
--- Returns ok, or false and why (and the running world is untouched).
function Restore.apply(data, slept: number?): (boolean, string?)
	local ok, why = Save.check(data)
	if not ok then return false, "not a save: " .. tostring(why) end
	local rec, err = Save.decode(data)
	if not rec then return false, err end
	if rec.meta.seed ~= world.seed then return false, ("the save is of seed %s, this map is seed %s"):format(tostring(rec.meta.seed), tostring(world.seed)) end

	-- 1. tear down: bodies, the overlay, and the camp/bag tiles stamped on the map
	for _, e in pairs(table.clone(S.entities)) do removeEntity(e) end
	if world.floodBackup then WorldGen.clearFlood(world) end
	for _, c in pairs(S.camps) do world.object[WorldGen.index(world, c.x, c.y)] = 0 end
	for _, b in pairs(S.bags) do world.object[WorldGen.index(world, b.x, b.y)] = 0 end

	-- 2. the record
	local regions = Ecology.init(world, Rng.new(world.seed):fork(1)) -- the DERIVED half (forest, village, col/row) is the map's
	for i, row in ipairs(rec.regions) do
		for k, v in pairs(row) do regions.list[i][k] = v end
	end
	for _, r in ipairs(regions.list) do r.live, r.tide = { deer = 0, boar = 0, wolf = 0 }, false end
	S.meta, S.calamity, S.regions, S.tribes = rec.meta, rec.calamity, regions, rec.tribes
	S.people, S.groups, S.camps, S.bags = rec.people, rec.groups, rec.camps, rec.bags
	Calendar.bind(S.meta)
	getRng().s = rec.meta.rngState
	S.day = Calendar.clock()

	-- 3. routes (derived from from/to), then the time the world slept through - on records only
	for _, g in pairs(S.groups) do
		groupScratch(g)
		Tick.rebuildRoute(g, world)
	end
	local report = Tick.catchUp(S, world, getRng(), slept or 0)
	Calendar.bind(S.meta) -- game time starts flowing again from the caught-up moment
	S.day = Calendar.clock()

	-- 4. the projections: stamped tiles, the overlay (only if the calamity outlived the sleep), bodies
	for _, c in pairs(S.camps) do world.object[WorldGen.index(world, c.x, c.y)] = if c.out then O.camp_out.id else O.camp_lit.id end
	for _, b in pairs(S.bags) do world.object[WorldGen.index(world, b.x, b.y)] = O.bag.id end
	local c = S.calamity
	if c.active and c.kind then c.flood = Calamity.applyOverlay(world, S.regions, c.kind) end -- the overlay ONLY
	local bodies, living = restoreBodies()

	-- 5. what the client is sent is rebuilt LAST, from the finished map
	Map.reencode()
	-- ...and anyone ALREADY connected (only ever true for Debug reload/savetest: a real boot restores before the
	-- door opens) still has the old calamity on screen. The client keeps its map, so tell it the one thing that can
	-- have changed under it: the water is up, or the water is down.
	for _, ps in pairs(S.players) do
		if c.active then
			notice(ps, "calamity", { kind = c.kind, phase = "start", text = Calamity.notice(c.kind), flood = c.flood })
		else
			notice(ps, "calamity", { kind = "flood", phase = "end", text = "The world has been reloaded." })
		end
	end
	print(("[Restore] day %d, %d living (%d bodies), %d groups, %d camps, %d bags%s; slept %d s = %d days"):format(S.day,
		living, bodies, #data.groups, #data.camps, #data.bags,
		if c.active then ", " .. tostring(c.kind) .. " in progress" else "", report.seconds, report.days))
	return true, nil
end

return Restore
