--!strict
-- Day/night maths shared by the server clock and the client tint. `frac` is 0..1 through one day; night is the
-- last NIGHT_FRACTION of it. Pure Luau so the ramps are tested.
local Config = require(script.Parent.Config)

local DayCycle = {}

--- The calendar from the world's one clock (docs/ARCHITECTURE.md R5): game seconds since the world began ->
--- (day, fraction through it). Day 1 starts at second 0. The day is DERIVED, so it is never saved.
function DayCycle.fromSeconds(gameSeconds: number): (number, number)
	local day = math.floor(gameSeconds / Config.DAY_SECONDS)
	return day + 1, (gameSeconds - day * Config.DAY_SECONDS) / Config.DAY_SECONDS
end

--- The inverse: the game second at which `day` is `frac` of the way through.
function DayCycle.toSeconds(day: number, frac: number): number
	return ((day - 1) + frac) * Config.DAY_SECONDS
end

--- Name of the part of the day, for the HUD.
function DayCycle.phase(frac: number): string
	local dayPart = 1 - Config.NIGHT_FRACTION
	if frac >= dayPart then
		return if frac >= 1 - Config.NIGHT_RAMP then "dawn" else "night"
	end
	if frac < dayPart * 0.45 then return "morning" end
	if frac < dayPart - Config.NIGHT_RAMP then return "afternoon" end
	return "dusk"
end

--- Night tint opacity: 0 by day, NIGHT_ALPHA at night, with equal-length linear fades at dusk and dawn.
function DayCycle.nightAlpha(frac: number): number
	local dayPart = 1 - Config.NIGHT_FRACTION
	local ramp = Config.NIGHT_RAMP
	local t
	if frac < dayPart - ramp then
		t = 0
	elseif frac < dayPart then
		t = (frac - (dayPart - ramp)) / ramp
	elseif frac < 1 - ramp then
		t = 1
	else
		t = (1 - frac) / ramp
	end
	return Config.NIGHT_ALPHA * math.clamp(t, 0, 1)
end

return DayCycle
