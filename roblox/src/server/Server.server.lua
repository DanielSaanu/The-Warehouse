--!strict
-- Server: owns the world, validates every move, runs the clock. Clients only draw what the server tells them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Movement = require(Shared:WaitForChild("Movement"))
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

-- epoch: bumped on every correction. Moves carry the epoch the client last heard; older ones were sent against a
-- position the server has since corrected, so they are dropped (see shared/Movement.lua).
type PlayerState = { player: Player, x: number, y: number, facing: string, epoch: number, budget: Movement.Budget, lastWorldInit: number }
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

--- Tell everyone except `except` about an entity change.
local function broadcast(except: Player?, ...: any)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= except and players[p.UserId] then EntityState:FireClient(p, ...) end
	end
end

-- Exposed as Player attributes so tools and QA can compare the server's tile with the client's prediction.
local function publish(st: PlayerState)
	st.player:SetAttribute("TileX", st.x)
	st.player:SetAttribute("TileY", st.y)
	st.player:SetAttribute("MoveEpoch", st.epoch)
end

local function snap(st: PlayerState)
	st.epoch += 1
	publish(st)
	EntityState:FireClient(st.player, "snap", st.player.UserId, st.x, st.y, st.facing, st.epoch)
end

-- The client asks for the world once its listeners exist (a RemoteEvent fired before the client is listening is
-- lost, which is exactly what happens in Play Solo if the server sends on PlayerAdded). Idempotent: ask again, get it again.
local function sendWorld(st: PlayerState)
	local player = st.player
	local others = {}
	for id, o in pairs(players) do
		if id ~= player.UserId then
			table.insert(others, { id = id, x = o.x, y = o.y, facing = o.facing, name = o.player.DisplayName })
		end
	end
	local d, frac = clockNow()
	WorldInit:FireClient(player, World.encoded, { x = st.x, y = st.y, facing = st.facing, epoch = st.epoch }, others, { day = d, frac = frac }, sheetIds)
end

local function addPlayer(player: Player): PlayerState?
	if player.Parent ~= Players then return nil end -- a late request from someone already leaving
	local existing = players[player.UserId]
	if existing then return existing end
	noCharacter(player)
	local spawn = WorldGen.nearestWalkable(world, world.spawn.x, world.spawn.y, 3) or world.spawn
	local st: PlayerState = { player = player, x = spawn.x, y = spawn.y, facing = "down", epoch = 0, budget = Movement.newBudget(os.clock()), lastWorldInit = -math.huge }
	players[player.UserId] = st
	publish(st)
	broadcast(player, "spawn", player.UserId, "player", st.x, st.y, st.facing, player.DisplayName)
	return st
end

Players.PlayerAdded:Connect(addPlayer)
for _, existing in ipairs(Players:GetPlayers()) do addPlayer(existing :: any) end

WorldInit.OnServerEvent:Connect(function(player: Player)
	local st = addPlayer(player)
	if not st then return end
	-- The client retries every 1.5 s until it has the world; ignore anything faster (the map is ~20 KB).
	local now = os.clock()
	if now - st.lastWorldInit < 1 then return end
	st.lastWorldInit = now
	sendWorld(st)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	if not players[player.UserId] then return end
	players[player.UserId] = nil
	broadcast(player, "leave", player.UserId)
end)

Move.OnServerEvent:Connect(function(player: Player, epoch: any, tx: any, ty: any, facing: any)
	local st = players[player.UserId]
	if not st then return end
	if type(epoch) ~= "number" or type(tx) ~= "number" or type(ty) ~= "number" or type(facing) ~= "string" or not FACINGS[facing] then return end
	if epoch ~= st.epoch then return end -- sent before the client heard our last correction
	if tx == st.x and ty == st.y then
		-- Turn in place. Only broadcast real changes.
		if st.facing ~= facing then
			st.facing = facing
			broadcast(player, "move", player.UserId, st.x, st.y, st.facing)
		end
		return
	end
	if not Movement.canStep(world, st.x, st.y, tx, ty) then snap(st) return end
	if not Movement.spend(st.budget, os.clock(), Movement.stepTime(world, tx, ty)) then snap(st) return end
	st.x, st.y, st.facing = tx, ty, facing
	publish(st)
	broadcast(player, "move", player.UserId, tx, ty, facing)
end)

-- ---------- clock broadcast ----------
task.spawn(function()
	while true do
		task.wait(1)
		local d, frac = clockNow()
		Clock:FireAllClients(d, frac)
	end
end)
