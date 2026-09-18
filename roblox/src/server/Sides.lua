--!nonstrict
-- Who takes whose side, on the server (docs/RUNG3.md part 1). The rule itself is pure and lives in
-- shared/Witness.lua; this turns the simulation's records into that rule's vocabulary and acts on its verdict.
--
-- It deliberately does not `require` Sim: Sim requires this and calls `Sides.bind` once the world exists, so the
-- two never form a require cycle. It also keeps Sim.lua's type inference inside Luau's budget, which a 1800-line
-- module had already reached.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Witness = require(Shared:WaitForChild("Witness"))
local Combat = require(Shared:WaitForChild("Combat"))

local Sides = {}

local S            -- Sim.state
local world
local faceEntity   -- Sim's, so a witness that only watches still turns to look
local markAggression
local pathTo

--- Called once by Sim.init, after the world exists.
function Sides.bind(ctx)
	S, world, faceEntity, markAggression, pathTo = ctx.state, ctx.world, ctx.faceEntity, ctx.markAggression, ctx.pathTo
end

local function cheb(x1: number, y1: number, x2: number, y2: number): number
	return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

-- ---------- who takes whose side (docs/RUNG3.md part 1) ----------
-- Everything the witness rule needs is already on the records; these three turn them into its vocabulary.

--- Who can actually do something about a fight. A farmer running is correct (Stats flags them `flees`).
function Sides.canFight(e): boolean
	if e.species then return e.kind ~= "deer" end
	return e.kind == "guard" or e.kind == "caravan_guard" or e.kind == "hunter" or e.kind == "bandit"
end

--- An entity as one side of a fight.
local function partyOf(e)
	return { tribe = e.tribe, tribeType = if e.tribe then S.tribes[e.tribe].tribeType else nil, species = e.species }
end

--- A player as one side of a fight, seen by `e`: what matters is what *this* witness's tribe thinks of them,
--- which is why the same event reads differently in two villages.
local function playerParty(ps, e)
	local t = e.tribe and S.tribes[e.tribe]
	return { player = true, rep = if t then ps.rep[t.tribeType] else 0 }
end

local function seerOf(e)
	local t = e.tribe and S.tribes[e.tribe]
	return {
		tribe = e.tribe, tribeType = t and t.tribeType, canFight = Sides.canFight(e),
		home = if t then WorldGen.villageAt(world, e.x, e.y, 4) == t.village else false,
	}
end

Sides.WITNESS_RANGE = 8   -- how far a fight carries
Sides.WITNESS_JOIN = 3    -- how many may pile in, so a village does not all fall on one wolf
Sides.WITNESS_EVERY = 1.5 -- a witness re-reads a fight at most this often

-- A "side" of a fight is { e = entity } or { ps = playerState }. `sideRef`/`sideOf` turn one into ids and back,
-- so a villager running for help can still say who was fighting when they arrive.
local function sideRef(side): any
	if side.ps then return { u = side.ps.player.UserId } end
	return { e = side.e.id }
end

local function sideOf(ref): any?
	if not ref then return nil end
	if ref.u then
		local ps = S.players[ref.u]
		return if ps and not ps.dead then { ps = ps } else nil
	end
	local o = S.entities[ref.e]
	return if o then { e = o } else nil
end

--- How witness `e` sees one side of the fight.
local function sideParty(side, e)
	if side.ps then return playerParty(side.ps, e) end
	return partyOf(side.e)
end

--- Point a witness at somebody, using whichever machinery already fits.
local function setFoe(e, foe, now: number): boolean
	if foe.ps then
		e.state, e.target, e.aggroUntil = "chase", foe.ps.player.UserId, now + 15
		markAggression(e, foe.ps.player.UserId) -- stepping into a fight is their own move, not something you did
		return true
	end
	if foe.e and foe.e ~= e then
		e.npcTarget, e.state = foe.e.id, "hunt"
		return true
	end
	return false
end

--- Find the nearest armed person of the same village, for an unarmed witness to run to.
local function nearestArmedKin(e)
	local best, bestD = nil, 16
	for _, o in pairs(S.entities) do
		if o ~= e and o.tribe == e.tribe and Sides.canFight(o) and not o.broken then
			local d = cheb(e.x, e.y, o.x, o.y)
			if d < bestD then best, bestD = o, d end
		end
	end
	return best
end

