--!strict
-- Movement rules shared by the client (prediction) and the server (authority). Pure Luau: tested outside Studio.
--
-- Protocol: the client sends Move(epoch, tx, ty, facing) with the tile it is stepping onto. The server accepts it
-- only if the epoch is current, the tile is adjacent to where the SERVER has the player, walkable, and the pace
-- budget allows it. Any rejection snaps the player back and bumps the epoch, so moves that were already in flight
-- (sent against the old position) are dropped silently instead of being applied from the wrong tile.
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
function Movement.spend(budget: Budget, now: number, stepTime: number): boolean
	budget.credit = math.min(Config.MOVE_BURST, budget.credit + math.max(0, now - budget.last))
	budget.last = now
	local cost = stepTime * Config.MOVE_SLACK
	if budget.credit < cost then return false end
	budget.credit -= cost
	return true
end

return Movement
