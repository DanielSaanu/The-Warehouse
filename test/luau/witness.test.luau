-- Who takes whose side (docs/RUNG3.md part 1). The cases below are Danzo's own, 2026-09-18:
-- "if i go out and make trouble and im getting chased if i run to somewhere where they dont like me they might
--  just watch, or if i am being attacked by someone they hate they might help even if theyre neutral towards me".
local Witness = __require("Witness")
local Reputation = __require("Reputation")

local function guardOf(tribe: number, tribeType: string, home: boolean?)
	return { tribe = tribe, tribeType = tribeType, canFight = true, home = home }
end
local function villagerOf(tribe: number, tribeType: string)
	return { tribe = tribe, tribeType = tribeType, canFight = false, home = true }
end
local function player(rep: number)
	return { player = true, rep = rep }
end
local function npc(tribe: number, tribeType: string)
	return { tribe = tribe, tribeType = tribeType }
end
local function animal(species: string)
	return { species = species }
end

-- The four cases the feature exists for.
do
	local farmerGuard = guardOf(1, "farmer", true)
	local bandit = npc(3, "plunderer")

	-- 1. Chased into a village that likes you: they turn out for you.
	assert(Witness.decide(farmerGuard, bandit, player(40)) == "help_victim", "a welcome player gets defended")
	assert(Witness.decide(farmerGuard, bandit, player(80)) == "help_victim", "so does family")

	-- 2. Chased into a village that is wary of you: they watch. You brought this here.
	assert(Witness.decide(farmerGuard, bandit, player(-20)) == "watch", "a wary village folds its arms")
	assert(Witness.decide(farmerGuard, bandit, player(-60)) == "watch", "and a hostile one certainly does")

	-- 3. Jumped by someone they hate while they are only neutral about you: they help you anyway.
	assert(Witness.decide(farmerGuard, bandit, player(0)) == "help_victim", "neutral still beats hated")

	-- 4. Murder in a square where you are family: the same people come for you.
	local kin = npc(1, "farmer")
	assert(Witness.decide(farmerGuard, player(80), kin) == "help_victim", "blood outweighs standing")
	assert(Witness.decide(farmerGuard, player(100), kin) == "help_victim", "even at the top of the scale")
end

-- It is not about the player at all: a band hitting a hunter squad near a farmer village makes the farmers choose.
do
	local farmerGuard = guardOf(1, "farmer", true)
	assert(Witness.decide(farmerGuard, npc(3, "plunderer"), npc(2, "hunter")) == "help_victim", "farmers side with hunters")
	-- and the plunderers' own people side the other way
	local banditWitness = guardOf(3, "plunderer", true)
	assert(Witness.decide(banditWitness, npc(3, "plunderer"), npc(2, "hunter")) == "help_attacker", "a band backs its own")
end

-- Villages defending themselves falls out of the rule rather than being a feature: a wolf is disliked by everyone.
do
	local guard = guardOf(1, "farmer", true)
	assert(Witness.decide(guard, animal("wolf"), npc(1, "farmer")) == "help_victim", "a wolf on a villager")
	assert(Witness.decide(guard, animal("wolf"), player(0)) == "help_victim", "a wolf on a stranger, even")
	assert(Witness.decide(guard, animal("wolf"), player(-30)) == "watch", "but not on someone they dislike")
end

-- Unarmed witnesses: flee, or run for help when it is someone they care about.
do
	local villager = villagerOf(1, "farmer")
	assert(Witness.decide(villager, npc(3, "plunderer"), npc(1, "farmer")) == "alarm", "a villager fetches help for kin")
	assert(Witness.decide(villager, npc(3, "plunderer"), player(40)) == "alarm", "and for a friend of the village")
	assert(Witness.decide(villager, npc(3, "plunderer"), player(-40)) == "flee", "but not for someone they dislike")
	assert(Witness.decide(villager, player(0), npc(1, "farmer")) == "alarm", "a stranger hitting one of ours brings help")
