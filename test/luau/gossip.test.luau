-- shared/Gossip.lua: news that has to TRAVEL, and the scar it leaves (docs/RUNG3.md part 3, DESIGN.md §7).
-- Everything here runs with no entities and no server, which is the situation catch-up is in.
local WorldGen = __require("WorldGen")
local Rng = __require("Rng")
local Config = __require("Config")
local Ecology = __require("Ecology")
local Families = __require("Families")
local Trade = __require("Trade")
local Reputation = __require("Reputation")
local Gossip = __require("Gossip")
local Save = __require("Save")
local Tick = __require("Tick")

local world = WorldGen.generate(1)
local DAY = Config.DAY_SECONDS
-- seed 1: 1 Glenworth (farmer), 2 Kenstow (hunter), 3 Wild's Rest (plunderer)
local FARMER, HUNTER, BANDIT = 1, 2, 3

--- A World Record the way Sim.init builds one, with the gossip nodes and one player.
local function newRecord(seed: number)
	local rng = Rng.new(seed)
	local w = {
		meta = { gameSeconds = 0, lastDailyTick = 1, nextRumourId = 0, lastContactSlot = -1 }, day = 1,
		tribes = {}, villages = {}, rumours = {}, people = Families.new(),
		regions = Ecology.init(world, rng:fork(1)), groups = {}, players = {}, camps = {}, bags = {},
		calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
	}
	local seedRep = {}
	for i, v in ipairs(world.villages) do
		w.tribes[i] = { villageId = i, tribeType = v.tribeType, stock = Trade.newStock(v.tribeType), population = 10, surnames = { "Ash" } }
		w.villages[i] = { id = i, knows = {} }
		seedRep[Gossip.villageKey(i)] = v.tribeType
	end
	-- a hunter squad out of Kenstow, and the bandit band out of Wild's Rest
	for _, spec in ipairs({ { id = "squad", tribe = HUNTER }, { id = "band", tribe = BANDIT } }) do
		local from, to = world.villages[spec.tribe], world.villages[FARMER]
		local g = { id = spec.id, kind = if spec.id == "squad" then "squad" else "band", tribe = spec.tribe,
			pos = 1, dir = 1, acc = 0, speed = 1.5, pauses = { 10, 10 }, pauseUntil = 0, knows = {},
			from = { x = from.spawn.x, y = from.spawn.y }, to = { x = to.spawn.x, y = to.spawn.y },
			members = {}, fullSize = 4, carry = {} }
		Tick.rebuildRoute(g, world)
		w.groups[spec.id] = g
	end
	local ps = { player = { UserId = 7, Name = "Danzo" }, rep = Reputation.newTable(seedRep), grudge = {}, heard = {} }
	w.players[7] = ps
	return w, ps, rng
end

local function count(t: { any }): number
	local n = 0
	for _ in pairs(t) do n += 1 end
	return n
end

-- A rumour seeded at the squad does NOT move the hunter VILLAGE's number, and does after one contact - once.
-- This is the whole reason the ledger stopped being keyed by tribe type.
do
	local w, ps = newRecord(1)
	local vk = Gossip.villageKey(HUNTER)
	local before = Gossip.standing(w, ps, vk)
	local r = Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	assert(r ~= nil, "a witnessed kill makes a rumour")
	assert(Gossip.standing(w, ps, "squad") < before, "the squad that saw it thinks worse of you at once")
	assert(Gossip.standing(w, ps, vk) == before, "their VILLAGE has not heard yet: that is part 3")

	Gossip.arrive(w, w.groups.squad) -- the squad comes home
	local told = Gossip.standing(w, ps, vk)
	assert(told < before, "once they are home, the village knows")
	Gossip.arrive(w, w.groups.squad)
	Gossip.arrive(w, w.groups.squad)
	assert(Gossip.standing(w, ps, vk) == told, "and it is not booked a second time, however often they come home")
	print(("   squad %.1f, Kenstow %.1f (was %.1f)"):format(Gossip.standing(w, ps, "squad"), told, before))
end

-- Strength falls with hops: the far tribe gets a weaker, vaguer version of the same story.
do
	local w, ps = newRecord(2)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local atSquad = Gossip.standing(w, ps, "squad")
	Gossip.arrive(w, w.groups.squad)            -- hop 1: the village hears it from the squad
	local atVillage = Gossip.standing(w, ps, Gossip.villageKey(HUNTER))
	local start = Reputation.START.hunter
	local firstHand, secondHand = start - atSquad, start - atVillage
	assert(secondHand > 0, "the village moved")
	assert(secondHand < firstHand, "but less than the people who were standing there")
	assert(math.abs(secondHand - firstHand * Gossip.HOP_FADE) < 1e-6, "exactly HOP_FADE of it")
	print(("   first hand %.2f, one hop %.2f (x%.2f)"):format(firstHand, secondHand, Gossip.HOP_FADE))
end

