--!strict
-- Reputation: one number per (tribe, player) from -100 (hostile) to 100 (family). Shown to the player as words.
-- Moves on events, fades toward neutral (half the distance every REP_FADE_DAYS). Grudges and gossip are rung 3.
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

--- Reputation changes caused by an event, per tribe type. `victimTribe` is the tribe type of the person acted on
--- (nil for wildlife). The bandit rule: every settled tribe likes a bandit killer, the plunderers do not.
function Reputation.deltas(event: string, victimKind: string?, victimTribe: string?): Deltas
	local d: Deltas = {}
	if event == "trade" and victimTribe then
		d[victimTribe] = 2
	elseif event == "hit" and victimTribe then
		if victimKind == "bandit" then d[victimTribe] = -2 else d[victimTribe] = -5 end
	elseif event == "kill" and victimTribe then
		if victimKind == "bandit" then
			d.plunderer = -15
			d.farmer = 5
			d.hunter = 5
		elseif victimKind == "guard" or victimKind == "caravan_guard" then
			d[victimTribe] = -20
		elseif victimKind == "hunter" then
			d[victimTribe] = -20
		else
			d[victimTribe] = -25
		end
	elseif event == "died_to" and victimTribe then
		d[victimTribe] = -10
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
