--!strict
-- Server: owns the world, validates every move, runs the clock. Clients only draw what the server tells them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local World = require(script.Parent:WaitForChild("World"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldInit = Remotes:WaitForChild("WorldInit") :: RemoteEvent
local Move = Remotes:WaitForChild("Move") :: RemoteEvent
local EntityState = Remotes:WaitForChild("EntityState") :: RemoteEvent
local Clock = Remotes:WaitForChild("Clock") :: RemoteEvent

-- This is a 2D game: no avatars in the 3D world. In Studio's Play Solo the first character can load before this
-- script runs, so also remove any character that slips through.
Players.CharacterAutoLoads = false
local function noCharacter(player: Player)
	if player.Character then player.Character:Destroy() end
	player.CharacterAdded:Connect(function(character) task.defer(function() character:Destroy() end) end)
end

World.init()
local world = World.get()
-- Decal id -> image id, once, so nobody has to do the Studio trick by hand.
local sheetIds = Sprites.ResolveOnServer()

type PlayerState = { player: Player, x: number, y: number, facing: string, lastMove: number }
local players: { [number]: PlayerState } = {}

-- ---------- clock ----------
local day = 1
local dayStart = os.clock()
local function clockNow(): (number, number)
	local elapsed = os.clock() - dayStart
	while elapsed >= Config.DAY_SECONDS do
		elapsed -= Config.DAY_SECONDS
		dayStart += Config.DAY_SECONDS
		day += 1
	end
	return day, elapsed / Config.DAY_SECONDS
end

-- ---------- players ----------
local FACINGS = { down = true, up = true, left = true, right = true }

local function snap(st: PlayerState)
	EntityState:FireClient(st.player, "snap", st.player.UserId, st.x, st.y, st.facing)
end

-- The client asks for the world once its listeners exist (a RemoteEvent fired before the client is listening is
-- lost, which is exactly what happens in Play Solo if the server sends on PlayerAdded). Idempotent: ask again, get it again.
local function sendWorld(player: Player)
	local st = players[player.UserId]
	if not st then return end
	local others = {}
	for id, o in pairs(players) do
		if id ~= player.UserId then
			table.insert(others, { id = id, x = o.x, y = o.y, facing = o.facing, name = o.player.Name })
		end
	end
	local d, frac = clockNow()
	WorldInit:FireClient(player, World.encoded, { x = st.x, y = st.y, facing = st.facing }, others, { day = d, frac = frac }, sheetIds)
end

local function addPlayer(player: Player)
	if players[player.UserId] then return end
	noCharacter(player)
	local spawn = WorldGen.nearestWalkable(world, world.spawn.x, world.spawn.y, 3) or world.spawn
	local st: PlayerState = { player = player, x = spawn.x, y = spawn.y, facing = "down", lastMove = 0 }
	players[player.UserId] = st
	EntityState:FireAllClients("spawn", player.UserId, "player", st.x, st.y, st.facing, player.Name)
end

Players.PlayerAdded:Connect(addPlayer)
for _, existing in ipairs(Players:GetPlayers()) do addPlayer(existing) end

WorldInit.OnServerEvent:Connect(function(player: Player)
	addPlayer(player)
	sendWorld(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	players[player.UserId] = nil
	EntityState:FireAllClients("leave", player.UserId)
end)

Move.OnServerEvent:Connect(function(player: Player, dx: any, dy: any, facing: any)
	local st = players[player.UserId]
	if not st then return end
	if type(dx) ~= "number" or type(dy) ~= "number" or type(facing) ~= "string" or not FACINGS[facing] then return end
	dx, dy = math.clamp(math.round(dx), -1, 1), math.clamp(math.round(dy), -1, 1)
	if dx == 0 and dy == 0 then
		st.facing = facing
		EntityState:FireAllClients("move", player.UserId, st.x, st.y, st.facing)
		return
	end
	if math.abs(dx) + math.abs(dy) ~= 1 then snap(st) return end
	local nx, ny = st.x + dx, st.y + dy
	if not WorldGen.walkable(world, nx, ny) then snap(st) return end
	local now = os.clock()
	local expected = Config.MOVE_STEP / TileTypes.speed(WorldGen.ground(world, nx, ny))
	if now - st.lastMove < expected * Config.MOVE_TOLERANCE then snap(st) return end
	st.x, st.y, st.facing, st.lastMove = nx, ny, facing, now
	EntityState:FireAllClients("move", player.UserId, nx, ny, facing)
end)

-- ---------- clock broadcast ----------
task.spawn(function()
	while true do
		task.wait(1)
		local d, frac = clockNow()
		Clock:FireAllClients(d, frac)
	end
end)
