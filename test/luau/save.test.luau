-- shared/Save.lua: the World Record <-> what goes in a DataStore (docs/ARCHITECTURE.md §2, A4).
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Config = __require("Config")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local Items = __require("Items")
local Reputation = __require("Reputation")
local Tick = __require("Tick")
local Save = __require("Save")

local world = WorldGen.generate(1)
local DAY = Config.DAY_SECONDS

local function deepEqual(a, b, path: string): (boolean, string?)
	if type(a) ~= type(b) then return false, path .. ": " .. type(a) .. " vs " .. type(b) end
	if type(a) ~= "table" then return a == b, if a == b then nil else ("%s: %s vs %s"):format(path, tostring(a), tostring(b)) end
	for k, v in pairs(a) do
		local ok, why = deepEqual(v, b[k], path .. "." .. tostring(k))
		if not ok then return false, why end
	end
	for k in pairs(b) do if a[k] == nil then return false, path .. "." .. tostring(k) .. ": only on the right" end end
	return true, nil
end

--- A lived-in record: three tribes, families, a caravan part way down its road, camps keyed by big sparse user
--- ids, a bag, a running flood - plus the TRANSIENT clutter the live server hangs on the same tables.
local function livedIn()
	local rng = Rng.new(21)
	local w = {
		meta = { gameSeconds = 0, lastDailyTick = 1, nextBagId = 0 }, day = 1,
		tribes = {}, people = Families.new(), regions = Ecology.init(world, rng:fork(1)), groups = {}, camps = {}, bags = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	}
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { villageId = i, tribeType = v.tribeType, stock = Trade.newStock(v.tribeType), population = 12, walled = i == 1,
			surnames = { "Ash", "Birch" }, guard = "e1", merchant = "e5", survivor = "e14" }
		for n = 1, 6 do Families.newAdult(w.people, rng, i, i, "villager", 1, nil, if n % 2 == 0 then "f" else "m") end
	end
	local farmer, hunter = world.villages[1], world.villages[2]
	local g = { id = "caravan", kind = "caravan", tribe = 1, pos = 1, dir = 1, acc = 0, speed = 1.5, pauses = { 120, 120 },
		from = { x = farmer.spawn.x, y = farmer.spawn.y }, to = { x = hunter.spawn.x, y = hunter.spawn.y },
		pauseUntil = 30, members = { { kind = "caravan_master", role = "caravan_master" }, { kind = "caravan_guard" } }, fullSize = 3, carry = {},
		entities = { e40 = true }, leader = "e40", target = "e9", materialised = false, trail = {}, aggroUntil = 0 }
	Tick.rebuildRoute(g, world)
	w.groups.caravan = g
	Tick.catchUp(w, world, rng, DAY * 30 + 123)
	g.carry = { hide = 2 }
	for _, r in ipairs(w.regions.list) do r.live = { deer = 3, boar = 0, wolf = 1 } end
	for _, p in pairs(w.people.people) do p.entity = "e" .. p.id end
	w.camps[4100200300] = { owner = 4100200300, x = 30, y = 70, litUntil = w.meta.gameSeconds + 500, out = false }
	w.camps[77] = { owner = 77, x = 31, y = 70, litUntil = 12, out = true }
	w.meta.nextBagId = 3
	w.bags.b3 = { id = "b3", x = 28, y = 69, owner = 77, slots = { { item = "food", n = 2 } }, droppedAt = w.meta.gameSeconds - 40 }
	w.calamity.kind, w.calamity.active, w.calamity.day, w.calamity.flood = "flood", true, w.day, { 1, 2, 3 }
	return w, rng
end

local STAMP = { seed = 1, rngState = 123456789, savedAt = 1790000000 }

-- The saved table is JSON-safe, and it holds the record and none of the clutter.
do
	local w = livedIn()
	local data = Save.encode(w, STAMP)
	local ok, why = Save.check(data)
	assert(ok, "a save must be JSON-safe: " .. tostring(why))
	assert(data.meta.version == Save.VERSION and data.meta.genVersion == WorldGen.GEN_VERSION and data.meta.seed == 1, "stamped")
	assert(data.meta.gameSeconds == w.meta.gameSeconds and data.meta.savedAt == STAMP.savedAt, "the clock and the wall stamp")
	local cg = data.groups[1]
	assert(cg.id == "caravan" and cg.to.x == w.groups.caravan.to.x and cg.carry.hide == 2, "the group's record")
	assert(cg.route == nil and cg.entities == nil and cg.leader == nil and cg.target == nil and cg.materialised == nil, "no route, no entity ids")
	assert(data.tribes[1].guard == nil and data.tribes[1].merchant == nil and data.tribes[1].survivor == nil, "tribe rows hold no entity ids")
	assert(data.tribes[1].villageId == 1 and data.tribes[1].village == nil, "a village id, never a village")
	assert(data.regions[1].live == nil and data.regions[1].forest == nil and data.regions[1].tide == nil, "regions: counts only")
	assert(data.calamity.flood == nil and data.calamity.kind == "flood", "the calamity, not its tiles")
	for _, row in ipairs(data.people.rows) do assert(row.entity == nil and row.children == nil, "people: no entity id, no derived children") end
