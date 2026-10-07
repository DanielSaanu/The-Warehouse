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
	local ps = { player = { UserId = 7, Name = "Danzo" }, rep = Reputation.newTable(seedRep), grudge = {} }
	w.players[7] = ps
	return w, ps, rng
end

--- The squad walking back into Kenstow: `from` is home, and `dir == -1` is the walk home, so this is the end at which
--- Tick.groupTurn calls Gossip.arrive when they get back. (Before QA round 2 these tests called arrive on a squad
--- standing at pos 1 heading OUT, which only worked because arrive ignored the end and always told the home village.)
local function comeHome(w, g)
	g.pos, g.dir = 1, -1
	return Gossip.arrive(w, g, world)
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

	comeHome(w, w.groups.squad) -- the squad comes home
	local told = Gossip.standing(w, ps, vk)
	assert(told < before, "once they are home, the village knows")
	comeHome(w, w.groups.squad)
	comeHome(w, w.groups.squad)
	assert(Gossip.standing(w, ps, vk) == told, "and it is not booked a second time, however often they come home")
	print(("   squad %.1f, Kenstow %.1f (was %.1f)"):format(Gossip.standing(w, ps, "squad"), told, before))
end

-- Strength falls with hops: the far tribe gets a weaker, vaguer version of the same story.
do
	local w, ps = newRecord(2)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local atSquad = Gossip.standing(w, ps, "squad")
	comeHome(w, w.groups.squad)            -- hop 1: the village hears it from the squad
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
		for _, h in ipairs(Gossip.holders(w)) do out[h.key] = table.concat(h.knows, ",") .. "@" .. table.concat(h.hops, ",") end
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
	comeHome(w, w.groups.squad)
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

-- ---------- QA round 1 (docs/qa/rung3-part3-round1.md): one test per FIX item, each failing on the old code ----------

-- FIX 1: rekey must let a v2 player's REAL standing win over the START values Sim.addPlayer already seeded.
-- The old rule ("copy only if the holder is empty") was never true, so every returning v2 player was reset.
do
	local w, ps = newRecord(20)
	-- what Restore.player sees: newRep()'s START values, then applyPlayer laying the v2 tribe-type keys on top
	local saved = { farmer = 55, hunter = -30, plunderer = -60 }
	for k, v in pairs(saved) do ps.rep[k] = v end
	Save.rekeyRep(w, ps.rep, saved)
	assert(ps.rep.v1 == 55 and ps.rep.v2 == -30 and ps.rep.v3 == -60, ("the v2 values win: v1 %s v2 %s v3 %s"):format(
		tostring(ps.rep.v1), tostring(ps.rep.v2), tostring(ps.rep.v3)))
	assert(ps.rep.farmer == nil and ps.rep.hunter == nil and ps.rep.plunderer == nil, "and the old keys are gone")
	-- a v3 record is already keyed by holder: rekey leaves it exactly as saved
	local w3, ps3 = newRecord(21)
	local saved3 = { v1 = 40, squad = -12 }
	for k, v in pairs(saved3) do ps3.rep[k] = v end
	local before = table.clone(ps3.rep)
	Save.rekeyRep(w3, ps3.rep, saved3)
	for k, v in pairs(before) do assert(ps3.rep[k] == v, "a v3 key is untouched at " .. k) end
end

