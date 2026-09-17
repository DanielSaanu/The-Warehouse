--!strict
-- Client: draws the world the server sends, predicts your own steps, follows you with the camera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Movement = require(Shared:WaitForChild("Movement"))
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Viewport = require(script.Parent:WaitForChild("Viewport"))

local player = Players.LocalPlayer
local myId = player.UserId
local playerGui = player:WaitForChild("PlayerGui")

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- The GUI exists before anything can yield, so a problem is never a silent blank screen.
-- Two ScreenGuis: a black backdrop that covers the whole screen including Roblox's top bar, and the game itself,
-- which stays below the top bar (and inside phone safe areas) so Roblox's buttons never cover the play area.
local backdropGui = Instance.new("ScreenGui")
backdropGui.Name = "Backdrop"
backdropGui.IgnoreGuiInset = true
backdropGui.ResetOnSpawn = false
backdropGui.DisplayOrder = 0
local backdrop = Instance.new("Frame")
backdrop.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = backdropGui
backdropGui.Parent = playerGui

local gui = Instance.new("ScreenGui")
gui.Name = "Game"
gui.IgnoreGuiInset = false
gui.ResetOnSpawn = false
gui.DisplayOrder = 1
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- layers sort among siblings: the night tint covers every entity
gui.Parent = playerGui

local loading = Instance.new("TextLabel")
loading.Name = "Loading"
loading.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
loading.BorderSizePixel = 0
loading.Size = UDim2.fromScale(1, 1)
loading.TextColor3 = Color3.fromRGB(236, 235, 240)
loading.Font = Enum.Font.Code
loading.TextSize = 20
loading.TextWrapped = true
loading.ZIndex = 100
loading.Text = "loading world..."
loading.Parent = gui
local loadingStart = os.clock()
task.spawn(function()
	while loading.Parent do
		task.wait(1)
		local waited = os.clock() - loadingStart
		if waited > 5 and loading.Parent then
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

-- ---------- state ----------
local world: WorldGen.World? = nil
local vp: Viewport.Viewport? = nil

-- epoch: bumped by the server on every correction; moves carry it so stale in-flight moves are ignored.
-- nextStepAt: when the current step's slide ends, i.e. the earliest the next step may start.
local me = { x = 1, y = 1, facing = "down", frame = 0, nextStepAt = 0, lastStepAt = -1, sentFacing = "down", epoch = 0 }
local remote: { [number]: { facing: string, frame: number, lastMove: number } } = {}
local currentVillage: WorldGen.Village? = nil
local clockDay, clockFrac, clockAt = 1, 0, os.clock()
local clockText = ""

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.W] = "up", [Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.S] = "down", [Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
}
local held: { string } = {}         -- most recent key last
local touchTarget: { x: number, y: number }? = nil
local activeTouch: any = nil

local TRIBE_WORD = { farmer = "farmers", hunter = "hunters", plunderer = "plunderers" }

local function spriteFor(facing: string, frame: number): string
	return ("player_%s_%d"):format(facing, frame)
end

-- ---------- HUD (inside the play area, above the night tint) ----------
local clockLabel: TextLabel? = nil
local bannerFrame: Frame? = nil
local bannerTitle: TextLabel? = nil
local bannerSub: TextLabel? = nil
local bannerToken = 0

local function hudLabel(parent: Instance, name: string): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.fromRGB(244, 244, 248)
	t.TextStrokeColor3 = Color3.fromRGB(27, 27, 47)
	t.TextStrokeTransparency = 0.4
	t.Font = Enum.Font.Code
	t.TextScaled = true
	t.Parent = parent
	return t
end

local function buildHud(v: Viewport.Viewport)
	local clockBox = Instance.new("Frame")
	clockBox.Name = "Clock"
	clockBox.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
	clockBox.BackgroundTransparency = 0.35
	clockBox.BorderSizePixel = 0
	clockBox.Position = UDim2.new(0, 6, 0, 6)
	clockBox.Size = UDim2.new(0.3, 0, 0.065, 0)
	clockBox.Parent = v.overlay
	local clockMin = Instance.new("UISizeConstraint")
	clockMin.MinSize = Vector2.new(150, 24)
	clockMin.Parent = clockBox
	local cl = hudLabel(clockBox, "Text")
	cl.Size = UDim2.new(1, -8, 1, -4)
	cl.Position = UDim2.fromOffset(4, 2)
	cl.TextXAlignment = Enum.TextXAlignment.Left
	cl.TextStrokeTransparency = 1
	cl.Text = "Day 1"
	clockLabel = cl

	local bf = Instance.new("Frame")
	bf.Name = "Banner"
	bf.AnchorPoint = Vector2.new(0.5, 0)
	bf.Position = UDim2.fromScale(0.5, 0.12)
	bf.Size = UDim2.fromScale(0.62, 0.16)
	bf.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
	bf.BackgroundTransparency = 1
	bf.BorderSizePixel = 0
	bf.Visible = false
	bf.Parent = v.overlay
	local bannerMin = Instance.new("UISizeConstraint")
	bannerMin.MinSize = Vector2.new(220, 56)
	bannerMin.Parent = bf
	local title = hudLabel(bf, "Title")
	title.Size = UDim2.fromScale(0.94, 0.58)
	title.Position = UDim2.fromScale(0.03, 0.06)
	local sub = hudLabel(bf, "Sub")
	sub.Size = UDim2.fromScale(0.94, 0.3)
	sub.Position = UDim2.fromScale(0.03, 0.64)
	sub.TextColor3 = Color3.fromRGB(207, 169, 85)
	bannerFrame, bannerTitle, bannerSub = bf, title, sub
