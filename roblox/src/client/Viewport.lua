--!strict
-- Viewport: a COLS x ROWS window onto the tile world that scrolls smoothly. A pool of (COLS+2)x(ROWS+2)
-- ImageLabels per layer is recycled as the camera moves; entities are ImageLabels positioned in tile space.
-- Continuous coordinates: tile (x, y) occupies [x-1, x) x [y-1, y). The camera is a continuous centre point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sprites = require(Shared:WaitForChild("Sprites"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Config = require(Shared:WaitForChild("Config"))

local Viewport = {}
Viewport.__index = Viewport

export type Entity = { img: ImageLabel, sprite: string, x: number, y: number, px: number, py: number, fromX: number, fromY: number, moveStart: number, moveTime: number, label: TextLabel? }

export type Viewport = typeof(setmetatable({} :: {
	cols: number, rows: number, world: WorldGen.World,
	root: Frame, worldFrame: Frame, layers: { [string]: Frame }, night: Frame,
	groundPool: { ImageLabel }, objectPool: { ImageLabel },
	cx: number, cy: number, ox: number?, oy: number?,
	entities: { [any]: Entity },
}, Viewport))

function Viewport.new(parent: Instance, cols: number, rows: number, world: WorldGen.World): Viewport
	local self = setmetatable({}, Viewport)
	self.cols, self.rows, self.world = cols, rows, world
	self.cx, self.cy = cols / 2, rows / 2
	self.entities = {}

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "PlayArea"
	root.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = cols / rows
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = root
	root.Parent = backdrop
	self.root = root

	local worldFrame = Instance.new("Frame")
	worldFrame.Name = "World"
	worldFrame.BackgroundTransparency = 1
	worldFrame.Size = UDim2.fromScale((cols + 2) / cols, (rows + 2) / rows)
	worldFrame.Parent = root
	self.worldFrame = worldFrame

	self.layers = {}
	for i, name in ipairs({ "Ground", "Objects", "Entities", "Effects" }) do
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = i
		f.Parent = worldFrame
		self.layers[name] = f
	end

	local cellSize = UDim2.fromScale(1 / (cols + 2), 1 / (rows + 2))
	self.groundPool, self.objectPool = {}, {}
	for r = 1, rows + 2 do
		for c = 1, cols + 2 do
			local pos = UDim2.fromScale((c - 1) / (cols + 2), (r - 1) / (rows + 2))
			local g = Sprites.New("grass", self.layers.Ground)
			g.Size, g.Position = cellSize, pos
			table.insert(self.groundPool, g)
			local o = Sprites.New("tree", self.layers.Objects)
			o.Size, o.Position = cellSize, pos
			o.Visible = false
			table.insert(self.objectPool, o)
		end
	end

	-- Night tint sits above the world, below the HUD (which lives outside the play area).
	local night = Instance.new("Frame")
	night.Name = "Night"
	night.BackgroundColor3 = Color3.fromRGB(10, 14, 40)
	night.BackgroundTransparency = 1
	night.BorderSizePixel = 0
	night.Size = UDim2.fromScale(1, 1)
	night.ZIndex = 10
	night.Parent = root
	self.night = night
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

local function repaint(self: Viewport)
	local cols, rows, world = self.cols, self.rows, self.world
	local ox, oy = self.ox :: number, self.oy :: number
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

--- Call every frame after moving the camera / entities.
function Viewport.refresh(self: Viewport, now: number)
	local cols, rows = self.cols, self.rows
	local vx, vy = self.cx - cols / 2, self.cy - rows / 2
	local ox, oy = math.floor(vx) - 1, math.floor(vy) - 1
	if ox ~= self.ox or oy ~= self.oy then
		self.ox, self.oy = ox, oy
		repaint(self)
	end
	self.worldFrame.Position = UDim2.fromScale((ox - vx) / cols, (oy - vy) / rows)
	for _, e in pairs(self.entities) do
		if e.moveTime > 0 then
			local t = math.clamp((now - e.moveStart) / e.moveTime, 0, 1)
			e.px = e.fromX + (e.x - 1 - e.fromX) * t
			e.py = e.fromY + (e.y - 1 - e.fromY) * t
			if t >= 1 then e.moveTime = 0 end
		end
		e.img.Position = UDim2.fromScale((e.px - ox) / (cols + 2), (e.py - oy) / (rows + 2))
		e.img.ZIndex = 3 + math.floor(e.py)
	end
end

function Viewport.addEntity(self: Viewport, id: any, sprite: string, x: number, y: number, label: string?): Entity
	local img = Sprites.New(sprite, self.layers.Entities)
	img.Size = UDim2.fromScale(1 / (self.cols + 2), 1 / (self.rows + 2))
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
		t.Size = UDim2.fromScale(3, 0.35)
		t.Position = UDim2.fromScale(-1, -0.4)
		t.ZIndex = 200
		t.Parent = img
		e.label = t
	end
	self.entities[id] = e
	return e
end

--- Slide an entity to a tile over `seconds` (0 = instant).
function Viewport.moveEntity(self: Viewport, id: any, x: number, y: number, seconds: number, now: number)
	local e = self.entities[id]
	if not e then return end
	e.fromX, e.fromY = e.px, e.py
	e.x, e.y = x, y
	if seconds <= 0 then
		e.px, e.py, e.moveTime = x - 1, y - 1, 0
	else
		e.moveStart, e.moveTime = now, seconds
	end
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

local _ = Config
return Viewport
