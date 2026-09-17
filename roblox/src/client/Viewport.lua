--!strict
-- Viewport: a COLS x ROWS window onto the tile world that scrolls smoothly.
--
-- Tiles are a ring buffer: a pool of (COLS+2M) x (ROWS+2M) ImageLabels per layer, each parked at its tile's fixed
-- position inside a World frame that scrolls continuously. When the camera crosses a tile, only the images whose
-- tiles left the window are moved to the far side and repainted; they are M tiles off screen when it happens, so no
-- repaint is ever visible and the World frame never jumps. Entities are ImageLabels positioned in the same frame.
-- Continuous coordinates: tile (x, y) occupies [x-1, x) x [y-1, y). The camera is a continuous centre point.
--
-- Pixel-crisp: tiles are drawn at a whole number of screen pixels (a whole multiple of 16 when that costs little
-- screen space). Scrolling moves in whole art pixels when the scale is a whole number, otherwise in whole screen
-- pixels: either way every frame's step is the same size, so scrolling never judders.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sprites = require(Shared:WaitForChild("Sprites"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Config = require(Shared:WaitForChild("Config"))

local ART = 16   -- art pixels per tile
local MARGIN = 2 -- tiles of pool beyond each edge of the window
-- Ground that animates: current sprite name -> its base. Frame 0 is what TileTypes names, so a freshly painted
-- tile is always valid and only joins the animation on the next flip.
local ANIM_GROUND = { water_0 = "water", water_1 = "water", river_0 = "river", river_1 = "river" } :: { [string]: string }

local Viewport = {}
Viewport.__index = Viewport

export type Entity = { img: ImageLabel, sprite: string, x: number, y: number, px: number, py: number, fromX: number, fromY: number, moveStart: number, moveTime: number, label: TextLabel?,
	fxUntil: number, fxX: number, fxY: number, hpBar: Frame?, hpFill: Frame? }
type Slot = { tx: number, ty: number, ground: ImageLabel, object: ImageLabel }

export type Viewport = typeof(setmetatable({} :: {
	cols: number, rows: number, world: WorldGen.World, tilePx: number,
	container: Frame, root: Frame, worldFrame: Frame, layers: { [string]: Frame }, night: Frame, overlay: Frame,
	slots: { Slot }, poolW: number, poolH: number, maxCols: number,
	cx: number, cy: number,
	entities: { [any]: Entity },
	badges: { [any]: ImageLabel },
	marker: ImageLabel, markerTile: { x: number, y: number }?, fireFrame: number, waterFrame: number,
}, Viewport))

function Viewport.new(parent: Instance, cols: number, rows: number, world: WorldGen.World): Viewport
	local container = Instance.new("Frame")
	container.Name = "Viewport"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "PlayArea"
	root.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = container

	local worldFrame = Instance.new("Frame")
	worldFrame.Name = "World"
	worldFrame.BackgroundTransparency = 1
	worldFrame.Size = UDim2.fromOffset(0, 0)
	worldFrame.Parent = root

	local layers: { [string]: Frame } = {}
	for i, name in ipairs({ "Ground", "Objects", "Entities" }) do
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(0, 0)
		f.ZIndex = i
		f.Parent = worldFrame
		layers[name] = f
	end

	-- The pool is sized for the widest window (Config.MAX_COLS); `cols` grows with the screen's aspect ratio in fit().
	local maxCols = math.max(cols, Config.MAX_COLS)
	local poolW, poolH = maxCols + 2 * MARGIN, rows + 2 * MARGIN
	local slots: { Slot } = {}
	for _ = 1, poolW * poolH do
		local g = Sprites.New("grass", layers.Ground)
		local o = Sprites.New("tree", layers.Objects)
		o.Visible = false
		-- tx = 0 marks "not assigned yet": every slot repaints on the first refresh.
		table.insert(slots, { tx = 0, ty = 0, ground = g, object = o })
	end

	-- Night tint sits above the world; the overlay (HUD) sits above the tint. ZIndex is sibling-relative: the
	-- ScreenGui must use ZIndexBehavior.Sibling.
	local night = Instance.new("Frame")
	night.Name = "Night"
	night.BackgroundColor3 = Color3.fromRGB(10, 14, 40)
	night.BackgroundTransparency = 1
	night.BorderSizePixel = 0
	night.Size = UDim2.fromScale(1, 1)
	night.ZIndex = 10
	night.Parent = root

	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 20
	overlay.Parent = root

	local marker = Sprites.New("marker", layers.Entities)
	marker.Visible = false
	marker.ZIndex = 1

	local self = setmetatable({
		cols = cols, rows = rows, world = world, tilePx = ART,
		container = container, root = root, worldFrame = worldFrame, layers = layers, night = night, overlay = overlay,
		slots = slots, poolW = poolW, poolH = poolH, maxCols = maxCols,
		cx = cols / 2, cy = rows / 2,
		entities = {},
		badges = {},
		marker = marker, markerTile = nil :: { x: number, y: number }?, fireFrame = 0, waterFrame = 0,
	}, Viewport)

	local function fit()
		local size = container.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		-- Wide screens see more columns (up to MAX_COLS) instead of black bars.
		local wantCols = math.clamp(math.floor(size.X / (size.Y / rows)), cols, maxCols)
		self.cols = wantCols
		local best = math.min(size.X / wantCols, size.Y / rows)
		-- A whole multiple of 16 keeps every art pixel the same size; use it unless it would waste much of the screen.
		local whole = math.floor(best / ART) * ART
		local t = if whole >= ART and whole >= best * 0.85 then whole else math.max(1, math.floor(best))
		self.tilePx = t
		-- Centred on a whole pixel (an anchor of 0.5 lands on a half pixel when the screen width is odd).
		root.Position = UDim2.fromOffset(math.floor((size.X - t * wantCols) / 2), math.floor((size.Y - t * rows) / 2))
		root.Size = UDim2.fromOffset(t * wantCols, t * rows)
		local cell = UDim2.fromOffset(t, t)
		for _, s in ipairs(slots) do
			s.ground.Size, s.object.Size = cell, cell
			s.tx = 0 -- positions depend on t: lay every slot out again
		end
		for _, e in pairs(self.entities) do e.img.Size = cell end
		marker.Size = cell
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return self
end

