--!strict
-- Client: draws the world the server sends, predicts your own steps, follows you with the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Viewport = require(script.Parent:WaitForChild("Viewport"))

local player = Players.LocalPlayer
local myId = player.UserId

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- The GUI exists before anything can yield, so a problem is never a silent blank screen.
local gui = Instance.new("ScreenGui")
gui.Name = "Game"
gui.IgnoreGuiInset = false -- keep our HUD below Roblox's own top-left buttons
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local loading = Instance.new("TextLabel")
loading.Name = "Loading"
loading.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
loading.BorderSizePixel = 0
loading.Size = UDim2.fromScale(1, 1)
loading.TextColor3 = Color3.fromRGB(236, 235, 240)
loading.Font = Enum.Font.Code
loading.TextScaled = true
loading.TextWrapped = true
loading.ZIndex = 100
loading.Text = "loading world..."
loading.Parent = gui
local loadingStart = os.clock()
task.spawn(function()
	while loading.Parent do
		task.wait(1)
		local waited = os.clock() - loadingStart
		if waited > 5 then
			loading.Text = ("still loading after %ds\n\nIf this stays: is `rojo serve` running and connected?\nIs the Server script running (Output should show a [World] line)?"):format(math.floor(waited))
		end
	end
end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldInit = Remotes:WaitForChild("WorldInit") :: RemoteEvent
local Move = Remotes:WaitForChild("Move") :: RemoteEvent
local EntityState = Remotes:WaitForChild("EntityState") :: RemoteEvent
local Clock = Remotes:WaitForChild("Clock") :: RemoteEvent

if Sprites.Sheets[1].Id == "rbxassetid://0" then
	warn("[Warehouse] Sprites.lua has no asset id. Run: npx warehouse roblox build --upload (see docs/ROBLOX_SETUP.md)")
end

-- ---------- HUD (outside the play area so the night tint does not cover it) ----------
local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.BackgroundTransparency = 1
hud.Size = UDim2.fromScale(1, 1)
hud.ZIndex = 50
hud.Parent = gui

local function makeLabel(name: string, size: UDim2, pos: UDim2, anchor: Vector2): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
	t.BackgroundTransparency = 0.35
	t.BorderSizePixel = 0
	t.TextColor3 = Color3.fromRGB(244, 244, 248)
	t.Font = Enum.Font.Code
	t.TextScaled = true
	t.Size = size
	t.Position = pos
	t.AnchorPoint = anchor
	t.ZIndex = 51
	t.Parent = hud
	return t
end
local clockLabel = makeLabel("Clock", UDim2.fromScale(0.22, 0.045), UDim2.new(0, 8, 0, 8), Vector2.new(0, 0))
clockLabel.Text = "Day 1"
local banner = makeLabel("Banner", UDim2.fromScale(0.5, 0.07), UDim2.fromScale(0.5, 0.06), Vector2.new(0.5, 0))
banner.Visible = false

-- ---------- world ----------
local world: WorldGen.World? = nil
local vp: Viewport.Viewport? = nil

local me = { x = 1, y = 1, facing = "down", frame = 0, lastStep = 0, lastTurnSent = 0 }
local currentVillage: WorldGen.Village? = nil
local bannerUntil = 0

local DIRS: { [string]: { number } } = { down = { 0, 1 }, up = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.W] = "up", [Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.S] = "down", [Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
}
local held: { string } = {}     -- most recent key last
local touchDir: string? = nil

local function spriteFor(facing: string, frame: number): string
	return ("player_%s_%d"):format(facing, frame)
end

local function showBanner(text: string)
	banner.Text = text
	banner.Visible = true
	bannerUntil = os.clock() + Config.BANNER_SECONDS
end

local function tryStep(dir: string, now: number)
	local w, v = world, vp
	if not w or not v then return end
	local d = DIRS[dir]
	local nx, ny = me.x + d[1], me.y + d[2]
	if me.facing ~= dir then
		me.facing = dir
		v:setSprite(myId, spriteFor(dir, me.frame))
	end
	if not WorldGen.walkable(w, nx, ny) then
		if now - me.lastTurnSent > 0.2 then
			me.lastTurnSent = now
			Move:FireServer(0, 0, dir)
		end
		return
	end
	local stepTime = Config.MOVE_STEP / TileTypes.speed(WorldGen.ground(w, nx, ny))
	if now - me.lastStep < stepTime then return end
	me.lastStep = now
	me.x, me.y = nx, ny
	me.frame = 1 - me.frame
	v:moveEntity(myId, nx, ny, stepTime, now)
	v:setSprite(myId, spriteFor(dir, me.frame))
	Move:FireServer(d[1], d[2], dir)
end

local function updateVillageBanner()
	local w = world
	if not w then return end
	local v = WorldGen.villageAt(w, me.x, me.y, 2)
	if v ~= currentVillage then
		currentVillage = v
		if v then showBanner(("%s  (%s)"):format(v.name, v.tribeName)) end
	end
end

WorldInit.OnClientEvent:Connect(function(encoded, meState, others, clock, sheetIds)
	if vp then return end
	Sprites.ApplySheetIds(sheetIds)
	loading:Destroy()
	world = WorldGen.decode(encoded)
	local w = world :: WorldGen.World
	local v = Viewport.new(gui, Config.COLS, Config.ROWS, w)
	vp = v
	me.x, me.y, me.facing = meState.x, meState.y, meState.facing
	v:addEntity(myId, spriteFor(me.facing, 0), me.x, me.y)
	for _, o in ipairs(others) do
		v:addEntity(o.id, spriteFor(o.facing, 0), o.x, o.y, o.name)
	end
	v:setCamera(me.x - 0.5, me.y - 0.5)
	clockLabel.Text = ("Day %d"):format(clock.day)
	updateVillageBanner()
	local start = w.villages[1]
	showBanner(("%s. The morning after."):format(start.name))
end)

EntityState.OnClientEvent:Connect(function(kind, id, ...)
	local v = vp
	if not v then return end
	if kind == "spawn" then
		if id == myId then return end
		local _, x, y, facing, name = ...
		if not v:getEntity(id) then v:addEntity(id, spriteFor(facing, 0), x, y, name) end
	elseif kind == "move" then
		if id == myId then return end
		local x, y, facing = ...
		local e = v:getEntity(id)
		if e then
			local moved = e.x ~= x or e.y ~= y
			v:moveEntity(id, x, y, if moved then Config.MOVE_STEP else 0, os.clock())
			v:setSprite(id, spriteFor(facing, if moved then (if e.sprite:sub(-1) == "0" then 1 else 0) else 0))
		end
	elseif kind == "leave" then
		v:removeEntity(id)
	elseif kind == "snap" then
		local x, y, facing = ...
		me.x, me.y, me.facing = x, y, facing
		v:moveEntity(myId, x, y, 0, os.clock())
		v:setSprite(myId, spriteFor(facing, 0))
	end
end)

-- Ask the server for the world now that our listener exists, and keep asking until it arrives.
task.spawn(function()
	while not vp do
		WorldInit:FireServer()
		task.wait(1.5)
	end
end)

Clock.OnClientEvent:Connect(function(day: number, frac: number)
	local dayPart = 1 - Config.NIGHT_FRACTION
	local phase = if frac < dayPart * 0.5 then "morning" elseif frac < dayPart * 0.85 then "afternoon" elseif frac < dayPart then "evening" else "night"
	clockLabel.Text = ("Day %d, %s"):format(day, phase)
	local v = vp
	if v then
		-- Ramp into night over the last 12% of daylight and out over the last 8% of night.
		local alpha = 0
		if frac >= dayPart then
			alpha = 0.55
			local nightFrac = (frac - dayPart) / Config.NIGHT_FRACTION
			if nightFrac > 0.92 then alpha = 0.55 * (1 - (nightFrac - 0.92) / 0.08) end
		elseif frac > dayPart - 0.12 then
			alpha = 0.55 * (frac - (dayPart - 0.12)) / 0.12
		end
		v:setNight(alpha)
	end
end)

-- ---------- input ----------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local dir = KEYS[input.KeyCode]
		if dir then
			for i = #held, 1, -1 do if held[i] == dir then table.remove(held, i) end end
			table.insert(held, dir)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		local v = vp
		if v then
			local tx, ty = v:screenToTile(input.Position.X, input.Position.Y)
			if tx and ty then
				local dx, dy = tx - me.x, ty - me.y
				if dx == 0 and dy == 0 then touchDir = nil
				elseif math.abs(dx) >= math.abs(dy) then touchDir = if dx > 0 then "right" else "left"
				else touchDir = if dy > 0 then "down" else "up" end
			end
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local dir = KEYS[input.KeyCode]
		if dir then for i = #held, 1, -1 do if held[i] == dir then table.remove(held, i) end end end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		touchDir = nil
	end
end)

-- ---------- frame loop ----------
RunService.RenderStepped:Connect(function()
	local v = vp
	if not v then return end
	local now = os.clock()
	local dir = held[#held] or touchDir
	if dir then tryStep(dir, now) end
	if now - me.lastStep > 0.35 and me.frame ~= 0 then
		me.frame = 0
		v:setSprite(myId, spriteFor(me.facing, 0))
	end
	local e = v:getEntity(myId)
	if e then v:setCamera(e.px + 0.5, e.py + 0.5) end
	v:refresh(now)
	updateVillageBanner()
	if banner.Visible and now > bannerUntil then banner.Visible = false end
end)
