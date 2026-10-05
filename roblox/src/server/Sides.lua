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
local Gossip = require(Shared:WaitForChild("Gossip"))
local Calendar = require(script.Parent:WaitForChild("Calendar"))
local Map = require(script.Parent:WaitForChild("Map"))
local Standing = require(script.Parent:WaitForChild("Standing"))

local Sides = {}

local S            -- Sim.state
local world
local faceEntity   -- Sim's, so a witness that only watches still turns to look
local markAggression
local pathTo
local text

--- Called once by Sim.init, after the world exists.
function Sides.bind(ctx)
	S, world, faceEntity, markAggression, pathTo = ctx.state, ctx.world, ctx.faceEntity, ctx.markAggression, ctx.pathTo
	text = ctx.text
end

function Sides.text(ps, msg: string, colour: string?)
	if text then text(ps, msg, colour) end
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
	-- Part 3: the number this witness holds is their GROUP's if they are on the road with one, else their village's.
	-- Witness.lua needs no change at all - `Party.rep` was always just "what this witness thinks", and now it is.
	return { player = true, rep = if e.tribe then Standing.of(ps, e) else 0 }
end

local function seerOf(e)
	local t = e.tribe and S.tribes[e.tribe]
	return {
		tribe = e.tribe, tribeType = t and t.tribeType, canFight = Sides.canFight(e),
		home = if t then WorldGen.villageAt(world, e.x, e.y, 4) == Map.village(t.villageId) else false,
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

--- One witness makes up its mind. Returns the verdict it actually acted on.
function Sides.applyVerdict(e, att, vic, x: number, y: number, now: number): string
	local verdict = Witness.decide(seerOf(e), sideParty(att, e), sideParty(vic, e))
	if verdict == "help_victim" then return if setFoe(e, att, now) then verdict else "watch" end
	if verdict == "help_attacker" then return if setFoe(e, vic, now) then verdict else "watch" end
	if verdict == "watch" or verdict == "shout" then
		-- looking at it is the whole behaviour, and it reads clearly: they saw, and they did nothing
		faceEntity(e, Combat.dirTo(e.x, e.y, x, y))
	elseif verdict == "flee" then
		-- never re-arm a flight already running, or every later blow scatters the village further and it never
		-- comes home
		e.state, e.threat = "flee", { x = x, y = y }
		e.fleeUntil = math.max(e.fleeUntil or 0, now + 6)
	elseif verdict == "alarm" then
		local kin = nearestArmedKin(e)
		if kin then
			e.state = "alarm"
			e.alarm = { to = kin.id, att = sideRef(att), vic = sideRef(vic), x = x, y = y, until_ = now + 25 }
		else
			e.state, e.threat = "flee", { x = x, y = y }
			e.fleeUntil = math.max(e.fleeUntil or 0, now + 6)
			return "flee"
		end
	end
	return verdict
end

--- The player is one of the two sides, or neither. Which side decides whether an intervention reads as help or
--- as the village turning on them.
local function playerIn(att, vic)
	if att.ps then return att.ps, "attacker" end
	if vic.ps then return vic.ps, "victim" end
	return nil, nil
end

--- One line, and not often, so the player can tell what their standing just bought them. Without this the whole
--- feature is legible only as sprites moving, and DESIGN.md §7 is about the player understanding where they stand.
local function tellPlayer(ps, role, forYou: number, againstYou: number, watched: number, alarmed: number, where, now: number)
	if forYou + againstYou + alarmed == 0 and not (watched > 0 and role == "victim") then return end
	-- Somebody wading in outranks somebody running for help, which outranks nobody moving. A louder line may
	-- interrupt the cooldown once: a villager shouting on the first blow must not swallow "the guard came".
	local rank = if forYou + againstYou > 0 then 3 elseif alarmed > 0 then 2 else 1
	if now < (ps.nextSideLine or 0) and rank <= (ps.lastSideRank or 0) then return end
	ps.nextSideLine, ps.lastSideRank = now + 6, rank
	local place = where or "They"
	if againstYou > 0 then
		Sides.text(ps, ("%s takes their side."):format(place), "warn")
	elseif forYou > 0 then
		Sides.text(ps, ("%s turns out for you."):format(place), "good")
	elseif alarmed > 0 then
		Sides.text(ps, if role == "attacker" then "Someone has run for the guard." else "Someone is running for help.")
	else
		Sides.text(ps, "They watched. Nobody moved.", "warn")
	end
end

--- An armed local has set about somebody who was coming for this player. Worth saying even though no blow has
--- landed on them: a village that protects you well enough that you are never hit would otherwise say nothing.
function Sides.tellHelp(ps, e)
	local now = Calendar.now()
	tellPlayer(ps, "victim", 1, 0, 0, 0, e.tribe and Map.village(S.tribes[e.tribe].villageId).name, now)
end

--- Everybody who can see a fight decides what to do about it (docs/RUNG3.md part 1). Called on every blow that
--- lands, which is also how a fight that moves through a village gets re-read by the people it passes.
--- Everybody who can see a fight decides what to do about it, and everybody who can see it REMEMBERS it. The two
--- sets are deliberately different sizes: the join cap limits who wades in, never who carries the story, and a
--- fleeing unarmed villager still counts - part 1 promised they "carry what they saw" and this is that hook.
--- Animals and babies weigh nothing either way.
function Sides.witnessed(att, vic, x: number, y: number)
	local now = Calendar.now()
	local joined = 0
	local ps, role = playerIn(att, vic)
	local forYou, againstYou, watched, alarmed, where = 0, 0, 0, 0, nil
	-- collected in the sweep below rather than in a second one; the victim keeps it so a fatal blow knows who saw it
	local holders = {}
	if vic.e then vic.e.seenBy = holders end
	for _, e in pairs(S.entities) do
		local involved = (att.e == e) or (vic.e == e)
		if not involved and not e.species and e.kind ~= "baby" and cheb(e.x, e.y, x, y) <= Sides.WITNESS_RANGE then
			local h = Gossip.holderOf(e)
			if h then holders[h] = true end
		end
		-- Animals do not weigh a fight, they hunt (see pickNpcTarget): without this a wolf watching a guard beat
		-- another wolf sides with the guard, because it dislikes wolves. A baby cannot act on any verdict either.
		-- `flee` counts as busy so a villager already running is not re-armed by every later blow.
		local busy = e.species ~= nil or e.kind == "baby" or e.broken
			or e.state == "chase" or e.state == "hunt" or e.state == "alarm" or e.state == "flee"
		if joined < Sides.WITNESS_JOIN and not involved and not busy and now >= (e.nextWitnessAt or 0) and cheb(e.x, e.y, x, y) <= Sides.WITNESS_RANGE then
			e.nextWitnessAt = now + Sides.WITNESS_EVERY
			local verdict = Sides.applyVerdict(e, att, vic, x, y, now)
			local helped = if verdict == "help_victim" then "victim" elseif verdict == "help_attacker" then "attacker" else nil
			if helped then joined += 1 end
			if ps then
				if helped then
					if helped == role then forYou += 1 else againstYou += 1 end
					where = where or (e.tribe and Map.village(S.tribes[e.tribe].villageId).name)
				elseif verdict == "alarm" then alarmed += 1
				elseif verdict == "watch" or verdict == "shout" then watched += 1 end
			end
		end
	end
	if ps then tellPlayer(ps, role, forYou, againstYou, watched, alarmed, where, now) end
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
	-- A full belly is a reason to stop. Without it a predator kills everything it can reach for as long as it
	-- can reach it, which is what "too bloodthirsty" means (Danzo, 2026-09-18).
	if o.species and Calendar.now() < (e.fedUntil or 0) then return false end
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
