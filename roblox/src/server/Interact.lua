--!nonstrict
-- The F key on the server: what is in front of the player decides what happens (DESIGN.md §8, §11).
-- Talk (villager line, guard topics, survivor script, caravan master), trade at a merchant or stall, rest at a
-- bed or camp, place a camp on a free tile outside a village, pick up a bag. The client shows a prompt built from
-- the same rules (Client.client.lua promptFor), the server is the authority.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local Items = require(Shared:WaitForChild("Items"))
local Combat = require(Shared:WaitForChild("Combat"))
local Reputation = require(Shared:WaitForChild("Reputation"))
local Trade = require(Shared:WaitForChild("Trade"))
local Ecology = require(Shared:WaitForChild("Ecology"))
local Calamity = require(Shared:WaitForChild("Calamity"))
local Talk = require(Shared:WaitForChild("Talk"))
local Rng = require(Shared:WaitForChild("Rng"))
local Sim = require(script.Parent:WaitForChild("Sim"))
local Map = require(script.Parent:WaitForChild("Map"))
local State = require(script.Parent:WaitForChild("State"))

local Interact = {}
local S = Sim.state
local O = TileTypes.ObjectByName
local lineRng = Rng.new(os.time())

local function compass(fx, fy, tx, ty): string
	local dx, dy = tx - fx, ty - fy
	local ns = if dy < -6 then "north" elseif dy > 6 then "south" else ""
	local ew = if dx > 6 then "east" elseif dx < -6 then "west" else ""
	if ns ~= "" and ew ~= "" then return ns .. "-" .. ew end
	if ns == "" and ew == "" then return "right here" end
	return ns .. ew
end

--- The knowledge bank for a village, built from live state.
function Interact.context(ps, tribeIdx: number): Talk.Context
	local world = Sim.world()
	local t = S.tribes[tribeIdx]
	local v = Map.village(t.villageId)
	local band = S.groups.band
	local bp = Sim.groupPos(band)
	local bandHint
	if #band.members == 0 then
		bandHint = "The band is broken. Somebody cut them down on the road."
	else
		local where = compass(v.cx, v.cy, bp.x, bp.y)
		bandHint = if where == "right here" then "The bandits are right outside. Keep your knife close."
			else ("There are bandits afoot: the band was last seen %s of here, on the road."):format(where)
	end
	local quotes = Trade.quotes(t.stock, t.tribeType, Reputation.priceMult(ps.rep[t.tribeType]) or 1.3)
	local parts = {}
	for _, q in ipairs(quotes) do table.insert(parts, ("%s %d"):format(q.label, q.buy)) end
	local survivor = t.survivor and S.entities[t.survivor]
	return {
		village = v.name, tribeType = t.tribeType, tribeName = v.tribeName,
		repWord = Reputation.word(ps.rep[t.tribeType]),
		warning = Sim.calamityWarning(),
		calamity = if S.calamity.active then Calamity.notice(S.calamity.kind) else nil,
		wildlife = Ecology.describe(Ecology.at(S.regions, world, v.cx, v.cy)),
		banditHint = bandHint,
		hunterVillage = world.villages[2].name, farmerVillage = world.villages[1].name, plundererVillage = world.villages[3].name,
		hunterDir = WorldGen.compass(world.villages[2].cx - v.cx, world.villages[2].cy - v.cy),
		plundererDir = WorldGen.compass(world.villages[3].cx - v.cx, world.villages[3].cy - v.cy),
		prices = table.concat(parts, ", "),
		scarce = Items.def(Trade.NEEDS[t.tribeType]).label, makes = Items.def(Trade.MAKES[t.tribeType]).label,
		survivorName = if survivor then survivor.first .. " " .. survivor.last else S.tribes[1].surnames[1],
		familyNews = t.news,
		playerName = ps.player.DisplayName,
	}
end

local function dialogue(ps, name: string, lines: { string }, choices: { string }?, role: string?, tribe: number?)
	ps.dialogue = { with = name, role = role, tribe = tribe }
	Sim.notice(ps, "dialogue", { name = name, lines = lines, choices = choices, labels = Talk.TOPIC_LABELS, role = role })
end

local function tribeAt(x: number, y: number): number?
	local v = WorldGen.villageAt(Sim.world(), x, y, 1)
	if not v then return nil end
	for i, t in ipairs(S.tribes) do
		if Map.village(t.villageId) == v then return i end
	end
	return nil
