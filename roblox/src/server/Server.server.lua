--!nonstrict
-- Server: owns the world, validates every move and action, runs the clock. Clients only draw what they are told.
-- The simulation itself lives in Sim.lua; the F key in Interact.lua. This file is the remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Movement = require(Shared:WaitForChild("Movement"))
local Sprites = require(Shared:WaitForChild("Sprites"))
local Map = require(script.Parent:WaitForChild("Map"))
local Sim = require(script.Parent:WaitForChild("Sim"))
local Interact = require(script.Parent:WaitForChild("Interact"))
local Persistence = require(script.Parent:WaitForChild("Persistence"))
local Restore = require(script.Parent:WaitForChild("Restore"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WorldInit = Remotes:WaitForChild("WorldInit") :: RemoteEvent
local Move = Remotes:WaitForChild("Move") :: RemoteEvent
local EntityState = Remotes:WaitForChild("EntityState") :: RemoteEvent
local Clock = Remotes:WaitForChild("Clock") :: RemoteEvent
local Action = Remotes:WaitForChild("Action") :: RemoteEvent
local Notice = Remotes:WaitForChild("Notice") :: RemoteEvent

-- This is a 2D game: no avatars in the 3D world. In Studio's Play Solo the first character can load before this
-- script runs, so also remove any character that slips through.
Players.CharacterAutoLoads = false
local function noCharacter(player: Player)
	if player.Character then player.Character:Destroy() end
	player.CharacterAdded:Connect(function(character) task.defer(function() character:Destroy() end) end)
end

-- THE BOOT ORDER (docs/ARCHITECTURE.md A5). Reading the save yields for seconds, and everything below - the map,
-- the sim, every remote handler - waits for it, so there is no moment when a player can join a half-built world:
-- nothing is listening yet. Players who arrived early are picked up by the GetPlayers() loop further down, and the
-- client asks for the world every 1.5 s until it gets one.
local boot = Persistence.loadWorld()
Map.init(boot.data and boot.data.meta.seed)
local world = Map.get()
-- Decal id -> image id, once, so nobody has to do the Studio trick by hand.
local sheetIds = Sprites.ResolveOnServer()

Sim.remotes.EntityState = EntityState
Sim.remotes.Notice = Notice
local restored, restoreWhy = Sim.init(boot.data, boot.slept)
if boot.data and not restored then
	-- the save is real but would not go in: this server plays on a new world and must NEVER write over the old one
	Persistence.forbid("the saved world would not restore: " .. tostring(restoreWhy))
end
print(("[Server] world %s (%s)"):format(if boot.data and restored then "restored" else "generated", Persistence.mode))

local players = Sim.state.players
local FACINGS = { down = true, up = true, left = true, right = true }

--- Tell everyone except `except` about an entity change.
local function broadcast(except: Player?, ...: any)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= except and players[p.UserId] then EntityState:FireClient(p, ...) end
	end
end

-- Exposed as Player attributes so tools and QA can compare the server's tile with the client's prediction.
local function publish(st)
	st.player:SetAttribute("TileX", st.x)
	st.player:SetAttribute("TileY", st.y)
	st.player:SetAttribute("MoveEpoch", st.epoch)
	st.player:SetAttribute("Hp", st.hp)
end

-- epoch: bumped on every correction. Moves carry the epoch the client last heard; older ones were sent against a
-- position the server has since corrected, so they are dropped (see shared/Movement.lua).
local function snap(st)
	st.epoch += 1
	publish(st)
	EntityState:FireClient(st.player, "snap", st.player.UserId, st.x, st.y, st.facing, st.epoch)
end

-- The client asks for the world once its listeners exist (a RemoteEvent fired before the client is listening is
-- lost, which is exactly what happens in Play Solo if the server sends on PlayerAdded). Idempotent: ask again, get it again.
local function sendWorld(st)
	local player = st.player
	local others = {}
	for id, o in pairs(players) do
		if id ~= player.UserId and not o.dead then
			table.insert(others, { id = id, x = o.x, y = o.y, facing = o.facing, name = o.player.DisplayName })
		end
	end
	local d, frac = Sim.clock()
	local c = Sim.state.calamity
	WorldInit:FireClient(player, Map.encoded, { x = st.x, y = st.y, facing = st.facing, epoch = st.epoch }, others, { day = d, frac = frac }, sheetIds,
		{ kind = c.kind, active = c.active, flood = c.flood, warning = Sim.calamityWarning() })
	-- interest management re-sends the entities it can see
	st.known = {}
	Sim.hud(st)
end

local joining = {} :: { [number]: boolean }
local function addPlayer(player: Player)
	if player.Parent ~= Players then return nil end -- a late request from someone already leaving
	local uid = player.UserId
	local existing = players[uid]
	if existing then return existing end
	if joining[uid] then return nil end -- their key is being read; the client asks again in 1.5 s
	joining[uid] = true
	noCharacter(player)
	local saved, readOk = Persistence.loadPlayer(uid) -- yields
	joining[uid] = nil
	if player.Parent ~= Players then return nil end
	local st = Sim.addPlayer(player, world.spawn.x, world.spawn.y, snap, saved)
	st.noSave = not readOk -- never write a key we failed to read: they play on a fresh kit and keep their real one
	publish(st)
	broadcast(player, "spawn", player.UserId, "player", st.x, st.y, st.facing, player.DisplayName, 1, "player")
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
	local st = players[player.UserId]
	if not st then return end
	task.spawn(Persistence.savePlayer, st, Sim.state.day)
	Sim.removePlayer(player)
	broadcast(player, "leave", player.UserId)
end)

Move.OnServerEvent:Connect(function(player: Player, epoch: any, tx: any, ty: any, facing: any)
	local st = players[player.UserId]
	if not st or st.dead then return end
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
	if not Movement.canStep(world, st.x, st.y, tx, ty, Sim.occupied) then snap(st) return end
	-- Charged for the tile being LEFT, not the one being entered: the client's slide onto a tile lasts that tile's
	-- step time, so the gap before this move is the step time of where the player has been standing. On uniform
	-- ground the two are the same; walking off grass into a river they are not, and charging the wrong one
	-- rejected the first step into the water every time.
	if not Movement.spend(st.budget, os.clock(), Movement.stepTime(world, st.x, st.y)) then snap(st) return end
	local fx, fy = st.x, st.y
	st.x, st.y, st.facing = tx, ty, facing
	Sim.playerMoved(st, fx, fy)
	publish(st)
	broadcast(player, "move", player.UserId, tx, ty, facing)
end)

Action.OnServerEvent:Connect(function(player: Player, kind: any, a: any, b: any, c: any)
	local st = players[player.UserId]
	if not st then return end
	if kind == "attack" then
		if type(a) == "string" and FACINGS[a] then Sim.attack(st, a) end
	elseif kind == "interact" then
		if type(a) == "string" and FACINGS[a] then st.facing = a end
		Interact.interact(st)
	elseif kind == "topic" then
		if type(a) == "string" then Interact.topic(st, a) end
	elseif kind == "trade" then
		if type(a) == "string" then Interact.trade(st, a, if type(b) == "string" then b else nil, if type(c) == "number" then c else 1) end
	elseif kind == "select" then
		Interact.select(st, if type(a) == "number" then a else nil)
	elseif kind == "close" then
		Interact.close(st)
	end
end)

-- ---------- clock broadcast ----------
task.spawn(function()
	while true do
		task.wait(1)
		local d, frac = Sim.clock()
		Clock:FireAllClients(d, frac)
		for _, st in pairs(players) do publish(st) end
	end
end)

Sim.start()
Persistence.start(Restore.snapshot, function() return players end, function() return Sim.state.day end)

-- Test hooks (see docs/qa/rung2-part2.md). From a script: ServerStorage.Debug:Invoke("teleport", 40, 50).
-- From the Studio command bar or a tool sandbox that cannot invoke bindables: set the `Debug` attribute on
-- Workspace to a command line ("calamity flood", "teleport 40 50", "give food 3") and read `DebugResult`.
local HttpService = game:GetService("HttpService")
local debug = Instance.new("BindableFunction")
debug.Name = "Debug"
debug.OnInvoke = function(cmd, ...) return Sim.debug(cmd, ...) end
debug.Parent = ServerStorage
workspace:GetAttributeChangedSignal("Debug"):Connect(function()
	local line = workspace:GetAttribute("Debug")
	if type(line) ~= "string" or line == "" then return end
	local args = {}
	for word in line:gmatch("%S+") do table.insert(args, tonumber(word) or word) end
	local cmd = table.remove(args, 1)
	local ok, result = pcall(Sim.debug, cmd, table.unpack(args))
	local text = if type(result) == "table" then HttpService:JSONEncode(result) else tostring(result)
	workspace:SetAttribute("DebugResult", (if ok then "" else "ERROR ") .. text)
	workspace:SetAttribute("Debug", "")
end)
