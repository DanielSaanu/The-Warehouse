--!strict
-- Reputation: one number per (tribe, player) from -100 (hostile) to 100 (family). Shown to the player as words.
-- Moves on events, fades toward neutral (half the distance every REP_FADE_DAYS). Grudges and gossip are rung 3.
--
-- Reputation is a record of your conduct, never of your luck (DESIGN.md §7): who drew first is the story, mercy
-- is worth more than a kill, murder of a runner is the worst, and being killed costs nothing.
local Config = require(script.Parent.Config)

local Reputation = {}

Reputation.MIN, Reputation.MAX = -100, 100

--- Where a new player starts with each tribe type: the farmers are your people, the plunderers just burnt them.
Reputation.START = { farmer = 20, hunter = 0, plunderer = -20 } :: { [string]: number }

function Reputation.word(v: number): string
	if v <= -50 then return "hostile" end
	if v <= -15 then return "wary" end
	if v < 15 then return "neutral" end
	if v < 50 then return "welcome" end
	return "family"
end

function Reputation.hostile(v: number): boolean return v <= -50 end
function Reputation.willTalk(v: number): boolean return v > -50 end
function Reputation.willTrade(v: number): boolean return v > -50 end
function Reputation.allowsRest(v: number): boolean return v > -15 end -- wary villages will not put you up either

--- Price multiplier at a merchant: nil means they will not deal with you at all.
function Reputation.priceMult(v: number): number?
	local w = Reputation.word(v)
	if w == "hostile" then return nil end
	if w == "wary" then return 1.3 end
	if w == "neutral" then return 1.0 end
	if w == "welcome" then return 0.9 end
	return 0.8
end

function Reputation.clamp(v: number): number
	return math.clamp(v, Reputation.MIN, Reputation.MAX)
end

--- Fade toward neutral over `days` in-game days.
function Reputation.fade(v: number, days: number): number
	return v * 0.5 ^ (days / Config.REP_FADE_DAYS)
end

export type Deltas = { [string]: number }
--- Context for a violent event: did they attack you first (self-defence), were they running from you (murder).
export type Context = { aggressor: boolean?, fleeing: boolean? }

--- The big number for killing a person of a kind. A child or a baby is the worst thing you can do to a village.
local KILL = { villager = -25, survivor = -25, merchant = -25, caravan_master = -25, pregnant = -40, baby = -40, child = -40, guard = -20, caravan_guard = -20, hunter = -20 } :: { [string]: number }

--- Reputation changes caused by an event, per tribe type. `victimTribe` is the tribe type of the person acted on
--- (nil for wildlife). Events: trade, hit, kill, mercy (a beaten person got away from you), escape (a band lost
--- you), died_to (nothing), rest.
function Reputation.deltas(event: string, victimKind: string?, victimTribe: string?, ctx: Context?): Deltas
	local d: Deltas = {}
	local c: Context = ctx or {}
	if event == "trade" and victimTribe then
		d[victimTribe] = 2
	elseif event == "hit" and victimTribe then
		-- a blow on someone who attacked you costs nothing; on an innocent, a little
		if not c.aggressor then d[victimTribe] = -1 end
	elseif event == "kill" and victimTribe then
		if victimKind == "bandit" then
			-- every settled tribe likes a bandit killer; the plunderers do not (less so when he drew first)
			d.plunderer = if c.aggressor and not c.fleeing then -8 else -15
			d.farmer = 5
			d.hunter = 5
		else
			local base = KILL[victimKind or ""] or -25
			-- murder of a runner is the full number whatever they did first; self-defence is half
			d[victimTribe] = if c.fleeing then base elseif c.aggressor then math.floor(base / 2) else base
		end
	elseif event == "mercy" and victimTribe then
		d[victimTribe] = 3
	elseif event == "escape" and victimTribe then
		if victimTribe == "plunderer" then d.plunderer = 2 end
	elseif event == "died_to" then
		-- being killed costs nothing: dying never feeds a grudge and never stacks (Danzo, 2026-09-17)
	elseif event == "rest" and victimTribe then
		d[victimTribe] = 1
	end
	return d
end

--- Apply deltas to a rep table in place.
function Reputation.apply(rep: { [string]: number }, deltas: Deltas)
	for tribe, delta in pairs(deltas) do
		rep[tribe] = Reputation.clamp((rep[tribe] or 0) + delta)
	end
end

function Reputation.newTable(): { [string]: number }
	local t = {}
	for k, v in pairs(Reputation.START) do t[k] = v end
	return t
end

return Reputation
