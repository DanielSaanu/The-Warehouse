--!nonstrict
-- Client: draws the world the server sends, predicts your own steps, follows you with the camera, and turns
-- input into actions. Move: WASD / arrows / tap. Attack: left click or Space. Interact: F (or tap the prompt).
-- Tab: standing. Esc: close a window.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local Movement = require(Shared:WaitForChild("Movement"))
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local Combat = require(Shared:WaitForChild("Combat"))
local Items = require(Shared:WaitForChild("Items"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Viewport = require(script.Parent:WaitForChild("Viewport"))
local Hud = require(script.Parent:WaitForChild("Hud"))

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
			loading.Text = ("loading world... %ds\n\nStill loading. If this stays, the server is starting up."):format(math.floor(waited))
		end
	end
end)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldInit = Remotes:WaitForChild("WorldInit") :: RemoteEvent
local Move = Remotes:WaitForChild("Move") :: RemoteEvent
local EntityState = Remotes:WaitForChild("EntityState") :: RemoteEvent
local Clock = Remotes:WaitForChild("Clock") :: RemoteEvent
local Action = Remotes:WaitForChild("Action") :: RemoteEvent
local Notice = Remotes:WaitForChild("Notice") :: RemoteEvent

if Sprites.Sheets[1].Id == "rbxassetid://0" then
	warn("[Warehouse] Sprites.lua has no asset id. Run: npx warehouse roblox build --upload (see docs/ROBLOX_SETUP.md)")
end

-- ---------- state ----------
local world: WorldGen.World? = nil
local vp: Viewport.Viewport? = nil
local hud = nil
local O = TileTypes.ObjectByName

-- epoch: bumped by the server on every correction; moves carry it so stale in-flight moves are ignored.
-- nextStepAt: when the current step's slide ends, i.e. the earliest the next step may start.
local me = { x = 1, y = 1, facing = "down", frame = 0, nextStepAt = 0, lastStepAt = -1, sentFacing = "down", epoch = 0, lastAttack = -1, dead = false, stepped = false }
-- everything else on screen: other players and NPCs, keyed by id
local ents: { [any]: { facing: string, frame: number, lastMove: number, base: string, kind: string } } = {}
local currentVillage: WorldGen.Village? = nil
local clockDay, clockFrac, clockAt = 1, 0, os.clock()
local inv = Items.new()
local rep = { farmer = 0, hunter = 0, plunderer = 0 }
local tribeNames = {}
local hintShown = false
local selected: number? = nil     -- hot bar slot in hand (1-9, 0 for the tenth)
local metSurvivor = false
local survivorIds: { [any]: boolean } = {} -- everyone with a marker over their head

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.W] = "up", [Enum.KeyCode.Up] = "up",
	[Enum.KeyCode.S] = "down", [Enum.KeyCode.Down] = "down",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
}
-- 1-9 take that hot bar slot in hand; 0 is the tenth.
local SLOT_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9, [Enum.KeyCode.Zero] = 10,
}
local held: { string } = {}         -- most recent key last
local touchTarget: { x: number, y: number }? = nil
local touchPath: { WorldGen.Pos }? = nil
local activeTouch: any = nil

local TRIBE_WORD = { farmer = "farmers", hunter = "hunters", plunderer = "plunderers" }
local SIDE_ONLY = { deer = true, boar = true, wolf = true }
-- Who takes a gift: mirrors GIFTABLE in server/Interact.lua.
local GIFTABLE = { villager = true, guard = true, merchant = true, caravan_master = true, survivor = true, pregnant = true }
local KEY_LEGEND = "WASD move  ·  click swing  ·  F act  ·  E bag  ·  Tab standing  ·  X close"
local TOUCH_LEGEND = "tap to walk  ·  tap the prompt to act"

--- The item in the selected hot bar slot, mirroring Interact.held on the server.
local function heldItem(): string?
	local slot = selected and inv.slots[selected]
	return if slot then slot.item else nil
end

--- Sprite name for a body facing a way. Animals only have left/right art.
local function spriteFor(base: string, facing: string, frame: number): string
	if SIDE_ONLY[base] then
		if facing == "up" then facing = "right" elseif facing == "down" then facing = "left" end
	end
	local name = ("%s_%s_%d"):format(base, facing, frame)
	if Sprites.Has(name) then return name end
	return ("%s_down_%d"):format(base, frame)
