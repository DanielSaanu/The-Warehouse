--!nonstrict
-- Development mode, read ONCE at boot (handoff H4; the rule is shared/DevMode.lua). Tick or untick the boolean
-- attribute `DevMode` on Workspace in Studio's Properties panel, then press Play: it never changes mid-session,
-- because turning it off mid-Play would start writing a throwaway world over the real save.
--   Dev.on  -> Persistence opens no DataStore at all, the Debug console exists, players get a DEV line on join
--   not on  -> an ordinary player's game. Always the case outside Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DevMode = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DevMode"))

local Dev = {}
Dev.on, Dev.why = DevMode.resolve(RunService:IsStudio(), workspace:GetAttribute(DevMode.ATTRIBUTE))
Dev.NOTICE = "DEV mode: nothing is saved, every Play is a new world, Debug is on. Untick Workspace.DevMode to play it straight."
print(("[Dev] %s: %s"):format(if Dev.on then "DEV mode ON" else "dev mode off", Dev.why))

return Dev
