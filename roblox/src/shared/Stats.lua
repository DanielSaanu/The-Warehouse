--!strict
-- Creature kinds: the same stat block for players, people and animals, so "hunters are the strongest one on one"
-- is just numbers (DESIGN.md §11). `sprite` is the base name; the client appends _<facing>_<frame>.
local Stats = {}

export type Kind = {
	name: string, sprite: string, hp: number, atk: number, def: number, speed: number,
	animal: boolean, flees: boolean, hostile: boolean, -- hostile: attacks players on sight (subject to reputation)
	label: string, -- what the prompt and hit text call it
}

type Opts = { animal: boolean?, flees: boolean?, hostile: boolean?, label: string? }
local function kind(name: string, sprite: string, hp: number, atk: number, def: number, speed: number, opts: Opts?): Kind
	local o: Opts = opts or {}
	return { name = name, sprite = sprite, hp = hp, atk = atk, def = def, speed = speed, animal = o.animal or false, flees = o.flees or false, hostile = o.hostile or false, label = o.label or name }
end

Stats.Kinds = {
	player = kind("player", "player", 10, 1, 0, 1.0),
	villager = kind("villager", "villager", 5, 1, 0, 0.8, { flees = true }),
	survivor = kind("survivor", "villager", 5, 1, 0, 0.8, { flees = true, label = "survivor" }),
	guard = kind("guard", "guard", 12, 3, 1, 1.0),
	merchant = kind("merchant", "merchant", 5, 1, 0, 0.8, { flees = true }),
	pregnant = kind("pregnant", "villager_preg", 5, 1, 0, 0.7, { flees = true, label = "villager" }),
	baby = kind("baby", "baby", 2, 0, 0, 0, { flees = false, label = "baby" }), -- stays where it is put
	caravan_master = kind("caravan_master", "merchant", 6, 1, 0, 0.9, { flees = true, label = "caravan master" }),
	caravan_guard = kind("caravan_guard", "guard", 10, 3, 1, 1.0, { label = "caravan guard" }),
	hunter = kind("hunter", "hunter", 10, 4, 1, 1.05),
	bandit = kind("bandit", "bandit", 7, 2, 0, 1.0, { hostile = true }),
	deer = kind("deer", "deer", 4, 0, 0, 1.3, { animal = true, flees = true }),
	boar = kind("boar", "boar", 8, 2, 1, 1.1, { animal = true }),
	wolf = kind("wolf", "wolf", 6, 3, 0, 1.25, { animal = true, hostile = true }),
} :: { [string]: Kind }

function Stats.get(name: string): Kind
	local k = Stats.Kinds[name]
	assert(k, "unknown kind " .. tostring(name))
	return k
end

return Stats
