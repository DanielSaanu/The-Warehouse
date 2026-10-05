--!nonstrict
-- Grudge: the scar a people carry for what you did to them (docs/RUNG3.md part 3, DESIGN.md §7). Pure Luau.
-- Split out of Gossip.lua (gossip QA round 1) when the owed ledger pushed Gossip past the 400-line ceiling: gossip is
-- how news TRAVELS, a grudge is how much it HURTS, and the two only meet in Gossip.seed. Gossip re-exports every
-- function here under its old name, so no caller changed.
-- Owns: `ps.grudge[tribeType]` (0 .. MAX). Keyed by TRIBE TYPE, not by holder: a scar is what a people carry, and
-- keying it per holder would let it dilute away by eviction.
local Config = require(script.Parent.Config)

local Grudge = {}

Grudge.MAX = 3
Grudge.GROUP = 0.25 -- the share of a grudge that lands on you for harm done while riding along (part 4)
Grudge.AMEND_GIFT = 0.1

function Grudge.grudge(ps, tribeType: string?): number
	if not tribeType then return 0 end
	return (ps.grudge and ps.grudge[tribeType]) or 0
end

function Grudge.set(ps, tribeType: string, v: number)
	ps.grudge = ps.grudge or {}
	ps.grudge[tribeType] = math.clamp(v, 0, Grudge.MAX)
end

--- What this act adds to the scar. Only serious harm scars; a slap and a hard bargain do not.
function Grudge.gain(event: string, victimKind: string?, ctx): number
	if event ~= "kill" then return 0 end
	local c = ctx or {}
	if victimKind == "bandit" then return 0.2 end
	if c.fleeing then return 0.5 end -- murder of a runner is the worst of it
	return 0.3
end

--- Harm multiplies by the scar the people already carried. Frozen into the rumour at creation, so what you did is
--- judged by the grudge you had when you did it, not the one you have when the news lands three days later.
function Grudge.multiplier(ps, tribeType: string?, withGroup: boolean?): number
	local g = Grudge.grudge(ps, tribeType)
	if withGroup then g *= Grudge.GROUP end -- harm done riding with a band spreads thin (§7); part 4 sets this
	return 1 + g
end

--- Amends: a gift chips at the scar. Time alone barely helps, which is what the long fade below is for.
function Grudge.amend(ps, tribeType: string?)
	if not tribeType then return end
	local g = Grudge.grudge(ps, tribeType)
	if g > 0 then Grudge.set(ps, tribeType, g - Grudge.AMEND_GIFT) end
end

--- Halve over GRUDGE_FADE_DAYS in-game days. A closed form over a day count, never a per-tick decrement: that is
--- what lets a decay measured in YEARS survive a world that slept past the four-week catch-up cap.
function Grudge.fade(ps, days: number)
	if not ps.grudge or days <= 0 then return end
	for tribeType, v in pairs(ps.grudge) do
		local n = v * 0.5 ^ (days / Config.GRUDGE_FADE_DAYS)
		ps.grudge[tribeType] = if n < 0.01 then nil else n
	end
end

return Grudge
