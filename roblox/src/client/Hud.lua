--!nonstrict
-- HUD: hearts, coin, inventory bar, prompt, notices, dialogue box, trade panel, standing screen, death overlay.
-- Everything lives inside the play area's overlay frame (above the night tint) and scales with it.
local TweenService = game:GetService("TweenService")
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

function Hud.new(overlay: Frame, callbacks)
	local self = setmetatable({ overlay = overlay, cb = callbacks, noticeToken = 0, dialogue = nil, page = 1 }, Hud)

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

	-- hearts + coin under the clock
	local hearts = Instance.new("Frame")
	hearts.Name = "Hearts"
	hearts.BackgroundTransparency = 1
	hearts.Position = UDim2.new(0, 6, 0.065, 12)
	hearts.Size = UDim2.new(0.3, 0, 0.06, 0)
	hearts.Parent = overlay
	local heartsMin = Instance.new("UISizeConstraint")
	heartsMin.MinSize = Vector2.new(150, 22)
	heartsMin.Parent = hearts
	self.hearts = {}
	for i = 1, 5 do
		local h = Sprites.New("heart", hearts)
		h.Size = UDim2.fromScale(0.16, 1)
		h.Position = UDim2.fromScale((i - 1) * 0.165, 0)
		h.SizeConstraint = Enum.SizeConstraint.RelativeYY
		self.hearts[i] = h
	end
	local coinIcon = Sprites.New("item_coin", hearts)
	coinIcon.Size = UDim2.fromScale(1, 1)
	coinIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	coinIcon.Position = UDim2.fromScale(0.86, 0)
	self.coin = label(hearts, "Coin", "0")
	self.coin.Size = UDim2.fromScale(0.5, 1)
	self.coin.Position = UDim2.new(0.86, 0, 0, 0)
	self.coin.Position = UDim2.fromScale(1.02, 0)
	self.coin.TextXAlignment = Enum.TextXAlignment.Left
	self.coin.TextColor3 = GOLD

	-- warning line (tomorrow's calamity) and rest point
	self.warning = label(overlay, "Warning", "")
	self.warning.Size = UDim2.new(0.5, 0, 0.045, 0)
	self.warning.Position = UDim2.new(0, 6, 0.125, 14)
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

	-- inventory bar (bottom)
	local bar = Instance.new("Frame")
	bar.Name = "Inventory"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -4)
	bar.Size = UDim2.fromScale(0.7, 0.075)
	bar.Parent = overlay
	local barMin = Instance.new("UISizeConstraint")
	barMin.MinSize = Vector2.new(260, 26)
	barMin.Parent = bar
	self.slots = {}
	for i = 1, Items.SLOTS do
		local s = Instance.new("Frame")
		s.Name = "Slot" .. i
		s.BackgroundColor3 = PANEL
		s.BackgroundTransparency = 0.35
		s.BorderSizePixel = 0
		s.Size = UDim2.fromScale(1, 1)
		s.SizeConstraint = Enum.SizeConstraint.RelativeYY
		s.Position = UDim2.fromScale((i - 1) * 0.1, 0)
		s.Parent = bar
		local img = Sprites.New("item_food", s)
		img.Size = UDim2.fromScale(1, 1)
		img.Visible = false
		local n = label(s, "N", "")
		n.Size = UDim2.fromScale(0.6, 0.45)
		n.Position = UDim2.fromScale(0.4, 0.55)
		n.TextXAlignment = Enum.TextXAlignment.Right
		self.slots[i] = { frame = s, img = img, n = n }
	end

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
	t.Size = UDim2.fromScale(0.8, 0.8)
	t.ZIndex = 30
	self.tradeFrame = t
	self.tradeTitle = label(t, "Title")
	self.tradeTitle.Size = UDim2.fromScale(1, 0.1)
	self.tradeTitle.TextColor3 = GOLD
	self.tradeLine = label(t, "Line")
	self.tradeLine.Size = UDim2.fromScale(1, 0.09)
	self.tradeLine.Position = UDim2.fromScale(0, 0.1)
	self.tradeLine.TextXAlignment = Enum.TextXAlignment.Left
	local head = label(t, "Head", "good              stock   buy     sell    you have")
	head.Size = UDim2.fromScale(1, 0.07)
	head.Position = UDim2.fromScale(0, 0.2)
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextColor3 = Color3.fromRGB(170, 170, 190)
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
		local name = label(row, "Name")
		name.Size = UDim2.fromScale(0.5, 1)
		name.Position = UDim2.fromScale(0.06, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local buy = button(row, "Buy", "buy", function() if self.cb.onTrade and self.rowGood[i] then self.cb.onTrade(if self.rowGood[i] == "camper_set" then "camper" else "buy", self.rowGood[i]) end end)
		buy.Size = UDim2.fromScale(0.17, 0.9)
		buy.Position = UDim2.fromScale(0.6, 0.05)
		local sell = button(row, "Sell", "sell", function() if self.cb.onTrade and self.rowGood[i] then self.cb.onTrade("sell", self.rowGood[i]) end end)
		sell.Size = UDim2.fromScale(0.17, 0.9)
		sell.Position = UDim2.fromScale(0.79, 0.05)
		self.tradeRows[i] = { row = row, icon = icon, name = name, buy = buy, sell = sell }
	end
	self.rowGood = {}
	self.tradeCoin = label(t, "Coin")
	self.tradeCoin.Size = UDim2.fromScale(0.6, 0.08)
	self.tradeCoin.Position = UDim2.fromScale(0, 0.86)
	self.tradeCoin.TextXAlignment = Enum.TextXAlignment.Left
	self.tradeCoin.TextColor3 = GOLD
	local close = button(t, "Close", "close (Esc)", function() self:closeAll() if self.cb.onClose then self.cb.onClose() end end)
	close.Size = UDim2.fromScale(0.3, 0.09)
	close.Position = UDim2.fromScale(0.68, 0.87)

	-- standing panel
	local st = panel(overlay, "Standing")
	st.AnchorPoint = Vector2.new(0.5, 0.5)
	st.Position = UDim2.fromScale(0.5, 0.5)
	st.Size = UDim2.fromScale(0.6, 0.5)
	st.ZIndex = 30
	self.standingFrame = st
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
end

function Hud.setPrompt(self, text: string?)
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
	self.dialogueMore.Text = if last then (if hasChoices then "Esc: leave" else "F / click: close") else ("F / click: more  (%d/%d)"):format(self.page, #d.lines)
	for i, b in ipairs(self.choices) do
		local c = hasChoices and last and d.choices[i]
		b.Visible = c ~= nil
		if c then b.Text = (d.labels and d.labels[c]) or c end
	end
	if hasChoices and last then self.dialogueText.Size = UDim2.fromScale(0.62, 0.62) else self.dialogueText.Size = UDim2.fromScale(1, 0.62) end
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
		r.name.Text = ("%-10s %5d   %3d     %3d      %d"):format(q.label, q.stock, q.buy, q.sell, have[q.good] or 0)
		r.buy.Text = "buy " .. q.buy
		r.sell.Text = "sell " .. q.sell
		r.sell.Visible = true
	end
	local r = self.tradeRows[5]
	if data.camper then
		r.row.Visible = true
		self.rowGood[5] = "camper_set"
		if r.icon.Name ~= "item_camper" then Sprites.Apply(r.icon, "item_camper") r.icon.Name = "item_camper" end
		r.name.Text = ("camper set                 %3d              %d"):format(data.camper, data.camperOwned or 0)
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
	local lines = { "Your standing (Tab to close)", "" }
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
end

function Hud.anyOpen(self): boolean
	return self.dialogue ~= nil or self.tradeFrame.Visible or self.standingFrame.Visible
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
