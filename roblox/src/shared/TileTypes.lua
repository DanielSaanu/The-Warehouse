--!strict
-- Tile definitions. Ground is one layer, objects sit on top. Ids are small integers so a map serialises to one byte per
-- tile (WorldGen packs id + 33 into a printable byte, so an id must stay under 94).
local TileTypes = {}

export type GroundDef = { id: number, name: string, sprite: string, walk: boolean, speed: number, hides: boolean }
-- `foot` is a multi-tile object's footprint in tiles; it is placed by its ANCHOR, the bottom-left tile, and the rest
-- of the footprint is `part` (or `part_open` when the object is not solid). The sprite may be TALLER than the footprint
-- (a roof, a tree's crown): the renderer hangs the extra rows over the tile behind, Pokemon-style
-- (docs/plans/world-expansion.md). `decor` objects are small and not solid: a road or a camp may clear them.
export type ObjectDef = { id: number, name: string, sprite: string, solid: boolean, interact: string?, foot: { w: number, h: number }?, decor: boolean? }

TileTypes.Ground = {
	[1] = { id = 1, name = "grass", sprite = "grass", walk = true, speed = 1.0, hides = false },
	[2] = { id = 2, name = "grass_2", sprite = "grass_2", walk = true, speed = 1.0, hides = false },
	[3] = { id = 3, name = "tall_grass", sprite = "tall_grass", walk = true, speed = 0.85, hides = true },
	[4] = { id = 4, name = "path", sprite = "path", walk = true, speed = 1.15, hides = false },
	[5] = { id = 5, name = "water", sprite = "water_0", walk = false, speed = 0, hides = false },
	[6] = { id = 6, name = "ford", sprite = "ford", walk = true, speed = 0.6, hides = false },
	[7] = { id = 7, name = "farm", sprite = "farm", walk = true, speed = 0.9, hides = false },
	[8] = { id = 8, name = "flood", sprite = "flood", walk = false, speed = 0, hides = false },
	-- The river is waded, not swum: slow going, but the map does not funnel every crossing to a ford. Lakes stay `water`.
	[9] = { id = 9, name = "river", sprite = "river_0", walk = true, speed = 0.35, hides = false },
	[10] = { id = 10, name = "scorched", sprite = "scorched_ground", walk = true, speed = 1.0, hides = false },
} :: { [number]: GroundDef }

local function obj(id: number, name: string, solid: boolean, extra: { [string]: any }?): ObjectDef
	local d: any = { id = id, name = name, sprite = name, solid = solid }
	for k, v in pairs(extra or {}) do d[k] = v end
	return d :: ObjectDef
end
local function foot(w: number, h: number): { w: number, h: number } return { w = w, h = h } end

-- 0 = nothing. `interact` is the F prompt verb when the player faces the object. Ids 1-17 are the original set and
-- are never renumbered (a saved camp or bag is stamped back by id).
TileTypes.Object = {
	[1] = obj(1, "tree", true),
	[2] = obj(2, "rock", true),
	[3] = obj(3, "cave", true),
	[4] = obj(4, "hut", true),
	[5] = obj(5, "hut_burnt", true),
	[6] = obj(6, "wall", true),
	[7] = obj(7, "gate", false),
	[8] = obj(8, "stall", true),
	[9] = obj(9, "bed", true, { interact = "Rest" }),
	[10] = obj(10, "hut_hunter", true),
	[11] = obj(11, "hut_plunderer", true),
	[12] = obj(12, "totem", true),
	[13] = obj(13, "skull_post", true),
	[14] = obj(14, "camp_lit", true, { sprite = "camp_lit_0", interact = "Rest" }),
	[15] = obj(15, "camp_out", true, { interact = "Rest" }),
	[16] = obj(16, "bag", false, { interact = "Pick up" }),
	[17] = obj(17, "sign", true, { interact = "Read" }),
	-- the body of a multi-tile object: every footprint tile but the anchor. No sprite of its own.
	[18] = obj(18, "part", true, { sprite = "" }),
	[19] = obj(19, "part_open", false, { sprite = "" }),
	-- buildings (the world expansion). Footprint in tiles; the sprite may be taller.
	[20] = obj(20, "town_hall", true, { foot = foot(3, 2) }),      -- 48x48: a stone hall, the roof over the row behind
	[21] = obj(21, "longhouse", true, { foot = foot(3, 2) }),      -- 48x32
	[22] = obj(22, "war_hall", true, { foot = foot(3, 2) }),       -- 48x32
	[23] = obj(23, "granary", true, { foot = foot(2, 2) }),        -- 32x32
	[24] = obj(24, "storehouse", true, { foot = foot(2, 2) }),
	[25] = obj(25, "tannery", true, { foot = foot(2, 2) }),
	[26] = obj(26, "trophy_hall", true, { foot = foot(2, 2) }),
	[27] = obj(27, "knights_post", true),                          -- 16x32: one tile, two tall
	[28] = obj(28, "windmill", true, { foot = foot(2, 2) }),       -- 32x48
	[29] = obj(29, "barn", true, { foot = foot(3, 3) }),           -- 48x64
	[30] = obj(30, "smokehouse", true),                            -- 16x32
	[31] = obj(31, "watchtower", true),                            -- 16x32
	[32] = obj(32, "ruined_watchtower", true),                     -- 16x32
	[33] = obj(33, "lookout_tree", true, { foot = foot(2, 2) }),   -- 32x48
	[34] = obj(34, "tent", true, { foot = foot(2, 2) }),
	[35] = obj(35, "abandoned_tent", true, { foot = foot(2, 2) }),
	[36] = obj(36, "muster_ring", false, { foot = foot(2, 2) }),   -- stood on, not in
	[37] = obj(37, "cage", true),
	[38] = obj(38, "loot_heap", true),
	[39] = obj(39, "drying_rack", true),
	[40] = obj(40, "well", true),
	[41] = obj(41, "firepit", true, { sprite = "camp_lit_0" }),    -- a village fire: lit, but nobody's camp
	[42] = obj(42, "palisade", true),
	[43] = obj(43, "palisade_gate", false),
	[44] = obj(44, "stockade", true, { foot = foot(2, 1) }),       -- 32x16, a barricade across a track
	[45] = obj(45, "stockade_gate", false),
	[46] = obj(46, "hiring_board", true),
	[47] = obj(47, "lantern_post", true),
	[48] = obj(48, "hay_bale", true),
	[49] = obj(49, "woodpile", true),
	[50] = obj(50, "cart", true, { foot = foot(2, 1) }),
	[51] = obj(51, "broken_cart", true, { foot = foot(2, 1) }),
	[52] = obj(52, "scarecrow", true),
	[53] = obj(53, "beehive", true),
	[54] = obj(54, "market_awning", true),
	-- nature
	[55] = obj(55, "pine", true),                                  -- 16x32
	[56] = obj(56, "pine_tall", true),                             -- 16x32
	[57] = obj(57, "tree_autumn", true),                           -- 16x32
	[58] = obj(58, "dead_tree", true),
	[59] = obj(59, "dead_tree_tall", true),                        -- 16x48
	[60] = obj(60, "boulder", true),
	[61] = obj(61, "boulder_mossy", true),
	[62] = obj(62, "rocks_grey", false, { decor = true }),
	[63] = obj(63, "rocks_brown", false, { decor = true }),
	[64] = obj(64, "bush", true),
	[65] = obj(65, "berry_bush", true),
	[66] = obj(66, "mushrooms", false, { decor = true }),
	[67] = obj(67, "flower_red", false, { decor = true }),
	[68] = obj(68, "flower_purple", false, { decor = true }),
	[69] = obj(69, "flower_white", false, { decor = true }),
	[70] = obj(70, "stump", true),
	[71] = obj(71, "fallen_log", true),
	[72] = obj(72, "reeds", false, { decor = true }),
	-- ruins and the places between villages
	[73] = obj(73, "rubble", true),
	[74] = obj(74, "bones", false, { decor = true }),
	[75] = obj(75, "skull", false, { decor = true }),
	[76] = obj(76, "arrows_in_ground", false, { decor = true }),
	[77] = obj(77, "battle_debris", false, { decor = true }),
	[78] = obj(78, "broken_wall", true),
	[79] = obj(79, "tombstone", true),
	[80] = obj(80, "roadside_shrine", true),                       -- 16x32
	[81] = obj(81, "grave_cross", true),
	[82] = obj(82, "broken_fence", true),
	[83] = obj(83, "ash_pile", false, { decor = true }),
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