function Viewport.setCamera(self: Viewport, cx: number, cy: number)
	local w, h = self.world.width, self.world.height
	self.cx = math.clamp(cx, self.cols / 2, math.max(self.cols / 2, w - self.cols / 2))
	self.cy = math.clamp(cy, self.rows / 2, math.max(self.rows / 2, h - self.rows / 2))
end

function Viewport.setNight(self: Viewport, alpha: number)
	self.night.BackgroundTransparency = 1 - math.clamp(alpha, 0, 1)
end

--- Park a slot at world tile (tx, ty) and paint it.
local function assign(self: Viewport, s: Slot, tx: number, ty: number)
	local t = self.tilePx
	s.tx, s.ty = tx, ty
	local pos = UDim2.fromOffset((tx - 1) * t, (ty - 1) * t)
	s.ground.Position, s.object.Position = pos, pos
	local gdef = TileTypes.Ground[WorldGen.ground(self.world, tx, ty)]
	-- animated ground joins the animation already in progress, so scrolling never rewinds the water a frame
	local want = gdef.sprite
	local abase = ANIM_GROUND[want]
	if abase then want = abase .. "_" .. self.waterFrame end
	if s.ground.Name ~= want then Sprites.Apply(s.ground, want) s.ground.Name = want end
	local o = WorldGen.object(self.world, tx, ty)
	if o == 0 then
		s.object.Visible = false
	else
		local odef = TileTypes.Object[o]
		if s.object.Name ~= odef.sprite then Sprites.Apply(s.object, odef.sprite) s.object.Name = odef.sprite end
		s.object.Visible = true
	end
end

--- Advance entity slides to `now`. Call before reading an entity's px/py (e.g. to aim the camera at it).
function Viewport.step(self: Viewport, now: number)
	for _, e in pairs(self.entities) do
		if e.moveTime > 0 then
			local t = math.clamp((now - e.moveStart) / e.moveTime, 0, 1)
			e.px = e.fromX + (e.x - 1 - e.fromX) * t
			e.py = e.fromY + (e.y - 1 - e.fromY) * t
			if t >= 1 then e.moveTime = 0 end
		end
	end
end

