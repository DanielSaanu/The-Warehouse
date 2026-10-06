--!nonstrict
-- Bodies walking (handoff H9; carved out of Sim.lua, a slice of Track B2): taking the next step of a path, getting
-- round whoever is in the way, and a group's members on the road (the leader walks the route, the rest keep close).
-- Owns: `e.path` / `e.pathI` / `e.nextStepAt` / `e.blockedCount` as a body walks them. The RULES are pure:
-- `shared/Steer.lua` (swap, detour, where a follower stands) and `shared/Tick.leaderStep` (the route, and `pos`).
-- Does NOT plan a path (Sim's pathTo), decide who to fight (Sim's think), or move a collapsed group (Tick.groups).
-- Bound, not required, for the entity helpers, which still live in Sim (the rest of B2 moves them to Bodies).
--   Walk.followPath(e, now)      -- 10 Hz, every entity: one step if due; blocked = swap, detour, or wait
--   Walk.groupStep(e, g, now)    -- a group member's think: leader on the route, the others within 2 tiles
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movement = require(Shared:WaitForChild("Movement"))
local Combat = require(Shared:WaitForChild("Combat"))
local Tick = require(Shared:WaitForChild("Tick"))
local Steer = require(Shared:WaitForChild("Steer"))
local State = require(script.Parent:WaitForChild("State"))
local Sides = require(script.Parent:WaitForChild("Sides"))
local Bands = require(script.Parent:WaitForChild("Bands"))
local Ride = require(script.Parent:WaitForChild("Ride"))

local Walk = {}

local S, occupied, tidx, cheb = State.state, State.occupied, State.tidx, State.cheb
local world, rng
local placeEntity, faceEntity, freeTile, pathTo, wanderStep, markAggression

function Walk.bind(ctx)
	world, rng = ctx.world, ctx.rng
	placeEntity, faceEntity, freeTile, pathTo = ctx.placeEntity, ctx.faceEntity, ctx.freeTile, ctx.pathTo
	wanderStep, markAggression = ctx.wanderStep, ctx.markAggression
end

--- Take the next step of the entity's path if it is due. A blocked step waits a moment, then (Steer.unblock) a
--- leader trades places with one of its own, or anyone walks round the crowd; failing both it waits, and after a
--- few tries drops the path so its brain plans again. Steps are 4-way: the old "a strictly closer neighbour"
--- side-step could never fire on a straight road (H9).
function Walk.followPath(e, now: number)
	if not e.path or now < e.nextStepAt or e.speed <= 0 then return end
	local step = e.path[e.pathI]
	if not step then e.path = nil return end
	if not Movement.canStep(world, e.x, e.y, step.x, step.y, occupied) then
		e.blockedCount = (e.blockedCount or 0) + 1
		faceEntity(e, Combat.dirTo(e.x, e.y, step.x, step.y))
		local other = S.entities[occupied[tidx(step.x, step.y)]]
		local act, p = nil, nil
		if e.blockedCount >= 2 then
			local g = e.group and S.groups[e.group]
			act, p = Steer.unblock(e.x, e.y, e.path, e.pathI, freeTile, function(x, y)
				local o = S.entities[occupied[tidx(x, y)]]
				return o ~= nil and math.abs(x - e.x) + math.abs(y - e.y) == 1 and Steer.maySwap(e, o, g and g.leader)
			end)
		end
		if act == "path" then
			e.path, e.pathI, e.blockedCount, e.nextStepAt = p, 1, 0, now -- the first tile is free: step next tick
			return
		elseif act ~= "swap" then
			e.nextStepAt = now + 0.3
			if e.blockedCount > 4 then e.path = nil e.blockedCount = 0 end
			return
		end
		-- make way for the master: the one in front takes our tile, and finds its own place again from there
		placeEntity(other, e.x, e.y, Combat.dirTo(other.x, other.y, e.x, e.y))
		other.path, other.nextStepAt = nil, now + Movement.stepTime(world, e.x, e.y) / math.max(other.speed, 0.1)
	end
	e.blockedCount = 0
	local facing = Combat.dirTo(e.x, e.y, step.x, step.y)
	placeEntity(e, step.x, step.y, facing)
	e.nextStepAt = now + Movement.stepTime(world, step.x, step.y) / e.speed
	e.pathI += 1
	if e.pathI > #e.path then e.path = nil end
end

--- Group members: the leader walks the route; the others follow the leader's trail.
function Walk.groupStep(e, g, now: number)
	if g.kind == "band" and g.target and S.players[g.target] and Sides.sheltered(S.players[g.target], e) then
		g.target, g.aggroUntil = nil, 0
	end
	-- Running for home: no aggro, no hunting, just go.
	if now < (g.retreatUntil or 0) then g.target, g.aggroUntil = nil, 0 end
	if g.target and now < g.aggroUntil and S.players[g.target] and not S.players[g.target].dead and not e.broken then
		e.state, e.target, e.aggroUntil = "chase", g.target, g.aggroUntil
		markAggression(e, g.target)
		return
	end
	if e.id == g.leader then
		if Ride.holds(g) then return end -- part 4: waiting for a rider who fell behind (Ride.tick faces them)
		if now < g.pauseUntil or (S.calamity.active and S.calamity.kind == "flood" and g.kind == "caravan") then
			wanderStep(e, now)
			return
		end
		-- the route rule is Tick.leaderStep (pure, tested): `pos` moves only on where the leader stands (H6, H9)
		local act = Tick.leaderStep(g, e.x, e.y, e.path ~= nil, { free = freeTile, step = function(r) e.path, e.pathI = { r }, 1 end,
			path = function(x, y, budget) return pathTo(e, x, y, budget, true) end })
		if act == "turn" then Ride.arrive(g) Bands.turn(g) elseif act == "lost" then Bands.collapse(g) end
	else
		local leader = S.entities[g.leader]
		if not leader then
			-- promote
			g.leader = e.id
			return
		end
		-- keep within 2 tiles of the leader, behind it rather than on the tiles it is about to walk (H9)
		if cheb(e.x, e.y, leader.x, leader.y) > 2 and (not e.path or now - e.lastPathAt > 1) then
			local ahead = leader.path and { leader.path[leader.pathI], leader.path[leader.pathI + 1] } or nil
			local spot = Steer.followSpot(freeTile, leader.x, leader.y, e.x, e.y, ahead, 2)
			if spot then pathTo(e, spot.x, spot.y, 200) end
		elseif not e.path and rng:chance(0.2) then
			e.home = { x = leader.x, y = leader.y }
			e.radius = 2
			wanderStep(e, now)
		end
	end
end

return Walk
