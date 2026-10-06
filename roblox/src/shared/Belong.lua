--!strict
-- Belonging: the rules for a player riding with a group (docs/plans/rung3-part4-belonging.md, rung 3 part 4).
-- Pure Luau, so `npm run test:luau` checks every rule (test/luau/belong.test.luau). The server adapter is
-- server/Ride.lua: it gathers the facts, calls these, and says the lines.
-- The test for every rule here is the one above the others: could an NPC ask, ride and be paid under the same rule,
-- with the same facts? Nothing reads a player-only field.
--   local answer, reason = Belong.ask(facts)    -- "yes" or why not
--   local coin = Belong.share(pot, alive, fullSize, shares, rode, walked)
--   local step, newLeg = Belong.legStep(g, g.pos, g.dir)  -- 1 Hz: the leg's road, reset at every turn
local Items = require(script.Parent.Items)

local Belong = {}

Belong.GRUDGE_NO = 0.25    -- a scar this deep with their people is a no until you make amends
Belong.BAR = { caravan = 15, squad = 15, band = -10 } :: { [string]: number } -- standing a kind wants (15 = welcome)
Belong.BAND_SNUB = 50      -- the band will not take the farmers' family
Belong.CARAVAN_POT = 30    -- coin the caravan master pays out per leg, before the cut and the split
Belong.LAG = 4             -- tiles behind the leader before they wait for you
Belong.WAIT = 20           -- seconds per leg the leader will wait, so one idle rider never stalls a caravan
Belong.LEAVE = 12          -- tiles from the leader that count as walking off
Belong.LEAVE_SECONDS = 10  -- for this long
Belong.NEAR = 6            -- close enough to count as walking with them
Belong.HEARD_HALF = 0.5    -- walk at least this much of a leg and the village hears you rode with them
Belong.JUMP = 6            -- route tiles in one second past which `pos` was moved, not walked (Tick.CATCH_UP is 4)
Belong.CLEAN, Belong.LEFT = 2, -3 -- standing with the group for leaving at an end, and mid-route

export type Facts = {
	kind: string,           -- caravan / squad / band
	busy: boolean,          -- fighting or running for home
	askedToday: boolean,
	riders: number, cap: number,
	grudge: number,         -- the player's grudge with this group's tribe type
	heardKill: string?,     -- the victim kind of the newest killing of their tribe they have heard about, if any
	groupRep: number, villageRep: number,
	farmerRep: number,      -- only the band reads it
}

--- The leader's answer. Checks in order, the first that fires wins (most specific first). Returns the answer key
--- ("busy", "asked", "full", "grudge", "heard", "standing", "snub" or "yes") and a detail for the line.
function Belong.ask(f: Facts): (string, string?)
	if f.busy then return "busy", nil end
	if f.askedToday then return "asked", nil end
	if f.riders >= f.cap then return "full", nil end
	if f.grudge >= Belong.GRUDGE_NO then return "grudge", nil end
	if f.heardKill then return "heard", f.heardKill end
	-- the lower of the two (Q5): one number, easy to say in the "no"
	if math.min(f.groupRep, f.villageRep) < (Belong.BAR[f.kind] or 15) then return "standing", nil end
	if f.kind == "band" and f.farmerRep >= Belong.BAND_SNUB then return "snub", nil end
	return "yes", nil
end

--- Does an answer use up the day's ask? Only a no does (so it cannot be pestered into a yes), and "not now" does
--- not: you only asked at a bad moment. A yes spends nothing: leave and ask again, and they know you.
function Belong.spendsAsk(answer: string): boolean
	return answer ~= "busy" and answer ~= "yes"
end

--- The value of what a group carries, at the goods' base price.
function Belong.value(carry: { [string]: number }): number
	local v = 0
	for item, n in pairs(carry) do
		local d = Items.Defs[item]
		if d and d.price then v += d.price * n end
	end
	return v
end

--- The pot at an arrival: the caravan's wage for the leg, plus what the group carries when it is home (`dir == -1`
--- before it turns: that is where Tick's deposit banks the carry into the village).
function Belong.pot(kind: string, carry: { [string]: number }, dir: number): number
	return (if kind == "caravan" then Belong.CARAVAN_POT else 0) + (if dir == -1 then Belong.value(carry) else 0)
end

--- One rider's coin. The pot is cut by losses (`alive / fullSize`), split into `shares` (living members plus riders),
--- and scaled by how much of the leg this rider walked with them (`rode / walked`): effort shows in pay.
function Belong.share(pot: number, alive: number, fullSize: number, shares: number, rode: number, walked: number): number
	if pot <= 0 or shares <= 0 or walked <= 0 or rode <= 0 then return 0 end
	local cut = math.clamp(alive / math.max(1, fullSize), 0, 1)
	return math.floor(pot * cut / shares * math.min(1, rode / walked))
end

export type Leg = { walked: number?, lastPos: number?, lastDir: number? }

--- One second of a group's leg, kept on `leg` (the group record's scratch: `walked`, `lastPos`, `lastDir`). A new
--- direction is a new leg wherever the turn happened (a folded Tick.groupTurn, a materialised Bands.turn, a squad
--- turning for home laden): `walked` starts again and the caller zeroes each rider's `rode` (H10). A move bigger
--- than JUMP in one second is nobody's road (Debug summon, Bands.collapse snapping `pos` to the route).
--- Returns this second's road (0 on a new leg) and whether a new leg began.
function Belong.legStep(leg: Leg, pos: number, dir: number): (number, boolean)
	local last = leg.lastPos or pos
	local turned = leg.lastDir ~= nil and leg.lastDir ~= dir
	leg.lastPos, leg.lastDir = pos, dir
	if turned then
		leg.walked = 0
		return 0, true
	end
	local step = math.abs(pos - last)
	if step > Belong.JUMP then step = 0 end
	leg.walked = (leg.walked or 0) + step
	return step, false
end

--- Did they ride enough of the leg that the village hears of it?
function Belong.heard(rode: number, walked: number): boolean
	return walked > 0 and rode / walked >= Belong.HEARD_HALF
end

--- How a ride ended: "clean" during a pause at an end, "left" anywhere else; "away" for a disconnect, a death or a
--- group that is gone (Q1: costs nothing, pays nothing).
function Belong.leaveGrade(atEnd: boolean, away: boolean): string
	if away then return "away" end
	return if atEnd then "clean" else "left"
end

--- The standing that grade costs or earns, with the group only.
function Belong.leaveDelta(grade: string): number
	if grade == "clean" then return Belong.CLEAN end
	if grade == "left" then return Belong.LEFT end
	return 0
end

--- Should the leader stop for a rider `lag` tiles behind, with `waitLeft` seconds of patience left this leg?
function Belong.wait(lag: number, waitLeft: number): boolean
	return lag > Belong.LAG and lag <= Belong.LEAVE and waitLeft > 0
end

return Belong
