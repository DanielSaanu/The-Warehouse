-- shared/Headlines.lua: "You were gone eleven days." A ring of world-level headlines, and the welcome built from it.
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Config = __require("Config")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local Tick = __require("Tick")
local Save = __require("Save")
local Headlines = __require("Headlines")

local world = WorldGen.generate(1)
local NAMES = { "Glenworth", "Kenstow", "Wild's Rest" }
local everyone = function(_tribe: number): boolean return true end

local function record()
	local rng = Rng.new(11)
	local w = { meta = { gameSeconds = 0, lastDailyTick = 1, nextBagId = 0 }, day = 1, tribes = {}, people = Families.new(),
		regions = Ecology.init(world, rng:fork(1)), groups = {}, camps = {}, bags = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0 } }
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { villageId = i, tribeType = v.tribeType, stock = Trade.newStock(v.tribeType), population = 10, surnames = { "Ash" } }
		for n = 1, 6 do Families.newAdult(w.people, rng, i, i, "villager", 1, nil, if n % 2 == 0 then "f" else "m") end
	end
	return w, rng
end

-- The ring: newest kept, oldest dropped, never more than MAX.
do
	local meta = {}
	for day = 1, Headlines.MAX + 10 do Headlines.push(meta, { day = day, kind = "calamity", what = "flood" }) end
	assert(#meta.headlines == Headlines.MAX, "the ring is capped")
	assert(meta.headlines[1].day == 11 and meta.headlines[Headlines.MAX].day == Headlines.MAX + 10, "the oldest fall off")
end

-- Catch-up WRITES headlines: a world that ticked with nobody in it still has something to tell whoever comes back.
do
	local w, rng = record()
	Tick.catchUp(w, world, rng, Tick.CATCHUP_CAP)
	local births = 0
	for _, h in ipairs(w.meta.headlines) do
		assert(h.kind == "born" and w.people.people[h.id] and w.people.people[h.id].born == h.day, "a birth headline points at the baby")
		births += 1
	end
	assert(births > 0, "four unobserved weeks produce births, and they are headlines")
	local welcome = Headlines.welcome(w.meta, w.people, 1, w.day, everyone, NAMES)
	assert(welcome and welcome.days == 28 and welcome.text == "You were gone 28 days.", "the headline of the welcome is how long")
	assert(#welcome.lines == math.min(Headlines.SHOWN, births) and welcome.more == births - #welcome.lines, "a glance, and a count of the rest")
	assert(welcome.lines[1].text:find("had a baby") and welcome.lines[1].color == "good", welcome.lines[1].text)
	-- and they survive a save, as plain data
	local data = Save.encode(w, { seed = 1, rngState = 1, savedAt = 1 })
	assert(Save.check(data), "headlines are JSON-safe")
	local back = assert(Save.decode(data))
	assert(#back.meta.headlines == births, "and come back")
end

-- What is shown: a death outranks a flood outranks a birth; newest first within a kind; only what happened AFTER
-- they left; only from tribes that would tell them (a calamity is everybody's news).
do
	local w = record()
	local victim, baby
	for _, p in pairs(w.people.people) do if p.tribe == 1 and not victim then victim = p end end
	baby = Families.add(w.people, { first = "Pela", last = "Ash", sex = "f", tribe = 1, village = 1, role = "baby", stage = "baby", born = 5, mother = victim.id })
	Headlines.push(w.meta, { day = 2, kind = "died", tribe = 2, id = 7 })   -- before they left
	Headlines.push(w.meta, { day = 5, kind = "born", tribe = 1, id = baby.id })
	Headlines.push(w.meta, { day = 7, kind = "calamity", what = "flood" })
	Families.die(w.people, victim.id, 9, "killed", "Danzo")
	Headlines.push(w.meta, { day = 9, kind = "died", tribe = 1, id = victim.id }) -- the killer is the registry's, not the headline's
	Headlines.push(w.meta, { day = 9, kind = "died", tribe = 3, id = 13 })  -- the plunderers' business
	local tells = function(tribe: number): boolean return tribe ~= 3 end
	local welcome = Headlines.welcome(w.meta, w.people, 3, 14, tells, NAMES)
	assert(welcome.days == 11 and #welcome.lines == 3 and welcome.more == 0, "three things they would hear about")
	assert(welcome.lines[1].text == ("%s %s of Glenworth was killed by Danzo."):format(victim.first, victim.last), welcome.lines[1].text)
	assert(welcome.lines[1].color == "warn" and welcome.lines[3].color == "good", "a death and a birth do not read alike")
	assert(welcome.lines[2].text == "The river flooded the low ground.", welcome.lines[2].text)
	assert(welcome.lines[3].text == ("%s %s of Glenworth had a baby, Pela."):format(victim.first, victim.last), welcome.lines[3].text)
	assert(Headlines.welcome(w.meta, w.people, 14, 14, tells, NAMES) == nil, "not gone a day: no welcome")
	local one = Headlines.welcome(w.meta, w.people, 13, 14, tells, NAMES)
	assert(one.text == "You were gone a day." and #one.lines == 1 and one.lines[1].text == "It was quiet while you were away.", "nothing they would hear about is said, not left blank")
	-- a gravestone still has a name
	w.day = 9 + Save.PRUNE_DAYS + 2
	local back = assert(Save.decode(Save.encode(w, { seed = 1, rngState = 1, savedAt = 1 })))
	assert(back.people.people[victim.id].role == "dead", "the victim is a gravestone now")
	assert(Headlines.describe(w.meta.headlines[4], back.people, NAMES):find(victim.first, 1, true), "and the headline still names them")
end

-- A massacre does not bury its own cause: four deaths in a beast tide still say there was a tide.
do
	local w = record()
	Headlines.push(w.meta, { day = 7, kind = "calamity", what = "beast_tide" })
	local n = 0
	for _, p in pairs(w.people.people) do
		if p.tribe == 1 and n < 4 then
			n += 1
			Families.die(w.people, p.id, 7, "killed", "the wild")
			Headlines.push(w.meta, { day = 7, kind = "died", tribe = 1, id = p.id })
		end
	end
	local welcome = Headlines.welcome(w.meta, w.people, 5, 8, everyone, NAMES)
	assert(#welcome.lines == 3 and welcome.more == 2, "three shown of five")
	assert(welcome.lines[1].text:find("was killed") and not welcome.lines[1].text:find(" by "), "the wild is not named as a killer")
	assert(welcome.lines[3].text == "A beast tide came down from the north.", "the tide keeps the last place: " .. welcome.lines[3].text)
end

print("headlines ok")
