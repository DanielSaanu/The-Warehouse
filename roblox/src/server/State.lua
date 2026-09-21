--!nonstrict
-- The ground everything on the server stands on: the World Record (`State.state`), tile occupancy, the two remotes,
-- and the handful of helpers every module needs to talk to a client. It exists so that server modules can
-- `require` what they share instead of being handed it through `bind(ctx)` (docs/ARCHITECTURE.md H4): it requires
-- nothing but Map and shared/, so anything may require it and no cycle can form.
-- Owns: the TABLES (their shape is ARCHITECTURE §2; who may WRITE which slice is R2 - not this file's business).
-- Does NOT hold behaviour: nothing here ticks, thinks, fights or saves. Carved verbatim out of Sim.lua (Track B).
--   local S = State.state                       -- S.tribes, S.people, S.groups, S.entities, S.players, ...
--   State.text(ps, "Your fire has gone out.")   -- one line on one player's HUD
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Items = require(Shared:WaitForChild("Items"))
local Map = require(script.Parent:WaitForChild("Map"))

local State = {}

-- Wired by Server.server.lua before Sim.start().
State.remotes = {} :: { EntityState: RemoteEvent, Notice: RemoteEvent }

-- ---------- state ----------
State.state = {
	meta = { gameSeconds = 0, lastDailyTick = 1, nextBagId = 0 }, -- the one clock (Calendar owns it); `day` below is derived, a cache
	day = 1,
	tribes = {},      -- [i] = { villageId, tribeType, stock, population, walled, surnames, news }
	people = nil,     -- Families.Registry: everyone who was ever born in this world
	regions = nil,    -- Ecology.Regions (+ live counts)
	groups = {},      -- [id] = group record
	entities = {},    -- [id] = entity
	players = {},     -- [userId] = player state
	camps = {},       -- [userId] = { x, y, litUntil, out }
	bags = {},        -- [id] = { x, y, owner, slots, droppedAt }
	calamity = { kind = nil, active = false, warnedDay = 0, day = 0, flood = nil },
}
local S = State.state

-- Tile occupancy: index -> entity id or player userId. People and animals never share a tile.
State.occupied = {} :: { [number]: any }

function State.tidx(x: number, y: number): number
	return WorldGen.index(Map.get(), x, y)
end

function State.cheb(x1, y1, x2, y2): number
	return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
end

-- ---------- replication ----------
function State.sendState(ps, ...)
	State.remotes.EntityState:FireClient(ps.player, ...)
end

function State.notice(ps, kind: string, data: any)
	State.remotes.Notice:FireClient(ps.player, kind, data)
end

function State.text(ps, msg: string, color: string?)
	State.notice(ps, "text", { text = msg, color = color })
end

--- Every player that currently knows entity `e`.
function State.broadcastEntity(e, ...)
	for _, ps in pairs(S.players) do
		if ps.known[e.id] then State.sendState(ps, ...) end
	end
end

--- A tile's object changed (a camp, a bag): everybody draws it.
function State.broadcastObject(x: number, y: number, objectId: number)
	for _, ps in pairs(S.players) do State.sendState(ps, "object", x, y, objectId) end
end

-- What a stranger is called. Everyone with a record has a name, but a player only SEES it once they have met that
-- person (talked to them, hit them, or been hit by them): until then a hunter is "hunter". Fifty full names on
-- screen was a wall of text, and a name means more when you earned it. The survivor is family: always named.
local ROLE_LABEL = { caravan_guard = "caravan guard", caravan_master = "caravan master" }
-- ...and the trades that come in CROWDS are not captioned at all until met: eight villagers on adjacent plots all
-- reading "villager" was a smear that said nothing (QA round 1). The sprite already says what they are. The posts
-- a player goes looking for - guard, merchant, caravan master - keep their caption.
local QUIET = { villager = true, pregnant = true, baby = true, hunter = true, bandit = true, caravan_guard = true }

--- The label THIS player sees over entity `e`.
function State.labelFor(ps, e): string?
	if not e.person or e.role == "survivor" then return e.label end
	if ps and ps.met and ps.met[e.person] then return e.name or e.label end
	if QUIET[e.role] then return nil end
	return ROLE_LABEL[e.role] or e.role or e.label
end

--- `ps` has now met `e`: from here on they see the name. Re-sent as leave + spawn, which the client already
--- understands, rather than a new message for a label.
function State.meet(ps, e)
	if not e.person or not ps.met or ps.met[e.person] then return end
	ps.met[e.person] = true
	if ps.known[e.id] then
		State.sendState(ps, "leave", e.id)
		State.sendState(ps, State.spawnPacket(e, ps))
	end
end

function State.spawnPacket(e, ps)
	return "spawn", e.id, e.sprite, e.x, e.y, e.facing, State.labelFor(ps, e), e.hp / e.maxHp, e.kind
end

function State.hud(ps)
	-- what was in hand may have been eaten, sold or dropped since it was picked up
	if ps.selected and not ps.inv.slots[ps.selected] then ps.selected = nil end
	State.notice(ps, "hud", {
		hp = ps.hp, maxHp = ps.maxHp, inv = Items.snapshot(ps.inv), rep = ps.rep,
		rest = ps.restText, dead = ps.dead,
		goal = ps.goal, metSurvivor = ps.metSurvivor, selected = ps.selected,
	})
end

--- Where this player wakes, in words (the HUD's rest line).
function State.restText(ps): string
	if ps.rest.kind == "camp" then return "your camp" end
	return Map.get().villages[ps.rest.village or 1].name
end

return State