end

local function openTrade(ps, tribeIdx: number, line: string?)
	local t = S.tribes[tribeIdx]
	local mult = Reputation.priceMult(ps.rep[t.tribeType])
	if not mult then
		Sim.text(ps, "The merchant will not deal with you.", "warn")
		return
	end
	ps.trading = tribeIdx
	Sim.notice(ps, "trade", {
		village = Map.village(t.villageId).name, tribeType = t.tribeType, quotes = Trade.quotes(t.stock, t.tribeType, mult),
		camper = Trade.camperPrice(t.tribeType, mult), camperOwned = Items.count(ps.inv, "camper_set"),
		coin = ps.inv.coin, inv = Items.snapshot(ps.inv), line = line, standing = Reputation.word(ps.rep[t.tribeType]),
	})
end

local function talkTo(ps, e)
	local tribeIdx = e.tribe
	local ctx = Interact.context(ps, tribeIdx or 1)
	local rep = ps.rep[ctx.tribeType]
	Sim.faceEntity(e, Combat.dirTo(e.x, e.y, ps.x, ps.y))
	State.meet(ps, e) -- from now on this player sees their name, not their trade
	if e.role == "survivor" then
		if not ps.metSurvivor then
			ps.metSurvivor = true
			Sim.hud(ps) -- the marker over their head goes out the moment you speak to them
		end
		dialogue(ps, e.name, Talk.survivor(ctx), nil, "survivor")
	elseif e.role == "guard" then
		if not Reputation.willTalk(rep) then dialogue(ps, e.label, { Talk.refusal(ctx) }) return end
		dialogue(ps, e.name .. ", guard of " .. ctx.village, { "Ask." }, Talk.TOPICS, "guard", tribeIdx)
	elseif e.role == "merchant" then
		if not Reputation.willTrade(rep) then dialogue(ps, e.label, { Talk.refusal(ctx) }) return end
		openTrade(ps, tribeIdx, Talk.merchant(ctx))
	elseif e.role == "caravan_master" then
		if not Reputation.willTalk(rep) then dialogue(ps, e.label, { Talk.refusal(ctx) }) return end
		dialogue(ps, e.name .. ", caravan master", Talk.caravanMaster(ctx), nil, "caravan_master")
	elseif e.group then
		if e.kind == "bandit" and rep < -10 then dialogue(ps, "bandit", { Talk.groupLine("bandit", ctx) }) return end
		if not Reputation.willTalk(rep) then dialogue(ps, e.label, { Talk.refusal(ctx) }) return end
		dialogue(ps, e.label, { Talk.groupLine(e.kind, ctx) })
	elseif e.kind == "baby" then
		Sim.text(ps, ("%s. Asleep. Best leave it that way."):format(e.first or "The baby"))
	elseif e.species then
		Sim.text(ps, ("The %s watches you."):format(e.kind))
	else
		if not Reputation.willTalk(rep) then dialogue(ps, "villager", { Talk.refusal(ctx) }) return end
		dialogue(ps, e.name, { Talk.villagerLine(lineRng, ctx) })
	end
end

local function restAt(ps, tribeIdx: number)
	local t = S.tribes[tribeIdx]
	if not Reputation.allowsRest(ps.rep[t.tribeType]) then
		Sim.text(ps, "They won't let you stay.", "warn")
		return
	end
	ps.rest = { kind = "village", village = tribeIdx }
	ps.restText = Sim.restText(ps)
	ps.hp = ps.maxHp
	Reputation.apply(ps.rep, Reputation.deltas("rest", nil, t.tribeType))
	Sim.text(ps, ("You rest. If the worst happens you will wake in %s."):format(Map.village(t.villageId).name), "good")
	Sim.hud(ps)
end

-- Who takes a gift: the people who live somewhere, not a band on the road (DESIGN.md §7 lists gifts as a rep event).
local GIFTABLE = { villager = true, guard = true, merchant = true, caravan_master = true, survivor = true, pregnant = true }

--- The item in the selected hot bar slot, or nil.
function Interact.held(ps): string?
	local slot = ps.selected and ps.inv.slots[ps.selected]
	return if slot then slot.item else nil
end

