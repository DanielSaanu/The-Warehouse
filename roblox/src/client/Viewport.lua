--!strict
-- Viewport: a COLS x ROWS window onto the tile world that scrolls smoothly. A pool of (COLS+2)x(ROWS+2)
-- ImageLabels per layer is recycled as the camera moves; entities are ImageLabels positioned in tile space.
-- Continuous coordinates: tile (x, y) occupies [x-1, x) x [y-1, y). The camera is a continuous centre point.
--
-- Pixel-crisp: tiles are drawn at a whole number of screen pixels (a whole multiple of 16 when that costs little
-- screen space), and the world and entities move in whole art pixels, so scrolling does not shimmer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sprites = require(Shared:WaitForChild("Sprites"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))

local ART = 16 -- art pixels per tile

local Viewport = {}
Viewport.__index = Viewport

export type Entity = { img: ImageLabel, sprite: string, x: number, y: number, px: number, py: number, fromX: number, fromY: number, moveStart: number, moveTime: number, label: TextLabel? }

export type Viewport = typeof(setmetatable({} :: {
	cols: number, rows: number, world: WorldGen.World, tilePx: number,
	container: Frame, root: Frame, worldFrame: Frame, layers: { [string]: Frame }, night: Frame, overlay: Frame,
	groundPool: { ImageLabel }, objectPool: { ImageLabel },
	cx: number, cy: number, ox: number, oy: number, painted: boolean,
	entities: { [any]: Entity },
}, Viewport))

local function quantize(v: number): number
	return math.floor(v * ART + 0.5) / ART
end

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
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Parent = container

	local worldFrame = Instance.new("Frame")
	worldFrame.Name = "World"
	worldFrame.BackgroundTransparency = 1
	worldFrame.Parent = root

	local layers: { [string]: Frame } = {}
	for i, name in ipairs({ "Ground", "Objects", "Entities" }) do
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = i
		f.Parent = worldFrame
		layers[name] = f
	end

	local cellSize = UDim2.fromScale(1 / (cols + 2), 1 / (rows + 2))
	local groundPool, objectPool = {}, {}
	for r = 1, rows + 2 do
		for c = 1, cols + 2 do
			local pos = UDim2.fromScale((c - 1) / (cols + 2), (r - 1) / (rows + 2))
			local g = Sprites.New("grass", layers.Ground)
			g.Size, g.Position = cellSize, pos
			table.insert(groundPool, g)
			local o = Sprites.New("tree", layers.Objects)
			o.Size, o.Position = cellSize, pos
			o.Visible = false
			table.insert(objectPool, o)
		end
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

	local self = setmetatable({
		cols = cols, rows = rows, world = world, tilePx = ART,
		container = container, root = root, worldFrame = worldFrame, layers = layers, night = night, overlay = overlay,
		groundPool = groundPool, objectPool = objectPool,
		cx = cols / 2, cy = rows / 2, ox = 0, oy = 0, painted = false,
		entities = {},
	}, Viewport)

	local function fit()
		local size = container.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		local best = math.min(size.X / cols, size.Y / rows)
		-- A whole multiple of 16 keeps every art pixel the same size; use it unless it would waste much of the screen.
		local whole = math.floor(best / ART) * ART
		local t = if whole >= ART and whole >= best * 0.85 then whole else math.max(1, math.floor(best))
		self.tilePx = t
		root.Size = UDim2.fromOffset(t * cols, t * rows)
		worldFrame.Size = UDim2.fromOffset(t * (cols + 2), t * (rows + 2))
		for _, e in pairs(self.entities) do e.img.Size = UDim2.fromOffset(t, t) end
	end
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return self
end

function Viewport.setCamera(self: Viewport, cx: number, cy: number)
	local w, h = self.world.width, self.world.height
	self.cx = quantize(math.clamp(cx, self.cols / 2, math.max(self.cols / 2, w - self.cols / 2)))
	self.cy = quantize(math.clamp(cy, self.rows / 2, math.max(self.rows / 2, h - self.rows / 2)))
end

function Viewport.setNight(self: Viewport, alpha: number)
	self.night.BackgroundTransparency = 1 - math.clamp(alpha, 0, 1)
end

local function repaint(self: Viewport)
	local cols, rows, world = self.cols, self.rows, self.world
	local ox, oy = self.ox, self.oy
	local i = 0
	for r = 1, rows + 2 do
		for c = 1, cols + 2 do
			i += 1
			local tx, ty = ox + c, oy + r
			local g = WorldGen.ground(world, tx, ty)
			local gdef = TileTypes.Ground[g]
			local gimg = self.groundPool[i]
			if gimg.Name ~= gdef.sprite then Sprites.Apply(gimg, gdef.sprite) gimg.Name = gdef.sprite end
			local o = WorldGen.object(world, tx, ty)
			local oimg = self.objectPool[i]
			if o == 0 then
				oimg.Visible = false
			else
				local odef = TileTypes.Object[o]
				if oimg.Name ~= odef.sprite then Sprites.Apply(oimg, odef.sprite) oimg.Name = odef.sprite end
				oimg.Visible = true
			end
		end
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
	local a = t / ART -- screen pixels per art pixel
	local vx, vy = self.cx - cols / 2, self.cy - rows / 2
	local ox, oy = math.floor(vx) - 1, math.floor(vy) - 1
	if not self.painted or ox ~= self.ox or oy ~= self.oy then
		self.ox, self.oy, self.painted = ox, oy, true
		repaint(self)
	end
	-- Camera and entities are quantized to whole art pixels, and every position is rounded to a whole screen pixel
	-- from its on-screen coordinate, so the followed player never wobbles against the world when a is fractional.
	local wx, wy = math.round((ox - vx) * ART * a), math.round((oy - vy) * ART * a)
	self.worldFrame.Position = UDim2.fromOffset(wx, wy)
	for _, e in pairs(self.entities) do
		local qx, qy = quantize(e.px), quantize(e.py)
		e.img.Position = UDim2.fromOffset(math.round((qx - vx) * ART * a) - wx, math.round((qy - vy) * ART * a) - wy)
		e.img.ZIndex = 1 + math.floor(e.py + 0.5)
	end
end

function Viewport.addEntity(self: Viewport, id: any, sprite: string, x: number, y: number, label: string?): Entity
	local img = Sprites.New(sprite, self.layers.Entities)
	img.Size = UDim2.fromOffset(self.tilePx, self.tilePx)
	local e: Entity = { img = img, sprite = sprite, x = x, y = y, px = x - 1, py = y - 1, fromX = x - 1, fromY = y - 1, moveStart = 0, moveTime = 0 }
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
