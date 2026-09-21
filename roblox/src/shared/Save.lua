--!nonstrict
-- The World Record <-> what goes in a DataStore (docs/ARCHITECTURE.md §2, A4). Pure Luau, so `npm test` runs it.
-- Owns: the SAVED SHAPE. encode() copies named fields only, so anything it does not name is transient by
-- construction: entity ids, routes, the map, flood tiles, `regions[].live`, `materialised`, Instances, functions.
-- To save a new field you add it to a list below; nothing is saved by accident.
-- The one trick: JSON object keys are strings, so an id-keyed map ({ [7] = person }) would come back string-keyed
-- and every `people[p.father]` would miss. Id-keyed maps are therefore written as ARRAYS OF ROWS carrying their
-- own id, and decode() rebuilds the index. Ids stay numbers in memory; nothing outside this file knows.
-- Does NOT touch DataStoreService (server/Persistence.lua), build bodies (Sim restore), or regenerate the map.
--   local data = Save.encode(Sim.state, { seed = world.seed, rngState = rng.s, savedAt = os.time() })
--   assert(Save.check(data))                      -- JSON-safe: what comes back is what went in
--   local record = Save.decode(data)              -- then Sim.restore(record)
local Config = require(script.Parent.Config)
local WorldGen = require(script.Parent.WorldGen)

local Save = {}

Save.VERSION = 2        -- the shape of the world key; bump it with a step in Save.migrate
Save.PLAYER_VERSION = 1
Save.MET_CAP = 128        -- remembered faces per player (ids are small numbers: ~0.5 KB at the cap)
Save.PRUNE_DAYS = 8 * Config.WEEK_DAYS -- the dead keep their full record this long, then only a gravestone

local function pick(src, fields: { string })
	local out = {}
	for _, k in ipairs(fields) do out[k] = src[k] end
	return out
end

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end

local function pos(p) return if p then { x = p.x, y = p.y } else nil end

-- ---------- the saved fields, node by node ----------
local META = { "gameSeconds", "lastDailyTick", "nextBagId", "worldId" }
local CALAMITY = { "kind", "active", "day", "warnedDay" }
local REGION = { "grass", "deer", "boar", "wolf" }
local TRIBE = { "tribeType", "villageId", "population", "walled", "news" }
local GROUP = { "id", "kind", "tribe", "pos", "dir", "acc", "speed", "fullSize", "pauseUntil", "replenishAt", "retreatUntil" }
local PERSON = { "id", "first", "last", "sex", "tribe", "village", "role", "stage", "born", "alive", "died", "cause", "killer",
	"father", "mother", "spouse", "widowed", "due", "grown", "group" }
local GRAVE = { "id", "first", "last", "sex", "tribe", "born", "died", "cause", "killer", "father", "mother" }
local CAMP = { "owner", "x", "y", "litUntil", "out" }
local BAG = { "id", "x", "y", "owner", "droppedAt", "public" }
local PLAYER = { "x", "y", "hp", "goalStage", "goalDone", "metSurvivor" }

local function sortedBy(rows, key: string)
	table.sort(rows, function(a, b) return a[key] < b[key] end)
	return rows
end

-- ---------- pruning ----------
--- Is this person a gravestone yet? Dead for longer than PRUNE_DAYS: they keep a name, dates, a cause and their
--- parents (the family tree still resolves through them), and lose everything else. Never deleted - the living
--- point at them. This is what keeps `people` inside the 4 MB key (ARCHITECTURE §5).
function Save.isGrave(p, day: number): boolean
	return (not p.alive) and p.died ~= nil and day - p.died > Save.PRUNE_DAYS
end

