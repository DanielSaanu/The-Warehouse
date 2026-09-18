--!strict
-- The world's ONE clock (docs/ARCHITECTURE.md R5). Owns `meta.gameSeconds` and nothing else yet.
-- Every sim timer on the server - durable or not - is an absolute value of Calendar.now(), so a saved timer needs
-- nothing done to it on load and expires correctly across a catch-up. os.clock() restarts near zero on every new
-- server, which is why nothing the world remembers may be stamped with it (test/structure.test.js enforces this).
-- This file holds the server's only sim-side os.clock() read: now() folds the wall time since the last call into
-- gameSeconds, so the clock is continuous (attack cooldowns need better than a tick) and there is one place to look.
-- Does NOT own calamities yet (Track B moves them here).
--   local now = Calendar.now()            -- stamp or compare a timer
--   local day, frac = Calendar.clock()    -- the calendar, derived
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("DayCycle"))

local Calendar = {}

export type Meta = { gameSeconds: number }
local meta: Meta = { gameSeconds = 0 }
local wall = os.clock()

--- Point the clock at the record that is saved (Sim.state.meta). Time starts flowing from this call.
function Calendar.bind(m: Meta)
	meta = m
	wall = os.clock()
end

function Calendar.now(): number
	local w = os.clock()
	meta.gameSeconds += math.max(0, w - wall)
	wall = w
	return meta.gameSeconds
end

function Calendar.clock(): (number, number)
	return DayCycle.fromSeconds(Calendar.now())
end

--- Jump the calendar FORWARD (Debug `night` / `jump` / `day`). Timers are absolute game time, so anything due before
--- the new moment expires: across a jump campfires burn out and bags vanish, because that much time really passed.
--- It never goes backwards: every live timer (an NPC's next thought, a cooldown) would then be hours in the
--- future and the world would stand still. Returns false, and does nothing, if the moment is already behind us.
function Calendar.setDay(day: number, frac: number): boolean
	local target = DayCycle.toSeconds(day, frac)
	if target < Calendar.now() then return false end
	meta.gameSeconds = target
	wall = os.clock()
	return true
end

--- The next time the day is `frac` through: today if that is still ahead, otherwise tomorrow.
function Calendar.skipTo(frac: number)
	local day = Calendar.clock()
	if not Calendar.setDay(day, frac) then Calendar.setDay(day + 1, frac) end
end

return Calendar