--- One witness makes up its mind. Returns true if it waded in.
function Sides.applyVerdict(e, att, vic, x: number, y: number, now: number): boolean
	local verdict = Witness.decide(seerOf(e), sideParty(att, e), sideParty(vic, e))
	if verdict == "help_victim" then return setFoe(e, att, now) end
	if verdict == "help_attacker" then return setFoe(e, vic, now) end
	if verdict == "watch" or verdict == "shout" then
		-- looking at it is the whole behaviour, and it reads clearly: they saw, and they did nothing
		faceEntity(e, Combat.dirTo(e.x, e.y, x, y))
	elseif verdict == "flee" then
		e.state, e.fleeUntil, e.threat = "flee", now + 6, { x = x, y = y }
	elseif verdict == "alarm" then
		local kin = nearestArmedKin(e)
		if kin then
			e.state = "alarm"
			e.alarm = { to = kin.id, att = sideRef(att), vic = sideRef(vic), x = x, y = y, until_ = now + 25 }
		else
			e.state, e.fleeUntil, e.threat = "flee", now + 6, { x = x, y = y }
		end
	end
	return false
end

--- Everybody who can see a fight decides what to do about it (docs/RUNG3.md part 1). Called on every blow that
--- lands, which is also how a fight that moves through a village gets re-read by the people it passes.
function Sides.witnessed(att, vic, x: number, y: number)
	local now = os.clock()
	local joined = 0
	for _, e in pairs(S.entities) do
		if joined >= Sides.WITNESS_JOIN then break end
		local involved = (att.e == e) or (vic.e == e)
		local busy = e.broken or e.state == "chase" or e.state == "hunt" or e.state == "alarm"
		if not involved and not busy and now >= (e.nextWitnessAt or 0) and cheb(e.x, e.y, x, y) <= Sides.WITNESS_RANGE then
			e.nextWitnessAt = now + Sides.WITNESS_EVERY
			if Sides.applyVerdict(e, att, vic, x, y, now) then joined += 1 end
		end
	end
end

--- The footprint plus one tile, so standing in a gateway counts.
local function inVillage(x: number, y: number): boolean
	return WorldGen.villageAt(world, x, y, 1) ~= nil
end

--- Somewhere this player is safe from `foe` right now. Only the first days are a sanctuary, so a new player's
--- first walk cannot end in an ambush they had no way to see coming (rung 2 part 4). After that the band will
--- follow you anywhere, and whether that was a good idea is decided by whoever is standing there: a village that
--- is family to you turns out, a village you have wronged folds its arms. Being defended has to be something
--- people *do*, not something the world quietly prevents.
function Sides.sheltered(ps, foe): boolean
	return S.day <= Config.GRACE_DAYS and inVillage(ps.x, ps.y)
end

--- Does `e` go for `o` on sight? Two quite different reasons: a predator is hungry, and an armed person has a
--- feud. Wolves hunting deer is what Ecology has done in the numbers since rung 2; this is the same thing where
--- a player can watch it (docs/RUNG3.md part 1).
function Sides.preysOn(e, o): boolean
	if e.species == "wolf" then return o.species == "deer" or o.species == "boar" end
	if e.species then return false end
	if e.kind == "hunter" and o.species then return true end       -- hunters hunt: that is the job
	if o.species == "wolf" and Sides.canFight(e) then return true end    -- everyone armed wants a wolf dead
	if o.species or not Sides.canFight(e) then return false end
	if not Witness.hostileOnSight(seerOf(e), partyOf(o)) then return false end
	-- A standing enemy is still a standing enemy, but a village does not start a fight on behalf of someone it
	-- likes even less than the enemy. If they are busy with a player this village would not lift a finger for,
	-- let them get on with it (Danzo, 2026-09-18: "if i run somewhere they dont like me they might just watch").
	local ps = o.target and S.players[o.target]
	if ps and not ps.dead then
		return Witness.decide(seerOf(e), partyOf(o), playerParty(ps, e)) ~= "watch"
	end
	return true
end

--- Does this armed person go for that player on sight? (Standing hostility, not taking a side in a fight.)
function Sides.hostileToPlayer(e, ps): boolean
	if not Sides.canFight(e) or not e.tribe then return false end
	return Witness.hostileOnSight(seerOf(e), playerParty(ps, e))
end

--- Running for help: reach the armed kin, tell them, then get out of the way.
function Sides.alarmStep(e, now: number)
	local a = e.alarm
	local kin = a and S.entities[a.to]
	if not a or not kin or now > a.until_ then
		e.state, e.alarm = "idle", nil
		return
	end
	if cheb(e.x, e.y, kin.x, kin.y) <= 2 then
		local att, vic = sideOf(a.att), sideOf(a.vic)
		if att and vic and not (kin.broken or kin.state == "chase" or kin.state == "hunt") then
			Sides.applyVerdict(kin, att, vic, a.x, a.y, now)
		end
		e.alarm = nil
		e.state, e.fleeUntil, e.threat = "flee", now + 5, { x = a.x, y = a.y }
		return
	end
	if not e.path or now - e.lastPathAt > 1 then pathTo(e, kin.x, kin.y, 250) end
end

return Sides