-- ---------- encode ----------
--- The World Record as a JSON-safe table. `w` is Sim.state (or a record shaped like it); `stamp` carries what the
--- record itself does not hold: { seed, rngState, savedAt }.
function Save.encode(w, stamp: { seed: number, rngState: number, savedAt: number })
	local day = w.day
	local out = {
		meta = pick(w.meta, META),
		calamity = pick(w.calamity, CALAMITY),
		regions = {}, tribes = {}, groups = {}, camps = {}, bags = {},
		people = { nextId = w.people.nextId, rows = {} },
	}
	out.meta.version, out.meta.genVersion = Save.VERSION, WorldGen.GEN_VERSION
	out.meta.seed, out.meta.rngState, out.meta.savedAt = stamp.seed, stamp.rngState, stamp.savedAt
	out.meta.headlines = copy(w.meta.headlines or {})
	for i, r in ipairs(w.regions.list) do out.regions[i] = pick(r, REGION) end
	for i, t in ipairs(w.tribes) do
		local row = pick(t, TRIBE)
		row.stock, row.surnames, row.plots = copy(t.stock), copy(t.surnames), copy(t.plots) -- plots: growth only; where they are is the map's
		out.tribes[i] = row
	end
	for _, g in pairs(w.groups) do
		local row = pick(g, GROUP)
		row.from, row.to, row.lateTarget = pos(g.from), pos(g.to), pos(g.lateTarget)
		row.pauses, row.carry, row.members = copy(g.pauses), copy(g.carry), {}
		for i, m in ipairs(g.members) do row.members[i] = { kind = m.kind, role = m.role, person = m.person } end
		table.insert(out.groups, row)
	end
	sortedBy(out.groups, "id")
	for _, p in pairs(w.people.people) do
		table.insert(out.people.rows, if Save.isGrave(p, day) then pick(p, GRAVE) else pick(p, PERSON))
	end
	sortedBy(out.people.rows, "id")
	for _, c in pairs(w.camps) do table.insert(out.camps, pick(c, CAMP)) end
	sortedBy(out.camps, "owner")
	for _, b in pairs(w.bags) do
		local row = pick(b, BAG)
		row.slots = copy(b.slots)
		table.insert(out.bags, row)
	end
	sortedBy(out.bags, "id")
	return out
end

-- ---------- decode ----------
--- Bring older saves up to VERSION, one step per version. Returns data, or nil, why, obsolete.
--- v1 -> v2 (2026-09-21): group members became people in the registry (`members[].person`, `Person.group`). There is
--- deliberately NO upgrade step: Danzo chose to start the world again rather than invent people for the old groups,
--- so a v1 world is OBSOLETE - a new one is started over it, like a save from another map generator. Players keep
--- their own keys. The next format change should upgrade in place: `if v == 2 then ... v = 3 end`.
function Save.migrate(data)
	local v = data.meta and data.meta.version
	if type(v) ~= "number" or v > Save.VERSION then return nil, "unknown save version " .. tostring(v), false end
	if v < 2 then return nil, "the save is from before groups had named members (v1): this is a new world", true end
	return data
end

--- A saved table back into a record with in-memory indexes: people by numeric id, camps by owner, groups and bags
--- by id. Regions come back as bare rows of counts - the derived half (forest, col, row, village) is the map's, so
--- the caller lays these over a fresh Ecology.init. Returns nil, reason if the save cannot be used; a save made by
--- a different WorldGen is one of those, because its seed no longer grows the map its records were made on.
function Save.decode(data)
	local ok, why, old = Save.migrate(data)
	if not ok then return nil, why, old end
	if data.meta.genVersion ~= WorldGen.GEN_VERSION then
		-- the third value says the save is OBSOLETE, not damaged: the caller may start a new world over it
		return nil, ("the map generator changed (save %s, now %s): this is a new world"):format(tostring(data.meta.genVersion), tostring(WorldGen.GEN_VERSION)), true
	end
	local w = {
		meta = copy(data.meta), calamity = copy(data.calamity), regions = copy(data.regions), tribes = copy(data.tribes),
		groups = {}, camps = {}, bags = {}, people = { nextId = data.people.nextId, people = {} },
	}
	w.calamity.flood = nil
	for _, row in ipairs(data.groups) do
		local g = copy(row)
		g.carry, g.members = g.carry or {}, g.members or {} -- an empty table has no JSON shape of its own
		w.groups[g.id] = g
	end
	for _, row in ipairs(data.people.rows) do
		local p = copy(row)
		p.children = {}
		if p.alive == nil then -- a gravestone
			p.alive, p.role, p.stage, p.village = false, "dead", "adult", 0
		end
		w.people.people[p.id] = p
	end
	-- children[] is derived from father/mother, so it is rebuilt, not saved: in id order, as Families.add grew it
	for _, row in ipairs(data.people.rows) do
		local p = w.people.people[row.id]
		for _, parent in ipairs({ p.father, p.mother }) do
			if w.people.people[parent] then table.insert(w.people.people[parent].children, p.id) end
		end
	end
	for _, row in ipairs(data.camps) do w.camps[row.owner] = copy(row) end
	for _, row in ipairs(data.bags) do
		local b = copy(row)
		b.slots = b.slots or {}
		w.bags[b.id] = b
	end
	return w