--- Lay out tiles and entities for the current camera. Call every frame after step() and setCamera().
function Viewport.refresh(self: Viewport)
	local cols, rows, t = self.cols, self.rows, self.tilePx
	local poolW, poolH = self.poolW, self.poolH
	-- Positions snap to a grid of `unit` screen pixels: one art pixel when the scale is whole, else one screen pixel.
	local unit = if t % ART == 0 then t / ART else 1
	local function snap(tiles: number): number
		return math.round(tiles * t / unit) * unit
	end
	local vx, vy = self.cx - cols / 2, self.cy - rows / 2

	-- Ring buffer: world tile (tx, ty) always lives in slot (tx mod poolW, ty mod poolH). Any slot whose tile has left
	-- the window is re-parked at the one tile in the window that maps to it.
	local x0, y0 = math.floor(vx) - MARGIN + 1, math.floor(vy) - MARGIN + 1
	for ty = y0, y0 + poolH - 1 do
		local row = (ty % poolH) * poolW
		for tx = x0, x0 + poolW - 1 do
			local s = self.slots[row + (tx % poolW) + 1]
			if s.tx ~= tx or s.ty ~= ty then assign(self, s, tx, ty) end
		end
	end

	-- The frame scrolls continuously; everything inside is at fixed world-pixel positions, and every entity is snapped
	-- from its on-screen coordinate, so the followed player never wobbles against the world.
	local wx, wy = snap(-vx), snap(-vy)
	self.worldFrame.Position = UDim2.fromOffset(wx, wy)
	local now = os.clock()
	for _, e in pairs(self.entities) do
		local ox, oy = 0, 0
		if now < e.fxUntil then ox, oy = e.fxX * t / ART, e.fxY * t / ART end
		e.img.Position = UDim2.fromOffset(snap(e.px - vx) - wx + ox, snap(e.py - vy) - wy + oy)
		e.img.ZIndex = 1 + math.floor(e.py + 0.5)
	end
	local m = self.markerTile
	if m then
		self.marker.Position = UDim2.fromOffset(snap(m.x - 1 - vx) - wx, snap(m.y - 1 - vy) - wy)
		self.marker.Visible = true
	else
		self.marker.Visible = false
	end
	-- a marker over someone's head bobs, so it reads as a marker and not as a hat
	if next(self.badges) ~= nil then
		local bob = math.sin(now * 4) * 0.09
		for id, b in pairs(self.badges) do
			local e = self.entities[id]
			if e then
				b.Position = UDim2.fromScale(0, -0.9 + bob)
				b.Visible = true
			else
				b.Visible = false
			end
		end
	end

	-- campfires flicker
	local frame = math.floor(now * 3) % 2
	if frame ~= self.fireFrame then
		self.fireFrame = frame
		local name = "camp_lit_" .. frame
		for _, s in ipairs(self.slots) do
			if s.object.Visible and (s.object.Name == "camp_lit_0" or s.object.Name == "camp_lit_1") and s.object.Name ~= name then
				Sprites.Apply(s.object, name)
				s.object.Name = name
			end
		end
	end
	-- and the water moves, at half that pace: a river, not a strobe
	local wframe = math.floor(now * 1.5) % 2
	if wframe ~= self.waterFrame then
		self.waterFrame = wframe
		for _, s in ipairs(self.slots) do
			local base = ANIM_GROUND[s.ground.Name]
			if base then
				local name = base .. "_" .. wframe
				if s.ground.Name ~= name then
					Sprites.Apply(s.ground, name)
					s.ground.Name = name
				end
			end
		end
	end
end

--- Hang a sprite over an entity's head (the survivor's marker). nil takes it down.
function Viewport.setBadge(self: Viewport, id: any, sprite: string?)
	local old = self.badges[id]
	if not sprite then
		if old then old:Destroy() self.badges[id] = nil end
		return
	end
	local e = self.entities[id]
	if not e then return end
	if old then
		if old.Name ~= sprite then Sprites.Apply(old, sprite) old.Name = sprite end
		return
	end
	local b = Sprites.New(sprite, e.img)
	b.Size = UDim2.fromScale(1, 1)
	b.Position = UDim2.fromScale(0, -0.9)
	b.ZIndex = 200
	self.badges[id] = b
end

--- Repaint one tile after the world changed under it (a camp placed, a bag dropped).
function Viewport.repaint(self: Viewport, tx: number, ty: number)
	local s = self.slots[(ty % self.poolH) * self.poolW + (tx % self.poolW) + 1]
	if s and s.tx == tx and s.ty == ty then assign(self, s, tx, ty) end
end

--- Repaint everything (a flood).
function Viewport.repaintAll(self: Viewport)
	for _, s in ipairs(self.slots) do s.tx = 0 end
end

function Viewport.setMarker(self: Viewport, x: number?, y: number?)
	self.markerTile = if x and y then { x = x, y = y } else nil
end

--- Hit flash: a red-white blink and a nudge away from the attacker.
function Viewport.flash(self: Viewport, id: any, color: Color3?, seconds: number?)
	local e = self.entities[id]
	if not e then return end
	e.img.ImageColor3 = color or Color3.fromRGB(255, 120, 120)
	task.delay(seconds or 0.12, function()
		if self.entities[id] == e then e.img.ImageColor3 = Color3.new(1, 1, 1) end
	end)