end

--- Tiles other creatures stand on (for prediction: you cannot walk into someone).
local function occupancy(): { [number]: boolean }
	local occ = {}
	local v, w = vp, world
	if not v or not w then return occ end
	for id, e in pairs(v.entities) do
		if id ~= myId then occ[WorldGen.index(w, e.x, e.y)] = true end
	end
	return occ
end

-- ---------- prompt ----------
local PROMPT_BY_KIND = { merchant = "Trade", deer = nil, boar = nil, wolf = nil }
--- The F prompt for what is in front of the player, mirroring server/Interact.lua.
local function promptFor(): string?
	local w, v = world, vp
	if not w or not v or me.dead then return nil end
	local item = heldItem()
	local isGood = item ~= nil and table.find(Items.GOODS, item) ~= nil
	local tx, ty = Combat.facingTile(me.x, me.y, me.facing)
	for id, e in pairs(v.entities) do
		if id ~= myId and e.x == tx and e.y == ty then
			local r = ents[id]
			if not r or r.kind == "player" then return nil end
			if SIDE_ONLY[r.base] then return nil end
			if isGood and GIFTABLE[r.kind] then return "F: Give " .. Items.def(item :: string).label end
			return "F: " .. (PROMPT_BY_KIND[r.kind] or "Talk")
		end
	end
	local obj = WorldGen.object(w, tx, ty)
	if obj == O.sign.id then return "F: Read" end
	if obj == O.bed.id or obj == O.camp_lit.id or obj == O.camp_out.id then return "F: Rest" end
	if obj == O.stall.id then return "F: Trade" end
	if obj == O.bag.id then return "F: Pick up" end
	if WorldGen.object(w, me.x, me.y) == O.bag.id then return "F: Pick up" end
	if item == "food" then return "F: Eat" end
	if obj == 0 and WorldGen.walkable(w, tx, ty) and not WorldGen.villageAt(w, tx, ty, 1) and Items.count(inv, "camper_set") > 0 then
		return "F: Camp"
	end
	return nil
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
	if not Movement.canStep(w, me.x, me.y, nx, ny, occupancy()) then
		if me.facing ~= dir then
			me.facing = dir
			v:setSprite(myId, spriteFor("player", dir, me.frame))
		end
		sendFacing(dir)
		return false
	end
	if now < me.nextStepAt then
		if me.facing ~= dir and now >= me.nextStepAt - 0.05 then
			-- About to turn: show the new facing right away.
			me.facing = dir
			v:setSprite(myId, spriteFor("player", dir, me.frame))
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
	me.stepped = true
	v:moveEntity(myId, nx, ny, stepTime, startAt)
	v:setSprite(myId, spriteFor("player", dir, me.frame))
	Move:FireServer(me.epoch, nx, ny, dir)
	return true
end

-- Tap-to-move: path-find to the tapped tile (around trees, walls and people) and follow it.
local function planTouch()
	local target, w = touchTarget, world
	if not target or not w then touchPath = nil return end
	touchPath = WorldGen.route(w, me.x, me.y, target.x, target.y, false, 800)
	if not touchPath then
		-- unreachable: walk toward it as far as the straight line allows
		touchPath = nil
	end
end

local function touchDirection(): string?
	local target, w = touchTarget, world
	if not target or not w then return nil end
	if target.x == me.x and target.y == me.y then
		touchTarget, touchPath = nil, nil
		if vp then vp:setMarker(nil) end
		return nil
	end
	local path = touchPath
	if not path or #path == 0 then
		planTouch()
		path = touchPath
		if not path or #path == 0 then
			touchTarget = nil
			if vp then vp:setMarker(nil) end
			return nil
		end
	end
	local nxt = path[1]
	if nxt.x == me.x and nxt.y == me.y then
		table.remove(path, 1)
		nxt = path[1]
		if not nxt then touchTarget = nil if vp then vp:setMarker(nil) end return nil end
	end
	if math.abs(nxt.x - me.x) + math.abs(nxt.y - me.y) ~= 1 then
		planTouch()
		return nil
	end
	local dir = Combat.dirTo(me.x, me.y, nxt.x, nxt.y)
	if not Movement.canStep(w, me.x, me.y, nxt.x, nxt.y, occupancy()) then
		-- someone stepped into the way: re-plan next frame
		touchPath = nil
		return dir
	end
	return dir
