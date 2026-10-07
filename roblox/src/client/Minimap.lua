--!strict
-- Minimap: the whole world in a corner, one coloured cell per CELL x CELL tiles, built once from the decoded map;
-- every village as a marker in its tribe's colour (the capitals bigger), the player as a white dot that moves.
-- M (or a tap on it) swaps between the small corner map and a large one in the middle of the screen. It owns
-- nothing else: no fog, no names, no tap-to-travel (the viewport does that).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))

local Minimap = {}
Minimap.__index = Minimap

local CELL = 8 -- tiles per cell: a 256 x 256 map is 32 x 32 cells, about a thousand frames, built once

local G = TileTypes.GroundByName
local O = TileTypes.ObjectByName
local COLOR = {
	grass = Color3.fromRGB(78, 138, 68), tall = Color3.fromRGB(64, 118, 60), forest = Color3.fromRGB(42, 84, 44),
	rocky = Color3.fromRGB(125, 122, 102), water = Color3.fromRGB(58, 110, 190), road = Color3.fromRGB(160, 124, 82),
	farm = Color3.fromRGB(176, 142, 70), village = Color3.fromRGB(208, 168, 92),
}
local TRIBE = { farmer = Color3.fromRGB(255, 214, 90), hunter = Color3.fromRGB(120, 220, 110), plunderer = Color3.fromRGB(235, 80, 70) } :: { [string]: Color3 }

export type Minimap = typeof(setmetatable({} :: {
	frame: Frame, dot: Frame, world: WorldGen.World, cols: number, rows: number, large: boolean, touch: boolean,
}, Minimap))

--- The colour that says most about a cell: a village if one stands in it, else water, road, forest, hills, farm.
local function cellColor(world: WorldGen.World, x0: number, y0: number): Color3
	local n, water, road, forest, rocky, farm, tall = 0, 0, 0, 0, 0, 0, 0
	for y = y0, math.min(world.height, y0 + CELL - 1) do
		for x = x0, math.min(world.width, x0 + CELL - 1) do
			n += 1
			local g, o = WorldGen.ground(world, x, y), WorldGen.object(world, x, y)
			if g == G.water.id or g == G.river.id then water += 1
			elseif g == G.path.id or g == G.ford.id then road += 1
			elseif g == G.forest_floor.id then forest += 1
			elseif g == G.rocky.id or o == O.rock.id then rocky += 1
			elseif g == G.farm.id then farm += 1
			elseif g == G.tall_grass.id then tall += 1 end
			if WorldGen.villageAt(world, x, y, 0) then return COLOR.village end
		end
	end
	if water >= n * 0.3 then return COLOR.water end
	if road >= 4 then return COLOR.road end
	if forest >= n * 0.4 then return COLOR.forest end
	if rocky >= n * 0.4 then return COLOR.rocky end
	if farm >= n * 0.3 then return COLOR.farm end
	if tall >= n * 0.5 then return COLOR.tall end
	return COLOR.grass
end

local function square(parent: Instance, name: string, color: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = parent
	return f
end

function Minimap.new(parent: Instance, world: WorldGen.World, touch: boolean): Minimap
	local cols, rows = math.ceil(world.width / CELL), math.ceil(world.height / CELL)
	local frame = Instance.new("Frame")
	frame.Name = "Minimap"
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 40)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.SizeConstraint = Enum.SizeConstraint.RelativeYY -- square, sized by the screen's height
	frame.ZIndex = 25 -- under the HUD's panels; the client also hides it while one is open
	frame.Parent = parent
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3)
	pad.Parent = frame
	for cy = 0, rows - 1 do
		for cx = 0, cols - 1 do
			local c = square(frame, "c", cellColor(world, cx * CELL + 1, cy * CELL + 1), 31)
			c.Position = UDim2.fromScale(cx / cols, cy / rows)
			c.Size = UDim2.fromScale(1 / cols + 0.002, 1 / rows + 0.002)
		end
	end
	for _, v in ipairs(world.villages) do
		local m = square(frame, "village", TRIBE[v.tribeType] or COLOR.village, 32)
		local s = if v.tier == "large" then 0.034 elseif v.tier == "mid" then 0.024 else 0.018
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.fromScale(v.cx / world.width, v.cy / world.height)
		m.Size = UDim2.fromScale(s, s)
		local minSize = Instance.new("UISizeConstraint") -- a hamlet is still a dot you can see on a phone
		minSize.MinSize = Vector2.new(5, 5)
		minSize.Parent = m
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 20, 30)
		stroke.Thickness = 1
		stroke.Parent = m
	end
	local dot = square(frame, "you", Color3.fromRGB(255, 255, 255), 33)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromScale(0.02, 0.02)
	local dotMin = Instance.new("UISizeConstraint")
	dotMin.MinSize = Vector2.new(5, 5)
	dotMin.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Parent = dot
	local self = setmetatable({ frame = frame, dot = dot, world = world, cols = cols, rows = rows, large = false, touch = touch }, Minimap)
	-- a tap or click on the map swaps its size (the only way on a phone; M on a keyboard)
	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 34
	button.Parent = frame
	button.Activated:Connect(function() self:toggle() end)
	self:layout()
	return self
end

--- Small: the top-right corner (below the touch hot bar, which lives there on a phone). Large: the middle.
function Minimap.layout(self: Minimap)
	local f = self.frame
	if self.large then
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(0.78, 0.78)
	else
		f.AnchorPoint = Vector2.new(1, 0)
		f.Position = if self.touch then UDim2.new(1, -6, 0.075, 8) else UDim2.new(1, -6, 0, 6)
		f.Size = UDim2.fromScale(0.26, 0.26)
	end
end

function Minimap.toggle(self: Minimap)
	self.large = not self.large
	self:layout()
end

--- Where the player is, in tiles (continuous: pass the viewport's smoothed position).
function Minimap.update(self: Minimap, x: number, y: number)
	self.dot.Position = UDim2.fromScale((x - 0.5) / self.world.width, (y - 0.5) / self.world.height)
end

function Minimap.setVisible(self: Minimap, on: boolean)
	self.frame.Visible = on
end

return Minimap
