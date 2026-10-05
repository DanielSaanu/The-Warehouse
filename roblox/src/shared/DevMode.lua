-- Development mode (handoff H4, Danzo 2026-10-05): the pure rule. server/Dev.lua reads Roblox and asks this.
-- Dev mode = NO DataStore reads or writes at all (every Play is a fresh world) + the Debug console + a DEV notice.
-- Off = exactly an ordinary player's game: the real save, no Debug, no dev text.
--   1. Outside Studio it is ALWAYS off, whatever the flag says: a published server is an ordinary game.
--   2. In Studio it follows the boolean attribute `DevMode` on Workspace. Only `false` turns it off; missing (or
--      anything else) means on, because the project is in development and the safe failure is "the real save is
--      never touched".
local DevMode = {}

DevMode.ATTRIBUTE = "DevMode"
DevMode.DEFAULT = true -- in Studio, with no attribute set

--- (on, why). `isStudio` = RunService:IsStudio(); `flag` = workspace:GetAttribute("DevMode").
function DevMode.resolve(isStudio: boolean, flag: any): (boolean, string)
	if not isStudio then return false, "not Studio: always an ordinary game" end
	if flag == false then return false, "Workspace.DevMode is off: the real save, no Debug" end
	if flag == true then return true, "Workspace.DevMode is on" end
	if flag == nil then return DevMode.DEFAULT, "Workspace.DevMode is not set: on by default in Studio" end
	return true, "Workspace.DevMode is not a boolean (" .. type(flag) .. "): treated as on" -- never write the save by accident
end

return DevMode