end

-- ---------- actions ----------
local function attack()
	local v = vp
	if not v or me.dead or not hud or hud:anyOpen() then return end
	local now = os.clock()
	if now < me.lastAttack + Config.ATTACK_COOLDOWN then return end
	me.lastAttack = now
	local d = Movement.DIRS[me.facing]
	v:nudge(myId, d[1] * 3, d[2] * 3, 0.1)
	Action:FireServer("attack", me.facing)
end

local function interact()
	if me.dead or not hud then return end
	if hud:bagOpen() then return end
	if hud:dialogueOpen() then
		if hud:advanceDialogue() then Action:FireServer("close") end
		return
	end
	if hud:tradeOpen() then return end
	Action:FireServer("interact", me.facing)
end

local function closePanels()
	if not hud then return end
	if hud:anyOpen() then
		hud:closeAll()
		Action:FireServer("close")
	end
end

--- Take a hot bar slot in hand, or put it away if it was already in hand. The server decides what F then does
--- with it (eat food, give a good away), so it has to hear about every change.
local function selectSlot(i: number)
	selected = if selected == i then nil else i
	if hud then hud:setSelected(selected) end
	Action:FireServer("select", i)
end

-- ---------- network ----------
local function applyFlood(tiles)
	local w, v = world, vp
	if not w or not v then return end
	if tiles then WorldGen.setFlood(w, tiles) else WorldGen.clearFlood(w) end
	v:repaintAll()
end

WorldInit.OnClientEvent:Connect(function(encoded, meState, others, clock, sheetIds, calamity)
	if vp then return end
	Sprites.ApplySheetIds(sheetIds)
	loading:Destroy()
	world = WorldGen.decode(encoded)
	local w = world :: WorldGen.World
	for _, vv in ipairs(w.villages) do tribeNames[vv.tribeType] = vv.tribeName end
	local v = Viewport.new(gui, Config.COLS, Config.ROWS, w)
	vp = v
	hud = Hud.new(v.overlay, {
		onInteract = interact,
		onTopic = function(topic) Action:FireServer("topic", topic) end,
		onTrade = function(op, good) Action:FireServer("trade", op, good, 1) end,
		onClose = function() Action:FireServer("close") end,
	})
	me.x, me.y, me.facing, me.sentFacing = meState.x, meState.y, meState.facing, meState.facing
	me.epoch = meState.epoch or 0
	v:addEntity(myId, spriteFor("player", me.facing, 0), me.x, me.y)
	for _, o in ipairs(others) do
		v:addEntity(o.id, spriteFor("player", o.facing, 0), o.x, o.y, o.name)
		ents[o.id] = { facing = o.facing, frame = 0, lastMove = 0, base = "player", kind = "player" }
	end
	v:setCamera(me.x - 0.5, me.y - 0.5)
	clockDay, clockFrac, clockAt = clock.day, clock.frac, os.clock()
	if calamity then
		if calamity.active and calamity.flood then applyFlood(calamity.flood) end
		if calamity.warning then hud:setWarning(calamity.warning) end
	end
	-- The opening beat: you wake in your own burnt village, and somebody is waiting to talk to you.
	local start = w.villages[1]
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	currentVillage = WorldGen.villageAt(w, me.x, me.y, 1)
	hud:banner(start.name, "Someone is calling you")
	hud:setLegend(if touch then TOUCH_LEGEND else KEY_LEGEND)
	hud:setHint("Read the signs.")
end)

