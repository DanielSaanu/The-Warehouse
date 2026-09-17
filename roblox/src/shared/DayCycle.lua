--!strict
-- Day/night maths shared by the server clock and the client tint. `frac` is 0..1 through one day; night is the
-- last NIGHT_FRACTION of it. Pure Luau so the ramps are tested.
local Config = require(script.Parent.Config)

local DayCycle = {}

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