end

-- Your own people scrapping with each other is a brawl, not an attack: shout, do not swing. An outsider striking
-- one of yours is a different thing entirely, however much you like the outsider.
do
	local guard = guardOf(1, "farmer", true)
	assert(Witness.decide(guard, npc(1, "farmer"), npc(1, "farmer")) == "shout", "two of your own brawling")
	assert(Witness.decide(guard, player(80), npc(1, "farmer")) == "help_victim", "a beloved outsider is still an outsider")
	assert(Witness.decide(guard, npc(2, "hunter"), npc(1, "farmer")) == "help_victim", "so is a friendly one")
end

-- Animals have no politics. A wolf feels -70 about a wolf and 0 about the guard beating it, so the rule alone
-- would have it side with the guard against its own packmate. Sides.witnessed excludes animal witnesses for
-- exactly this reason; the rule is asserted here so the reason is written down where the numbers are.
do
	local wolf = { tribe = nil, tribeType = nil, canFight = true, home = false }
	local packmate = animal("wolf")
	local guard = npc(1, "farmer")
	assert(Witness.feel(wolf, packmate) < Witness.feel(wolf, guard),
		"by feeling alone a wolf prefers a farmer to another wolf - which is why animals must not be witnesses")
	assert(Witness.decide(wolf, guard, packmate) == "help_attacker",
		"and the rule would have it help the guard: Sides.witnessed must never ask an animal")
end

-- The same event, read in two villages, must come out differently. That is the whole design point.
do
	local bandit = npc(3, "plunderer")
	local likesYou = guardOf(1, "farmer", true)
	local waryOfYou = guardOf(2, "hunter", true)
	local verdictA = Witness.decide(likesYou, bandit, player(40))
	local verdictB = Witness.decide(waryOfYou, bandit, player(-20))
	assert(verdictA == "help_victim" and verdictB == "watch", "standing is comparative, not a permission check")
end

-- feel(): the scale behaves, and kin outranks every opinion a stranger can earn.
do
	local w = guardOf(1, "farmer", true)
	assert(Witness.feel(w, npc(1, "farmer")) == Witness.KIN, "own village is kin")
	assert(Witness.feel(w, npc(2, "hunter")) > 0, "farmers get on with hunters")
	assert(Witness.feel(w, npc(3, "plunderer")) < -50, "and not with the band")
	assert(Witness.feel(w, player(37)) == 37, "a player is exactly what this tribe thinks of them")
	assert(Witness.feel(w, animal("wolf")) < Witness.feel(w, animal("deer")), "wolves are worse than deer")
	assert(Witness.KIN > 100 - 1 - 10, "kin has to outrank a player the tribe adores")
	assert(Witness.feel(w, npc(1, "farmer")) > Witness.feel(w, player(Reputation.MAX)) - Witness.GAP,
		"killing one of ours is answered even by a village that loves you")
end

-- Standing hostility is a separate question from taking sides, and it must not fire on the merely unpopular.
do
	local farmerGuard = guardOf(1, "farmer", true)
	assert(Witness.hostileOnSight(farmerGuard, npc(3, "plunderer")), "a band on farmer ground gets attacked")
	assert(not Witness.hostileOnSight(farmerGuard, npc(2, "hunter")), "hunters do not")
	assert(not Witness.hostileOnSight(farmerGuard, player(-20)), "a wary player is not attacked on sight")
	assert(Witness.hostileOnSight(farmerGuard, player(-60)), "a hostile one is")
	-- away from home you need a real feud, not just dislike
	local away = guardOf(1, "farmer", false)
	assert(Witness.hostileOnSight(away, npc(3, "plunderer")), "the band is a real feud anywhere")
	local hunterAway = guardOf(2, "hunter", false)
	assert(Witness.hostileOnSight(hunterAway, npc(3, "plunderer")), "hunters carry their feud with them")
end

print("witness: every side-taking case ok")
