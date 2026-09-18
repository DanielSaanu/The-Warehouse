--!nonstrict
-- The goal line (docs/qa/rung2-part4.md): one sentence under the clock, moved on by what the player does. It is a
-- tutorial, not a quest system - it stops for good at the first calamity. Owns: ps.goalStage, ps.goal, ps.goalDone
-- (goalStage and goalDone are saved with the player; the sentence is rebuilt from the stage, never saved).
-- Carved verbatim out of Sim.lua when Sim hit its line ceiling. It does not require Sim: Sim passes its `hud` in.
--   Goals.set(ps, 3)        -- never backwards, never after it is done
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Talk = require(Shared:WaitForChild("Talk"))
local Map = require(script.Parent:WaitForChild("Map"))

local Goals = {}

local hud = function(_ps) end
function Goals.bind(hudFn)
	hud = hudFn
end

local function goalContext(): Talk.Context
	local world = Map.get()
	local hunter, farmer = world.villages[2], world.villages[1]
	return {
		hunterVillage = hunter.name,
		hunterDir = WorldGen.compass(hunter.cx - farmer.cx, hunter.cy - farmer.cy),
	} :: any
end

--- Move the goal line to `stage` (see Talk.GOAL_STAGES), but never backwards and never after it is done.
function Goals.set(ps, stage: number)
	if ps.goalDone or stage <= ps.goalStage then return end
	ps.goalStage = stage
	ps.goal = Talk.goal(stage, goalContext())
	if not ps.goal then ps.goalDone = true end
	hud(ps)
end

--- Retire the goal line for good (the first calamity: the world has bigger news than the tutorial).
function Goals.clear(ps)
	if ps.goalDone then return end
	ps.goalDone, ps.goal = true, nil
	hud(ps)
end

--- A returning player's stage came out of their save; the sentence for it did not (it is derived).
function Goals.rebuild(ps)
	if not ps.goalDone and ps.goalStage > 0 then ps.goal = Talk.goal(ps.goalStage, goalContext()) end
end

--- The goal line follows the player around: walking into the hunter village is what finishes the road goal, and
--- from day 6 the only thing being asked is that they are somewhere safe when the week turns. 1 Hz.
function Goals.tick(players, day: number)
	local world = Map.get()
	for _, ps in pairs(players) do
		if not ps.goalDone and not ps.dead then
			if ps.goalStage == 2 and WorldGen.villageAt(world, ps.x, ps.y, 1) == world.villages[2] then Goals.set(ps, 3) end
			if day >= Config.WEEK_DAYS - 1 then Goals.set(ps, 5) end
		end
	end
end

return Goals
