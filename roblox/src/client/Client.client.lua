--!strict
-- First playable: a walled room, a player you can move with WASD / arrows / tap, and a rain cycle from the server.
-- Everything visual comes from Sprites.lua, which The Warehouse generates. Add a scene there, rebuild, use it here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Grid = require(Shared:WaitForChild("Grid"))
local Config = require(Shared:WaitForChild("Config"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local RainState = ReplicatedStorage:WaitForChild("RainState") :: RemoteEvent

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Game"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

if Sprites.Sheets[1].Id == "rbxassetid://0" then
	warn("[Warehouse] Sprites.lua has no asset id yet. Run: warehouse roblox build --upload (see docs/ROBLOX_SETUP.md)")
end

local grid = Grid.new(gui, Config.COLS, Config.ROWS)

-- World: walls around the edge, moss inside. Later this comes from the server / generator.
local solid: { [string]: boolean } = {}
for y = 1, Config.ROWS do
	for x = 1, Config.COLS do
		local wall = x == 1 or y == 1 or x == Config.COLS or y == Config.ROWS
		grid:setTile(x, y, if wall then "wall_stone" else "floor_moss")
		if wall then solid[x .. "," .. y] = true end
	end
end

-- A couple of scavengers standing around, so the room is not empty.
grid:spawn("scav_idle", 10, 4)
grid:spawn("scav_red", 12, 8)

-- Player
local px, py = 3, 3
local me = grid:spawn("slug_idle", px, py)

local function tryMove(dx: number, dy: number)
	local nx, ny = px + dx, py + dy
	if not grid:inBounds(nx, ny) or solid[nx .. "," .. ny] then return end
	px, py = nx, ny
	grid:moveTo(me, px, py, Config.MOVE_TWEEN)
	if dx ~= 0 then grid:face(me, dx) end
end

local KEYS = {
	[Enum.KeyCode.W] = { 0, -1 }, [Enum.KeyCode.Up] = { 0, -1 },
	[Enum.KeyCode.S] = { 0, 1 }, [Enum.KeyCode.Down] = { 0, 1 },
	[Enum.KeyCode.A] = { -1, 0 }, [Enum.KeyCode.Left] = { -1, 0 },
	[Enum.KeyCode.D] = { 1, 0 }, [Enum.KeyCode.Right] = { 1, 0 },
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local d = KEYS[input.KeyCode]
		if d then tryMove(d[1], d[2]) end
	elseif input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Tap: move one step toward the tapped cell (dominant axis).
		local root = grid.root
		local rel = (input.Position - Vector3.new(root.AbsolutePosition.X, root.AbsolutePosition.Y, 0))
		local cx = math.floor(rel.X / root.AbsoluteSize.X * Config.COLS) + 1
		local cy = math.floor(rel.Y / root.AbsoluteSize.Y * Config.ROWS) + 1
		local dx, dy = cx - px, cy - py
		if math.abs(dx) >= math.abs(dy) then tryMove(math.sign(dx), 0) else tryMove(0, math.sign(dy)) end
	end
end)

-- HUD (Roblox text is fine for now; a baked pixel-font logo can replace it later via a "text" scene).
local hud = Instance.new("TextLabel")
hud.Name = "Cycle"
hud.BackgroundTransparency = 0.4
hud.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
hud.TextColor3 = Color3.fromRGB(244, 244, 248)
hud.Font = Enum.Font.Code
hud.TextScaled = true
hud.Size = UDim2.fromScale(0.35, 0.06)
hud.Position = UDim2.fromScale(0.01, 0.01)
hud.ZIndex = 10
hud.Parent = grid.layers.HUD

RainState.OnClientEvent:Connect(function(raining: boolean, secondsLeft: number)
	grid:setRain(raining)
	hud.Text = if raining then ("RAIN  %ds"):format(secondsLeft) else ("rain in %ds"):format(secondsLeft)
end)