EntityState.OnClientEvent:Connect(function(kind, id, ...)
	local v, w = vp, world
	if not v or not w then return end
	if kind == "spawn" then
		if id == myId then return end
		local base, x, y, facing, name, hpFrac, ekind = ...
		if not v:getEntity(id) then
			v:addEntity(id, spriteFor(base, facing, 0), x, y, name)
			ents[id] = { facing = facing, frame = 0, lastMove = 0, base = base, kind = ekind or base }
			if hpFrac and hpFrac < 1 then v:setHp(id, hpFrac) end
			-- the one person with something to tell you gets an arrow over their head until you have heard it
			if (ekind or base) == "survivor" then
				survivorIds[id] = true
				if not metSurvivor then v:setBadge(id, "marker_arrow") end
			end
		end
	elseif kind == "move" then
		if id == myId then return end
		local x, y, facing = ...
		local e, r = v:getEntity(id), ents[id]
		if e and r then
			local now = os.clock()
			if e.x ~= x or e.y ~= y then
				local adjacent = math.abs(e.x - x) + math.abs(e.y - y) == 1
				v:moveEntity(id, x, y, if adjacent then Movement.stepTime(w, x, y) else 0, now)
				r.frame = 1 - r.frame
				r.lastMove = now
			end
			r.facing = facing
			v:setSprite(id, spriteFor(r.base, facing, r.frame))
		end
	elseif kind == "leave" then
		v:removeEntity(id)
		ents[id] = nil
		survivorIds[id] = nil
	elseif kind == "die" then
		if id == myId then return end
		v:flash(id, Color3.fromRGB(255, 60, 60), 0.2)
		task.delay(0.2, function() v:removeEntity(id) ents[id] = nil survivorIds[id] = nil end)
	elseif kind == "hit" then
		local hpFrac = ...
		v:flash(id)
		if id ~= myId then v:setHp(id, hpFrac) end
		if id == myId then
			local d = Movement.DIRS[me.facing]
			v:nudge(myId, -d[1] * 2, -d[2] * 2, 0.1)
		end
	elseif kind == "attack" then
		local facing = ...
		local d = Movement.DIRS[facing] or Movement.DIRS.down
		v:nudge(id, d[1] * 3, d[2] * 3, 0.1)
		local r = ents[id]
		if r then r.facing = facing v:setSprite(id, spriteFor(r.base, facing, r.frame)) end
	elseif kind == "telegraph" then
		v:flash(id, Color3.fromRGB(255, 240, 140), Config.TELEGRAPH)
		v:nudge(id, 0, -2, Config.TELEGRAPH)
	elseif kind == "object" then
		-- ("object", x, y, objectId): the x lands in `id`
		local x = id
		local y, objectId = ...
		w.object[WorldGen.index(w, x, y)] = objectId
		v:repaint(x, y)
	elseif kind == "snap" then
		local x, y, facing, epoch = ...
		if type(epoch) ~= "number" or epoch <= me.epoch then return end
		me.epoch = epoch
		me.x, me.y, me.facing, me.sentFacing = x, y, facing, facing
		local now = os.clock()
		local e = v:getEntity(myId)
		local far = e and (math.abs(e.x - x) + math.abs(e.y - y) > 3)
		v:moveEntity(myId, x, y, if far then 0 else 0.1, now)
		me.nextStepAt = now + 0.12
		v:setSprite(myId, spriteFor("player", facing, 0))
		touchTarget, touchPath = nil, nil
		v:setMarker(nil)
		if me.dead then
			me.dead = false
			if hud then hud:hideDead() end
		end
	end
end)

