-- shared/Belong.lua: riding along with a group (docs/plans/rung3-part4-belonging.md, phase 1). Every rule the
-- server's Ride.lua leans on, with no entities and no server.
local Belong = __require("Belong")
local Reputation = __require("Reputation")
local Gossip = __require("Gossip")
local Talk = __require("Talk")
local Config = __require("Config")

--- A stranger in good standing asking the caravan: every check passes.
local function facts(over)
	local f = { kind = "caravan", busy = false, askedToday = false, riders = 0, cap = Config.RIDERS_MAX, grudge = 0,
		heardKill = nil, groupRep = 20, villageRep = 20, farmerRep = 20 }
	for k, v in pairs(over or {}) do f[k] = v end
	return f
end

-- ---------- the ask: each check fires, in the plan's order ----------
assert(Belong.ask(facts()) == "yes", "a welcome stranger rides with the caravan")
assert(Belong.ask(facts({ busy = true, askedToday = true, riders = 2 })) == "busy", "fighting comes first")
assert(Belong.ask(facts({ askedToday = true, riders = 2 })) == "asked", "then the day's ask")
assert(Belong.ask(facts({ riders = Config.RIDERS_MAX, grudge = 1 })) == "full", "then the cap (Q2)")
assert(Config.RIDERS_MAX == 2, "at most two riders per group (Q2)")
assert(Belong.ask(facts({ grudge = Belong.GRUDGE_NO, heardKill = "hunter" })) == "grudge", "then a grudge")
assert(Belong.ask(facts({ grudge = Belong.GRUDGE_NO - 0.01 })) == "yes", "a scar below the line is not a no")
local a, why = Belong.ask(facts({ heardKill = "caravan_guard", groupRep = -40 }))
assert(a == "heard" and why == "caravan_guard", "then a killing they heard of, and the reason names it")
-- the LOWER of the group's and the village's number (Q5)
assert(Belong.ask(facts({ groupRep = 14, villageRep = 60 })) == "standing", "the group's number is the lower")
assert(Belong.ask(facts({ groupRep = 60, villageRep = 14 })) == "standing", "the village's number is the lower")
assert(Belong.ask(facts({ groupRep = 15, villageRep = 15 })) == "yes", "welcome (15) is enough for the caravan")
-- a new player: farmer START 20 rides at once, hunter START 0 must earn the squad
assert(Belong.ask(facts({ groupRep = Reputation.START.farmer, villageRep = Reputation.START.farmer })) == "yes",
	"the caravan is the first-minute group")
assert(Belong.ask(facts({ kind = "squad", groupRep = Reputation.START.hunter, villageRep = Reputation.START.hunter })) == "standing",
	"a stranger has to earn the squad")
-- the band (phase 3 offers it; the rule is here already)
assert(Belong.ask(facts({ kind = "band", groupRep = -10, villageRep = -10, farmerRep = 0 })) == "yes", "the band talks at -10")
assert(Belong.ask(facts({ kind = "band", groupRep = -10, villageRep = -10, farmerRep = 50 })) == "snub", "not the farmers' family")
-- what spends the day's ask: only a no, and not "not now"
assert(Belong.spendsAsk("standing") and Belong.spendsAsk("heard") and Belong.spendsAsk("full"), "a no spends the ask")
assert(not Belong.spendsAsk("busy") and not Belong.spendsAsk("yes"), "not now and yes do not")

-- ---------- the pot and the share ----------
assert(Belong.value({ hide = 4, food = 5 }) == 4 * 6 + 5 * 3, "the carry at base prices")
assert(Belong.pot("caravan", {}, 1) == Belong.CARAVAN_POT, "the caravan's wage at the far end")
assert(Belong.pot("caravan", { hide = 1 }, -1) == Belong.CARAVAN_POT + 6, "home: the wage plus the carry")
assert(Belong.pot("squad", { hide = 4 }, 1) == 0, "the squad's far end pays nothing: the carry is not home")
assert(Belong.pot("squad", { hide = 4 }, -1) == 24, "home, the carry is the pot")
-- full crew of 3 plus one rider who walked the whole leg: 30 / 4
assert(Belong.share(30, 3, 3, 4, 50, 50) == 7, "a full crew splits four ways")
assert(Belong.share(30, 2, 3, 3, 50, 50) == math.floor(30 * 2 / 3 / 3), "a member lost cuts every share")
assert(Belong.share(30, 3, 3, 4, 25, 50) == 3, "half the leg walked, half the share")
assert(Belong.share(30, 3, 3, 4, 80, 50) == 7, "never more than a full share")
assert(Belong.share(30, 3, 3, 4, 0, 50) == 0 and Belong.share(0, 3, 3, 4, 50, 50) == 0, "nothing walked or nothing in the pot")
assert(Belong.share(30, 0, 3, 1, 50, 50) == 0, "a crew wiped out pays nobody")
assert(Belong.heard(25, 50) and not Belong.heard(24, 50) and not Belong.heard(5, 0), "half the leg and the village hears")

