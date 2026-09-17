--!strict
-- Server: owns the world clock. Clients only draw what the server tells them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RainState = ReplicatedStorage:WaitForChild("RainState") :: RemoteEvent

local raining = false
local timeLeft = Config.CYCLE_SECONDS

Players.PlayerAdded:Connect(function(p)
	RainState:FireClient(p, raining, timeLeft)
end)

while true do
	task.wait(1)
	timeLeft -= 1
	if timeLeft <= 0 then
		raining = not raining
		timeLeft = if raining then Config.RAIN_SECONDS else Config.CYCLE_SECONDS
	end
	RainState:FireAllClients(raining, timeLeft)
end
