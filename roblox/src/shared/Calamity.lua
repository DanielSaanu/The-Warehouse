--!strict
-- The weekly clock (DESIGN.md §10). One calamity per in-game week, on the last day of the week, with a warning the
-- day before. Rung 2 has two: flood and beast tide. Pure Luau.
local Config = require(script.Parent.Config)
local Rng = require(script.Parent.Rng)

local Calamity = {}

Calamity.KINDS = { "flood", "beast_tide" }

--- The calamity day of the week `day` belongs to (7, 14, 21, ...).
function Calamity.dayOf(day: number): number
	return math.ceil(day / Config.WEEK_DAYS) * Config.WEEK_DAYS
end

function Calamity.isWarningDay(day: number): boolean
	return day % Config.WEEK_DAYS == Config.WEEK_DAYS - 1
end

function Calamity.isCalamityDay(day: number): boolean
	return day % Config.WEEK_DAYS == 0
end

--- Which calamity a given week gets. Deterministic per world seed and week so the warning matches the event.
function Calamity.pick(seed: number, week: number): string
	local rng = Rng.new(seed * 7919 + week * 104729)
	return rng:pick(Calamity.KINDS)
end

function Calamity.weekOf(day: number): number
	return math.ceil(day / Config.WEEK_DAYS)
end

--- Should the calamity start now? Once per calamity day, at CALAMITY_START into it.
function Calamity.shouldStart(day: number, frac: number, started: boolean): boolean
	return not started and Calamity.isCalamityDay(day) and frac >= Config.CALAMITY_START
end

function Calamity.label(kind: string): string
	if kind == "flood" then return "Flood" end
	if kind == "beast_tide" then return "Beast tide" end
	return kind
end

--- The sign the day before, for the HUD and the guard.
function Calamity.warning(kind: string): string
	if kind == "flood" then return "The river is running high. It will burst its banks tomorrow." end
	if kind == "beast_tide" then return "Wolves are howling in the north. A beast tide is coming tomorrow." end
	return "Something is coming."
end

--- The line when it hits.
function Calamity.notice(kind: string): string
	if kind == "flood" then return "The river has burst its banks. Low ground is under water until tomorrow." end
	if kind == "beast_tide" then return "Wolves pour in from the north. Stay near walls or a fire." end
	return "A calamity."
end

function Calamity.over(kind: string): string
	if kind == "flood" then return "The water is going down." end
	if kind == "beast_tide" then return "The wolves are drifting back north." end
	return "It has passed."
end

return Calamity
