--!nonstrict
-- HUD: hearts, coin, inventory bar, prompt, notices, dialogue box, trade panel, standing screen, death overlay.
-- Everything lives inside the play area's overlay frame (above the night tint) and scales with it.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sprites = require(Shared:WaitForChild("Sprites"))
local Items = require(Shared:WaitForChild("Items"))
local Reputation = require(Shared:WaitForChild("Reputation"))

local Hud = {}
Hud.__index = Hud

local INK = Color3.fromRGB(244, 244, 248)
local PANEL = Color3.fromRGB(27, 27, 47)
local GOLD = Color3.fromRGB(207, 169, 85)
local RED = Color3.fromRGB(230, 90, 90)
local GREEN = Color3.fromRGB(120, 200, 120)
local COLORS = { warn = RED, good = GREEN, rep = GOLD }

local function label(parent: Instance, name: string, text: string?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.TextColor3 = INK
	t.TextStrokeColor3 = PANEL
	t.TextStrokeTransparency = 0.4
	t.Font = Enum.Font.Code
	t.TextScaled = true
	t.TextWrapped = true
	t.Text = text or ""
	t.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 10
	c.MaxTextSize = 22
	c.Parent = t
	return t
end

local function panel(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = f
	return f
end

local function button(parent: Instance, name: string, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = Color3.fromRGB(62, 62, 92)
	b.BorderSizePixel = 0
	b.TextColor3 = INK
	b.Font = Enum.Font.Code
	b.TextScaled = true
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 10
	c.MaxTextSize = 20
	c.Parent = b
	b.Activated:Connect(onClick)
	return b
end

--- A round-cornered translucent button for thumbs. `min` is its smallest side in pixels: a touch target must stay
--- hittable however small the play area gets.
--- `holds` maps the InputObject that is pressing a button to the release to run when it ends. A thumb that slides
--- off the button, or lifts somewhere else entirely, still lets go of the direction: without this a d-pad sticks.
--- The table is captured by every button's closures, so it is only ever cleared in place, never reassigned.
local function padButton(holds: { [any]: () -> () }, parent: Instance, name: string, onDown: () -> (), onUp: (() -> ())?, min: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.35
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Text = ""
	b.TextColor3 = INK
	b.Font = Enum.Font.Code
	b.TextScaled = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = b
	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(min, min)
	size.Parent = b
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 11
	limit.MaxTextSize = 22
	limit.Parent = b
	-- InputBegan/InputEnded rather than Activated: a d-pad has to know when the thumb goes down and when it comes
	-- off again, including when it slides off the edge of the button.
	local function isPress(i: InputObject): boolean
		return i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1
	end
	b.InputBegan:Connect(function(i)
		if not isPress(i) then return end
		if onUp then holds[i] = onUp end
		onDown()
	end)
	if onUp then
		b.InputEnded:Connect(function(i)
			if isPress(i) and holds[i] then holds[i] = nil onUp() end
		end)
	end
	return b
end

--- A small x in a panel's top right. The thumb controls hide behind an open panel, so every panel needs a way
--- out that does not depend on a key: without this a touch player who opens the bag is stuck in it.
local function closeX(parent: Instance, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "CloseX"
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, 0, 0, 0)
	b.Size = UDim2.fromOffset(44, 44)
	b.BackgroundColor3 = Color3.fromRGB(62, 62, 92)
	b.BorderSizePixel = 0
	b.Text = "x"
	b.TextColor3 = INK
	b.Font = Enum.Font.Code
	b.TextSize = 24
	b.ZIndex = 32
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = b
	local floor = Instance.new("UISizeConstraint")
	floor.MinSize = Vector2.new(44, 44) -- on touch this is the only exit from the bag and standing panels
	floor.Parent = b
	b.Activated:Connect(onClick)
	return b
end

function Hud.new(overlay: Frame, callbacks, touch: boolean?)
	local self = setmetatable({ overlay = overlay, cb = callbacks, noticeToken = 0, dialogue = nil, page = 1, touch = touch or false, holds = {} }, Hud)
	-- The catch-all: whatever the button missed, the end of the input itself releases.
	UserInputService.InputEnded:Connect(function(i)
		local up = self.holds[i]
		if up then self.holds[i] = nil up() end
	end)

	-- clock (top left)
	local clockBox = Instance.new("Frame")
	clockBox.Name = "Clock"
	clockBox.BackgroundColor3 = PANEL
	clockBox.BackgroundTransparency = 0.35
	clockBox.BorderSizePixel = 0
	clockBox.Position = UDim2.new(0, 6, 0, 6)
	clockBox.Size = UDim2.new(0.3, 0, 0.065, 0)
	clockBox.Parent = overlay
	local clockMin = Instance.new("UISizeConstraint")
	clockMin.MinSize = Vector2.new(150, 24)
	clockMin.Parent = clockBox
	self.clock = label(clockBox, "Text", "Day 1")
	self.clock.Size = UDim2.new(1, -8, 1, -4)
	self.clock.Position = UDim2.fromOffset(4, 2)
	self.clock.TextXAlignment = Enum.TextXAlignment.Left
	self.clock.TextStrokeTransparency = 1

	-- hearts + coin under the clock. One row, left to right: each heart is as wide as the row is tall
	-- (RelativeYY with a full scale), which is what stops them coming out as thin slivers.
	local hearts = Instance.new("Frame")
	hearts.Name = "Hearts"
	hearts.BackgroundTransparency = 1
	hearts.Position = UDim2.new(0, 6, 0.065, 12)
	hearts.Size = UDim2.new(0.34, 0, 0.055, 0)
	hearts.Parent = overlay
	local heartsMin = Instance.new("UISizeConstraint")
	heartsMin.MinSize = Vector2.new(170, 20)
	heartsMin.Parent = hearts
	local heartRow = Instance.new("UIListLayout")
	heartRow.FillDirection = Enum.FillDirection.Horizontal
	heartRow.VerticalAlignment = Enum.VerticalAlignment.Center
	heartRow.SortOrder = Enum.SortOrder.LayoutOrder
	heartRow.Padding = UDim.new(0, 2)
	heartRow.Parent = hearts
	self.hearts = {}
	for i = 1, 5 do
		local h = Sprites.New("heart", hearts)
		h.Size = UDim2.fromScale(1, 1)
		h.SizeConstraint = Enum.SizeConstraint.RelativeYY
		h.LayoutOrder = i
		self.hearts[i] = h
	end
	local gap = Instance.new("Frame")
	gap.Name = "Gap"
	gap.BackgroundTransparency = 1
	gap.Size = UDim2.new(0, 10, 1, 0)
	gap.LayoutOrder = 6
	gap.Parent = hearts
	local coinIcon = Sprites.New("item_coin", hearts)
	coinIcon.Size = UDim2.fromScale(1, 1)
	coinIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coinIcon.LayoutOrder = 7
	self.coin = label(hearts, "Coin", "0")
	self.coin.Size = UDim2.new(0, 52, 1, 0)
	self.coin.LayoutOrder = 8
	self.coin.TextXAlignment = Enum.TextXAlignment.Left
	self.coin.TextColor3 = GOLD

	-- the goal line: one sentence under the hearts, set by the server (docs/qa/rung2-part4.md)
	self.goal = label(overlay, "Goal", "")
	self.goal.Size = UDim2.new(0.52, 0, 0.045, 0)
	self.goal.Position = UDim2.new(0, 6, 0.125, 14)
	self.goal.TextXAlignment = Enum.TextXAlignment.Left
	self.goal.Visible = false

	-- warning line (tomorrow's calamity) and rest point
	self.warning = label(overlay, "Warning", "")
	self.warning.Size = UDim2.new(0.5, 0, 0.045, 0)
	self.warning.Position = UDim2.new(0, 6, 0.18, 16)
	self.warning.TextXAlignment = Enum.TextXAlignment.Left
	self.warning.TextColor3 = GOLD
	self.warning.Visible = false

	-- banner (village name, calamity)
	local bf = Instance.new("Frame")
	bf.Name = "Banner"
	bf.AnchorPoint = Vector2.new(0.5, 0)
	bf.Position = UDim2.fromScale(0.5, 0.12)
	bf.Size = UDim2.fromScale(0.62, 0.16)
	bf.BackgroundColor3 = PANEL
	bf.BackgroundTransparency = 1
	bf.BorderSizePixel = 0
	bf.Visible = false
	bf.Parent = overlay
	local bannerMin = Instance.new("UISizeConstraint")
	bannerMin.MinSize = Vector2.new(220, 56)
	bannerMin.Parent = bf
	self.bannerFrame = bf
	self.bannerTitle = label(bf, "Title")
	self.bannerTitle.Size = UDim2.fromScale(0.94, 0.58)
	self.bannerTitle.Position = UDim2.fromScale(0.03, 0.06)
	self.bannerSub = label(bf, "Sub")
	self.bannerSub.Size = UDim2.fromScale(0.94, 0.3)
	self.bannerSub.Position = UDim2.fromScale(0.03, 0.64)
	self.bannerSub.TextColor3 = GOLD
	self.bannerToken = 0

	-- notices: a short stack under the banner
	self.notices = Instance.new("Frame")
	self.notices.Name = "Notices"
	self.notices.BackgroundTransparency = 1
	self.notices.AnchorPoint = Vector2.new(0.5, 0)
	self.notices.Position = UDim2.fromScale(0.5, 0.3)
	self.notices.Size = UDim2.fromScale(0.8, 0.2)
	self.notices.Parent = overlay
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 2)
	list.Parent = self.notices

	-- Inventory bar. On a keyboard it sits bottom left and the key legend has the bottom right. On a touch device
	-- both bottom corners belong to thumbs, so it moves to the top right where nothing else lives.
	local bar = Instance.new("Frame")
	bar.Name = "Inventory"
	bar.BackgroundTransparency = 1
	if self.touch then
		bar.AnchorPoint = Vector2.new(1, 0)
		bar.Position = UDim2.new(1, -6, 0, 6)
		bar.Size = UDim2.fromScale(0.5, 0.062)
	else
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 6, 1, -4)
		bar.Size = UDim2.fromScale(0.52, 0.075)
	end
	bar.Parent = overlay
	local barMin = Instance.new("UISizeConstraint")
	barMin.MinSize = Vector2.new(250, 26)
	barMin.Parent = bar
	self.slots = {}
	for i = 1, Items.SLOTS do
		local s = Instance.new("TextButton")
		s.Name = "Slot" .. i
		s.BackgroundColor3 = PANEL
		s.BackgroundTransparency = 0.35
		s.BorderSizePixel = 0
		s.Text = ""
		s.AutoButtonColor = false
		s.Size = UDim2.fromScale(1, 1)
		s.SizeConstraint = Enum.SizeConstraint.RelativeYY
		s.Position = UDim2.fromScale((i - 1) * 0.1, 0)
		s.Parent = bar
		s.Activated:Connect(function() if self.cb.onSelect then self.cb.onSelect(i) end end)
		-- the slot in hand is outlined: 1-9 picks one, and F then eats it or gives it away
		local ring = Instance.new("UIStroke")
		ring.Color = GOLD
		ring.Thickness = 2
		ring.Enabled = false
		ring.Parent = s
		local img = Sprites.New("item_food", s)
		img.Size = UDim2.fromScale(1, 1)
		img.Visible = false
		local n = label(s, "N", "")
		n.Size = UDim2.fromScale(0.6, 0.45)
		n.Position = UDim2.fromScale(0.4, 0.55)
		n.TextXAlignment = Enum.TextXAlignment.Right
		self.slots[i] = { frame = s, img = img, n = n, ring = ring }
	end
	self.selected = nil

	-- ---------- touch controls ----------
	-- Built only on a touch device. The d-pad has the bottom-left corner and the four verbs the bottom-right, so
	-- both thumbs rest where they already are and neither covers the middle of the play area.
	self.touchControls = {}
	if self.touch then
		local pad = Instance.new("Frame")
		pad.Name = "DPad"
		pad.BackgroundTransparency = 1
		pad.AnchorPoint = Vector2.new(0, 1)
		pad.Position = UDim2.new(0, 10, 1, -10)
		pad.Size = UDim2.fromScale(0.22, 0.32)
		pad.Parent = overlay
		local padMin = Instance.new("UISizeConstraint")
		padMin.MinSize = Vector2.new(140, 140) -- 0.32 of this is 44.8, so a button never drops under 44 px
		padMin.Parent = pad
		table.insert(self.touchControls, pad)
		-- One arrow sprite, turned four ways. Thirds of the frame, in a cross.
		local DIRS = {
			{ dir = "up", x = 1, y = 0, rot = 0 },
			{ dir = "left", x = 0, y = 1, rot = -90 },
			{ dir = "right", x = 2, y = 1, rot = 90 },
			{ dir = "down", x = 1, y = 2, rot = 180 },
		}
		for _, d in ipairs(DIRS) do
			local b = padButton(self.holds, pad, d.dir, function()
				if self.cb.onMoveStart then self.cb.onMoveStart(d.dir) end
			end, function()
				if self.cb.onMoveEnd then self.cb.onMoveEnd(d.dir) end
			end, 44)
			b.Size = UDim2.fromScale(0.32, 0.32)
			b.Position = UDim2.fromScale(d.x * 0.34, d.y * 0.34)
			local arrow = Sprites.New("ui_arrow", b)
			arrow.Size = UDim2.fromScale(0.68, 0.68)
			arrow.SizeConstraint = Enum.SizeConstraint.RelativeYY
			arrow.AnchorPoint = Vector2.new(0.5, 0.5)
			arrow.Position = UDim2.fromScale(0.5, 0.5)
			arrow.Rotation = d.rot
		end

		local acts = Instance.new("Frame")
		acts.Name = "Actions"
		acts.BackgroundTransparency = 1
		acts.AnchorPoint = Vector2.new(1, 1)
		acts.Position = UDim2.new(1, -10, 1, -10)
		acts.Size = UDim2.fromScale(0.24, 0.32)
		acts.Parent = overlay
		local actsMin = Instance.new("UISizeConstraint")
		actsMin.MinSize = Vector2.new(140, 132)
		actsMin.Parent = acts
		table.insert(self.touchControls, acts)
		-- 2x2. The swing is under the resting thumb, bottom right; act sits straight above it.
		local bagBtn = padButton(self.holds, acts, "Bag", function() if self.cb.onBag then self.cb.onBag() end end, nil, 44)
		bagBtn.Size = UDim2.fromScale(0.46, 0.46)
		bagBtn.Position = UDim2.fromScale(0, 0)
		local bagIcon = Sprites.New("bag", bagBtn)
		bagIcon.Size = UDim2.fromScale(0.7, 0.7)
		bagIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
		bagIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		bagIcon.Position = UDim2.fromScale(0.5, 0.5)

		local repBtn = padButton(self.holds, acts, "Standing", function() if self.cb.onStanding then self.cb.onStanding() end end, nil, 44)
		repBtn.Size = UDim2.fromScale(0.46, 0.46)
		repBtn.Position = UDim2.fromScale(0, 0.54)
		repBtn.Text = "you" -- "rep" means nothing to someone who has never played this

		local attackBtn = padButton(self.holds, acts, "Attack", function() if self.cb.onAttack then self.cb.onAttack() end end, nil, 48)
		attackBtn.Size = UDim2.fromScale(0.46, 0.46)
		attackBtn.Position = UDim2.fromScale(0.54, 0.54)
		attackBtn.BackgroundTransparency = 0.2
		local knife = Sprites.New("item_knife", attackBtn)
		knife.Size = UDim2.fromScale(0.78, 0.78)
		knife.SizeConstraint = Enum.SizeConstraint.RelativeYY
		knife.AnchorPoint = Vector2.new(0.5, 0.5)
		knife.Position = UDim2.fromScale(0.5, 0.5)
		self.actionsFrame = acts
	end

	-- key legend: always on, dimmed, out of the way in the bottom right, gone while a panel is up
	self.legend = label(overlay, "Legend", "")
	if self.touch then
		self.legend.AnchorPoint = Vector2.new(0.5, 1)
		self.legend.Position = UDim2.new(0.5, 0, 1, -6)
		self.legend.Size = UDim2.fromScale(0.3, 0.045)
		self.legend.TextXAlignment = Enum.TextXAlignment.Center
	else
		self.legend.AnchorPoint = Vector2.new(1, 1)
		self.legend.Position = UDim2.new(1, -8, 1, -6)
		self.legend.Size = UDim2.fromScale(0.4, 0.05)
		self.legend.TextXAlignment = Enum.TextXAlignment.Right
	end
	self.legend.TextWrapped = true
	self.legend.TextTransparency = 0.3
	self.legend.TextStrokeTransparency = 0.6
	self.legend.Visible = false
	local legendSize = Instance.new("UITextSizeConstraint")
	legendSize.MinTextSize = 9
	legendSize.MaxTextSize = 15
	legendSize.Parent = self.legend

	-- prompt above the bar (a button so touch can tap it)
	self.prompt = button(overlay, "Prompt", "", function() if self.cb.onInteract then self.cb.onInteract() end end)
	self.prompt.AnchorPoint = Vector2.new(0.5, 1)
	self.prompt.Position = UDim2.new(0.5, 0, 0.9, 0)
	self.prompt.Size = UDim2.fromScale(0.26, 0.06)
	self.prompt.BackgroundColor3 = PANEL
	self.prompt.BackgroundTransparency = 0.2
	self.prompt.Visible = false
	local promptMin = Instance.new("UISizeConstraint")
	promptMin.MinSize = Vector2.new(120, 22)
	promptMin.Parent = self.prompt
	if self.touch then
		-- On a thumb layout the prompt IS the act button: it joins the cluster, top right of the four.
		promptMin.MinSize = Vector2.new(42, 42)
		self.prompt.Parent = self.actionsFrame
		self.prompt.AnchorPoint = Vector2.new(0, 0)
		self.prompt.Position = UDim2.fromScale(0.54, 0)
		self.prompt.Size = UDim2.fromScale(0.46, 0.46)
		self.prompt.BackgroundTransparency = 0.35
		self.prompt.Text = "act"
		self.prompt.TextWrapped = true -- "Give hides" in a 60 px button wraps instead of shrinking to nothing
		self.prompt.Visible = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = self.prompt
	end

	-- controls hint
	self.hint = label(overlay, "Hint", "")
	self.hint.AnchorPoint = Vector2.new(0.5, 1)
	self.hint.Position = UDim2.fromScale(0.5, 0.82)
	self.hint.Size = UDim2.fromScale(0.8, 0.05)
	self.hint.TextColor3 = GOLD
	self.hint.Visible = false

	-- dialogue box
	local d = panel(overlay, "Dialogue")
	d.AnchorPoint = Vector2.new(0.5, 1)
	d.Position = UDim2.new(0.5, 0, 1, -6)
	d.Size = UDim2.fromScale(0.94, 0.34)
	d.ZIndex = 30
	self.dialogueFrame = d
	self.dialogueName = label(d, "Name")
	self.dialogueName.Size = UDim2.fromScale(1, 0.2)
	self.dialogueName.TextXAlignment = Enum.TextXAlignment.Left
	self.dialogueName.TextColor3 = GOLD
	self.dialogueText = label(d, "Text")
	self.dialogueText.Size = UDim2.fromScale(0.62, 0.62)
	self.dialogueText.Position = UDim2.fromScale(0, 0.22)
	self.dialogueText.TextXAlignment = Enum.TextXAlignment.Left
	self.dialogueText.TextYAlignment = Enum.TextYAlignment.Top
	self.dialogueMore = label(d, "More", "F / click: continue")
	self.dialogueMore.Size = UDim2.fromScale(0.62, 0.14)
	self.dialogueMore.Position = UDim2.fromScale(0, 0.86)
	self.dialogueMore.TextXAlignment = Enum.TextXAlignment.Left
	self.dialogueMore.TextColor3 = Color3.fromRGB(170, 170, 190)
	closeX(d, function()
		self:closeAll()
		if self.cb.onClose then self.cb.onClose() end
	end)
	self.choices = {}
	for i = 1, 4 do
		local b = button(d, "Choice" .. i, "", function()
			local c = self.dialogue and self.dialogue.choices and self.dialogue.choices[i]
			if c and self.cb.onTopic then self.cb.onTopic(c) end
		end)
		b.Size = UDim2.fromScale(0.35, 0.18)
		b.Position = UDim2.fromScale(0.65, 0.22 + (i - 1) * 0.2)
		b.Visible = false
		self.choices[i] = b
	end

	-- trade panel
	local t = panel(overlay, "Trade")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.88, 0.86)
	t.BackgroundTransparency = 0.05
	t.ZIndex = 30
	self.tradeFrame = t
	self.tradeTitle = label(t, "Title")
	self.tradeTitle.Size = UDim2.fromScale(1, 0.1)
	self.tradeTitle.TextColor3 = GOLD
	self.tradeLine = label(t, "Line")
	self.tradeLine.Size = UDim2.fromScale(1, 0.09)
	self.tradeLine.Position = UDim2.fromScale(0, 0.1)
	self.tradeLine.TextXAlignment = Enum.TextXAlignment.Left
	self.tradeLine.TextStrokeTransparency = 1
	-- Columns: icon | good | stock | buy | sell | yours. The header and every row use the same positions, so the
	-- columns line up at any width.
	-- Do not set TextWrapped = false on any of these: Roblox turns TextScaled off with it, which is what pinned
	-- the whole panel at 14px and made it unreadable in the first playtest.
	local COL = { name = { 0.07, 0.24 }, stock = { 0.32, 0.12 }, buy = { 0.46, 0.17 }, sell = { 0.65, 0.17 }, have = { 0.84, 0.16 } }
	local function cell(parent: Instance, key: string, text: string, align: Enum.TextXAlignment): TextLabel
		local l = label(parent, key, text)
		l.Size = UDim2.fromScale(COL[key][2], 1)
		l.Position = UDim2.fromScale(COL[key][1], 0)
		l.TextXAlignment = align
		l.TextStrokeTransparency = 1
		-- the first playtest could not read this panel: bigger type, and white rather than grey
		local size = l:FindFirstChildWhichIsA("UITextSizeConstraint")
		if size then size.MinTextSize = 13 size.MaxTextSize = 30 end
		return l
	end
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.fromScale(1, 0.07)
	head.Position = UDim2.fromScale(0, 0.2)
	head.Parent = t
	for key, text in pairs({ name = "good", stock = "stock", buy = "buy", sell = "sell", have = "yours" }) do
		cell(head, key, text, if key == "name" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center).TextColor3 = INK
	end
	self.tradeRows = {}
	for i = 1, 5 do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0.1)
		row.Position = UDim2.fromScale(0, 0.27 + (i - 1) * 0.11)
		row.Parent = t
		local icon = Sprites.New("item_food", row)
		icon.Size = UDim2.fromScale(1, 1)
		icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
		local name = cell(row, "name", "", Enum.TextXAlignment.Left)
		local stock = cell(row, "stock", "", Enum.TextXAlignment.Center)
		local have = cell(row, "have", "", Enum.TextXAlignment.Center)
		local buy = button(row, "Buy", "buy", function() if self.cb.onTrade and self.rowGood[i] then self.cb.onTrade(if self.rowGood[i] == "camper_set" then "camper" else "buy", self.rowGood[i]) end end)
		buy.Size = UDim2.fromScale(COL.buy[2], 0.9)
		buy.Position = UDim2.fromScale(COL.buy[1], 0.05)
		local sell = button(row, "Sell", "sell", function() if self.cb.onTrade and self.rowGood[i] then self.cb.onTrade("sell", self.rowGood[i]) end end)
		sell.Size = UDim2.fromScale(COL.sell[2], 0.9)
		sell.Position = UDim2.fromScale(COL.sell[1], 0.05)
		for _, b in ipairs({ buy, sell }) do
			local size = b:FindFirstChildWhichIsA("UITextSizeConstraint")
			if size then size.MinTextSize = 12 size.MaxTextSize = 26 end
		end
		self.tradeRows[i] = { row = row, icon = icon, name = name, stock = stock, have = have, buy = buy, sell = sell }
	end
	self.rowGood = {}
	self.tradeCoin = label(t, "Coin")
	self.tradeCoin.Size = UDim2.fromScale(0.6, 0.08)
	self.tradeCoin.Position = UDim2.fromScale(0, 0.86)
	self.tradeCoin.TextXAlignment = Enum.TextXAlignment.Left
	self.tradeCoin.TextColor3 = GOLD
	local close = button(t, "Close", if self.touch then "close" else "close (Esc)", function() self:closeAll() if self.cb.onClose then self.cb.onClose() end end)
	close.Size = UDim2.fromScale(0.3, 0.09)
	close.Position = UDim2.fromScale(0.68, 0.87)

	-- bag panel (E): every slot with its count, and which one is in hand
	local bag = panel(overlay, "Bag")
	bag.AnchorPoint = Vector2.new(0.5, 0.5)
	bag.Position = UDim2.fromScale(0.5, 0.5)
	bag.Size = UDim2.fromScale(0.66, 0.82)
	bag.BackgroundTransparency = 0.05
	bag.ZIndex = 30
	self.bagFrame = bag
	self.bagTitle = label(bag, "Title", "Your bag")
	self.bagTitle.Size = UDim2.fromScale(1, 0.09)
	self.bagTitle.TextXAlignment = Enum.TextXAlignment.Left
	self.bagTitle.TextColor3 = GOLD
	self.bagRows = {}
	for i = 1, Items.SLOTS do
		-- A row is a button: tapping it is how a thumb takes a slot in hand, and it is the obvious place to try.
		local row = Instance.new("TextButton")
		row.Name = "Bag" .. i
		row.BackgroundColor3 = GOLD
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Text = ""
		row.AutoButtonColor = false
		row.Size = UDim2.fromScale(1, 0.072)
		row.Position = UDim2.fromScale(0, 0.11 + (i - 1) * 0.077)
		row.Parent = bag
		row.Activated:Connect(function() if self.cb.onSelect then self.cb.onSelect(i) end end)
		local icon = Sprites.New("item_food", row)
		icon.Size = UDim2.fromScale(1, 1)
		icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
		icon.Position = UDim2.fromScale(0.06, 0)
		local key = label(row, "Key", tostring(i % 10))
		key.Size = UDim2.fromScale(0.05, 1)
		key.TextColor3 = GOLD
		local name = label(row, "Name", "")
		name.Size = UDim2.fromScale(0.72, 1)
		name.Position = UDim2.fromScale(0.14, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextStrokeTransparency = 1
		local size = name:FindFirstChildWhichIsA("UITextSizeConstraint")
		if size then size.MinTextSize = 13 size.MaxTextSize = 28 end
		self.bagRows[i] = { row = row, icon = icon, name = name, key = key }
	end
	closeX(bag, function() self.bagFrame.Visible = false end)
	self.bagFoot = label(bag, "Foot", "")
	self.bagFoot.Size = UDim2.fromScale(1, 0.09)
	self.bagFoot.Position = UDim2.fromScale(0, 0.9)
	self.bagFoot.TextXAlignment = Enum.TextXAlignment.Left
	self.bagFoot.TextColor3 = Color3.fromRGB(190, 190, 205)

	-- standing panel
	local st = panel(overlay, "Standing")
	st.AnchorPoint = Vector2.new(0.5, 0.5)
	st.Position = UDim2.fromScale(0.5, 0.5)
	st.Size = UDim2.fromScale(0.6, 0.5)
	st.ZIndex = 30
	self.standingFrame = st
	closeX(st, function() self.standingFrame.Visible = false end)
	self.standingText = label(st, "Text")
	self.standingText.Size = UDim2.fromScale(1, 1)
	self.standingText.TextXAlignment = Enum.TextXAlignment.Left
	self.standingText.TextYAlignment = Enum.TextYAlignment.Top

	-- death overlay
	local dead = Instance.new("Frame")
	dead.Name = "Dead"
	dead.BackgroundColor3 = Color3.fromRGB(20, 6, 8)
	dead.BackgroundTransparency = 0.35
	dead.BorderSizePixel = 0
	dead.Size = UDim2.fromScale(1, 1)
	dead.Visible = false
	dead.ZIndex = 40
	dead.Parent = overlay
	self.deadFrame = dead
	self.deadText = label(dead, "Text")
	self.deadText.Size = UDim2.fromScale(0.8, 0.3)
	self.deadText.Position = UDim2.fromScale(0.1, 0.35)
	self.deadText.TextColor3 = RED
	return self
end

function Hud.setClock(self, text: string)
	if self.clock.Text ~= text then self.clock.Text = text end
end

function Hud.banner(self, title: string, sub: string)
	local bf, bt, bs = self.bannerFrame, self.bannerTitle, self.bannerSub
	self.bannerToken += 1
	local token = self.bannerToken
	bt.Text, bs.Text = title, sub
	bf.Visible = true
	local fadeIn = TweenInfo.new(0.25)
	bf.BackgroundTransparency, bt.TextTransparency, bs.TextTransparency = 1, 1, 1
	TweenService:Create(bf, fadeIn, { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(bt, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(bs, fadeIn, { TextTransparency = 0 }):Play()
	task.delay(3, function()
		if token ~= self.bannerToken then return end
		local fadeOut = TweenInfo.new(0.6)
		TweenService:Create(bf, fadeOut, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(bt, fadeOut, { TextTransparency = 1 }):Play()
		local last = TweenService:Create(bs, fadeOut, { TextTransparency = 1 })
		last.Completed:Connect(function() if token == self.bannerToken then bf.Visible = false end end)
		last:Play()
	end)
end

function Hud.setHearts(self, hp: number, maxHp: number)
	for i, h in ipairs(self.hearts) do
		local v = hp - (i - 1) * 2
		local name = if v >= 2 then "heart" elseif v == 1 then "heart_half" else "heart_empty"
		if h.Name ~= name then Sprites.Apply(h, name) h.Name = name end
	end
end

function Hud.setInventory(self, inv)
	self.inv = inv
	self.coin.Text = tostring(inv.coin or 0)
	for i, s in ipairs(self.slots) do
		local slot = inv.slots[i]
		if slot then
			local def = Items.Defs[slot.item]
			local sprite = if def then def.sprite else "bag"
			if s.img.Name ~= sprite then Sprites.Apply(s.img, sprite) s.img.Name = sprite end
			s.img.Visible = true
			s.n.Text = if slot.n > 1 then tostring(slot.n) else ""
		else
			s.img.Visible = false
			s.n.Text = ""
		end
	end
	if self.bagFrame.Visible then self:renderBag() end
end

--- The goal line under the hearts. nil takes it away for good.
function Hud.setGoal(self, text: string?)
	self.goal.Text = if text then "-> " .. text else ""
	self.goal.Visible = text ~= nil and text ~= ""
end

--- Which hot bar slot is in hand (nil = empty-handed).
function Hud.setSelected(self, i: number?)
	self.selected = i
	for n, s in ipairs(self.slots) do s.ring.Enabled = n == i end
	if self.bagFrame.Visible then self:renderBag() end
end

-- ---------- key legend ----------
function Hud.setLegend(self, text: string)
	self.legend.Text = text
	self.legend.Visible = text ~= "" and not self:anyOpen()
end

--- Called every frame: the legend and the touch controls are always on, except while a panel covers the play area.
function Hud.refreshChrome(self)
	local open = self:anyOpen() or self.deadFrame.Visible
	-- A panel covering the d-pad must not leave a direction held down behind it. Cleared in place: rebinding
	-- self.holds would orphan the table padButton's closures captured, and the safety net would be writing to one
	-- table while the catch-all read another.
	if open and next(self.holds) ~= nil then
		local pending = {}
		for i, up in pairs(self.holds) do
			self.holds[i] = nil
			table.insert(pending, up)
		end
		for _, up in ipairs(pending) do up() end
	end
	local want = self.legend.Text ~= "" and not open
	if self.legend.Visible ~= want then self.legend.Visible = want end
	for _, c in ipairs(self.touchControls) do
		if c.Visible == open then c.Visible = not open end
	end
	if self.touch and self.prompt.Visible == open then self.prompt.Visible = not open end
end

-- ---------- bag ----------
function Hud.renderBag(self)
	local inv = self.inv or { slots = {}, coin = 0 }
	for i, r in ipairs(self.bagRows) do
		local slot = inv.slots[i]
		local held = self.selected == i
		r.row.BackgroundTransparency = if held then 0.75 else 1
		r.key.TextTransparency = if slot then 0 else 0.6
		if slot then
			local def = Items.Defs[slot.item]
			local sprite = if def then def.sprite else "bag"
			if r.icon.Name ~= sprite then Sprites.Apply(r.icon, sprite) r.icon.Name = sprite end
			r.icon.Visible = true
			r.name.Text = ("%s x%d%s"):format(if def then def.label else slot.item, slot.n, if held then "   (in hand)" else "")
			r.name.TextColor3 = if held then GOLD else INK
		else
			r.icon.Visible = false
			r.name.Text = "-"
			r.name.TextColor3 = Color3.fromRGB(120, 120, 140)
		end
	end
	self.bagTitle.Text = ("Your bag        %d coin"):format(inv.coin or 0)
	self.bagFoot.Text = if self.touch
		then "tap a slot to take it in hand (again to put it away)  ·  act eats food, or gives a good to a villager"
		else "1-9 to take a slot in hand (again to put it away)  ·  F eats food, or gives a good to a villager  ·  E or X to close"
end

function Hud.toggleBag(self)
	if self.bagFrame.Visible then self.bagFrame.Visible = false return end
	self:closeDialogue()
	self.tradeFrame.Visible = false
	self.standingFrame.Visible = false
	self:renderBag()
	self.bagFrame.Visible = true
end

function Hud.bagOpen(self): boolean
	return self.bagFrame.Visible
end

function Hud.setPrompt(self, text: string?)
	if self.touch then
		-- No F key to name, and the button never goes away: with nothing in front of you it still eats what is
		-- in your hand, so hiding it would hide a verb the player needs.
		local verb = if text then (text:gsub("^F: ", "")) else "act"
		if self.prompt.Text ~= verb then self.prompt.Text = verb end
		self.prompt.Visible = not self:anyOpen()
		return
	end
	if text then
		if self.prompt.Text ~= text then self.prompt.Text = text end
		self.prompt.Visible = true
	else
		self.prompt.Visible = false
	end
end

function Hud.setHint(self, text: string?)
	self.hint.Text = text or ""
	self.hint.Visible = text ~= nil
end

function Hud.setWarning(self, text: string?)
	self.warning.Text = text or ""
	self.warning.Visible = text ~= nil
end

function Hud.notice(self, text: string, color: string?)
	local t = label(self.notices, "Notice", text)
	t.Size = UDim2.new(1, 0, 0.3, 0)
	t.TextColor3 = COLORS[color or ""] or INK
	t.LayoutOrder = math.floor(os.clock() * 1000) % 1000000000
	local kids = self.notices:GetChildren()
	local n = 0
	for _, k in ipairs(kids) do if k:IsA("TextLabel") then n += 1 end end
	if n > 3 then
		for _, k in ipairs(kids) do if k:IsA("TextLabel") then k:Destroy() n -= 1 if n <= 3 then break end end end
	end
	task.delay(4, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tw.Completed:Connect(function() t:Destroy() end)
		tw:Play()
	end)
end

-- ---------- dialogue ----------
function Hud.showDialogue(self, data)
	self.tradeFrame.Visible = false
	self.bagFrame.Visible = false
	self.dialogue = data
	self.page = 1
	self.dialogueFrame.Visible = true
	self:renderDialogue()
end

function Hud.renderDialogue(self)
	local d = self.dialogue
	if not d then return end
	self.dialogueName.Text = d.name or ""
	self.dialogueText.Text = d.lines[self.page] or ""
	local last = self.page >= #d.lines
	local hasChoices = d.choices ~= nil and #d.choices > 0
	if self.touch then
		self.dialogueMore.Text = if last then (if hasChoices then "tap a question, or the map to leave" else "tap to close") else ("tap to go on  (%d/%d)"):format(self.page, #d.lines)
	else
		self.dialogueMore.Text = if last then (if hasChoices then "Esc: leave" else "F / click: close") else ("F / click: more  (%d/%d)"):format(self.page, #d.lines)
	end
	local showChoices = hasChoices and last
	for i, b in ipairs(self.choices) do
		local c = if showChoices then d.choices[i] else nil
		b.Visible = c ~= nil
		if c then b.Text = (d.labels and d.labels[c]) or c end
	end
	self.dialogueText.Size = if showChoices then UDim2.fromScale(0.62, 0.62) else UDim2.fromScale(1, 0.62)
end

--- Advance the dialogue. Returns true when it closed.
function Hud.advanceDialogue(self): boolean
	local d = self.dialogue
	if not d then return true end
	if self.page < #d.lines then
		self.page += 1
		self:renderDialogue()
		return false
	end
	if d.choices and #d.choices > 0 then return false end -- wait for a choice or Esc
	self:closeDialogue()
	return true
end

function Hud.closeDialogue(self)
	self.dialogue = nil
	self.dialogueFrame.Visible = false
end

function Hud.dialogueOpen(self): boolean
	return self.dialogue ~= nil
end

-- ---------- trade ----------
function Hud.showTrade(self, data)
	self:closeDialogue()
	self.bagFrame.Visible = false
	self.tradeFrame.Visible = true
	self.tradeTitle.Text = ("%s  (%s, you are %s here)"):format(data.village, data.tribeType .. "s", data.standing or "")
	if data.line then self.tradeLine.Text = data.line end
	local have = {}
	for _, s in ipairs(data.inv.slots) do have[s.item] = (have[s.item] or 0) + s.n end
	for i, q in ipairs(data.quotes) do
		local r = self.tradeRows[i]
		r.row.Visible = true
		self.rowGood[i] = q.good
		local sprite = Items.def(q.good).sprite
		if r.icon.Name ~= sprite then Sprites.Apply(r.icon, sprite) r.icon.Name = sprite end
		r.name.Text = q.label
		r.stock.Text = tostring(q.stock)
		r.have.Text = tostring(have[q.good] or 0)
		r.buy.Text = "buy " .. q.buy
		r.sell.Text = "sell " .. q.sell
		r.sell.Visible = true
	end
	local r = self.tradeRows[5]
	if data.camper then
		r.row.Visible = true
		self.rowGood[5] = "camper_set"
		if r.icon.Name ~= "item_camper" then Sprites.Apply(r.icon, "item_camper") r.icon.Name = "item_camper" end
		r.name.Text = "camper set"
		r.stock.Text = ""
		r.have.Text = tostring(data.camperOwned or 0)
		r.buy.Text = "buy " .. data.camper
		r.sell.Visible = false
	else
		r.row.Visible = false
		self.rowGood[5] = nil
	end
	self.tradeCoin.Text = ("coin: %d"):format(data.coin)
end

function Hud.tradeOpen(self): boolean
	return self.tradeFrame.Visible
end

-- ---------- standing ----------
function Hud.toggleStanding(self, rep, tribeNames)
	if self.standingFrame.Visible then self.standingFrame.Visible = false return end
	self.bagFrame.Visible = false
	local lines = { if self.touch then "Your standing (tap the x to close)" else "Your standing (Tab to close)", "" }
	for _, t in ipairs({ "farmer", "hunter", "plunderer" }) do
		local v = rep[t] or 0
		table.insert(lines, ("%-22s %s"):format(tribeNames[t] or t, Reputation.word(v)))
	end
	table.insert(lines, "")
	table.insert(lines, "Trade and help to rise. Harm their people and they remember.")
	self.standingText.Text = table.concat(lines, "\n")
	self.standingFrame.Visible = true
end

function Hud.closeAll(self)
	self:closeDialogue()
	self.tradeFrame.Visible = false
	self.standingFrame.Visible = false
	self.bagFrame.Visible = false
end

function Hud.anyOpen(self): boolean
	return self.dialogue ~= nil or self.tradeFrame.Visible or self.standingFrame.Visible or self.bagFrame.Visible
end

-- ---------- death ----------
function Hud.showDead(self, by: string, seconds: number, at: string)
	self:closeAll()
	self.deadFrame.Visible = true
	self.deadText.Text = ("You died to %s.\nWaking at %s..."):format(by, at)
end

function Hud.hideDead(self)
	self.deadFrame.Visible = false
end

return Hud