-- NOBODY SAW IT: no rumour, and no change anywhere in the world. §7's "you can outrun your reputation".
do
	local w, ps = newRecord(3)
	local before = Gossip.standing(w, ps, Gossip.villageKey(HUNTER))
	local r = Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, {})
	assert(r == nil, "no witnesses, no rumour")
	assert(#w.rumours == 0, "nothing in the ring")
	assert(Gossip.standing(w, ps, Gossip.villageKey(HUNTER)) == before, "and nobody thinks any differently of you")
	assert(Gossip.grudge(ps, "hunter") == 0, "an unseen killing does not even scar")
end

-- A holder never applies the same rumour twice, including across a ring eviction and its compaction.
do
	local w, ps = newRecord(4)
	for n = 1, Gossip.MAX_RUMOURS + 10 do
		Gossip.seed(w, 7, "gift", "villager", FARMER, nil, 1, { [Gossip.villageKey(FARMER)] = true })
		assert(#w.rumours <= Gossip.MAX_RUMOURS, "the ring never grows past its cap")
	end
	local knows = w.villages[FARMER].knows
	assert(#knows == Gossip.MAX_RUMOURS, ("knows is bounded by the ring: %d"):format(#knows))
	-- every id a holder still knows must still be IN the ring: no dangling ids can reach Save.check
	for _, id in ipairs(knows) do assert(Gossip.find(w, id) ~= nil, "no dangling rumour id after eviction") end
	local ok, why = Save.check(Save.encode(w, { seed = 1, rngState = 1, savedAt = 0 }))
	assert(ok, "the gossip nodes are JSON-safe: " .. tostring(why))
end

-- The scar: a grudge multiplies the NEXT killing, and a gift chips at it.
do
	local w, ps = newRecord(5)
	local vk = Gossip.villageKey(HUNTER)
	local start = Gossip.standing(w, ps, vk)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { [vk] = true })
	local firstCost = start - Gossip.standing(w, ps, vk)
	assert(Gossip.grudge(ps, "hunter") > 0, "murder of a runner scars")
	-- clear the ledger but not the scar, so the second killing is measured on its own
	ps.rep[vk] = start
	local scar = Gossip.grudge(ps, "hunter")
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 2, { [vk] = true })
	local secondCost = start - Gossip.standing(w, ps, vk)
	assert(secondCost > firstCost, ("the second one costs more: %.1f then %.1f"):format(firstCost, secondCost))
	assert(math.abs(secondCost - firstCost * (1 + scar)) < 1e-6, "by exactly the grudge they were carrying")

	local held = Gossip.grudge(ps, "hunter")
	Gossip.amend(ps, "hunter")
	assert(Gossip.grudge(ps, "hunter") < held, "a gift is amends")
	-- and a grudge halves in GRUDGE_FADE_DAYS, as a closed form over days, not a per-tick decrement
	local g0 = Gossip.grudge(ps, "hunter")
	Gossip.fadeGrudge(ps, Config.GRUDGE_FADE_DAYS)
	assert(math.abs(Gossip.grudge(ps, "hunter") - g0 * 0.5) < 1e-6, "halves in an in-game year")
	print(("   murder cost %.1f, then %.1f with a scar of %.2f"):format(firstCost, secondCost, scar))
end

-- Kindness is never multiplied by a grudge: only harm is.
do
	local w, ps = newRecord(6)
	local vk = Gossip.villageKey(FARMER)
	ps.grudge.farmer = 2
	local before = Gossip.standing(w, ps, vk)
	Gossip.seed(w, 7, "gift", "villager", FARMER, nil, 1, { [vk] = true })
	local gain = Gossip.standing(w, ps, vk) - before
	local plain = Reputation.deltas("gift", "villager", "farmer").farmer
	assert(math.abs(gain - plain) < 1e-6, "a gift is worth the same whatever they hold against you")
end

-- catchUp(n) equals n live seconds, INCLUDING every exchange. This is the guard against anyone lumping contact
-- into an hourly step later: it is a schedule derived from gameSeconds, not a second movement granularity.
do
	local function run(lump: boolean)
		local w, ps, rng = newRecord(7)
		Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
		if lump then
			Tick.catchUp(w, world, rng, 400)
		else
			for _ = 1, 400 do
				w.meta.gameSeconds += 1
				Tick.groups(w, world, w.meta.gameSeconds)
			end
		end
		local out = { rumours = #w.rumours }
		for _, h in ipairs(Gossip.holders(w)) do out[h.key] = table.concat(h.knows, ",") end
		for holder, v in pairs(ps.rep) do out["rep:" .. holder] = ("%.6f"):format(v) end
		return out
	end
	local live, caught = run(false), run(true)
	assert(count(live) == count(caught), "the same set of holders and keys either way")
	for k, v in pairs(live) do
		assert(caught[k] == v, ("catch-up differs from live play at %s: %s vs %s"):format(k, tostring(v), tostring(caught[k])))
	end
	assert(live["v2"] ~= "" or live["squad"] ~= "", "something actually travelled in 400 s")
	print(("   catch-up == live for %d keys after 400 s"):format(count(live)))
end

-- Contact is gated on the schedule, so it cannot fire twice in the same slot however often Tick.groups is called.
do
	local w = newRecord(8)
	w.meta.gameSeconds = 5 * Gossip.EVERY
	assert(Gossip.meet(w, w.meta.gameSeconds) == 0 or true, "first call in a slot may exchange")
	local slot = w.meta.lastContactSlot
	Gossip.meet(w, w.meta.gameSeconds)
	assert(w.meta.lastContactSlot == slot, "a second call in the same slot does nothing")
	Gossip.meet(w, w.meta.gameSeconds + Gossip.EVERY)
	assert(w.meta.lastContactSlot == slot + 1, "the next slot runs")
end

-- Old news stops travelling: a stale rumour leaves the ring and every holder forgets it.
do
	local w = newRecord(9)
	local vk = Gossip.villageKey(FARMER)
	Gossip.seed(w, 7, "gift", "villager", FARMER, nil, 1, { [vk] = true })
	assert(#w.villages[FARMER].knows == 1, "heard it")
	Gossip.dropStale(w, 1 + Gossip.STALE_DAYS)
	assert(#w.rumours == 1, "still fresh on the last day")
	Gossip.dropStale(w, 2 + Gossip.STALE_DAYS)
	assert(#w.rumours == 0 and #w.villages[FARMER].knows == 0, "past STALE_DAYS it is gone, and so is knowing it")
end

-- A player who was OFFLINE when the news arrived gets it applied when they come back, exactly once, at each holder
-- that heard it - and the replay after that changes nothing.
do
	local w, ps = newRecord(10)
	local vk = Gossip.villageKey(HUNTER)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local online = Gossip.standing(w, ps, vk)
	w.players[7] = nil -- they log off before the squad gets home
	Gossip.arrive(w, w.groups.squad)
	assert(Gossip.standing(w, ps, vk) == online, "nothing was applied to an absent player")
	assert(#w.villages[HUNTER].knows == 1, "but the village heard it all the same")

	w.players[7] = ps
	Gossip.catchUpPlayer(w, ps, 7)
	local back = Gossip.standing(w, ps, vk)
	assert(back < online, "it is waiting for them when they walk in")
	Gossip.catchUpPlayer(w, ps, 7)
	assert(Gossip.standing(w, ps, vk) == back, "and the replay is idempotent")
	print(("   away: Kenstow %.1f -> %.1f on return"):format(online, back))
end

-- The worst case IN BYTES, so a future shape change has to argue with a number rather than a feeling
-- (docs/RUNG3.md part 3). Save.check has already proved the shape is what JSON gives back unchanged, so encoding it
-- the same way HttpService would is just a matter of counting.
local function jsonLen(v): number
	local ty = type(v)
	if ty == "number" then
		-- Roblox encodes integers without a decimal point; that is the shape every count and id in the save has
		return #(if v % 1 == 0 then tostring(math.floor(v)) else tostring(v))
	elseif ty == "string" then return #v + 2
	elseif ty == "boolean" then return if v then 4 else 5
	elseif ty ~= "table" then return 4 end -- nil
	local n, out = #v, 2                    -- the braces or brackets
	if n > 0 then
		for _, x in ipairs(v) do out += jsonLen(x) + 1 end
		return out - 1
	end
	local keys = 0
	for k, x in pairs(v) do
		keys += 1
		out += #k + 3 + jsonLen(x) + 1 -- "key": value,
	end
	return if keys == 0 then out else out - 1
end

do
	local w, ps = newRecord(11)
	local stamp = { seed = 1, rngState = 1, savedAt = 1758600000 }
	local before = jsonLen(Save.encode(w, stamp))
	-- the worst case the design argued for: the ring FULL, and every holder knowing every rumour in it
	for n = 1, Gossip.MAX_RUMOURS do
		Gossip.seed(w, 7, "kill", "villager", FARMER, { fleeing = true }, 1, { [Gossip.villageKey(FARMER)] = true })
	end
	for _, a in ipairs(Gossip.holders(w)) do
		for _, r in ipairs(w.rumours) do Gossip.tell(w, a.key, r.id) end
	end
	local full = jsonLen(Save.encode(w, stamp))
	local cost = full - before
	local holders = #Gossip.holders(w)
	local perHolder = cost / holders
	-- 6 holders today. The number that matters is that it does NOT grow with the number of players: the ring is
	-- world-level, so 300 players make the same 64 rows. Budget is the 4 MB key (ARCHITECTURE §5).
	assert(#w.rumours == Gossip.MAX_RUMOURS, "the ring is full")
	assert(cost < 40 * 1024, ("gossip's worst case must stay well inside the key: %d B"):format(cost))
	assert(perHolder < 2048, ("per holder, everything known: %.0f B"):format(perHolder))
	print(("   world %d B -> %d B: gossip's worst case is %d B over %d holders (%.0f B each)"):format(
		before, full, cost, holders, perHolder))
end
print("gossip ok")