-- ---------- leaving ----------
assert(Belong.leaveGrade(true, false) == "clean" and Belong.leaveGrade(false, false) == "left", "an end, or the road")
assert(Belong.leaveGrade(false, true) == "away" and Belong.leaveGrade(true, true) == "away", "a disconnect is stepping away (Q1)")
assert(Belong.leaveDelta("clean") > 0 and Belong.leaveDelta("left") == -3 and Belong.leaveDelta("away") == 0, "what each costs")

-- ---------- the leader waits ----------
assert(not Belong.wait(Belong.LAG, 20), "close enough: no wait")
assert(Belong.wait(Belong.LAG + 1, 20), "behind: wait")
assert(not Belong.wait(Belong.LAG + 1, 0), "out of patience for this leg: walk on")
assert(not Belong.wait(Belong.LEAVE + 1, 20), "walked off: no wait")

-- ---------- the rumour it leaves ----------
assert(Gossip.TRAVELS.rode, "riding a leg is news that travels")
local d = Reputation.deltas("rode", "caravan", "farmer")
assert(d.farmer == 4 and d.hunter == 3 and d.plunderer == -2, "the caravan's people, its partners, its enemies")
local b = Reputation.deltas("rode", "band", "plunderer")
assert(b.plunderer == 4 and b.farmer == -4 and b.hunter == -4, "riding with the band is the mirror")

-- ---------- the lines name where, what and pay ----------
local yes = Talk.joinYes("caravan", { dest = "Kenstow", home = "Glenworth" })
assert(yes:find("Kenstow") and yes:find("bandits") and yes:find("share"), "the yes names the place, the job and the pay")
assert(Talk.joinYes("squad", { dest = "Kenstow", home = "Kenstow", homeward = true }):find("home to Kenstow"),
	"a squad walking home says so, not 'out for deer in Kenstow' (seen in Studio)")
assert(Talk.joinNo("heard", { dest = "", home = "", reason = "hunter" }):find("hunter"), "a no says what they heard")
assert(Talk.joinNo("standing", { dest = "", home = "Glenworth" }):find("Glenworth"), "and where to earn it")
local arr = Talk.arrival({ dest = "Kenstow", home = "", pay = 7, heard = true, scarce = "food" })
assert(arr:find("7 coin") and arr:find("Kenstow will hear") and arr:find("food"), "arrival: pay, news, one pointer")
assert(Talk.TOPIC_LABELS.ride and Talk.TOPIC_LABELS.leave, "the client gets labels for the two topics")
assert(not table.find(Talk.TOPICS, "ride"), "guards do not offer to take you along")

-- ---------- through the real gossip path, and the save (Q3: a ride is never saved) ----------
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local Save = __require("Save")
local Tick = __require("Tick")
local world = WorldGen.generate(1)
local HUNTER = 2 -- seed 1: 1 Glenworth (farmer), 2 Kenstow (hunter), 3 Wild's Rest (plunderer)

