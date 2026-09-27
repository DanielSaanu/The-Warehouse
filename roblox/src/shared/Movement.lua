--!strict
-- Movement rules shared by the client (prediction) and the server (authority). Pure Luau: tested outside Studio.
--
-- Protocol: the client sends Move(epoch, tx, ty, facing) with the tile it is stepping onto. The server accepts it
-- only if the epoch is current, the tile is adjacent to where the SERVER has the player, walkable, and the pace
-- budget allows it. Any rejection snaps the player back and bumps the epoch, so moves that were already in flight
-- (sent against the old position) are dropped silently instead of being applied from the wrong tile.
--
-- Pace: a step is charged the step time of the tile the player is LEAVING. The client's slide onto a tile lasts
-- that tile's step time and the next step cannot start before it ends, so the real gap between two moves is the
-- step time of the tile in between. Charging the tile being entered instead only agrees on uniform ground.
local Config = require(script.Parent.Config)
local TileTypes = require(script.Parent.TileTypes)
local WorldGen = require(script.Parent.WorldGen)

local Movement = {}

Movement.DIRS = { down = { 0, 1 }, up = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } } :: { [string]: { number } }

--- Seconds it takes to step onto tile (x, y).
function Movement.stepTime(world: WorldGen.World, x: number, y: number): number
	local speed = TileTypes.speed(WorldGen.ground(world, x, y))
	return Config.MOVE_STEP / (if speed > 0 then speed else 1)
end

--- Can something standing on (x, y) step onto (tx, ty)? `occupied` is a set of tile indices with a creature on them
--- (people and animals block each other; the client builds it from the entities it can see).
function Movement.canStep(world: WorldGen.World, x: number, y: number, tx: number, ty: number, occupied: { [number]: any }?): boolean
	if math.abs(tx - x) + math.abs(ty - y) ~= 1 or not WorldGen.walkable(world, tx, ty) then return false end
	if occupied and occupied[WorldGen.index(world, tx, ty)] then return false end
	return true
end

export type Budget = { credit: number, last: number }

function Movement.newBudget(now: number): Budget
	return { credit = Config.MOVE_BURST, last = now }
end

--- Pace check. Elapsed time earns credit (capped at MOVE_BURST); a step spends MOVE_SLACK x its step time.
--- Returns false (and spends nothing) when the step came too soon.
--- A step that costs more than the whole burst window (wading a river) gets the burst on top of its own price
--- instead: otherwise the credit could never reach it and the tile would be impossible to enter, and with the cap
--- set to the price exactly there would be no jitter tolerance left at all. Ordinary tiles are unaffected.
function Movement.spend(budget: Budget, now: number, stepTime: number): boolean
	local cost = stepTime * Config.MOVE_SLACK
	local cap = if cost > Config.MOVE_BURST then cost + Config.MOVE_BURST else Config.MOVE_BURST
	budget.credit = math.min(cap, budget.credit + math.max(0, now - budget.last))
	budget.last = now
	if budget.credit < cost then return false end
	budget.credit -= cost
	return true
end

return Movement
