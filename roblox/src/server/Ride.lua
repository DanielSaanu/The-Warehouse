--!nonstrict
-- Riding along (rung 3 part 4 phase 1, docs/plans/rung3-part4-belonging.md): a player asks a group's leader, rides
-- its route, is paid at each arrival, and the village there hears of it. The RULES are pure in shared/Belong.lua;
-- this gathers their facts from the live world and says the lines.
-- A rider is SCRATCH (`g.riders[userId]`, `ps.ride`), never saved and never a row in `g.members` (learnings S7):
-- `members` is people, and three rules count it. A disconnect, a death or a server stop ends a ride at no cost (Q1).
-- Owns: `g.riders`, `g.walked`, `g.lastPos`, `g.waitLeft`, `g.holding` (set up by Bands.scratch), `ps.ride`,
-- `ps.asked`. Does NOT own the group's route or carry (Bands, Tick) or anybody's standing (Standing).
--   Ride.choices(ps, e)          -- the talk-window topics this person offers you, or nil
--   Ride.topic(ps, topic, e)     -- "ride" or "leave": the lines to show
--   Ride.tick(now)               -- 1 Hz: who walked with them, who lags, who walked off
--   Ride.holds(g)                -- the leader is waiting for a rider (Walk.groupStep)
--   Ride.arrive(g)               -- at an end, before Bands.turn: pay, and seed the `rode` rumour
--   Ride.blocks(ps, e)           -- a blow on your own group is stopped (Sim.attack)
--   Ride.pot(ps, loot)           -- a rider's kill: goods to the pot, coin back to the killer (Sim's killEntity)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Belong = require(Shared:WaitForChild("Belong"))
local Talk = require(Shared:WaitForChild("Talk"))
local Gossip = require(Shared:WaitForChild("Gossip"))
local Grudge = require(Shared:WaitForChild("Grudge"))
local Items = require(Shared:WaitForChild("Items"))
local Trade = require(Shared:WaitForChild("Trade"))
local Combat = require(Shared:WaitForChild("Combat"))
local State = require(script.Parent:WaitForChild("State"))
local Map = require(script.Parent:WaitForChild("Map"))
local Calendar = require(script.Parent:WaitForChild("Calendar"))
local Standing = require(script.Parent:WaitForChild("Standing"))
local Bands = require(script.Parent:WaitForChild("Bands"))

local Ride = {}
local S = State.state
local cheb = State.cheb
Ride.face = nil :: ((any, string) -> ())? -- Sim's faceEntity, set in Sim.init (Sim requires this module, not the reverse)

local function leaderOf(g)
	return g.leader and S.entities[g.leader] or nil
end

local function count(t): number
	local n = 0
	for _ in pairs(t or {}) do n += 1 end
	return n
end

--- A line in the leader's voice: their name in front, so it is never a voice from nowhere.
local function say(ps, g, line: string, colour: string?)
	local l = leaderOf(g)
	State.text(ps, if l and l.first then l.first .. ": " .. line else line, colour)
end

--- The village at the end the group is walking to (`dir`), its name and tribe index; the squad's wood has none.
local function endOf(g, dir: number): (string, number?)
	local at = if dir == -1 then g.from else g.to
	local i = at and Gossip.villageAt(S, Map.get(), at.x, at.y)
	if i then return Map.village(S.tribes[i].villageId).name, i end
	return "the woods", nil
end

--- Fighting or running for home: no time to talk about joining.
local function busy(g, now: number): boolean
	if now < (g.retreatUntil or 0) or (g.target ~= nil and now < (g.aggroUntil or 0)) then return true end
	for id in pairs(g.entities or {}) do
		local m = S.entities[id]
		if m and (m.state == "chase" or m.state == "flee") then return true end
	end
	return false
end

--- The newest killing of this group's tribe that the group or its village has heard about, as the victim's kind.
local function heardKill(ps, g): string?
	local uid, best = ps.player.UserId, nil
	for _, key in ipairs({ tostring(g.id), Gossip.villageKey(g.tribe) }) do
		local r = Gossip.latest(S, key, uid)
		if r and (not best or r.day > best.day or (r.day == best.day and r.id > best.id)) then best = r end
	end
	return if best and best.event == "kill" and best.tribe == g.tribe then best.victim else nil