--- A World Record the way Sim.init builds one (as in gossip.test.luau), with the squad and one player.
local function newRecord()
	local rng = Rng.new(5)
	local w = {
		meta = { gameSeconds = 0, lastDailyTick = 1, nextRumourId = 0, lastContactSlot = -1, nextBagId = 0 }, day = 1,
		tribes = {}, villages = {}, rumours = {}, owed = {}, people = Families.new(),
		regions = Ecology.init(world, rng:fork(1)), groups = {}, players = {}, camps = {}, bags = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	}
	local seedRep = {}
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { villageId = i, tribeType = v.tribeType, stock = Trade.newStock(v.tribeType), population = 10, surnames = { "Ash" } }
		w.villages[i] = { id = i, knows = {}, hops = {} }
		seedRep[Gossip.villageKey(i)] = v.tribeType
	end
	local home, wood = world.villages[HUNTER], world.villages[1]
	local g = { id = "squad", kind = "squad", tribe = HUNTER, pos = 1, dir = 1, acc = 0, speed = 2, pauses = { 10, 10 },
		pauseUntil = 0, knows = {}, hops = {}, from = { x = home.spawn.x, y = home.spawn.y }, to = { x = wood.spawn.x, y = wood.spawn.y },
		members = {}, fullSize = 4, carry = {}, retreatUntil = 0 }
	for _ = 1, 4 do Tick.enlist(w, rng, g, "hunter", nil, 1) end
	Tick.rebuildRoute(g, world)
	w.groups.squad = g
	local ps = { player = { UserId = 7, Name = "Danzo" }, rep = Reputation.newTable(seedRep), grudge = {} }
	w.players[7] = ps
	return w, ps
end

-- the rumour is seeded at the group (hop 0) and the village hears it one hand weaker when the squad comes home
local w, ps = newRecord()
local kenstow = Gossip.villageKey(HUNTER)
local before = Gossip.standing(w, ps, kenstow)
assert(Gossip.seed(w, 7, "rode", "squad", HUNTER, {}, 1, { squad = true }), "a ridden leg is a rumour at the group")
assert(Gossip.standing(w, ps, "squad") > Reputation.START.hunter, "the squad thinks better of you at once")
assert(Gossip.standing(w, ps, kenstow) == before, "Kenstow has not heard yet: it travels with the squad")
local g = w.groups.squad
g.pos, g.dir = 1, -1 -- walking back into Kenstow: the end at which Tick.groupTurn calls Gossip.arrive
Tick.groupTurn(w, g, 0, {}, world)
assert(math.abs(Gossip.standing(w, ps, kenstow) - (before + 4 * Gossip.HOP_FADE)) < 1e-6, "Kenstow hears it, one hop weaker")

-- Found in Studio (phase 1): the caravan stood beside Kenstow's spawn for good, because a squad hunter waited on that
-- tile and "walk on to the one after it" has no tile after the last. Beside a taken END tile is arrived.
do
	local w2 = newRecord()
	local sq = w2.groups.squad
	sq.pos, sq.dir, sq.materialised = 2, -1, true -- one tile from home
	local home = sq.route[1]
	local leader = { x = sq.route[2].x, y = sq.route[2].y }
	local ops = { free = function() return false end, step = function() end, path = function() return false end }
	local act
	for _ = 1, 8 do
		act = Tick.leaderStep(sq, leader.x, leader.y, false, ops)
		if act == "turn" then break end
	end
	assert(math.abs(leader.x - home.x) + math.abs(leader.y - home.y) <= 1, "the fixture leader is beside the end tile")
	assert(act == "turn", "a leader beside a taken end tile turns instead of waiting forever")
end

-- a ridden group encodes exactly as an unridden one, and `rode` survives a save in the ring
local function same(a, b): boolean
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do if not same(v, b[k]) then return false end end
	for k in pairs(b) do if a[k] == nil then return false end end
	return true
end
local stamp = { seed = 1, rngState = 1, savedAt = 0 }
local plain = Save.encode(w, stamp)
g.riders, g.walked, g.lastPos, g.waitLeft, g.holding = { [7] = { rode = 30, legs = 1 } }, 30, 4, 12, true
ps.ride, ps.asked = "squad", { squad = 1 }
assert(same(plain, Save.encode(w, stamp)), "riders are scratch: the world key does not change (Q3)")
local p1 = Save.encodePlayer({ x = 1, y = 1, hp = 5, inv = { coin = 3, slots = {} }, rep = ps.rep, rest = {}, grudge = {} }, 1, "w")
assert(p1.ride == nil and p1.asked == nil, "nor does the player key")
local ok, err = Save.check(plain)
assert(ok, "the save checks: " .. tostring(err))
local back = Save.decode(plain)
assert(back and back.rumours[1].event == "rode", "a `rode` rumour round-trips with Save.VERSION " .. Save.VERSION)
assert(Save.VERSION == 4 and Save.PLAYER_VERSION == 1, "no version bump for part 4 (Q3)")

print("    belong ok")
