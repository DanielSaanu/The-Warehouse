--!strict
-- Grid: the whole "2D engine". A square-ish play area that scales to any screen, split into COLS x ROWS
-- cells. Every cell is an ImageLabel pointed at a sprite from the generated Sprites module.
local TweenService = game:GetService("TweenService")
local Sprites = require(script.Parent.Sprites)

local Grid = {}
Grid.__index = Grid

export type Grid = typeof(setmetatable({} :: {
	cols: number,
	rows: number,
	root: Frame,
	layers: { [string]: Frame },
	cells: { [string]: ImageLabel },
	rain: { ImageLabel },
}, Grid))

local LAYER_ORDER = { "Floor", "Objects", "Actors", "Overlay", "HUD" }

function Grid.new(parent: Instance, cols: number, rows: number): Grid
	local self = setmetatable({}, Grid)
	self.cols = cols
	self.rows = rows
	self.cells = {}
	self.rain = {}

	local root = Instance.new("Frame")
	root.Name = "PlayArea"
	root.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
	root.BorderSizePixel = 0
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)

	-- Keep the tile aspect ratio on every screen: the area shrinks to fit, never stretches.
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = cols / rows
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = root
	root.Parent = parent
	self.root = root

	self.layers = {}
	for i, name in ipairs(LAYER_ORDER) do
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = i
		f.Parent = root
		self.layers[name] = f
	end
	return self
end

function Grid.cellSize(self: Grid): UDim2
	return UDim2.fromScale(1 / self.cols, 1 / self.rows)
end

function Grid.cellPos(self: Grid, x: number, y: number): UDim2
	return UDim2.fromScale((x - 1) / self.cols, (y - 1) / self.rows)
end

function Grid.inBounds(self: Grid, x: number, y: number): boolean
	return x >= 1 and y >= 1 and x <= self.cols and y <= self.rows
end

--- Set the floor sprite of a cell.
function Grid.setTile(self: Grid, x: number, y: number, spriteName: string): ImageLabel
	local key = x .. "," .. y
	local img = self.cells[key]
	if not img then
		img = Sprites.New(spriteName, self.layers.Floor)
		img.Size = self:cellSize()
		img.Position = self:cellPos(x, y)
		self.cells[key] = img
	else
		Sprites.Apply(img, spriteName)
	end
	return img
end

--- Spawn a movable sprite (creature, item) on a layer. Returns the ImageLabel; keep it to move it later.
function Grid.spawn(self: Grid, spriteName: string, x: number, y: number, layer: string?): ImageLabel
	local img = Sprites.New(spriteName, self.layers[layer or "Actors"])
	img.Size = self:cellSize()
	img.Position = self:cellPos(x, y)
	return img
end

--- Slide a sprite to a cell.
function Grid.moveTo(self: Grid, img: ImageLabel, x: number, y: number, seconds: number?)
	local goal = { Position = self:cellPos(x, y) }
	if seconds and seconds > 0 then
		TweenService:Create(img, TweenInfo.new(seconds, Enum.EasingStyle.Linear), goal):Play()
	else
		img.Position = goal.Position
	end
end

--- Face left (-1) or right (1) by mirroring the sprite rect.
function Grid.face(self: Grid, img: ImageLabel, dir: number)
	local s = Sprites.Sprites[img.Name]
	if not s then return end
	if dir < 0 then
		img.ImageRectOffset = Vector2.new(s.X + s.W, s.Y)
		img.ImageRectSize = Vector2.new(-s.W, s.H)
	else
		img.ImageRectOffset = Vector2.new(s.X, s.Y)
		img.ImageRectSize = Vector2.new(s.W, s.H)
	end
end

--- Cover the whole area with a rain overlay sprite (or clear it).
function Grid.setRain(self: Grid, on: boolean, spriteName: string?)
	if on and #self.rain == 0 then
		for y = 1, self.rows do
			for x = 1, self.cols do
				local img = self:spawn(spriteName or "rain_tile", x, y, "Overlay")
				img.ImageTransparency = 0.25
				table.insert(self.rain, img)
			end
		end
	elseif not on then
		for _, img in ipairs(self.rain) do img:Destroy() end
		table.clear(self.rain)
	end
end

return Grid
