--!nonstrict
-- The ONLY file where saving touches Roblox (docs/ARCHITECTURE.md A5): DataStoreService in, DataStoreService out.
-- Owns: the policy. What is saved is shared/Save.lua's business; how a save becomes a world is Restore.lua's.
--   1. NEVER write a key you failed to read. A DataStore hiccup at boot followed by an autosave is how a world is
--      erased, so any read error puts this server in NO-SAVE mode for its whole life (it plays on a fresh world).
--      A player whose key failed to read plays on a fresh kit and is never written either.
--   2. One server owns the world: the save carries a lease. A second server loads the world, sees a live lease,
--      and CONTENDS: it plays (DESIGN §14's "the second diverges") but does not write while the lease is live. If
--      the owner dies without releasing it, the lease runs out and the contender's next autosave takes over - so a
--      crash costs at most LEASE_SECONDS of not saving, never two timelines overwriting each other.
--   3. A save from another map generator is obsolete, not damaged: a new world is started and saved over it. A save
--      that cannot be understood (a newer version, a broken shape) is left alone: NO-SAVE.
-- In Studio without "Enable Studio Access to API Services" every call errors, which is rule 1: the game still runs.
--   local boot = Persistence.loadWorld()   -- { mode = "new"|"loaded"|"contending"|"nosave", data = table?, slept = seconds, why = string? }
--   Persistence.start(Restore.snapshot)    -- autosave + save on shutdown
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Save = require(Shared:WaitForChild("Save"))

local Persistence = {}

local STORE, WORLD_KEY = "Lowlands_v1", "world"
local ME = HttpService:GenerateGUID(false) -- game.JobId is empty in Studio; this is unique per server either way

Persistence.mode = "nosave" -- until loadWorld says otherwise
Persistence.why = "loadWorld has not run"

local store
local function getStore()
	if not store then store = DataStoreService:GetDataStore(STORE) end
	return store
end

--- Swap in anything with GetAsync / SetAsync / UpdateAsync (Debug `savetest` uses a table in memory, so the whole
--- save -> lease -> load -> restore path can be run in a Studio that has no DataStore access).
--- Returns the store it replaced (nil = the real one, not opened yet) so the caller can PUT IT BACK: a server left
--- pointing at a fake would go on "saving" into memory and logging success while the real world was never written.
function Persistence.useStore(fake)
	local was = store
	store = fake
	return was
end

--- pcall with backoff: DataStores throttle and hiccup, and one failure is not a verdict.
local function attempt(what: string, fn)
	local err
	for try = 1, 3 do
		local ok, a, b = pcall(fn)
		if ok then return true, a, b end
		err = a
		warn(("[Persistence] %s failed (try %d/3): %s"):format(what, try, tostring(a)))
		if tostring(a):find("not allowed") then break end -- Studio without API access: asking again changes nothing
		if try < 3 then task.wait(2 ^ try) end
	end
	return false, err
end

local function noSave(why: string)
	Persistence.mode, Persistence.why = "nosave", why
	warn("[Persistence] NO-SAVE mode: " .. why)
	return { mode = "nosave", data = nil, slept = 0, why = why }
end

--- Somebody else found a reason this server must never write the world (the save would not restore, say).
function Persistence.forbid(why: string)
	noSave(why)
end

-- ---------- the world ----------
--- Read the world key and decide what kind of server this is. Yields. Call once, before anything else exists.
function Persistence.loadWorld()
	if not Config.SAVE_WORLD then return noSave("Config.SAVE_WORLD is off") end
	local ok, data = attempt("reading the world", function() return getStore():GetAsync(WORLD_KEY) end)
	if not ok then return noSave("the world could not be read, so it will not be written: " .. tostring(data)) end
	if data == nil then
		Persistence.mode, Persistence.why = "new", "no save yet"
		print("[Persistence] no saved world: starting one")
		return { mode = "new", data = nil, slept = 0 }
	end
	local shapeOk, shapeWhy = Save.check(data)
	if not shapeOk then return noSave("the saved world is damaged and is being left alone: " .. tostring(shapeWhy)) end
	local rec, why, obsolete = Save.decode(data)
	if not rec then
		if obsolete then
			Persistence.mode, Persistence.why = "new", why
			print("[Persistence] " .. tostring(why))
			return { mode = "new", data = nil, slept = 0, why = why }
		end
		return noSave("the saved world cannot be used and is being left alone: " .. tostring(why))
	end
	local now = os.time()
	local slept = math.max(0, now - (data.meta.savedAt or now))
	if not Save.mayWrite(data, ME, now) then
		Persistence.mode, Persistence.why = "contending", "another server holds the world's lease"
		warn("[Persistence] another server holds the world's lease: this one diverges, and saves only if that lease runs out")
		return { mode = "contending", data = data, slept = slept, why = Persistence.why }
	end
	Persistence.mode, Persistence.why = "loaded", "ok"
	print(("[Persistence] loaded the world: saved %d s ago"):format(slept))
	return { mode = "loaded", data = data, slept = slept }
end

--- Write the world. `snapshot` is Restore.snapshot. Refuses in NO-SAVE mode, and refuses (inside UpdateAsync, so it
--- is atomic) if another server has taken the lease since.
function Persistence.saveWorld(snapshot, release: boolean?): boolean
	if Persistence.mode == "nosave" then return false end
	local data = snapshot()
	local shapeOk, shapeWhy = Save.check(data)
	if not shapeOk then warn("[Persistence] refusing to save a world that is not JSON-safe: " .. tostring(shapeWhy)) return false end
	Save.stampLease(data, ME, os.time(), release)
	local lost = false
	local ok, err = attempt("saving the world", function()
		getStore():UpdateAsync(WORLD_KEY, function(existing)
			if not Save.mayWrite(existing, ME, os.time()) then lost = true return nil end
			return data
		end)
	end)
	if lost then
		if Persistence.mode ~= "contending" then warn("[Persistence] another server holds the world's lease now; not saving over it") end
		Persistence.mode, Persistence.why = "contending", "another server holds the world's lease"
		return false
	end
	if ok then
		Persistence.mode, Persistence.why = "loaded", "ok"
		print(("[Persistence] world saved: day %d, %d bytes"):format(math.floor(data.meta.gameSeconds / Config.DAY_SECONDS) + 1, #HttpService:JSONEncode(data)))
	else
		warn("[Persistence] the world was NOT saved: " .. tostring(err))
	end
	return ok
end

-- ---------- players ----------
--- A player's saved table, or nil for a new player. Second value false = the read FAILED: play, but never save.
function Persistence.loadPlayer(userId: number): (any, boolean)
	if not Config.SAVE_WORLD or Persistence.mode == "nosave" then return nil, false end -- no store to ask: nobody is saved
	local ok, data = attempt("reading player " .. userId, function() return getStore():GetAsync("player_" .. userId) end)
	if not ok then return nil, false end
	return data, true
end

function Persistence.savePlayer(ps, day: number): boolean
	if not Config.SAVE_WORLD or ps.noSave then return false end
	local data = Save.encodePlayer(ps, day)
	-- somebody who left before their client ever drew the world never saw their welcome: their absence is not over
	if ps.welcome and not ps.sawWorld and ps.lastSeenDay then data.lastSeenDay = ps.lastSeenDay end
	if ps.dead then data.x, data.y, data.hp = nil, nil, ps.maxHp end -- the dead wake at their rest point, whole
	if not Save.check(data) then warn("[Persistence] a player record is not JSON-safe; not saved") return false end
	local ok = attempt("saving player " .. ps.player.UserId, function() getStore():SetAsync("player_" .. ps.player.UserId, data) end)
	return ok
end

-- ---------- the loop ----------
--- Autosave, and a last save when the server closes (the lease is released so the next server need not wait it out).
function Persistence.start(snapshot, players, currentDay)
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_SECONDS)
			Persistence.saveWorld(snapshot)
		end
	end)
	game:BindToClose(function()
		for _, ps in pairs(players()) do task.spawn(Persistence.savePlayer, ps, currentDay()) end
		Persistence.saveWorld(snapshot, true)
		if RunService:IsStudio() then task.wait(0.5) else task.wait(2) end -- let the player writes land
	end)
end

return Persistence
