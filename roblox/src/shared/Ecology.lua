--!strict
-- The ecosystem as numbers (DESIGN.md §9). Per region: grass health and counts of deer, boar and wolf. A daily tick
-- makes herbivores eat and breed, predators eat herbivores, starving populations shrink, a little drifts to the
-- neighbours, and the map edges breathe: wolves push in from the north, deer drift south ahead of them, boar fill
-- what the deer leave. Pure Luau, deterministic given an Rng.
local Rng = require(script.Parent.Rng)
local WorldGen = require(script.Parent.WorldGen)
local TileTypes = require(script.Parent.TileTypes)

local Ecology = {}

export type Region = {
	id: number, col: number, row: number,
	forest: number,   -- fraction of tiles that are trees
	open: number,     -- walkable tiles (room to spawn on)
	village: boolean, -- a village sits (partly) in this region
	grass: number,    -- 0..1
	deer: number, boar: number, wolf: number,
	tide: boolean,    -- beast tide: wolves roam by day
}
export type Regions = { list: { Region }, cols: number, rows: number }

Ecology.SPECIES = { "deer", "boar", "wolf" }
Ecology.CAP = { deer = 14, boar = 7, wolf = 6 } :: { [string]: number }

local function regionsOf(list: { Region }, cols: number, rows: number): Regions
	return { list = list, cols = cols, rows = rows }
end

function Ecology.init(world: WorldGen.World, rng: Rng.Rng): Regions
	local cols, rows = WorldGen.regionCols(world), WorldGen.regionRows(world)
	local list: { Region } = {}
	local tree, water = TileTypes.ObjectByName.tree.id, TileTypes.GroundByName.water.id
	for r = 1, cols * rows do
		local x0, y0, x1, y1 = WorldGen.regionBounds(world, r)
		local trees, open, total, wet = 0, 0, 0, 0
		local village = false
		for y = y0, y1 do
			for x = x0, x1 do
				total += 1
				if WorldGen.object(world, x, y) == tree then trees += 1 end
				if WorldGen.ground(world, x, y) == water then wet += 1 end
				if WorldGen.walkable(world, x, y) then open += 1 end
				if not village and WorldGen.villageAt(world, x, y, 0) then village = true end
			end
		end
		local forest = trees / math.max(1, total)
		local row = math.floor((r - 1) / cols) + 1
		local land = 1 - wet / math.max(1, total)
		local deer = math.round((2 + 8 * forest + rng:float() * 2) * land)
		local boar = math.round((0.5 + 4 * forest + rng:float()) * land)
		local wolf = 0
		if row == 1 then wolf = rng:int(1, 3) elseif forest > 0.3 and rng:chance(0.6) then wolf = 1 end
		if village then deer, boar, wolf = math.floor(deer / 2), math.floor(boar / 2), 0 end
		list[r] = { id = r, col = (r - 1) % cols + 1, row = row, forest = forest, open = open, village = village,
			grass = 0.8 + rng:float() * 0.2, deer = deer, boar = boar, wolf = wolf, tide = false }
	end
	return regionsOf(list, cols, rows)
end

local function neighbours(rg: Regions, r: Region): { Region }
	local out = {}
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local c, w = r.col + d[1], r.row + d[2]
		if c >= 1 and c <= rg.cols and w >= 1 and w <= rg.rows then table.insert(out, rg.list[(w - 1) * rg.cols + c]) end
	end
	return out
end