-- FIX 2: road meetings are by PLACE. Both groups at pos 1 are at their own homes, far apart: they must not meet.
do
	local w, ps = newRecord(22)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local sq, band = w.groups.squad, w.groups.band
	sq.pos, band.pos = 1, 1
	local a, b = sq.route[1], band.route[1]
	assert(math.abs(a.x - b.x) + math.abs(a.y - b.y) > 4, "the two homes are far apart (fixture check)")
	w.meta.gameSeconds = Gossip.EVERY
	Gossip.meet(w, w.meta.gameSeconds)
	assert(#band.knows == 0, "groups at pos 1 on opposite sides of the map do not meet")
	-- both at the far end of their routes, which is the same village: now they share a tile, and they do meet
	sq.pos, band.pos = #sq.route, #band.route
	local ea, eb = sq.route[sq.pos], band.route[band.pos]
	assert(math.floor(ea.x / 2) == math.floor(eb.x / 2) and math.floor(ea.y / 2) == math.floor(eb.y / 2), "fixture: same 2x2 cell")
	band.materialised = true
	Gossip.meet(w, 2 * Gossip.EVERY)
	assert(#band.knows == 0, "a MATERIALISED group's pos is stale, so it is not bucketed")
	band.materialised = nil
	Gossip.meet(w, 3 * Gossip.EVERY)
	assert(#band.knows == 1, "groups standing in the same place swap news")
	assert(band.hops[1] == 1, "one hand from the squad that saw it")
end

-- FIX 3: only a story that would move somebody's number is news. A deer is not.
do
	local w = newRecord(23)
	assert(Gossip.seed(w, 7, "kill", "deer", nil, nil, 1, { squad = true }) == nil, "an animal kill is not a rumour")
	assert(Gossip.seed(w, 7, "escape", "hunter", HUNTER, nil, 1, { squad = true }) == nil, "an escape from hunters moves nobody")
	assert(#w.rumours == 0 and #w.groups.squad.knows == 0, "nothing reached the ring")
	assert(Gossip.seed(w, 7, "kill", "bandit", BANDIT, nil, 1, { squad = true }) ~= nil, "a bandit killing still is")
	assert(Gossip.latest(w, "squad", 7).victim == "bandit", "and that is what they talk about")
end

-- FIX 4: strength is set by how many hands the story came through to reach THIS holder, not by a counter on the
-- shared row. The reviewer's case: squad -> village -> farmers, then squad -> band. The band is one hand away.
do
	local w, ps = newRecord(24)
	local start = Reputation.START.plunderer
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local firstHand = Reputation.START.hunter - Gossip.standing(w, ps, "squad")
	Gossip.exchange(w, "squad", Gossip.villageKey(HUNTER))
	Gossip.exchange(w, Gossip.villageKey(HUNTER), Gossip.villageKey(FARMER))
	Gossip.exchange(w, "squad", "band")
	local _, bandHops = Gossip.latest(w, "band", 7)
	local _, farmHops = Gossip.latest(w, Gossip.villageKey(FARMER), 7)
	local _, squadHops = Gossip.latest(w, "squad", 7)
	assert(bandHops == 1, ("the band heard it from the eyewitnesses: 1 hop, got %s"):format(tostring(bandHops)))
	assert(farmHops == 2, "the farmers heard it second hand from the hunters' village")
	assert(squadHops == 0, "and the eyewitnesses are still eyewitnesses (their line must not turn into hearsay)")
	-- a hunter killing moves the hunters only; the band's number is START, which is the point of checking hops
	assert(Gossip.standing(w, ps, "band") == start, "a hunter's murder means nothing to the plunderers")
	-- the same rumour about a BANDIT moves everyone, so the strengths can be read off directly
	local w2, ps2 = newRecord(25)
	Gossip.seed(w2, 7, "kill", "bandit", BANDIT, nil, 1, { squad = true })
	Gossip.exchange(w2, "squad", Gossip.villageKey(HUNTER))
	Gossip.exchange(w2, Gossip.villageKey(HUNTER), Gossip.villageKey(FARMER))
	Gossip.exchange(w2, "squad", "band")
	local d = Reputation.deltas("kill", "bandit", "plunderer", {}).plunderer
	assert(math.abs((Gossip.standing(w2, ps2, "band") - start) - d * Gossip.HOP_FADE) < 1e-6,
		"the band books it at ONE hop, whatever order the exchanges ran in")
	print(("   eyewitness 0 hops (%.1f), band 1 hop, farmers 2 hops"):format(firstHand))
end

-- FIX 4b + 5: an offline player gets EXACTLY what an online one would have, even after the story travels on, goes
-- stale and leaves the ring before they come back. Logging off must not launder a killing (old: online -15,
-- offline -8.44 after more exchanges; and 0 once the rumour was dropped).
do
	local vk = Gossip.villageKey(HUNTER)
	local AWAY = Gossip.STALE_DAYS + 2
	local function play(online: boolean)
		local w, ps = newRecord(26)
		Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
		if not online then w.players[7] = nil end
		Gossip.exchange(w, "squad", vk)
		Gossip.exchange(w, vk, Gossip.villageKey(FARMER)) -- the story travels on, which used to weaken the replay
		Gossip.exchange(w, "squad", "band")
		w.day = 1 + AWAY
		Gossip.dropStale(w, w.day) -- and leaves the ring altogether
		assert(#w.rumours == 0 and #w.villages[HUNTER].knows == 0, "the rumour is gone from the world")
		if online then
			for holder, v in pairs(ps.rep) do ps.rep[holder] = Reputation.fade(v, AWAY) end -- the daily fades they sat through
		else
			for holder, v in pairs(ps.rep) do ps.rep[holder] = Reputation.fade(v, AWAY) end -- Standing.away's fade
			assert(w.owed[7] ~= nil, "what they have coming is on the world, not in the ring")
			w.players[7] = ps
			Gossip.catchUpPlayer(w, ps, 7)
			assert(w.owed[7] == nil, "and it is paid once")
			Gossip.catchUpPlayer(w, ps, 7)
		end
		return Gossip.standing(w, ps, vk), Gossip.standing(w, ps, "squad")
	end
	local onV, onS = play(true)
	local offV, offS = play(false)
	assert(onV < Reputation.START.hunter, "the village moved")
	assert(math.abs(onV - offV) < 1e-6, ("away or not, the village thinks the same: online %.4f, offline %.4f"):format(onV, offV))
	assert(math.abs(onS - offS) < 1e-6, "and so does the squad that saw it")
	print(("   logged off for %d days: Kenstow %.2f either way"):format(AWAY, offV))
end

-- FIX 5, eviction: a ring flooded by other news still cannot launder what an absent player did.
do
	local w, ps = newRecord(27)
	local vk = Gossip.villageKey(HUNTER)
	w.players[7] = nil
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { [vk] = true })
	for _ = 1, Gossip.MAX_RUMOURS + 5 do
		Gossip.seed(w, 8, "gift", "villager", FARMER, nil, 1, { [Gossip.villageKey(FARMER)] = true })
	end
	assert(Gossip.find(w, 1) == nil, "the killing was evicted")
	local before = Gossip.standing(w, ps, vk)
	w.players[7] = ps
	Gossip.catchUpPlayer(w, ps, 7)
	assert(Gossip.standing(w, ps, vk) < before, "and it is still waiting for them when they walk in")
end

-- QA round 2 (H5): a group's arrival tells the village AT THAT END, never its own village from across the map.
-- The reviewer's probe: the squad sees a kill, then turns round at the far (forest) end - Kenstow must not move.
do
	local w, ps = newRecord(30)
	local vk = Gossip.villageKey(HUNTER)
	local before = Gossip.standing(w, ps, vk)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local sq = w.groups.squad
	sq.pos, sq.dir = #sq.route, 1                   -- at the far end of the walk out
	sq.pauseUntil = 0
	Tick.groupTurn(w, sq, 100, {}, world)
	assert(Gossip.standing(w, ps, vk) == before, "the squad turning round far from home does not tell Kenstow")
	assert(#w.villages[HUNTER].knows == 0, "Kenstow has heard nothing yet")
	-- the squad in this fixture walks to Glenworth, so the far end IS a village: that village hears it, one hop out
	local fk = Gossip.villageKey(FARMER)
	assert(#w.villages[FARMER].knows == 1 and w.villages[FARMER].hops[1] == 1, "the village at that end hears it instead")
	assert(sq.dir == -1, "and they turn for home")
	sq.pos = 1
	Tick.groupTurn(w, sq, 200, {}, world)            -- back at Kenstow
	assert(Gossip.standing(w, ps, vk) < before, "Kenstow hears it when they walk in")
	-- an end that is no village tells nobody
	local w2 = newRecord(31)
	Gossip.seed(w2, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local s2 = w2.groups.squad
	s2.to = { x = 1, y = 1 }                         -- the corner of the map: no village there
	s2.dir = 1
	assert(Gossip.villageAt(w2, world, 1, 1) == nil, "fixture: no village at the corner")
	assert(Gossip.arrive(w2, s2, world) == 0, "a forest end exchanges with nobody")
	for i in ipairs(w2.villages) do assert(#w2.villages[i].knows == 0, "no village heard it") end
	print(("   the squad's news reaches %s at the far end, Kenstow only on the walk home"):format(fk))
end

-- QA round 3 (H6): a MATERIALISED group's `pos` moves only with its bodies. The reviewer saw the squad leader stand in
-- the forest after a chase while `pos` walked home, Kenstow heard, and the hide was banked. Driven through
-- Tick.leaderStep with fake bodies: a path "succeeds" only within budget/10 tiles, and walking is instant.
do
	local function bodies(leader)
		local ops = {}
		function ops.free() return true end
		function ops.step(r) leader.x, leader.y = r.x, r.y end
		function ops.path(x, y, budget)
			if math.abs(leader.x - x) + math.abs(leader.y - y) > budget / 10 then return false end
			leader.x, leader.y = x, y
			return true
		end
		return ops
	end
	local function off(leader, r) return math.abs(leader.x - r.x) + math.abs(leader.y - r.y) end

	-- chase, then return: pulled 30 tiles off the road mid-way home, the squad walks back and only THEN goes home
	local w, ps = newRecord(33)
	local vk = Gossip.villageKey(HUNTER)
	local before = Gossip.standing(w, ps, vk)
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local sq = w.groups.squad
	sq.pos, sq.dir, sq.materialised = math.floor(#sq.route / 2), -1, true
	local mid = sq.route[sq.pos]
	local leader = { x = mid.x + 30, y = mid.y }
	local ops = bodies(leader)
	local turned = false
	for _ = 1, 4 * #sq.route do
		local act = Tick.leaderStep(sq, leader.x, leader.y, false, ops)
		if act == "turn" then
			Tick.groupTurn(w, sq, 500, {}, world, { x = leader.x, y = leader.y })
			turned = true
			break
		end
		assert(act ~= "lost", "a squad 30 tiles off the road finds its way back")
		assert(off(leader, sq.route[sq.pos]) <= 1, ("pos %d is where the bodies are (leader %d,%d)"):format(sq.pos, leader.x, leader.y))
	end
	assert(turned, "and gets home")
	assert(Gossip.villageAt(w, world, leader.x, leader.y) == HUNTER, "standing in Kenstow when it turns")
	assert(Gossip.standing(w, ps, vk) < before, "which is when Kenstow hears")

	-- lost: no path back to the road at all. `pos` stays where the bodies are, nobody hears, and the adapter is
	-- told to collapse the group instead of letting the route index walk on without them
	local w2, ps2 = newRecord(34)
	Gossip.seed(w2, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	local s2 = w2.groups.squad
	s2.pos, s2.dir, s2.materialised = 3, -1, true
	local far = { x = s2.route[3].x + 30, y = s2.route[3].y }
	local ops2 = bodies(far)
	ops2.path = function() return false end -- walled in: no path back at any budget
	local act
	for _ = 1, Tick.LOST_TRIES + 1 do act = Tick.leaderStep(s2, far.x, far.y, false, ops2) end
	assert(act == "lost", "a leader that cannot get back is reported lost")
	assert(s2.pos == Tick.nearestRouteIndex(s2, far.x, far.y), "and pos is the route tile nearest the bodies")
	assert(#w2.villages[HUNTER].knows == 0, "Kenstow heard nothing")

	-- and if a turn fires anyway with the leader out in the forest, the village is not told
	s2.pos = 1
	Tick.groupTurn(w2, s2, 600, {}, world, far)
	assert(#w2.villages[HUNTER].knows == 0, "arrive refuses when the leader is not in the village")
	print(("   chase then return: back on the road and home at pos %d, Kenstow told only then"):format(sq.pos))
end

-- owe clamps: an owed sum is bounded by the widest swing a rep can make, so a huge debt cannot grow without end.
do
	local w = newRecord(32)
	w.players[7] = nil
	for n = 1, 12 do Gossip.seed(w, 7, "kill", "child", HUNTER, { fleeing = true }, 1, { [Gossip.villageKey(HUNTER)] = true }) end
	local span = Reputation.MAX - Reputation.MIN
	assert(w.owed[7].rep.v2 == -span, ("owed is clamped at -%d: %s"):format(span, tostring(w.owed[7].rep.v2)))
end

-- `owed` is bounded: standing owed to somebody who never comes back fades like any other, and is forgotten.
do
	local w = newRecord(28)
	w.players[7] = nil
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	assert(w.owed[7] ~= nil, "owed")
	Gossip.dropStale(w, 1 + Config.REP_FADE_DAYS)
	assert(w.owed[7] ~= nil, "a month later it is halved, not gone")
	Gossip.dropStale(w, 1 + 7 * Config.REP_FADE_DAYS)
	assert(w.owed[7] == nil, "after seven half-lives it is below OWED_MIN and dropped")
end

-- CONSIDER 1: a returning player's catch-up is silent, live news is not - and silence is a parameter, so nothing can
-- leave it stuck on.
do
	local w, ps = newRecord(29)
	local told = 0
	Gossip.onChange = function() told += 1 end
	Gossip.seed(w, 7, "kill", "hunter", HUNTER, { fleeing = true }, 1, { squad = true })
	assert(told == 1, "the player is told when the squad's opinion moves")
	w.players[7] = nil
	comeHome(w, w.groups.squad)
	w.players[7] = ps
	Gossip.catchUpPlayer(w, ps, 7)
	assert(told == 1, "catch-up says nothing: the welcome does that")
	Gossip.onChange = nil
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
-- `owed` in bytes: what absent players have coming, worst case = every one of them owed at every holder. It is the
-- one gossip node that DOES grow with players, so it gets its own number (and OWED_MIN fades it out, see above).
do
	local w = newRecord(12)
	local stamp = { seed = 1, rngState = 1, savedAt = 1758600000 }
	local before = jsonLen(Save.encode(w, stamp))
	local PLAYERS = 32
	w.owed = {}
	for n = 1, PLAYERS do
		local rep = {}
		for _, h in ipairs(Gossip.holders(w)) do rep[h.key] = -12.345678901234 end
		w.owed[4100000000 + n] = { day = 120, rep = rep }
	end
	local cost = jsonLen(Save.encode(w, stamp)) - before
	local each = cost / PLAYERS
	-- it also grows with the holders (16 villages since the world expansion), so the budget is per holder: ~25 B each
	assert(each < 32 * #Gossip.holders(w), ("owed per absent player, owed at all %d holders: %.0f B"):format(#Gossip.holders(w), each))
	print(("   owed: %d absent players at all %d holders = %d B (%.0f B each)"):format(PLAYERS, #Gossip.holders(w), cost, each))
end
print("gossip ok")
