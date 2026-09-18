--!strict
-- Who starts a fight with whom (DESIGN.md §5 and §20). Pure: it sees a plain description of two creatures and
-- the state of the region, never the world or the entity table, so the rule can be tested outside Studio.
--
-- This used to be three lines inside Sim.pickNpcTarget that only ran for hunters, guards and caravan guards,
-- which is why a wolf's only route to aggression was the player.
local Aggression = {}

export type Actor = {
	kind: string,        -- villager, guard, hunter, bandit, caravan_guard, deer, boar, wolf, ...
	species: string?,    -- deer / boar / wolf for animals, nil for people
	tribeType: string?,  -- farmer / hunter / plunderer, nil for animals and strays
	inVillage: boolean,
	flees: boolean,      -- Stats: does this kind run rather than fight
}

--- How far each kind looks for something to fight that is not a player. A kind that is not in here starts
--- nothing of its own: villagers, merchants, deer and boar all wait to be provoked.
Aggression.RANGE = { hunter = 6, guard = 5, caravan_guard = 5, wolf = 8, bandit = 7 } :: { [string]: number }

--- Does `a` go for `b`? `tide` is the beast tide flag of a's region.
function Aggression.wants(a: Actor, b: Actor, tide: boolean): boolean
	if a.kind == "hunter" then
		-- hunters bring meat home and clear what preys on their squads; they do not start on other people
		return b.species ~= nil or b.kind == "bandit"
	elseif a.kind == "guard" or a.kind == "caravan_guard" then
		return b.species == "wolf" or b.kind == "bandit"
	elseif a.species == "wolf" then
		if b.species == "deer" or b.species == "boar" then return true end
		-- during a beast tide the wolves come off the hill and take whoever is caught outside the walls
		return tide and b.species == nil and b.flees and not b.inVillage
	elseif a.kind == "bandit" then
		-- DESIGN.md §5: plunderers live off caravans and off anyone caught outside the walls. They do not rob
		-- their own, and they will not follow you inside a village.
		if b.species ~= nil or b.kind == "bandit" then return false end
		if b.tribeType == "plunderer" then return false end
		return not b.inVillage
	end
	return false
end

return Aggression