--- Hand the held good over for nothing. The village is better stocked and remembers it.
local function giveTo(ps, e, good: string): boolean
	local ti = e.tribe
	local t = ti and S.tribes[ti]
	if not t then return false end
	if not Reputation.willTalk(ps.rep[t.tribeType]) then
		Sim.text(ps, "They will not take anything from you.", "warn")
		return true
	end
	if not Items.remove(ps.inv, good, 1) then return false end
	t.stock[good] = (t.stock[good] or 0) + 1
	Reputation.apply(ps.rep, Reputation.deltas("gift", e.kind, t.tribeType))
	Sim.faceEntity(e, Combat.dirTo(e.x, e.y, ps.x, ps.y))
	Sim.text(ps, ("You give %s your %s. A gift. They remember that."):format(e.first or e.label or "them", Items.def(good).label), "rep")
	Sim.hud(ps)
	return true
end

--- Eat one of the held food. The only way to heal outside a bed.
local FOOD_HEAL = 3
local function eat(ps): boolean
	if not Items.remove(ps.inv, "food", 1) then return false end
	ps.hp = math.min(ps.maxHp, ps.hp + FOOD_HEAL)
	Sim.text(ps, "You eat.", "good")
	Sim.hud(ps)
	return true
end

--- Which hot bar slot is in hand. nil, or the same slot again, means empty-handed.
function Interact.select(ps, slot: number?)
	local n = tonumber(slot)
	if n and ps.selected == n then n = nil end
	ps.selected = if n and n >= 1 and n <= Items.SLOTS and ps.inv.slots[n] then n else nil
	Sim.hud(ps)
end

--- F pressed.
function Interact.interact(ps)
	if ps.dead then return end
	local world = Sim.world()
	local tx, ty = Combat.facingTile(ps.x, ps.y, ps.facing)
	local id = Sim.occupied[WorldGen.index(world, tx, ty)]
	local e = id and S.entities[id]
	if e then
		local good = Interact.held(ps)
		if good and table.find(Items.GOODS, good) and GIFTABLE[e.role or ""] and e.tribe then
			if giveTo(ps, e, good) then return end
		end
		talkTo(ps, e)
		return
	end
	local obj = WorldGen.object(world, tx, ty)
	if obj == O.sign.id then
		local text = world.signs and world.signs[WorldGen.index(world, tx, ty)]
		dialogue(ps, "a wooden sign", Talk.sign(text or "The weather has taken the words off it."), nil, "sign")
		return
	elseif obj == O.bed.id then
		local ti = tribeAt(tx, ty)
		if ti then restAt(ps, ti) end
		return
	elseif obj == O.stall.id then
		local ti = tribeAt(tx, ty)
		if ti then
			local t = S.tribes[ti]
			local m = t.merchant and S.entities[t.merchant]
			if not m then Sim.text(ps, "The stall is empty. The merchant is gone.", "warn") return end
			openTrade(ps, ti, Talk.merchant(Interact.context(ps, ti)))
		end
		return
	elseif obj == O.camp_lit.id or obj == O.camp_out.id then
		local c = S.camps[ps.player.UserId]
		if c and c.x == tx and c.y == ty then
			ps.rest = { kind = "camp" }
			ps.restText = Sim.restText(ps)
			ps.hp = ps.maxHp
			Sim.text(ps, if c.out then "You rest by the cold ashes. You will wake here." else "You rest by the fire. You will wake here.", "good")
			Sim.hud(ps)
		else
			Sim.text(ps, "Someone else's camp.")
		end
		return
	elseif obj == O.bag.id then
		local b = Sim.bagAt(tx, ty)
		if b and (b.owner == ps.player.UserId or b.public) then Sim.takeBag(ps, b) end
		return
	end
	-- a bag is not solid: you may be standing on it
	if WorldGen.object(world, ps.x, ps.y) == O.bag.id then
		local b = Sim.bagAt(ps.x, ps.y)
		if b and (b.owner == ps.player.UserId or b.public) then Sim.takeBag(ps, b) return end
	end
	-- food in hand and nothing in front of you: eat it
	if Interact.held(ps) == "food" and eat(ps) then return end
	-- a free tile outside any village: camp
	if WorldGen.walkable(world, tx, ty) and not WorldGen.villageAt(world, tx, ty, 1) then
		if Items.count(ps.inv, "camper_set") == 0 then
			Sim.text(ps, "You have no camper set. Merchants sell them.", "warn")
			return
		end
		Items.remove(ps.inv, "camper_set", 1)
		Sim.placeCamp(ps, tx, ty)
		Sim.text(ps, "You unroll the bedroll and strike the flint. This is your camp now.", "good")
		Sim.hud(ps)
	elseif WorldGen.walkable(world, tx, ty) then
		Sim.text(ps, "Not inside a village. Camp out in the open.")
	else
		Sim.text(ps, "Nothing here.")
	end