end

local function showBanner(title: string, sub: string)
	local bf, bt, bs = bannerFrame, bannerTitle, bannerSub
	if not bf or not bt or not bs then return end
	bannerToken += 1
	local token = bannerToken
	bt.Text, bs.Text = title, sub
	bf.Visible = true
	local fadeIn = TweenInfo.new(0.25)
	bf.BackgroundTransparency, bt.TextTransparency, bs.TextTransparency = 1, 1, 1
	TweenService:Create(bf, fadeIn, { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(bt, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(bs, fadeIn, { TextTransparency = 0 }):Play()
	task.delay(Config.BANNER_SECONDS, function()
		if token ~= bannerToken then return end
		local fadeOut = TweenInfo.new(0.6)
		TweenService:Create(bf, fadeOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(bt, fadeOut, { TextTransparency = 1 }):Play()
		local last = TweenService:Create(bs, fadeOut, { TextTransparency = 1 })
		last.Completed:Connect(function() if token == bannerToken then bf.Visible = false end end)
		last:Play()
	end)
end

-- Enter a village at its footprint + 1; leave only once 5 tiles clear, so walking along the edge does not flicker.
local function updateVillageBanner()
	local w = world
	if not w then return end
	if currentVillage then
		if WorldGen.villageAt(w, me.x, me.y, 5) ~= currentVillage then currentVillage = nil end
	else
		local v = WorldGen.villageAt(w, me.x, me.y, 1)
		if v then
			currentVillage = v
			showBanner(v.name, TRIBE_WORD[v.tribeType] or v.tribeType)
		end
	end
end

-- ---------- movement ----------
local function sendFacing(dir: string)
	if me.sentFacing ~= dir then
		me.sentFacing = dir
		Move:FireServer(me.epoch, me.x, me.y, dir)
	end
end

local function tryStep(dir: string, now: number): boolean
	local w, v = world, vp
	if not w or not v then return false end
	local d = Movement.DIRS[dir]
	local nx, ny = me.x + d[1], me.y + d[2]
	if not Movement.canStep(w, me.x, me.y, nx, ny) then
		if me.facing ~= dir then
			me.facing = dir
			v:setSprite(myId, spriteFor(dir, me.frame))
		end
		sendFacing(dir)
		return false
	end
	if now < me.nextStepAt then
		if me.facing ~= dir and now >= me.nextStepAt - 0.05 then
			-- About to turn: show the new facing right away.
			me.facing = dir
			v:setSprite(myId, spriteFor(dir, me.frame))
		end
		return true
	end
	-- Walking on from a step that just ended: start this slide exactly when that one ended, so there is no hitch.
	-- After a pause, start now.
	local startAt = if now - me.nextStepAt < 0.05 then me.nextStepAt else now
	local stepTime = Movement.stepTime(w, nx, ny)
	me.x, me.y, me.facing = nx, ny, dir
	me.frame = 1 - me.frame
	me.nextStepAt, me.lastStepAt = startAt + stepTime, now
	me.sentFacing = dir
	v:moveEntity(myId, nx, ny, stepTime, startAt)
	v:setSprite(myId, spriteFor(dir, me.frame))
	Move:FireServer(me.epoch, nx, ny, dir)
	return true
end

-- Tap-to-move: walk toward the tapped tile, one axis at a time, and stop on arrival or when blocked.
local function touchDirection(): string?
	local target, w = touchTarget, world
	if not target or not w then return nil end
	local dx, dy = target.x - me.x, target.y - me.y
	if dx == 0 and dy == 0 then
		touchTarget = nil
		return nil
	end
	local horiz = if dx > 0 then "right" elseif dx < 0 then "left" else nil
	local vert = if dy > 0 then "down" elseif dy < 0 then "up" else nil
	local first, second = horiz, vert
	if math.abs(dy) > math.abs(dx) then first, second = vert, horiz end
	for _, dir in ipairs({ first, second }) do
		if dir then
			local d = Movement.DIRS[dir]
			if Movement.canStep(w, me.x, me.y, me.x + d[1], me.y + d[2]) then return dir end
		end
	end
	-- Both ways blocked: face the target and give up.
	touchTarget = nil
	return first
end

-- ---------- network ----------
WorldInit.OnClientEvent:Connect(function(encoded, meState, others, clock, sheetIds)
	if vp then return end
	Sprites.ApplySheetIds(sheetIds)
	loading:Destroy()
	world = WorldGen.decode(encoded)
	local w = world :: WorldGen.World
	local v = Viewport.new(gui, Config.COLS, Config.ROWS, w)
	vp = v
	buildHud(v)
	me.x, me.y, me.facing, me.sentFacing = meState.x, meState.y, meState.facing, meState.facing
	me.epoch = meState.epoch or 0
	v:addEntity(myId, spriteFor(me.facing, 0), me.x, me.y)
	for _, o in ipairs(others) do
		v:addEntity(o.id, spriteFor(o.facing, 0), o.x, o.y, o.name)
		remote[o.id] = { facing = o.facing, frame = 0, lastMove = 0 }
	end
	v:setCamera(me.x - 0.5, me.y - 0.5)
	clockDay, clockFrac, clockAt = clock.day, clock.frac, os.clock()
	-- The opening beat: you wake in your own burnt village.
	local start = w.villages[1]
	currentVillage = WorldGen.villageAt(w, me.x, me.y, 1)
	showBanner(start.name, ("%s - the morning after"):format(TRIBE_WORD[start.tribeType] or start.tribeType))
end)

EntityState.OnClientEvent:Connect(function(kind, id, ...)
	local v, w = vp, world
	if not v or not w then return end
	if kind == "spawn" then
		if id == myId then return end
		local _, x, y, facing, name = ...
		if not v:getEntity(id) then
			v:addEntity(id, spriteFor(facing, 0), x, y, name)
			remote[id] = { facing = facing, frame = 0, lastMove = 0 }
		end
	elseif kind == "move" then
		if id == myId then return end
		local x, y, facing = ...
		local e, r = v:getEntity(id), remote[id]
		if e and r then
			local now = os.clock()
			if e.x ~= x or e.y ~= y then
				local adjacent = math.abs(e.x - x) + math.abs(e.y - y) == 1
				v:moveEntity(id, x, y, if adjacent then Movement.stepTime(w, x, y) else 0, now)
				r.frame = 1 - r.frame
				r.lastMove = now
			end
			r.facing = facing
			v:setSprite(id, spriteFor(facing, r.frame))
		end
	elseif kind == "leave" then
		v:removeEntity(id)
		remote[id] = nil
	elseif kind == "snap" then
		local x, y, facing, epoch = ...
		if type(epoch) ~= "number" or epoch <= me.epoch then return end
		me.epoch = epoch
		me.x, me.y, me.facing, me.sentFacing = x, y, facing, facing
		local now = os.clock()
		v:moveEntity(myId, x, y, 0.1, now)
		me.nextStepAt = now + 0.12
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
	clockDay, clockFrac, clockAt = day, frac, os.clock()
end)

-- ---------- input ----------
local function clearInput()
	table.clear(held)
	touchTarget, activeTouch = nil, nil
end

local function aimTouch(input: any)
	local v = vp
	if not v then return end
	local tx, ty = v:screenToTile(input.Position.X, input.Position.Y)
	if tx and ty then touchTarget = { x = tx, y = ty } end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local dir = KEYS[input.KeyCode]
		if dir then
			for i = #held, 1, -1 do if held[i] == dir then table.remove(held, i) end end
			table.insert(held, dir)
			touchTarget = nil
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		activeTouch = input
		aimTouch(input)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	-- Dragging a finger re-aims the walk.
	if input == activeTouch then aimTouch(input) end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local dir = KEYS[input.KeyCode]
		if dir then for i = #held, 1, -1 do if held[i] == dir then table.remove(held, i) end end end
	elseif input == activeTouch then
		activeTouch = nil -- keep walking to the tile under the finger when it lifted
	end
end)
-- Alt-tab while holding a key: the key-up never arrives, so forget everything held.
UserInputService.WindowFocusReleased:Connect(clearInput)

-- ---------- frame loop ----------
RunService.RenderStepped:Connect(function()
	local v = vp
	if not v then return end
	local now = os.clock()

	local dir = held[#held] or touchDirection()
	if dir then tryStep(dir, now) end
	if now > me.nextStepAt + 0.08 and me.frame ~= 0 then
		me.frame = 0
		v:setSprite(myId, spriteFor(me.facing, 0))
	end
	for id, r in pairs(remote) do
		if r.frame ~= 0 and now - r.lastMove > Config.MOVE_STEP * 2 then
			r.frame = 0
			v:setSprite(id, spriteFor(r.facing, 0))
		end
	end

	player:SetAttribute("PredictedX", me.x) -- compare with the server's TileX/TileY (set on the same Player)
	player:SetAttribute("PredictedY", me.y)

	-- Order matters: advance slides, then aim the camera at where the player is THIS frame, then lay out.
	v:step(now)
	local e = v:getEntity(myId)
	if e then v:setCamera(e.px + 0.5, e.py + 0.5) end
	v:refresh()

	-- Clock: interpolate between the server's once-a-second updates so dusk and dawn fade smoothly.
	local frac = clockFrac + (now - clockAt) / Config.DAY_SECONDS
	local day = clockDay
	if frac >= 1 then frac -= 1 day += 1 end
	v:setNight(DayCycle.nightAlpha(frac))
	local text = ("Day %d, %s"):format(day, DayCycle.phase(frac))
	local cl = clockLabel
	if cl and text ~= clockText then
		clockText = text
		cl.Text = text
	end

	updateVillageBanner()
end)