end

--- A short lunge in a direction (attack swing) or a shake (wind-up), in art pixels.
function Viewport.nudge(self: Viewport, id: any, dx: number, dy: number, seconds: number)
	local e = self.entities[id]
	if not e then return end
	e.fxX, e.fxY, e.fxUntil = dx, dy, os.clock() + seconds
end

--- A thin health bar under a hurt entity (hidden at full health).
function Viewport.setHp(self: Viewport, id: any, frac: number)
	local e = self.entities[id]
	if not e then return end
	if frac >= 1 or frac <= 0 then
		if e.hpBar then e.hpBar.Visible = false end
		return
	end
	if not e.hpBar then
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.fromRGB(27, 27, 47)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(0.8, 0.1)
		bar.Position = UDim2.fromScale(0.1, 1.02)
		bar.Parent = e.img
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.fromRGB(184, 56, 60)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = bar
		e.hpBar, e.hpFill = bar, fill
	end
	e.hpBar.Visible = true
	e.hpFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
end

function Viewport.addEntity(self: Viewport, id: any, sprite: string, x: number, y: number, label: string?): Entity
	local img = Sprites.New(sprite, self.layers.Entities)
	img.Size = UDim2.fromOffset(self.tilePx, self.tilePx)
	local e: Entity = { img = img, sprite = sprite, x = x, y = y, px = x - 1, py = y - 1, fromX = x - 1, fromY = y - 1, moveStart = 0, moveTime = 0, fxUntil = 0, fxX = 0, fxY = 0 }
	if label then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Text = label
		t.TextColor3 = Color3.fromRGB(236, 235, 240)
		t.TextStrokeColor3 = Color3.fromRGB(27, 27, 47)
		t.TextStrokeTransparency = 0
		t.Font = Enum.Font.Code
		t.TextScaled = true
		t.Size = UDim2.fromScale(3, 0.4)
		t.Position = UDim2.fromScale(-1, -0.45)
		t.Parent = img
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize = 10
		limit.MaxTextSize = 20
		limit.Parent = t
		e.label = t
	end
	self.entities[id] = e
	return e
end

--- Slide an entity to a tile over `seconds` (0 = instant), starting at time `startAt`. When the previous slide has
--- finished by `startAt` (continuous walking), the new slide starts from the previous tile rather than from wherever
--- the last frame left it, so a held key walks without a hitch between steps.
function Viewport.moveEntity(self: Viewport, id: any, x: number, y: number, seconds: number, startAt: number)
	local e = self.entities[id]
	if not e then return end
	if e.moveTime > 0 and startAt >= e.moveStart + e.moveTime - 1e-6 then
		e.fromX, e.fromY = e.x - 1, e.y - 1
	else
		e.fromX, e.fromY = e.px, e.py
	end
	e.x, e.y = x, y
	if seconds <= 0 then
		e.px, e.py, e.moveTime = x - 1, y - 1, 0
	else
		e.moveStart, e.moveTime = startAt, seconds
	end
end

--- When the entity's current slide ends (or ended).
function Viewport.slideEnd(self: Viewport, id: any): number
	local e = self.entities[id]
	return if e and e.moveTime > 0 then e.moveStart + e.moveTime else 0
end

function Viewport.setSprite(self: Viewport, id: any, sprite: string)
	local e = self.entities[id]
	if e and e.sprite ~= sprite then
		e.sprite = sprite
		Sprites.Apply(e.img, sprite)
	end
end

function Viewport.removeEntity(self: Viewport, id: any)
	local e = self.entities[id]
	if e then e.img:Destroy() self.entities[id] = nil end
	self.badges[id] = nil -- the badge was a child of the image, so it went with it
end

function Viewport.getEntity(self: Viewport, id: any): Entity?
	return self.entities[id]
end

--- Convert a screen position (e.g. a tap) to a tile, or nil if outside the play area.
function Viewport.screenToTile(self: Viewport, sx: number, sy: number): (number?, number?)
	local root = self.root
	local rx = (sx - root.AbsolutePosition.X) / root.AbsoluteSize.X
	local ry = (sy - root.AbsolutePosition.Y) / root.AbsoluteSize.Y
	if rx < 0 or ry < 0 or rx > 1 or ry > 1 then return nil, nil end
	local vx, vy = self.cx - self.cols / 2, self.cy - self.rows / 2
	return math.floor(vx + rx * self.cols) + 1, math.floor(vy + ry * self.rows) + 1
end

return Viewport