end

-- ---------- players (their own key each) ----------
--- `worldId` is the world's own id (meta.worldId): the faces a player has met are people OF that world.
function Save.encodePlayer(ps, day: number, worldId: string?)
	local out = pick(ps, PLAYER)
	out.version, out.lastSeenDay = Save.PLAYER_VERSION, day
	out.inv = { coin = ps.inv.coin, slots = copy(ps.inv.slots) }
	out.rep, out.rest = copy(ps.rep), copy(ps.rest)
	-- the people this player has met (they see names, not trades): ids, newest kept if the list ever gets long
	out.met, out.metWorld = {}, worldId
	for id in pairs(ps.met or {}) do table.insert(out.met, id) end
	table.sort(out.met)
	while #out.met > Save.MET_CAP do table.remove(out.met, 1) end
	return out
end

--- Lay a saved player over a freshly made live one. Position is the caller's business (the tile may be a wall, a
--- flood or a campfire by now), so x and y are returned, not applied.
function Save.applyPlayer(ps, data, worldId: string?): (number?, number?)
	if type(data) ~= "table" or data.version ~= Save.PLAYER_VERSION then return nil, nil end
	for _, k in ipairs(PLAYER) do
		if k ~= "x" and k ~= "y" and data[k] ~= nil then ps[k] = data[k] end
	end
	ps.inv = { coin = data.inv.coin, slots = copy(data.inv.slots or {}) }
	for tribe, v in pairs(data.rep) do ps.rep[tribe] = v end
	ps.rest = copy(data.rest)
	-- Person ids mean nothing in another world: after a reset, id 2 is somebody else, and a stranger would be named.
	ps.met = {}
	if worldId ~= nil and data.metWorld == worldId then
		for _, id in ipairs(data.met or {}) do ps.met[id] = true end
	end
	return data.x, data.y
end

-- ---------- the lease ----------
-- One server owns the world key at a time (DESIGN §14 accepts that a second server diverges; it must not also
-- overwrite). The save carries `lease = { owner, untilTime }`; the owner renews it with every save and drops it on
-- shutdown. These are the two decisions, pure so they are tested: may I write, and what do I stamp.
Save.LEASE_SECONDS = 3 * Config.AUTOSAVE_SECONDS

--- May `owner` write over `existing` (the table in the store now, or nil) at wall time `now`?
function Save.mayWrite(existing, owner: string, now: number): boolean
	local lease = type(existing) == "table" and existing.lease
	if type(lease) ~= "table" then return true end
	return lease.owner == owner or (lease.untilTime or 0) <= now
end

function Save.stampLease(data, owner: string, now: number, release: boolean?)
	data.lease = { owner = owner, untilTime = if release then 0 else now + Save.LEASE_SECONDS }
	return data
end

-- ---------- the shape check ----------
--- Is `t` something JSON gives back unchanged? Every table is a dense array OR has only string keys; every number
--- is finite; nothing is a function, userdata or thread; nothing is visited twice. Returns ok, "path: reason".
--- This is why a decode(encode()) test without a JSON library means something: under this shape JSON is the
--- identity, so whatever survives the pure round trip survives the real one.
function Save.check(t): (boolean, string?)
	local seen = {}
	local function walk(v, path: string): string?
		local ty = type(v)
		if ty == "number" then
			if v ~= v or v == math.huge or v == -math.huge then return path .. ": not a finite number" end
		elseif ty == "table" then
			if seen[v] then return path .. ": the same table appears twice (a cycle, or a shared reference)" end
			seen[v] = true
			local n, count = #v, 0
			for k in pairs(v) do
				count += 1
				if type(k) == "number" then
					if n == 0 or k < 1 or k > n or k % 1 ~= 0 then return ("%s: numeric key %s outside a dense array (JSON would make it a string)"):format(path, tostring(k)) end
				elseif type(k) ~= "string" then
					return path .. ": key of type " .. type(k)
				elseif n > 0 then
					return path .. ": mixes array items with the string key '" .. k .. "'"
				end
			end
			if n > 0 and count ~= n then return path .. ": array with holes" end
			for k, x in pairs(v) do
				local err = walk(x, path .. "." .. tostring(k))
				if err then return err end
			end
		elseif ty ~= "string" and ty ~= "boolean" and ty ~= "nil" then
			return path .. ": a " .. ty .. " cannot be saved"
		end
		return nil
	end
	local err = walk(t, "save")
	return err == nil, err
end

return Save
