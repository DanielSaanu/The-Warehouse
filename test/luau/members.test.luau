-- Stable group members (docs/ARCHITECTURE.md B1): the caravan, the squad and the band are made of PEOPLE in the
-- family registry, not anonymous specs re-rolled on every materialise. Gossip (rung 3 part 3) stands on this: an
-- NPC can only remember and retell what it saw if it is the same person tomorrow.
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Config = __require("Config")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local Tick = __require("Tick")
local Save = __require("Save")

local world = WorldGen.generate(1)

local function newRecord()
	local rng = Rng.new(9)
	local w = {
		meta = { gameSeconds = 0, lastDailyTick = 1, nextBagId = 0 }, day = 1,
		tribes = {}, people = Families.new(), regions = Ecology.init(world, rng:fork(1)), groups = {}, camps = {}, bags = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	}
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { tribeType = v.tribeType, villageId = i, stock = Trade.newStock(v.tribeType), population = 10, surnames = { "Ash", "Birch" } }
		for n = 1, 13 do Families.newAdult(w.people, rng, i, i, "villager", 1, nil, if n % 2 == 0 then "f" else "m") end
	end
	local hunter = world.villages[2]
	local g = { id = "squad", kind = "squad", tribe = 2, pos = 1, dir = 1, acc = 0, speed = 2, pauses = { 60, 90 },
		from = { x = hunter.spawn.x, y = hunter.spawn.y }, to = { x = world.villages[1].spawn.x, y = world.villages[1].spawn.y },
		pauseUntil = 30, members = {}, fullSize = 4, carry = {}, retreatUntil = 0 }
	for _ = 1, 4 do Tick.enlist(w, rng, g, "hunter", nil, 1) end
	Tick.rebuildRoute(g, world)
	w.groups.squad = g
	return w, rng
end

-- Members are people of the tribe, on the road.
local w, rng = newRecord()
local g = w.groups.squad
assert(#g.members == 4, "four hunters enlisted")
for _, m in ipairs(g.members) do
	local p = w.people.people[m.person]
	assert(p and p.alive and p.tribe == 2 and p.group == "squad" and p.role == "hunter", "a member is a living person of the tribe, marked as on the road")
	assert(p.last == "Ash" or p.last == "Birch", "with one of the tribe's surnames, so relatives can find them")
end

-- ...and they do not count as villagers: not toward the cap, not for pairing, not as heirs.
assert(#Families.villagers(w.people, 2) == 13, "the squad does not count toward Kenstow's living cap")
Families.formCouples(w.people, 2, 1)
for _, m in ipairs(g.members) do assert(w.people.people[m.person].spouse == nil, "nobody marries someone who is never home") end
do
	local mothers = 0
	for wk = 1, 12 do mothers += #Families.weeklyConceive(w.people, rng, 2, wk * 7, "hunter") end
	assert(mothers >= 1, "a hunter village with a squad out still has room for children")
end

-- A death is one particular person, and the replacement is a NEW person: the dead stay dead.
do
	local lost = g.members[2].person
	Families.die(w.people, lost, 3, "killed", "a wolf")
	table.remove(g.members, 2)
	g.replenishAt = 0
	local before = w.people.nextId
	Tick.daily(w, rng, 4, 10)
	assert(#g.members == 4, "the squad is made whole at home")
	local fresh = g.members[4].person
	assert(fresh > before and fresh ~= lost and w.people.people[fresh].group == "squad", "by somebody new")
	assert(not w.people.people[lost].alive, "and the dead hunter is still in the registry, dead")
end

-- The same faces survive a save.
do
	local data = Save.encode(w, { seed = 1, rngState = 1, savedAt = 0 })
	assert(Save.check(data))
	local back = Save.decode(data)
	assert(back, "a v2 save decodes")
	for i, m in ipairs(g.members) do
		assert(back.groups.squad.members[i].person == m.person, "member ids round-trip")
		assert(back.people.people[m.person].group == "squad", "and so does being on the road")
	end
	-- a v1 world (anonymous members) is obsolete, not damaged: a new world is started over it
	data.meta.version = 1
	local rec, why, obsolete = Save.decode(data)
	assert(rec == nil and obsolete == true and why:find("new world"), "a v1 save is obsolete: " .. tostring(why))
	data.meta.version = 99
	local rec2, _, obsolete2 = Save.decode(data)
	assert(rec2 == nil and not obsolete2, "a save from the future is left alone, not overwritten")
end

-- Catch-up never changes who is in a group unless somebody is replaced.
do
	local w2, rng2 = newRecord()
	local ids = {}
	for i, m in ipairs(w2.groups.squad.members) do ids[i] = m.person end
	Tick.catchUp(w2, world, rng2, 3 * Config.DAY_SECONDS)
	for i, m in ipairs(w2.groups.squad.members) do assert(m.person == ids[i], "three days asleep and it is the same four hunters") end
end

print("    members ok")
