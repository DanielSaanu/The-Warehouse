--!strict
-- Who takes whose side (DESIGN.md §7, docs/RUNG3.md part 1). Pure Luau: every case can be checked outside Studio.
--
-- One rule, applied by every NPC that can see a fight:
--
--   Help the side you dislike less, if the gap is worth a fight.
--   If you dislike both, watch. If you like both, shout but do not swing.
--
-- The point (Danzo, 2026-09-18) is that standing is **comparative, not a permission check**. A village that is
-- merely neutral about you will help you against someone it hates; a village that is wary of you will stand and
-- watch you die in its own square. No threshold on a single number can say that, which is why the decision takes
-- both parties at once.
local Reputation = require(script.Parent.Reputation)

local Witness = {}

-- How one tribe type feels about another, before anything a player has done enters into it. From DESIGN.md §5 and
-- Danzo's notes in ideas/INBOX.md: hunters and plunderers are naturally antagonistic (the band ambushes the small
-- hunting parties), farmers and hunters trade and get on, and everyone settled hates the plunderers.
Witness.TRIBE_FEELING = {
	farmer = { farmer = 45, hunter = 20, plunderer = -60 },
	hunter = { farmer = 20, hunter = 45, plunderer = -70 },
	plunderer = { farmer = -35, hunter = -45, plunderer = 35 },
} :: { [string]: { [string]: number } }

-- What an armed person thinks of an animal. A wolf is a thing everyone wants dead, which is why "villages defend
-- themselves in a beast tide" needs no rule of its own. Deer are game, not enemies.
Witness.ANIMAL_FEELING = { wolf = -70, boar = -30, deer = -10 } :: { [string]: number }

Witness.KIN = 90          -- someone of your own village: the strongest pull there is
Witness.GAP = 15          -- how much more you have to like one side before it is worth a fight
Witness.DISLIKE = -15     -- at or below this you dislike them (Reputation's "wary" boundary)
Witness.LIKE = 15         -- at or above this you like them ("welcome")
Witness.ALARM = 15        -- an unarmed witness runs for help when it is someone they like being hurt
Witness.OUTRAGE = 0.6     -- how much of your regard for the victim is charged to whoever struck them

--- One side of a fight, described in the only terms a witness cares about.
--- `rep` is the witness's own tribe's standing with that player, and is what makes the same event read
--- differently in two villages.
export type Party = {
	player: boolean?,     -- a player rather than an NPC
	rep: number?,         -- for a player: this witness's tribe's standing with them
	tribe: number?,       -- for an NPC: which tribe (index), so same-tribe reads as kin
	tribeType: string?,   -- for an NPC: farmer / hunter / plunderer
	species: string?,     -- for an animal: deer / boar / wolf
}

export type Seer = {
	tribe: number?,
	tribeType: string?,
	canFight: boolean,
	home: boolean?,       -- is this their own ground
}

--- How the witness feels about one party, on Reputation's -100..100 scale.
function Witness.feel(w: Seer, p: Party): number
	if p.species then return Witness.ANIMAL_FEELING[p.species] or -20 end
	if p.player then return p.rep or 0 end
	-- an NPC: their own village first, then how the tribes feel about each other
	if p.tribe ~= nil and w.tribe ~= nil and p.tribe == w.tribe then return Witness.KIN end
	local row = w.tribeType and Witness.TRIBE_FEELING[w.tribeType]
	if row and p.tribeType then return row[p.tribeType] or 0 end
	return 0
end

export type Verdict = "help_attacker" | "help_victim" | "watch" | "shout" | "flee" | "alarm"

--- What this witness does about `attacker` hitting `victim`.
function Witness.decide(w: Seer, attacker: Party, victim: Party): Verdict
	local fa, fv = Witness.feel(w, attacker), Witness.feel(w, victim)
	-- A witness judges what it just watched, not what it thought this morning: striking someone they value costs
	-- the attacker on the spot, which is why a village you are family in still turns on you for murder in its
	-- square. Their own people scrapping with each other is a brawl, not an attack, and is not charged this way.
	local ownBrawl = w.tribe ~= nil and attacker.tribe == w.tribe and victim.tribe == w.tribe
	if not ownBrawl then fa -= math.max(0, fv) * Witness.OUTRAGE end
	if not w.canFight then
		-- A farmer running is correct. But they run *somewhere*: for the nearest person who can do something,
		-- if it is someone they care about being hurt. That is how a village that is not looking finds out.
		if fv >= Witness.ALARM and fv > fa then return "alarm" end
		return "flee"
	end
	-- Dislike both and it is not your fight, whoever wins. This is the case that lets a village you have wronged
	-- fold its arms while the band you led there cuts you down.
	if fa <= Witness.DISLIKE and fv <= Witness.DISLIKE then return "watch" end
	local gap = fv - fa
	if math.abs(gap) < Witness.GAP then
		if fa >= Witness.LIKE and fv >= Witness.LIKE then return "shout" end
		return "watch"
	end
	return if gap > 0 then "help_victim" else "help_attacker"
end

--- Standing hostility, which is a different question from taking a side in a fight: does this armed person go
--- for that one on sight? Their own ground makes them bolder; a hunter carries the feud with the plunderers
--- wherever they meet it.
function Witness.hostileOnSight(w: Seer, p: Party): boolean
	local f = Witness.feel(w, p)
	if p.player then return Reputation.hostile(p.rep or 0) end
	if w.home then return f <= Witness.DISLIKE end
	return f <= -50
end

return Witness