end

--- The leader offers "ride" (or "leave", if you are with them). Phase 1: the caravan and the squad; the band's own
--- ask rules are phase 3.
function Ride.choices(ps, e): { string }?
	local g = e.group and S.groups[e.group]
	if not g or g.leader ~= e.id or g.kind == "band" then return nil end
	return { if ps.ride == g.id then "leave" else "ride" }
end

--- How a ride ends. `away` (Q1: a disconnect, a death, a group gone) costs nothing and says nothing; otherwise the
--- grade is the plan's: clean in a pause at an end (a small plus, once you have ridden a leg), else "left" (−3).
local function finish(ps, g, uid, away: boolean): string?
	local r = g.riders[uid]
	g.riders[uid] = nil
	if ps and ps.ride == g.id then ps.ride = nil end
	if away or not ps or not r then return nil end
	local grade = Belong.leaveGrade(Calendar.now() < (g.pauseUntil or 0), false)
	local d = Belong.leaveDelta(grade)
	if grade == "clean" and (r.legs or 0) == 0 then d = 0 end -- no standing for joining and leaving on the spot
	if d ~= 0 then Standing.apply(ps, tostring(g.id), { [S.tribes[g.tribe].tribeType] = d }) end
	return Talk.leave(grade)
end

local function ask(ps, g): { string }
	local now, uid = Calendar.now(), ps.player.UserId
	if ps.ride == g.id then return { "You're with us already. Keep up." } end
	if ps.ride then return { "You're riding with somebody else." } end
	local t = S.tribes[g.tribe]
	local dest = endOf(g, g.dir)
	local c = { dest = dest, home = Map.village(t.villageId).name, homeward = g.dir == -1 }
	ps.asked = ps.asked or {}
	local farmer = 1
	for i, tr in ipairs(S.tribes) do if tr.tribeType == "farmer" then farmer = i end end
	local answer, detail = Belong.ask({
		kind = g.kind, busy = busy(g, now), askedToday = ps.asked[g.id] == S.day,
		riders = count(g.riders), cap = Config.RIDERS_MAX, grudge = Grudge.grudge(ps, t.tribeType),
		heardKill = heardKill(ps, g), groupRep = Standing.at(ps, tostring(g.id)), villageRep = Standing.tribe(ps, g.tribe),
		farmerRep = Standing.tribe(ps, farmer),
	})
	if answer ~= "yes" then
		if Belong.spendsAsk(answer) then ps.asked[g.id] = S.day end
		c.reason = detail
		return { Talk.joinNo(answer, c) }
	end
	g.riders[uid] = { rode = 0, legs = 0 }
	ps.ride = g.id
	g.waitLeft = Belong.WAIT
	print(("[Ride] %s rides with the %s"):format(ps.player.Name, g.id))
	return { Talk.joinYes(g.kind, c) }
end

--- A talk-window topic from the leader. Returns the lines to show.
function Ride.topic(ps, topic: string, e): { string }
	local g = e.group and S.groups[e.group]
	if not g or g.leader ~= e.id then return { "Ask the one in charge." } end
	if topic == "ride" then return ask(ps, g) end
	if ps.ride ~= g.id then return { "You're not with us." } end
	return { finish(ps, g, ps.player.UserId, false) or "Suit yourself." }
end

