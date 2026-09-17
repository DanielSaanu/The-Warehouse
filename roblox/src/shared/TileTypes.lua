--!strict
-- Tile definitions. Ground is one layer, objects sit on top. Ids are small integers so a map serialises to one byte per tile.
local TileTypes = {}

export type GroundDef = { id: number, name: string, sprite: string, walk: boolean, speed: number, hides: boolean }
export type ObjectDef = { id: number, name: string, sprite: string, solid: boolean, interact: string?, big: boolean? }

TileTypes.Ground = {
	[1] = { id = 1, name = "grass", sprite = "grass", walk = true, speed = 1.0, hides = false },
	[2] = { id = 2, name = "grass_2", sprite = "grass_2", walk = true, speed = 1.0, hides = false },
	[3] = { id = 3, name = "tall_grass", sprite = "tall_grass", walk = true, speed = 0.85, hides = true },
	[4] = { id = 4, name = "path", sprite = "path", walk = true, speed = 1.15, hides = false },
	[5] = { id = 5, name = "water", sprite = "water", walk = false, speed = 0, hides = false },
	[6] = { id = 6, name = "ford", sprite = "ford", walk = true, speed = 0.6, hides = false },
	[7] = { id = 7, name = "farm", sprite = "farm", walk = true, speed = 0.9, hides = false },
	[8] = { id = 8, name = "flood", sprite = "flood", walk = false, speed = 0, hides = false },
} :: { [number]: GroundDef }

-- 0 = nothing. `interact` is the F prompt verb when the player faces the object.
TileTypes.Object = {
	[1] = { id = 1, name = "tree", sprite = "tree", solid = true },
	[2] = { id = 2, name = "rock", sprite = "rock", solid = true },
	[3] = { id = 3, name = "cave", sprite = "cave", solid = true },
	[4] = { id = 4, name = "hut", sprite = "hut", solid = true },
	[5] = { id = 5, name = "hut_burnt", sprite = "hut_burnt", solid = true },
	[6] = { id = 6, name = "wall", sprite = "wall", solid = true },
	[7] = { id = 7, name = "gate", sprite = "gate", solid = false },
	[8] = { id = 8, name = "stall", sprite = "stall", solid = true },
	[9] = { id = 9, name = "bed", sprite = "bed", solid = true, interact = "Rest" },
	[10] = { id = 10, name = "hut_hunter", sprite = "hut_hunter", solid = true },
	[11] = { id = 11, name = "hut_plunderer", sprite = "hut_plunderer", solid = true },
	[12] = { id = 12, name = "totem", sprite = "totem", solid = true },
	[13] = { id = 13, name = "skull_post", sprite = "skull_post", solid = true },
	[14] = { id = 14, name = "camp_lit", sprite = "camp_lit_0", solid = true, interact = "Rest" },
	[15] = { id = 15, name = "camp_out", sprite = "camp_out", solid = true, interact = "Rest" },
	[16] = { id = 16, name = "bag", sprite = "bag", solid = false, interact = "Pick up" },
} :: { [number]: ObjectDef }

TileTypes.GroundByName = {} :: { [string]: GroundDef }
TileTypes.ObjectByName = {} :: { [string]: ObjectDef }
for _, d in pairs(TileTypes.Ground) do TileTypes.GroundByName[d.name] = d end
for _, d in pairs(TileTypes.Object) do TileTypes.ObjectByName[d.name] = d end

function TileTypes.walkable(groundId: number, objectId: number): boolean
	local g = TileTypes.Ground[groundId]
	if not g or not g.walk then return false end
	local o = TileTypes.Object[objectId]
	if o and o.solid then return false end
	return true
end

function TileTypes.speed(groundId: number): number
	local g = TileTypes.Ground[groundId]
	return if g then g.speed else 1
end

return TileTypes