--- One in-game day for every region.
function Ecology.dailyTick(rg: Regions, rng: Rng.Rng)
	-- 1. eat, breed, starve
	for _, r in ipairs(rg.list) do
		r.grass = math.clamp(r.grass + 0.08 * (1 - r.grass) - 0.015 * r.deer - 0.01 * r.boar, 0, 1)
		local capScale = math.clamp(r.open / 160, 0.3, 1)
		-- herbivores
		if r.grass > 0.35 then
			r.deer += math.floor(r.deer * 0.2 + rng:float())
			r.boar += math.floor(r.boar * 0.15 + rng:float() * 0.7)
		else
			r.deer -= math.ceil(r.deer * 0.25)
			r.boar -= math.ceil(r.boar * 0.15)
		end
		-- predators eat herbivores and breed when fed
		if r.wolf > 0 then
			local need = r.wolf
			local prey = r.deer + r.boar
			if prey >= need then
				local eatDeer = math.min(r.deer, math.ceil(need * 0.6))
				r.deer -= eatDeer
				r.boar -= math.min(r.boar, need - eatDeer)
				r.wolf += math.floor(r.wolf * 0.15 + rng:float() * 0.5)
			else
				r.deer, r.boar = 0, 0
				r.wolf -= math.ceil(r.wolf * 0.3)
			end
		end
		r.deer = math.clamp(r.deer, 0, math.floor(Ecology.CAP.deer * capScale))
		r.boar = math.clamp(r.boar, 0, math.floor(Ecology.CAP.boar * capScale))
		r.wolf = math.clamp(r.wolf, 0, if r.village then 1 else math.floor(Ecology.CAP.wolf * capScale))
	end
	-- 2. drift: a tenth of each population wanders to a neighbour
	for _, r in ipairs(rg.list) do
		local ns = neighbours(rg, r)
		for _, sp in ipairs(Ecology.SPECIES) do
			local n = (r :: any)[sp] :: number
			local moving = math.floor(n * 0.1)
			if moving == 0 and n > 1 and rng:chance(0.3) then moving = 1 end
			if moving > 0 and #ns > 0 then
				local to = rng:pick(ns)
				;(r :: any)[sp] = n - moving
				;(to :: any)[sp] = ((to :: any)[sp] :: number) + moving
			end
		end
	end
	-- 3. the borders breathe: wolves from the north, deer drift south (in at the top, out at the bottom), boar fill gaps
	for _, r in ipairs(rg.list) do
		if r.row == 1 then
			if rng:chance(0.4) then r.wolf += 1 end
			if rng:chance(0.4) then r.deer += 1 end
		elseif r.row == rg.rows then
			if r.deer > 0 and rng:chance(0.3) then r.deer -= 1 end
			if r.wolf > 0 and rng:chance(0.3) then r.wolf -= 1 end
		end
		if r.deer < 2 and r.boar < 2 and rng:chance(0.2) then r.boar += 1 end
		if r.village then r.wolf = math.min(r.wolf, 1) end
	end
end

--- Beast tide: wolves pour in from the north and roam by day everywhere for the rest of the day. The north is
--- hit hardest; every region gets at least a few, so a player anywhere on the map meets the tide.
function Ecology.beastTide(rg: Regions)
	for _, r in ipairs(rg.list) do
		if r.row <= 2 then
			r.wolf = math.min(Ecology.CAP.wolf * 2, r.wolf * 2 + 3)
		elseif r.village then
			r.wolf = math.max(r.wolf, 2)
		else
			r.wolf = math.max(r.wolf + 1, 3)
		end
		r.tide = true
	end
end

function Ecology.endTide(rg: Regions)
	for _, r in ipairs(rg.list) do r.tide = false end
end

function Ecology.totals(rg: Regions): { deer: number, boar: number, wolf: number }
	local t = { deer = 0, boar = 0, wolf = 0 }
	for _, r in ipairs(rg.list) do t.deer += r.deer; t.boar += r.boar; t.wolf += r.wolf end
	return t
end

function Ecology.at(rg: Regions, world: WorldGen.World, x: number, y: number): Region
	return rg.list[WorldGen.regionOf(world, x, y)]
end

--- A line a villager might say about the animals near (x, y).
function Ecology.describe(r: Region): string
	if r.wolf >= 3 then return "Wolves. Too many wolves. Don't sleep in the open." end
	if r.deer >= 8 then return "The deer are thick round here this week. Good eating if you can catch one." end
	if r.deer <= 1 and r.boar <= 1 then return "The woods have gone quiet. Something has eaten or scared off the game." end
	if r.boar >= 4 then return "Mind the boar. They charge if you so much as look at them." end
	if r.grass < 0.4 then return "The grass is grazed to the dirt. The deer will starve or move on." end
	return "Deer and a few boar about. A wolf now and then, at night."
end

return Ecology