--- 1 Hz, for every group with riders: count the road each rider walked with them, wait for one who lags, and let
--- go of one who walked off, disconnected or died.
local function tickGroup(g, now: number)
	local step = math.abs((g.pos or 1) - (g.lastPos or g.pos or 1))
	g.lastPos = g.pos
	g.walked = (g.walked or 0) + step
	local l = leaderOf(g)
	local lag, lagger = 0, nil
	for uid, r in pairs(g.riders) do
		local ps = S.players[uid]
		if not ps or ps.dead or #g.members == 0 then
			finish(ps, g, uid, true)
		elseif not g.materialised then
			-- folded away because every player walked off: a rider who was already far had walked off
			local line = finish(ps, g, uid, r.farSince == nil)
			if line then say(ps, g, line) end
		elseif l then
			local d = cheb(ps.x, ps.y, l.x, l.y)
			if d <= Belong.NEAR then r.rode += step end
			if d > Belong.LEAVE then
				r.farSince = r.farSince or now
				if now - r.farSince >= Belong.LEAVE_SECONDS then
					local line = finish(ps, g, uid, false)
					if line then say(ps, g, line) end
				end
			else
				r.farSince = nil
				if Belong.wait(d, g.waitLeft or 0) and d > lag then lag, lagger = d, ps end
			end
		end
	end
	-- patience is spent only while they would be walking: a pause at an end is not waiting
	g.holding = lagger ~= nil and now >= (g.pauseUntil or 0)
	if g.holding and l then
		g.waitLeft -= 1
		if Ride.face then Ride.face(l, Combat.dirTo(l.x, l.y, lagger.x, lagger.y)) end
	end
end

function Ride.tick(now: number)
	for _, g in pairs(S.groups) do
		if g.riders and next(g.riders) then tickGroup(g, now) else g.holding = false end
	end
end

function Ride.holds(g): boolean
	return g.holding == true
end

--- At an end of the route, BEFORE Bands.turn (whose deposit empties the carry and whose Gossip.arrive tells the
--- village): each rider who is still with them is paid their share, and one who walked at least half the leg has a
--- `rode` rumour seeded at the group, so the village at this end hears it one hand weaker.
function Ride.arrive(g)
	local riders = count(g.riders)
	if riders > 0 then
		local pot = Belong.pot(g.kind, g.carry, g.dir)
		local shares, alive = #g.members + riders, #g.members
		local name, ti = endOf(g, g.dir)
		local l = leaderOf(g)
		local inVillage = l ~= nil and ti ~= nil and Gossip.villageAt(S, Map.get(), l.x, l.y) == ti
		for uid, r in pairs(g.riders) do
			local ps = S.players[uid]
			if ps and not ps.dead and l and cheb(ps.x, ps.y, l.x, l.y) <= Belong.LEAVE then
				local coin = Belong.share(pot, alive, g.fullSize or alive, shares, r.rode, g.walked or 0)
				if coin > 0 then ps.inv.coin += coin State.hud(ps) end
				local rode = Belong.heard(r.rode, g.walked or 0)
				if rode then
					Standing.event(ps, "rode", g.kind, g.tribe, {}, { [tostring(g.id)] = true })
					r.legs += 1
				end
				local scarce = if ti then Items.def(Trade.NEEDS[S.tribes[ti].tribeType]).label else nil
				-- the squad's far end is a wood with nothing to pay: no line, the hunt is the point there
				if pot > 0 or ti then
					say(ps, g, Talk.arrival({ dest = name, home = name, scarce = scarce, pay = coin, heard = rode and inVillage }), "good")
				end
				print(("[Ride] %s paid %d at %s (rode %d of %d)"):format(ps.player.Name, coin, name, r.rode, g.walked or 0))
			end
			r.rode = 0
		end
	end
	g.walked, g.waitLeft = 0, Belong.WAIT
end

--- A blow on a member of your own group does not land (phase 1: every blow; the second-blow betrayal is phase 3).
function Ride.blocks(ps, e): boolean
	if not ps.ride or e.group ~= ps.ride then return false end
	local now = Calendar.now()
	if now >= (ps.blockedAt or 0) + 3 then
		ps.blockedAt = now
		State.text(ps, (e.first or "They") .. ": Oi! Watch it.", "warn")
	end
	return true
end

--- A rider's kill: the goods go into the group's pot (Q6, so nobody races for a corpse), the coin stays theirs.
function Ride.pot(ps, loot)
	local g = ps and ps.ride and S.groups[ps.ride]
	if not g then return loot end
	local goods = {}
	for item, n in pairs(loot) do
		if item ~= "coin" and n > 0 then table.insert(goods, ("%d %s"):format(n, Items.def(item).label)) end
	end
	if #goods == 0 then return loot end
	Bands.addCarry(g, loot)
	table.sort(goods)
	State.text(ps, "Into the pot: " .. table.concat(goods, ", ") .. ".")
	return { coin = loot.coin }
end

return Ride