Notice.OnClientEvent:Connect(function(kind, data)
	if not hud or not vp then return end
	if kind == "hud" then
		inv = data.inv
		rep = data.rep
		hud:setHearts(data.hp, data.maxHp)
		hud:setInventory(inv)
		hud:setGoal(data.goal)
		if data.selected ~= selected then
			selected = data.selected
			hud:setSelected(selected)
		end
		if data.metSurvivor and not metSurvivor then
			metSurvivor = true
			for id in pairs(survivorIds) do vp:setBadge(id, nil) end
		end
	elseif kind == "text" then
		hud:notice(data.text, data.color)
	elseif kind == "dialogue" then
		hud:showDialogue(data)
	elseif kind == "trade" then
		hud:showTrade(data)
	elseif kind == "calamity" then
		if data.phase == "warning" then
			hud:setWarning(data.text)
			hud:banner("Warning", data.text)
		elseif data.phase == "start" then
			hud:setWarning(nil)
			if data.kind == "flood" then applyFlood(data.flood) end
			hud:banner(if data.kind == "flood" then "Flood" else "Beast tide", data.text)
			hud:notice(data.text, "warn")
		elseif data.phase == "end" then
			if data.kind == "flood" then applyFlood(nil) end
			hud:notice(data.text, "good")
		end
	elseif kind == "died" then
		me.dead = true
		table.clear(held)
		touchTarget, touchPath = nil, nil
		hud:showDead(data.by, data.seconds, data.at)
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
	touchTarget, touchPath, activeTouch = nil, nil, nil
	if vp then vp:setMarker(nil) end
end

local function aimTouch(input: any)
	local v = vp
	if not v or (hud and hud:anyOpen()) then return end
	local tx, ty = v:screenToTile(input.Position.X, input.Position.Y)
	if tx and ty then
		touchTarget = { x = tx, y = ty }
		touchPath = nil
		v:setMarker(tx, ty)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		if key == Enum.KeyCode.Escape or key == Enum.KeyCode.X or key == Enum.KeyCode.Backspace then closePanels() return end
		-- Roblox marks keys it has bindings for (Space = jump) as processed even though we have no character;
		-- only a focused text box (chat) should swallow our keys.
		if UserInputService:GetFocusedTextBox() then return end
		if key == Enum.KeyCode.F or key == Enum.KeyCode.Return then interact() return end
		if key == Enum.KeyCode.E then
			if hud then
				-- opening the bag over a conversation ends the conversation on the server too
				if hud:anyOpen() and not hud:bagOpen() then Action:FireServer("close") end
				hud:toggleBag()
			end
			return
		end
		if key == Enum.KeyCode.Tab then if hud then hud:toggleStanding(rep, tribeNames) end return end
		if key == Enum.KeyCode.Space then attack() return end
		local slot = SLOT_KEYS[key]
		if slot then selectSlot(slot) return end
		local dir = KEYS[key]
		if dir and not (hud and hud:anyOpen()) then
			for i = #held, 1, -1 do if held[i] == dir then table.remove(held, i) end end
			table.insert(held, dir)
			touchTarget, touchPath = nil, nil
			if vp then vp:setMarker(nil) end
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		if processed then return end
		if hud and hud:dialogueOpen() then interact() return end
		attack()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		if processed then return end
		if hud and hud:dialogueOpen() then interact() return end
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
local lastPrompt = nil
RunService.RenderStepped:Connect(function()
	local v = vp
	if not v or not hud then return end
	local now = os.clock()

	local blocked = me.dead or hud:anyOpen()
	local dir = if blocked then nil else (held[#held] or touchDirection())
	if dir then tryStep(dir, now) end
	if now > me.nextStepAt + 0.08 and me.frame ~= 0 then
		me.frame = 0
		v:setSprite(myId, spriteFor("player", me.facing, 0))
	end
	for id, r in pairs(ents) do
		if r.frame ~= 0 and now - r.lastMove > Config.MOVE_STEP * 2 then
			r.frame = 0
			v:setSprite(id, spriteFor(r.base, r.facing, 0))
		end
	end

	player:SetAttribute("PredictedX", me.x) -- compare with the server's TileX/TileY (set on the same Player)
	player:SetAttribute("PredictedY", me.y)
	player:SetAttribute("PredictedFacing", me.facing)
	player:SetAttribute("PredictedEpoch", me.epoch)
	player:SetAttribute("InputBlocked", blocked)

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
	hud:setClock(("Day %d, %s"):format(day, DayCycle.phase(frac)))

	-- prompt and hint
	local p = if blocked then nil else promptFor()
	if p ~= lastPrompt then lastPrompt = p hud:setPrompt(p) end
	hud:refreshLegend()
	if not hintShown and me.stepped then
		hintShown = true
		task.delay(12, function() if hud then hud:setHint(nil) end end)
	end

	-- Enter a village at its footprint + 1; leave only once 5 tiles clear, so walking along the edge does not flicker.
	local w = world
	if w then
		if currentVillage then
			if WorldGen.villageAt(w, me.x, me.y, 5) ~= currentVillage then currentVillage = nil end
		else
			local vv = WorldGen.villageAt(w, me.x, me.y, 1)
			if vv then
				currentVillage = vv
				hud:banner(vv.name, TRIBE_WORD[vv.tribeType] or vv.tribeType)
			end
		end
	end
end)
