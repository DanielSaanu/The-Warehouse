--!strict
-- Combat maths shared by the server (authority) and the client (feel). Pure Luau.
local Config = require(script.Parent.Config)
local Rng = require(script.Parent.Rng)

local Combat = {}

Combat.DIRS = { down = { 0, 1 }, up = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } } :: { [string]: { number } }

--- Damage of one hit. Never zero: a knife still cuts through leather.
function Combat.damage(atk: number, def: number): number
	return math.max(1, atk - def)
end

--- The tile in front of (x, y) when facing `facing`.
function Combat.facingTile(x: number, y: number, facing: string): (number, number)
	local d = Combat.DIRS[facing] or Combat.DIRS.down
	return x + d[1], y + d[2]
end

--- Facing name that points from (x1, y1) toward (x2, y2), by the larger axis.
function Combat.dirTo(x1: number, y1: number, x2: number, y2: number): string
	local dx, dy = x2 - x1, y2 - y1
	if math.abs(dx) >= math.abs(dy) then
		return if dx >= 0 then "right" else "left"
	end
	return if dy >= 0 then "down" else "up"
end

--- Tile a target on (tx, ty) is knocked to by a hit from (ax, ay): one tile straight away from the attacker.
function Combat.knockbackTile(ax: number, ay: number, tx: number, ty: number): (number, number)
	local dx, dy = tx - ax, ty - ay
	if dx == 0 and dy == 0 then return tx, ty + 1 end
	if math.abs(dx) >= math.abs(dy) then
		return tx + (if dx > 0 then 1 else -1), ty
	end
	return tx, ty + (if dy > 0 then 1 else -1)
end

function Combat.adjacent(x1: number, y1: number, x2: number, y2: number): boolean
	return math.abs(x1 - x2) + math.abs(y1 - y2) == 1
end

--- What a kill leaves the killer. Coin goes straight to the purse.
export type Loot = { [string]: number }
function Combat.loot(kind: string, rng: Rng.Rng): Loot
	if kind == "deer" then return { hide = 1, food = 1 } end
	if kind == "boar" then return { food = 2, hide = 1 } end
	if kind == "wolf" then return { hide = 1 } end
	if kind == "bandit" then
		local l: Loot = { coin = rng:int(2, 4) }
		if rng:chance(0.2) then l.camper_set = 1 end
		if rng:chance(0.3) then l.food = 1 end
		return l
	end
	if kind == "hunter" then return { hide = 1, coin = 2 } end
	if kind == "guard" or kind == "caravan_guard" then return { coin = 2 } end
	if kind == "caravan_master" then return { coin = 6, food = 2 } end
	if kind == "merchant" then return { coin = 5 } end
	return {}
end

--- Timing helpers so the client and server agree on the feel rules.
Combat.COOLDOWN = Config.ATTACK_COOLDOWN
Combat.INVULN = Config.HIT_INVULN
Combat.TELEGRAPH = Config.TELEGRAPH

return Combat
