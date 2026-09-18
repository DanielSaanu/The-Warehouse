-- The rung 2 part 2 shared modules: items, combat, reputation, trade, ecology, calamity, talk, routing, flood.
local WorldGen = __require("WorldGen")
local TileTypes = __require("TileTypes")
local Rng = __require("Rng")
local Items = __require("Items")
local Combat = __require("Combat")
local Reputation = __require("Reputation")
local Trade = __require("Trade")
local Ecology = __require("Ecology")
local Calamity = __require("Calamity")
local Talk = __require("Talk")
local Stats = __require("Stats")
local Movement = __require("Movement")
local Config = __require("Config")

local world = WorldGen.generate(1)
local G, O = TileTypes.GroundByName, TileTypes.ObjectByName

-- Items: the day one kit fits, stacks fill before new slots, remove refuses shortfalls.
do
	local inv = Items.dayOneKit()
	assert(#inv.slots == 4, "kit uses 4 slots")
	assert(Items.count(inv, "food") == 2 and Items.count(inv, "camper_set") == 1, "kit contents")
	assert(Items.weaponAtk(inv) == 2, "knife attack")
	assert(Items.add(inv, "food", 9) == 9 and #inv.slots == 5, "food stacks to 10 then a new slot")
	for _ = 1, 5 do Items.add(inv, "ore", 10) end
	assert(#inv.slots == Items.SLOTS, "ten slots")
	assert(Items.add(inv, "hide", 1) == 0, "full inventory refuses")
	assert(not Items.remove(inv, "hide", 1), "cannot remove what you lack")
	assert(Items.remove(inv, "food", 11) and Items.count(inv, "food") == 0, "remove across stacks")
	assert(Items.room(inv, "food") >= 10, "room after removing")
end

-- Combat: damage floors at 1, knockback goes straight away from the attacker, facing tile maths.
do
	assert(Combat.damage(3, 1) == 2 and Combat.damage(1, 5) == 1, "damage")
	local kx, ky = Combat.knockbackTile(5, 5, 6, 5)
	assert(kx == 7 and ky == 5, "knockback right")
	kx, ky = Combat.knockbackTile(5, 5, 5, 4)
	assert(kx == 5 and ky == 3, "knockback up")
	local fx, fy = Combat.facingTile(2, 2, "left")
	assert(fx == 1 and fy == 2, "facing tile")
	assert(Combat.dirTo(0, 0, 3, -1) == "right" and Combat.dirTo(0, 0, 0, 4) == "down", "dirTo")
	local rng = Rng.new(3)
	assert(Combat.loot("deer", rng).hide == 1, "deer drops hide")
	assert((Combat.loot("bandit", rng).coin or 0) >= 2, "bandits carry coin")
	for k in pairs(Stats.Kinds) do assert(Stats.get(k).hp > 0, "kind " .. k) end
	assert(Stats.get("hunter").atk > Stats.get("guard").atk and Stats.get("guard").atk > Stats.get("bandit").atk, "hunters strongest one on one, bandits weakest")
end

-- Reputation: words, thresholds, event deltas, fade.
do
	assert(Reputation.word(-60) == "hostile" and Reputation.word(-20) == "wary" and Reputation.word(0) == "neutral" and Reputation.word(30) == "welcome" and Reputation.word(80) == "family", "words")
	local rep = Reputation.newTable()
	assert(Reputation.word(rep.farmer) == "welcome" and Reputation.word(rep.plunderer) == "wary", "starting standing")
	Reputation.apply(rep, Reputation.deltas("kill", "bandit", "plunderer"))
	assert(rep.plunderer == -35 and rep.farmer == 25 and rep.hunter == 5, "killing a bandit: plunderers down, others up")
	Reputation.apply(rep, Reputation.deltas("kill", "villager", "farmer"))
	assert(rep.farmer == 0, "killing your own villager")
	assert(Reputation.priceMult(-60) == nil and Reputation.priceMult(-20) == 1.3 and Reputation.priceMult(60) == 0.8, "price multiplier")
	assert(not Reputation.allowsRest(-20) and Reputation.allowsRest(0), "wary villages refuse a bed")
	assert(math.abs(Reputation.fade(40, Config.REP_FADE_DAYS) - 20) < 1e-9, "half the distance per fade period")
	for _ = 1, 100 do Reputation.apply(rep, Reputation.deltas("kill", "villager", "farmer")) end
	assert(rep.farmer == Reputation.MIN, "clamped")
end

-- Trade: scarcity raises prices, plenty lowers them, sell < buy, restock drifts to target.
do
	local stock = Trade.newStock("farmer")
	local full = Trade.buyPrice("food", stock, "farmer", 1)
	stock.food = 2
	local scarce = Trade.buyPrice("food", stock, "farmer", 1)
	stock.food = 60
	local glut = Trade.buyPrice("food", stock, "farmer", 1)
	assert(scarce > full and full > glut, ("prices: scarce %d full %d glut %d"):format(scarce, full, glut))
	assert(Trade.sellPrice("food", stock, "farmer", 1) < Trade.buyPrice("food", stock, "farmer", 1), "merchant takes a cut")
	assert(Trade.buyPrice("hide", stock, "farmer", 1.3) >= Trade.buyPrice("hide", stock, "farmer", 1.0), "wary pays more")
	assert(Trade.camperPrice("farmer", 1) == 15 and Trade.camperPrice("plunderer", 1) == nil, "camper sets")
	stock = Trade.newStock("hunter")
	stock.hide = 0
	for _ = 1, 30 do Trade.dailyRestock(stock, "hunter") end
	assert(stock.hide >= Trade.TARGET.hunter.hide, "hunters restock hides")
	assert(#Trade.quotes(stock, "hunter", 1) == 4, "four goods")
end

-- Ecology: 200 days without the world emptying or exploding; the north keeps wolves; a beast tide adds them.
do
	local rng = Rng.new(11)
	local rg = Ecology.init(world, rng)
	assert(rg.cols == 6 and rg.rows == 6 and #rg.list == 36, "6x6 regions")
	local t0 = Ecology.totals(rg)
	assert(t0.deer > 20 and t0.boar > 5 and t0.wolf >= 3, ("initial counts deer %d boar %d wolf %d"):format(t0.deer, t0.boar, t0.wolf))
	for _ = 1, 200 do Ecology.dailyTick(rg, rng) end
	local t = Ecology.totals(rg)
	assert(t.deer >= 10 and t.deer <= 36 * Ecology.CAP.deer, "deer stay in a sane band: " .. t.deer)
	assert(t.wolf >= 1 and t.wolf <= 36 * Ecology.CAP.wolf, "wolves stay in a sane band: " .. t.wolf)
	assert(t.boar >= 3, "boar survive: " .. t.boar)
	for _, r in ipairs(rg.list) do
		assert(r.deer >= 0 and r.boar >= 0 and r.wolf >= 0, "no negative counts")
		assert(r.grass >= 0 and r.grass <= 1, "grass in range")
		if r.village then assert(r.wolf <= 1, "villages keep wolves out") end
	end
	local before = Ecology.totals(rg).wolf
	-- a beast tide is a one-time surge plus an overlay flag, and only the surge changes what is saved
	Ecology.wolfSurge(rg)
	assert(Ecology.totals(rg).wolf > before, "beast tide adds wolves")
	assert(not rg.list[1].tide, "the surge alone does not set the overlay")
	local surged = Ecology.totals(rg).wolf
	for _ = 1, 3 do assert(Calamity.applyOverlay(world, rg, "beast_tide") == nil, "a tide has no tiles") end
	assert(rg.list[1].tide and rg.list[36].tide, "the tide is felt everywhere")
	assert(Ecology.totals(rg).wolf == surged, "re-applying the overlay (what a load does) never adds wolves")
	assert(rg.list[36].wolf >= 2, "even the far corner has wolves during a tide")
	Ecology.endTide(rg)
	assert(not rg.list[1].tide, "tide ends")
	assert(#Ecology.describe(rg.list[1]) > 10, "wildlife line")
	print(("ecology after 200 days: deer %d boar %d wolf %d"):format(t.deer, t.boar, t.wolf))
end

-- Calamity clock: warning on day 6, calamity on day 7, starts once, deterministic pick, has text.
do
	assert(Calamity.isWarningDay(6) and Calamity.isCalamityDay(7) and not Calamity.isCalamityDay(8), "week days")
	assert(Calamity.dayOf(3) == 7 and Calamity.dayOf(7) == 7 and Calamity.dayOf(8) == 14, "calamity day of")
	assert(Calamity.shouldStart(7, 0.5, false) and not Calamity.shouldStart(7, 0.1, false) and not Calamity.shouldStart(7, 0.5, true) and not Calamity.shouldStart(6, 0.9, false), "start rule")
	assert(Calamity.pick(1, 1) == Calamity.pick(1, 1), "deterministic")
	local seen = {}
	for wk = 1, 40 do seen[Calamity.pick(1, wk)] = true end
	assert(seen.flood and seen.beast_tide, "both calamities come round")
	for _, k in ipairs(Calamity.KINDS) do
		assert(#Calamity.warning(k) > 10 and #Calamity.notice(k) > 10 and #Calamity.over(k) > 5 and #Calamity.label(k) > 2, "text for " .. k)
	end
end

-- Flood: covers ground near the river, spares village footprints, is walk-blocking and lifts cleanly.
do
	local tiles = WorldGen.floodTiles(world)
	assert(#tiles > 200, "flood covers the banks: " .. #tiles)
	for _, i in ipairs(tiles) do
		local x, y = (i - 1) % world.width + 1, math.floor((i - 1) / world.width) + 1
		assert(not WorldGen.villageAt(world, x, y, 0), "flood inside a village")
	end
	local i1 = tiles[1]
	local g1 = world.ground[i1]
	WorldGen.setFlood(world, tiles)
	assert(world.ground[i1] == G.flood.id, "flooded")
	local x, y = (i1 - 1) % world.width + 1, math.floor((i1 - 1) / world.width) + 1
	assert(not WorldGen.walkable(world, x, y), "flood water is not walkable")
	assert(WorldGen.walkable(world, world.spawn.x, world.spawn.y), "spawn stays dry")
	WorldGen.clearFlood(world)
	assert(world.ground[i1] == g1, "restored")
end

-- Routing: every village pair has a road route; tap-to-move BFS goes around a tree; occupancy blocks a step.
do
	local vs = world.villages
	for i = 1, 3 do
		for j = i + 1, 3 do
			local r = WorldGen.route(world, vs[i].spawn.x, vs[i].spawn.y, vs[j].spawn.x, vs[j].spawn.y, true)
			assert(r and #r > 10, "no route " .. vs[i].name .. " -> " .. vs[j].name)
			local onRoad = 0
			for _, p in ipairs(r) do
				local g = WorldGen.ground(world, p.x, p.y)
				if g == G.path.id or g == G.ford.id then onRoad += 1 end
			end
			assert(onRoad / #r > 0.6, ("route %s -> %s keeps to the road (%d of %d)"):format(vs[i].name, vs[j].name, onRoad, #r))
			-- each step is adjacent to the last
			local px, py = vs[i].spawn.x, vs[i].spawn.y
			for _, p in ipairs(r) do
				assert(math.abs(p.x - px) + math.abs(p.y - py) == 1, "route step not adjacent")
				px, py = p.x, p.y
			end
		end
	end
	-- a bounded search that cannot reach returns nil quickly
	assert(WorldGen.route(world, world.spawn.x, world.spawn.y, 2, 2, false, 50) == nil, "bounded search gives up")
	local occ = {}
	local sx, sy = world.spawn.x, world.spawn.y
	occ[WorldGen.index(world, sx, sy - 1)] = "someone"
	assert(Movement.canStep(world, sx, sy, sx, sy - 1) and not Movement.canStep(world, sx, sy, sx, sy - 1, occ), "occupied tiles block")
end

-- Villages look different: hunter tents and a totem, plunderer huts and a skull post, farmers unchanged.
do
	local count = {}
	for i = 1, world.width * world.height do local o = world.object[i]; if o ~= 0 then count[o] = (count[o] or 0) + 1 end end
	assert((count[O.hut_hunter.id] or 0) >= 4 and (count[O.totem.id] or 0) == 1, "hunter village dressing")
	assert((count[O.hut_plunderer.id] or 0) >= 4 and (count[O.skull_post.id] or 0) == 1, "plunderer village dressing")
	assert((count[O.hut.id] or 0) >= 1 and (count[O.hut_burnt.id] or 0) == 3, "farmer village dressing")
	for _, v in ipairs(world.villages) do
		assert(WorldGen.reachable(world, world.spawn.x, world.spawn.y, v.spawn.x, v.spawn.y), "landmarks do not block " .. v.name)
	end
end

-- Talk: every role has words for every tribe and topic; the survivor names the hunter village.
do
	local rng = Rng.new(5)
	for _, tribe in ipairs({ "farmer", "hunter", "plunderer" }) do
		local ctx = { village = "Testham", tribeType = tribe, tribeName = "the Testham tribe", repWord = "neutral", warning = "A flood is coming.", calamity = nil,
			wildlife = "Deer about.", banditHint = "Bandits on the north road.", hunterVillage = "Kenstow", hunterDir = "east", farmerVillage = "Glenworth",
			plundererVillage = "Wild's Rest", plundererDir = "north",
			prices = "food 2, hides 5", scarce = "tools", makes = "food", survivorName = "Nelia Greybrook", playerName = "Dan" }
		for _ = 1, 20 do assert(#Talk.villagerLine(rng, ctx) > 5, "villager line") end
		for _, topic in ipairs(Talk.TOPICS) do assert(#Talk.guard(ctx, topic) > 10, "guard " .. topic) end
		assert(#Talk.refusal(ctx) > 5 and #Talk.merchant(ctx) > 5 and #Talk.caravanMaster(ctx) == 3, "roles")
		local s = Talk.survivor(ctx)
		local all = table.concat(s, " ")
		assert(#s >= 5 and all:find("Kenstow") and all:find("WASD"), "survivor teaches and points east")
		assert(all:find("Do not go north"), "survivor warns you off the raiders' road on day one")
		assert(all:find("sign"), "survivor tells you to read the signs")
		assert(#Talk.sign("Kenstow, east. Hunters.") == 1, "a sign is one page")
	end
end

-- The goal line: one sentence at a time, in order, and it ends.
do
	local ctx = { hunterVillage = "Kenstow", hunterDir = "east" } :: any
	local seen = {}
	for stage = 1, #Talk.GOAL_STAGES do
		local g = Talk.goal(stage, ctx)
		assert(g and #g > 8, "goal " .. stage)
		assert(not seen[g], "goals repeat at stage " .. stage)
		seen[g] = true
	end
	assert(Talk.goal(2, ctx):find("east") and Talk.goal(2, ctx):find("Kenstow"), "the road goal names the village and the way")
	assert(Talk.goal(#Talk.GOAL_STAGES + 1, ctx) == nil, "the chain ends, it is not a quest log")
	assert(Talk.goal(0, ctx) == nil, "nothing is asked before the first goal")
end

-- The flood overlay is idempotent: a load re-lays it over a fresh map, maybe more than once, and lifting it after
-- any number of applications gives back exactly the dry map (docs/ARCHITECTURE.md A3, save blockers 4 and 6).
do
	local w2 = WorldGen.generate(1)
	local dry = table.clone(w2.ground)
	local rg2 = Ecology.init(w2, Rng.new(4))
	local first = Calamity.applyOverlay(w2, rg2, "flood")
	local again = Calamity.applyOverlay(w2, rg2, "flood")
	assert(first and again and #first > 100 and #first == #again, "re-applying finds the same tiles, not the ones still dry")
	WorldGen.clearFlood(w2)
	for i, g in ipairs(dry) do assert(w2.ground[i] == g, "the flood lifts completely after being applied twice") end
end

print("sim modules ok")

-- Conduct-based reputation: who drew first, mercy, murder of a runner, dying costs nothing.
do
	local d = Reputation.deltas("hit", "villager", "farmer")
	assert(d.farmer == -1, "a blow on an innocent is -1")
	assert(next(Reputation.deltas("hit", "bandit", "plunderer", { aggressor = true })) == nil, "hitting someone who attacked you costs nothing")
	assert(Reputation.deltas("kill", "villager", "farmer").farmer == -25, "murder")
	assert(Reputation.deltas("kill", "guard", "farmer", { aggressor = true }).farmer == -10, "self-defence is half")
	assert(Reputation.deltas("kill", "guard", "farmer", { aggressor = true, fleeing = true }).farmer == -20, "killing a runner is the full number")
	assert(Reputation.deltas("kill", "baby", "farmer").farmer == -40, "babies")
	assert(Reputation.deltas("kill", "bandit", "plunderer", { aggressor = true }).plunderer == -8 and Reputation.deltas("kill", "bandit", "plunderer").farmer == 5, "bandits")
	assert(Reputation.deltas("mercy", "bandit", "plunderer").plunderer == 3, "mercy")
	assert(Reputation.deltas("escape", "bandit", "plunderer").plunderer == 2 and next(Reputation.deltas("escape", "guard", "farmer")) == nil, "escape only counts with the band")
	assert(next(Reputation.deltas("died_to", "bandit", "plunderer")) == nil, "dying costs nothing")
	assert(Reputation.deltas("gift", "villager", "hunter").hunter == 2, "a gift is remembered")
end

-- Families: couples, weekly conception, gestation, babies growing up, deaths and succession.
do
	local Families = __require("Families")
	local rng = Rng.new(21)
	local reg = Families.new()
	local surnames = { "Ashford", "Oakley" }
	for i = 1, 6 do Families.newAdult(reg, rng, 1, 1, "villager", 1, surnames[(i % 2) + 1], if i <= 3 then "m" else "f") end
	local guard = Families.newAdult(reg, rng, 1, 1, "guard", 1, "Ashford", "m")
	assert(Families.formCouples(reg, 1, 1) >= 2, "couples form between unrelated adults")
	for _, p in pairs(reg.people) do
		if p.spouse then
			local s = reg.people[p.spouse]
			assert(s.spouse == p.id and s.sex ~= p.sex and s.last ~= p.last, "a couple is one man, one woman, different surnames")
		end
	end
	local pregnant = {}
	for wk = 1, 8 do
		for _, m in ipairs(Families.weeklyConceive(reg, rng, 1, wk * 7)) do table.insert(pregnant, m) end
	end
	assert(#pregnant >= 1, "somebody falls pregnant over eight weeks")
	assert(pregnant[1].stage == "pregnant" and pregnant[1].due, "pregnant with a due day")
	local born, grown = {}, {}
	for day = 1, 120 do
		local r = Families.daily(reg, rng, day)
		for _, b in ipairs(r.born) do table.insert(born, b) end
		for _, g in ipairs(r.grown) do table.insert(grown, g) end
	end
	assert(#born >= 1, "babies are born")
	local baby = born[1]
	assert(baby.stage == "adult" or reg.people[baby.id].stage == "adult", "babies grow up within 120 days")
	assert(baby.father and baby.mother and baby.last == reg.people[baby.father].last, "the baby takes the father's surname")
	assert(table.find(reg.people[baby.mother].children, baby.id), "the mother's record lists the child")
	assert(#Families.villagers(reg, 1) <= Families.MAX_PEOPLE, "villages stay under the visible cap")
	Families.die(reg, guard.id, 50, "killed", "Dan")
	assert(not guard.alive and guard.killer == "Dan", "a death is recorded with its cause")
	local heir = Families.successor(reg, guard)
	assert(heir and heir.role == "villager", "a villager takes the dead guard's place")
	assert(#Families.relatives(reg, baby) >= 2, "relatives are findable for gossip")
	print(("families: %d born, %d grown, %d couples"):format(#born, #grown, 2))
end