end

-- The round trip. In memory ids are NUMBERS and maps are keyed by them; after decode they still are - this is the
-- assertion that fails if anybody saves an id-keyed map as a map (JSON would hand the keys back as strings).
do
	local w = livedIn()
	local data = Save.encode(w, STAMP)
	local back = assert(Save.decode(data))
	local n = 0
	for id, p in pairs(back.people.people) do
		n += 1
		assert(type(id) == "number" and p.id == id, "people are indexed by their numeric id")
		if p.father then assert(back.people.people[p.father], p.first .. "'s father resolves") end
		if p.mother then assert(back.people.people[p.mother], p.first .. "'s mother resolves") end
	end
	assert(n == #data.people.rows and n > 18, "everyone came back, babies included (" .. n .. ")")
	for id, p in pairs(w.people.people) do
		local ok, why = deepEqual(p.children, back.people.people[id].children, "children of " .. id)
		assert(ok, "children are rebuilt from father/mother exactly: " .. tostring(why))
	end
	assert(back.camps[4100200300] and back.camps[4100200300].x == 30 and back.camps[77].out == true, "camps are indexed by numeric user id")
	assert(back.bags.b3.slots[1].n == 2 and back.groups.caravan.pos == w.groups.caravan.pos, "bags and groups by id")
	assert(back.people.nextId == w.people.nextId and back.meta.nextBagId == 3, "the counters come back, so new ids cannot collide")
	-- a record that was saved, loaded and saved again is the same save
	back.day, back.regions = w.day, { list = back.regions }
	local ok, why = deepEqual(data, Save.encode(back, STAMP), "save")
	assert(ok, "encode(decode(x)) == x: " .. tostring(why))
end

-- Catch-up on a DECODED record works: the loaded world can be ticked (routes rebuilt from from/to first).
do
	local w, rng = livedIn()
	local back = assert(Save.decode(Save.encode(w, STAMP)))
	local regions = Ecology.init(world, Rng.new(1))
	for i, row in ipairs(back.regions) do for k, v in pairs(row) do regions.list[i][k] = v end end
	back.regions, back.day = regions, w.day
	for _, g in pairs(back.groups) do Tick.rebuildRoute(g, world) end
	assert(#back.groups.caravan.route == #w.groups.caravan.route, "the route is rebuilt from from/to")
	local report = Tick.catchUp(back, world, rng, DAY * 2)
	assert(report.days == 2 and back.calamity.active == false, "two days later the flood has ended")
end

-- Gravestones: long-dead people shrink, the family tree still resolves through them, and they never vanish.
do
	local w = livedIn()
	local child
	for _, p in pairs(w.people.people) do if p.mother then child = p break end end
	assert(child, "the fixture has at least one child")
	Families.die(w.people, child.mother, w.day - Save.PRUNE_DAYS - 1, "wolves", nil)
	Families.die(w.people, child.father, w.day - 1, "fever", nil)
	local data = Save.encode(w, STAMP)
	local grave, fresh
	for _, row in ipairs(data.people.rows) do
		if row.id == child.mother then grave = row elseif row.id == child.father then fresh = row end
	end
	assert(grave.alive == nil and grave.role == nil and grave.cause == "wolves" and grave.first, "a gravestone: name, dates, cause")
	assert(fresh.alive == false and fresh.role ~= nil, "the recently dead keep their full record")
	local back = assert(Save.decode(data))
	local m = back.people.people[child.mother]
	assert(m and m.alive == false and m.children[1] ~= nil, "the gravestone is a person again: dead, and still somebody's mother")
	assert(#Families.villagers(back.people, child.tribe) > 0, "Families still works over a registry with gravestones")
	assert(Save.check(data), "still JSON-safe")
end

-- A save from another map generator is a different world: decode refuses it (the caller starts a new world).
do
	local data = Save.encode(livedIn(), STAMP)
	data.meta.genVersion = WorldGen.GEN_VERSION + 1
	local back, why = Save.decode(data)
	assert(back == nil and why:find("new world"), "refused: " .. tostring(why))
	data.meta.genVersion, data.meta.version = WorldGen.GEN_VERSION, Save.VERSION + 1
	assert(Save.decode(data) == nil, "a save from the future is refused too")
end

-- Save.check catches what JSON would silently change.
do
	local function bad(t, needle: string)
		local ok, why = Save.check(t)
		assert(not ok and why:find(needle, 1, true), "expected '" .. needle .. "', got " .. tostring(why))
	end
	bad({ people = { [7] = { id = 7 } } }, "numeric key")
	bad({ camps = { [4100200300] = {} } }, "numeric key")
	assert(not Save.check({ a = { 1, 2, nil, 4 } }), "an array with a hole")
	bad({ lastAttack = -math.huge }, "finite")
	bad({ x = 0 / 0 }, "finite")
	bad({ snap = function() end }, "function")
	bad({ list = { 1, 2, name = "x" } }, "mixes")
	local shared = { x = 1 }
	bad({ a = shared, b = shared }, "twice")
	assert(Save.check({ a = {}, b = { 1, 2, 3 }, c = { d = "e", f = true } }), "plain data passes")
end

-- Players: their own key, named fields only - the live record holds a Player Instance, a function and -math.huge.
do
	local ps = { player = newproxy(), snap = function() end, lastAttack = -math.huge, budget = { t = 1 }, known = { e1 = true },
		x = 40, y = 41, hp = 7, maxHp = 10, inv = Items.dayOneKit(), rep = Reputation.newTable(), rest = { kind = "village", village = 2 },
		goalStage = 3, goalDone = false, metSurvivor = true }
	ps.inv.coin = 12
	ps.rep.hunter = 15
	local data = Save.encodePlayer(ps, 9)
	assert(Save.check(data), "a player save is JSON-safe")
	assert(data.player == nil and data.snap == nil and data.lastAttack == nil and data.known == nil, "none of the live clutter")
	local fresh = { x = 1, y = 1, hp = 10, inv = Items.dayOneKit(), rep = Reputation.newTable(), rest = { kind = "village", village = 1 }, goalStage = 0 }
	local x, y = Save.applyPlayer(fresh, data)
	assert(x == 40 and y == 41 and fresh.x == 1, "position is returned for the caller to validate, not applied")
	assert(fresh.hp == 7 and fresh.inv.coin == 12 and Items.count(fresh.inv, "food") == 2 and fresh.rep.hunter == 15, "kit, coin, standing")
	assert(fresh.rest.village == 2 and fresh.goalStage == 3 and fresh.metSurvivor == true and data.lastSeenDay == 9, "rest, goal, last seen")
	assert(Save.applyPlayer(fresh, { version = 99 }) == nil, "an unknown player version is ignored, not half-applied")
	-- the people a player has met (they see names, not trades) travel with the player, capped
	ps.met = { [7] = true, [43] = true }
	local d2 = Save.encodePlayer(ps, 9, "1-100-7")
	assert(Save.check(d2) and #d2.met == 2 and d2.met[1] == 7 and d2.metWorld == "1-100-7", "met people are saved as a sorted array of ids, with the world they belong to")
	Save.applyPlayer(fresh, d2, "1-100-7")
	assert(fresh.met[7] and fresh.met[43] and not fresh.met[8], "and come back as a set in the same world")
	-- person ids mean nothing in another world: after a reset, id 7 is somebody else (QA round 2)
	Save.applyPlayer(fresh, d2, "1-200-9")
	assert(next(fresh.met) == nil, "a different world: nobody is an acquaintance")
	Save.applyPlayer(fresh, d2, nil)
	assert(next(fresh.met) == nil, "a world with no id yet: nobody is an acquaintance")
	Save.applyPlayer(fresh, data, "1-100-7")
	assert(next(fresh.met) == nil, "a key from before faces were remembered restores as nobody met")
	for id = 1, Save.MET_CAP + 20 do ps.met[id] = true end
	local d3 = Save.encodePlayer(ps, 9, "1-100-7")
	assert(#d3.met == Save.MET_CAP and d3.met[#d3.met] == Save.MET_CAP + 20, "the list is capped, keeping the newest ids")
end

-- v2 -> v3 (rung 3 part 3, gossip): the first real IN-PLACE migration. Nothing is lost and no world is reset - a v2
-- world comes back with everybody having heard nothing yet, which is the correct starting state.
do
	local w = livedIn()
	local data = Save.encode(w, { seed = 1, rngState = 7, savedAt = 1790000000 })
	-- forge a v2 key: the version it was written at, and none of the nodes v3 adds
	data.meta.version = 2
	data.villages, data.rumours, data.meta.nextRumourId = nil, nil, nil
	for _, g in ipairs(data.groups) do g.knows = nil end
	local before = { tribes = #data.tribes, groups = #data.groups, people = #data.people.rows, day = data.meta.gameSeconds }

	local rec, why, obsolete = Save.decode(data)
	assert(rec ~= nil, "a v2 world upgrades in place: " .. tostring(why))
	assert(not obsolete, "it is NOT obsolete - nobody has to start again")
	assert(data.meta.version == 3, "and it is stamped v3")
	assert(#rec.tribes == before.tribes, "every tribe row came through")
	assert(rec.meta.gameSeconds == before.day, "the clock is untouched")
	assert(rec.meta.nextRumourId == 0, "the ring starts empty")
	assert(#rec.rumours == 0, "nothing is travelling yet")
	local villages = 0
	for i, v in ipairs(rec.villages) do
		villages += 1
		assert(v.knows ~= nil and #v.knows == 0, ("village %d has heard nothing"):format(i))
	end
	assert(villages == before.tribes, "one village row per tribe row")
	for id, g in pairs(rec.groups) do assert(#g.knows == 0, "group " .. tostring(id) .. " has heard nothing") end
	local living = 0
	for _, p in pairs(rec.people.people) do if p.alive then living += 1 end end
	assert(living > 0, "the people came through")
	-- `migrate` upgraded the key in place, so the key ITSELF is now a valid v3 one: JSON-safe, with the new nodes.
	-- (The decoded record is not re-encodable here for the same reason the round-trip test above does not do it:
	-- `regions` decodes to bare rows, and the caller lays them over a fresh Ecology.init.)
	local ok2, why2 = Save.check(data)
	assert(ok2, "the migrated key is JSON-safe: " .. tostring(why2))
	assert(#data.villages == before.tribes and data.rumours ~= nil, "as v3, with its village rows and an empty ring")
	assert(#data.groups == before.groups and #data.people.rows == before.people, "and it lost nothing on the way")
end

-- The PLAYER key must not bump: applyPlayer discards a record whose version differs, so gossip's fields are additive.
do
	local ps = { player = newproxy(), x = 40, y = 41, hp = 7, maxHp = 10, inv = Items.dayOneKit(),
		rep = Reputation.newTable(), rest = { kind = "village", village = 2 }, goalStage = 3 }
	ps.inv.coin = 31
	local data = Save.encodePlayer(ps, 9, "1-100-7")
	assert(data.version == 1, "part 3 did NOT bump PLAYER_VERSION")
	data.grudge, data.heard = nil, nil -- a key written before grudges existed
	local fresh = { x = 1, y = 1, hp = 10, inv = Items.dayOneKit(), rep = {}, rest = { kind = "village", village = 1 }, goalStage = 0 }
	local x, y = Save.applyPlayer(fresh, data, "1-100-7")
	assert(x ~= nil, "an older player key still restores, coin and standing intact")
	assert(fresh.inv.coin == ps.inv.coin, "their coin survived")
	assert(type(fresh.grudge) == "table" and next(fresh.grudge) == nil, "no grudge, not a nil field")
	assert(type(fresh.heard) == "table", "and an empty heard set")
end

-- The lease: one server writes the world. Pure decisions, so they are tested here and Persistence only obeys them.
do
	local now = 1790000000
	assert(Save.mayWrite(nil, "A", now), "nobody has saved yet")
	assert(Save.mayWrite({ meta = {} }, "A", now), "a save with no lease (an old one) is free")
	local data = Save.stampLease({}, "A", now)
	assert(data.lease.untilTime == now + Save.LEASE_SECONDS, "a lease outlives a missed autosave or two")
	assert(Save.mayWrite(data, "A", now + 10), "the owner renews")
	assert(not Save.mayWrite(data, "B", now + 10), "a second server may not write while the lease is live")
	assert(Save.mayWrite(data, "B", now + Save.LEASE_SECONDS), "but takes over when the owner has gone quiet")
	Save.stampLease(data, "A", now, true)
	assert(Save.mayWrite(data, "B", now + 1), "a clean shutdown releases the lease at once")
	assert(Save.check(data), "the lease is JSON-safe too")
end

print("save ok")
