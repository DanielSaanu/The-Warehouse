--!nonstrict
-- Camps and bags: the two things a player leaves lying in the world, and their TILES on the map.
-- Owns (docs/ARCHITECTURE.md R2): `S.camps`, `S.bags`, `S.meta.nextBagId`, and every runtime write to the map's
-- object layer. That last part is the point: a camp or bag tile is DERIVED from its row, so it is never saved -
-- `Tiles.stampAll()` puts them back after a load, and nobody else may write `world.object`.
-- Does NOT decide where a bag lands (the caller finds the free tile) or who may rest (Interact).
-- Carved verbatim out of Sim.lua (Track B1); timers are game time (Calendar.now()), so they survive a save.
--   Tiles.placeCamp(ps, x, y)      Tiles.dropBag(ps, pos)      Tiles.tick(now)   -- 1 Hz
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local Items = require(Shared:WaitForChild("Items"))
local Map = require(script.Parent:WaitForChild("Map"))
local State = require(script.Parent:WaitForChild("State"))
local Calendar = require(script.Parent:WaitForChild("Calendar"))

local Tiles = {}

local S = State.state
local O = TileTypes.ObjectByName
local HOUR = Config.DAY_SECONDS / 24

-- ---------- camps and bags ----------
function Tiles.placeCamp(ps, x: number, y: number)
	local uid = ps.player.UserId
	local old = S.camps[uid]
	if old then
		Map.get().object[State.tidx(old.x, old.y)] = 0
		State.broadcastObject(old.x, old.y, 0)
	end
	S.camps[uid] = { x = x, y = y, litUntil = Calendar.now() + Config.CAMPFIRE_HOURS * HOUR, out = false, owner = uid }
	Map.get().object[State.tidx(x, y)] = O.camp_lit.id
	State.broadcastObject(x, y, O.camp_lit.id)
	ps.rest = { kind = "camp" }
	ps.restText = State.restText(ps)
end

function Tiles.destroyCamp(uid: number, why: string)
	local c = S.camps[uid]
	if not c then return end
	S.camps[uid] = nil
	if Map.get().object[State.tidx(c.x, c.y)] == O.camp_lit.id or Map.get().object[State.tidx(c.x, c.y)] == O.camp_out.id then
		Map.get().object[State.tidx(c.x, c.y)] = 0
		State.broadcastObject(c.x, c.y, 0)
	end
	local ps = S.players[uid]
	if ps then
		if ps.rest.kind == "camp" then ps.rest = { kind = "village", village = 1 } ps.restText = State.restText(ps) end
		State.text(ps, why, "warn")
		State.hud(ps)
	end
end

function Tiles.tick(now: number)
	for uid, c in pairs(S.camps) do
		if not c.out and now >= c.litUntil then
			c.out = true
			Map.get().object[State.tidx(c.x, c.y)] = O.camp_out.id
			State.broadcastObject(c.x, c.y, O.camp_out.id)
			local ps = S.players[uid]
			if ps then State.text(ps, "Your fire has gone out.") end
		end
		-- wolves at an unlit camp trample it
		if c.out then
			for _, e in pairs(S.entities) do
				if e.species == "wolf" and State.cheb(e.x, e.y, c.x, c.y) <= 1 then Tiles.destroyCamp(uid, "Wolves have torn up your camp.") break end
			end
		end
	end
	-- a dropped bag is private for half an in-game day, then anyone may take it, and it is gone at a full day
	for id, b in pairs(S.bags) do
		local age = now - b.droppedAt
		if age > Config.BAG_PRIVATE_SECONDS and not b.public then
			b.public = true
			for _, ps in pairs(S.players) do
				if ps.player.UserId ~= b.owner then State.sendState(ps, "object", b.x, b.y, O.bag.id) end
			end
		end
		if age > Config.BAG_LIFETIME_SECONDS then
			S.bags[id] = nil
			Map.get().object[State.tidx(b.x, b.y)] = 0
			State.broadcastObject(b.x, b.y, 0)
		end
	end
end

function Tiles.bagAt(x: number, y: number)
	for _, b in pairs(S.bags) do
		if b.x == x and b.y == y then return b end
	end
	return nil
end

function Tiles.takeBag(ps, b)
	local got = {}
	local left = {}
	for _, s in ipairs(b.slots) do
		local added = Items.add(ps.inv, s.item, s.n)
		if added > 0 then table.insert(got, added .. " " .. Items.def(s.item).label) end
		if added < s.n then table.insert(left, { item = s.item, n = s.n - added }) end
	end
	if #left > 0 then
		b.slots = left
		State.text(ps, "You take " .. table.concat(got, ", ") .. ". The rest will not fit.", "warn")
	else
		S.bags[b.id] = nil
		Map.get().object[State.tidx(b.x, b.y)] = 0
		State.broadcastObject(b.x, b.y, 0)
		State.text(ps, if #got > 0 then "You take " .. table.concat(got, ", ") .. "." else "The bag is empty.")
	end
	State.hud(ps)
end

--- Everything a dying player carried, left on the ground at `pos` (the caller finds the free tile: that is Bodies' job).
function Tiles.dropBag(ps, pos)
	local slots = Items.dropAll(ps.inv)
	if #slots == 0 then return end
	if WorldGen.object(Map.get(), pos.x, pos.y) ~= 0 then return end
	-- bags are saved, so their counter is too (meta); entity ids are never saved, so theirs is a file local
	S.meta.nextBagId += 1
	local id = "b" .. S.meta.nextBagId
	S.bags[id] = { id = id, x = pos.x, y = pos.y, owner = ps.player.UserId, slots = slots, droppedAt = Calendar.now() }
	Map.get().object[State.tidx(pos.x, pos.y)] = O.bag.id
	State.sendState(ps, "object", pos.x, pos.y, O.bag.id)
end

-- ---------- after a load ----------
--- Take every camp and bag tile off the map (before a saved record replaces the rows)...
function Tiles.unstampAll()
	local world = Map.get()
	for _, c in pairs(S.camps) do world.object[WorldGen.index(world, c.x, c.y)] = 0 end
	for _, b in pairs(S.bags) do world.object[WorldGen.index(world, b.x, b.y)] = 0 end
end

--- ...and put the rows' tiles back (after). The tiles are derived from the rows, so this is all a load needs.
function Tiles.stampAll()
	local world = Map.get()
	for _, c in pairs(S.camps) do world.object[WorldGen.index(world, c.x, c.y)] = if c.out then O.camp_out.id else O.camp_lit.id end
	for _, b in pairs(S.bags) do world.object[WorldGen.index(world, b.x, b.y)] = O.bag.id end
end

return Tiles