end

--- A guard topic.
function Interact.topic(ps, topic: string)
	if not ps.dialogue or ps.dialogue.role ~= "guard" then return end
	if not table.find(Talk.TOPICS, topic) then return end
	-- the guard you are talking to, whatever tile you stand on
	local ti = ps.dialogue.tribe or tribeAt(ps.x, ps.y) or 1
	local ctx = Interact.context(ps, ti)
	dialogue(ps, ps.dialogue.with, { Talk.guard(ctx, topic) }, Talk.TOPICS, "guard", ti)
end

--- Trade operations: buy/sell one good, or buy a camper set.
function Interact.trade(ps, op: string, good: string?, n: number?)
	local ti = ps.trading
	if not ti or ps.dead then return end
	local t = S.tribes[ti]
	local mult = Reputation.priceMult(ps.rep[t.tribeType])
	if not mult then ps.trading = nil return end
	local count = math.clamp(math.floor(tonumber(n) or 1), 1, 10)
	if op == "buy" and good and table.find(Items.GOODS, good) then
		local done = 0
		for _ = 1, count do
			local price = Trade.buyPrice(good, t.stock, t.tribeType, mult)
			if (t.stock[good] or 0) <= 0 then Sim.text(ps, "They are out of " .. Items.def(good).label .. ".", "warn") break end
			if ps.inv.coin < price then Sim.text(ps, "Not enough coin.", "warn") break end
			if Items.room(ps.inv, good) < 1 then Sim.text(ps, "No room in your bag.", "warn") break end
			ps.inv.coin -= price
			t.stock[good] -= 1
			Items.add(ps.inv, good, 1)
			done += 1
		end
		if done > 0 then Reputation.apply(ps.rep, Reputation.deltas("trade", nil, t.tribeType)) end
	elseif op == "sell" and good and table.find(Items.GOODS, good) then
		local done = 0
		for _ = 1, count do
			if Items.count(ps.inv, good) < 1 then break end
			local price = Trade.sellPrice(good, t.stock, t.tribeType, mult)
			Items.remove(ps.inv, good, 1)
			ps.inv.coin += price
			t.stock[good] = (t.stock[good] or 0) + 1
			done += 1
		end
		if done > 0 then
			Reputation.apply(ps.rep, Reputation.deltas("trade", nil, t.tribeType))
			if ps.goalStage <= 4 then Sim.setGoal(ps, 5) end -- the first thing you ever sold
		end
	elseif op == "camper" then
		local price = Trade.camperPrice(t.tribeType, mult)
		if not price then Sim.text(ps, "They do not sell camper sets.", "warn")
		elseif ps.inv.coin < price then Sim.text(ps, "Not enough coin.", "warn")
		elseif Items.room(ps.inv, "camper_set") < 1 then Sim.text(ps, "No room in your bag.", "warn")
		else
			ps.inv.coin -= price
			Items.add(ps.inv, "camper_set", 1)
			Reputation.apply(ps.rep, Reputation.deltas("trade", nil, t.tribeType))
			Sim.text(ps, "A bedroll and a flint. Somewhere to sleep that is yours.", "good")
		end
	end
	openTrade(ps, ti, nil)
	Sim.hud(ps)
end

--- Closing a conversation is what moves the goal line on: you have heard the whole of what they said.
function Interact.close(ps)
	local d = ps.dialogue
	ps.dialogue = nil
	ps.trading = nil
	if not d then return end
	if d.role == "survivor" and ps.goalStage <= 1 then
		Sim.setGoal(ps, 2)
	elseif d.role == "guard" and d.tribe == 2 and ps.goalStage <= 3 then
		Sim.setGoal(ps, 4)
	end
end

return Interact
