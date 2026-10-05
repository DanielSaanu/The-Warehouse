--!nonstrict
-- Gossip: what a village or a band has HEARD about you, and the scar it leaves (docs/RUNG3.md part 3, DESIGN.md §7).
-- Pure Luau over the World Record, so `npm run test:luau` runs the whole rule. No entities, no Instances, no server.
--
-- The one decision to hold on to (handoff H1): memory is the TRANSPORT, reputation and grudge are the LEDGER.
-- Memory has to be capped, so a reputation recomputed from it would HEAL when the cap evicted - the opposite of §7's
-- "they remember everything at once". So `ps.rep` is still the stored number; what changed is its KEY. It used to be
-- the tribe type, which meant a squad on the road learning something moved its whole village's number too. It is now
-- the HOLDER: a village ("v1".."v3") or a group (its id). A holder is anything that can know a thing and can meet
-- another holder.
--
-- Owns: the rumour ring (`w.rumours`), `knows`/`hops` on every village and group row, `meta.nextRumourId`,
-- and `w.owed` (what absent players have coming). Grudge, the scar, is shared/Grudge.lua.
-- Does NOT own: what a number MEANS (Reputation's rule), who witnessed what (server/Sides.lua), or when contact
-- happens (Tick calls in, on a schedule derived from gameSeconds alone, so catch-up and live play agree exactly).
--   Gossip.seed(w, uid, "kill", "hunter", 2, ctx, day, { v2 = true, squad = true })
--   Gossip.arrive(w, g)                      -- a group reached an end of its route: it and that village swap
--   Gossip.meet(w, now)                      -- the EVERY schedule: groups sharing a stretch of road swap
local Config = require(script.Parent.Config)
local Reputation = require(script.Parent.Reputation)
local Grudge = require(script.Parent.Grudge)

local Gossip = {}

Gossip.MAX_RUMOURS = 64   -- the same ring size as Headlines.MAX: one number to remember. ~117 B each.
Gossip.HOP_FADE = 0.75    -- each exchange weakens the story. §7 says hops, not age.
Gossip.STALE_DAYS = 14    -- old news stops travelling: it leaves the ring at the daily tick
Gossip.EVERY = 60         -- game seconds between road-meeting sweeps (a tenth of an in-game day)
Gossip.OWED_MIN = 0.5     -- owed standing that has faded below this is forgotten (it bounds `w.owed`)

--- Set by server/Standing.bind, so the player is TOLD when news moves a holder's opinion of them - a rumour that
--- arrives silently is a feature nobody can see. nil here keeps this module pure: the tests never set it, and
--- catchUpPlayer applies with `silent`, because a returning player gets the welcome instead of forty lines. (Silence
--- is a parameter, not a module flag: a flag set by hand stays stuck on if anything between set and reset errors.)
Gossip.onChange = nil :: ((any, string, number, number) -> ())?

--- Events that become a story somebody carries home. Everything else - a slap, a trade, a night's rest - is instant
--- and local: a -1 slap is not news, and one long fight's blows would fill the ring on their own.
Gossip.TRAVELS = { kill = true, mercy = true, escape = true, gift = true, rode = true } :: { [string]: boolean }

-- ---------- holders ----------
function Gossip.villageKey(tribeIdx: number): string
	return "v" .. tostring(tribeIdx)
end

--- The tribe index a VILLAGE key names, or nil for a group key: the one place a key is parsed. Group ids are words.
function Gossip.villageIndex(holderKey: string): number?
	local vi = string.match(holderKey, "^v(%d+)$")
	return if vi then tonumber(vi) else nil
end

--- The holder whose opinion an entity carries: its group if it is on the road with one, else its village.
function Gossip.holderOf(e): string?
	if e.group then return tostring(e.group) end
	if e.tribe then return Gossip.villageKey(e.tribe) end
	return nil
end

--- Which tribe index a holder belongs to, so its tribe type can be read. nil if the holder is gone.
function Gossip.tribeOf(w, holderKey: string): number?
	local vi = Gossip.villageIndex(holderKey)
	if vi then return vi end
	local g = w.groups[holderKey]
	return if g then g.tribe else nil
end

local function tribeTypeOf(w, holderKey: string): string?
	local i = Gossip.tribeOf(w, holderKey)
	local t = i and w.tribes[i]
	return if t then t.tribeType else nil
end

--- A holder's row with its memory ready: `knows[i]` is a rumour id, `hops[i]` how many hands it came through to reach
--- THIS holder (per holder, never on the shared row: see docs/RUNG3.md part 3, "How it spreads"). Pads with 0.
local function ready(row)
	row.knows = row.knows or {}
	row.hops = row.hops or {}
	for i = #row.hops + 1, #row.knows do row.hops[i] = 0 end
	return row
end

--- Every holder in the world, as { key, knows, hops }. Villages first, then groups in id order, so a compaction
--- sweep and a debug dump are both deterministic.
function Gossip.holders(w)
	local out = {}
	for i in ipairs(w.tribes) do
		local v = w.villages and w.villages[i]
		if v then
			ready(v)
			table.insert(out, { key = Gossip.villageKey(i), knows = v.knows, hops = v.hops })
		end
	end
	local ids = {}
	for id in pairs(w.groups) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
	for _, id in ipairs(ids) do
		local g = ready(w.groups[id])
		table.insert(out, { key = tostring(id), knows = g.knows, hops = g.hops })
	end
	return out
end

local function rowOf(w, holderKey: string)
	local vi = Gossip.villageIndex(holderKey)
	if vi then
		local v = w.villages and w.villages[vi]
		return if v then ready(v) else nil
	end
	local g = w.groups[holderKey]
	return if g then ready(g) else nil
end

-- ---------- standing: the read path every hot caller uses ----------
--- What `holderKey` thinks of this player. Falls back holder -> that holder's village -> the tribe type's START, so
--- `ps.rep` only ever holds a key whose opinion has actually DIVERGED: a player who has only traded has three keys,
--- not forty-three. One table lookup on the hot path; no scan, no derivation, no cache.
function Gossip.standing(w, ps, holderKey: string?): number
	if not holderKey then return 0 end
	local v = ps.rep[holderKey]
	if v ~= nil then return v end
	local i = Gossip.tribeOf(w, holderKey)
	if i then
		local vk = Gossip.villageKey(i)
		if ps.rep[vk] ~= nil then return ps.rep[vk] end
		local t = w.tribes[i]
		if t then return Reputation.START[t.tribeType] or 0 end
	end
	return 0
end

--- What a tribe thinks of this player: its village's number. (Rung 4 gives a tribe several villages; then this is a
--- choice of key inside here, and nothing else in the game changes.)
function Gossip.tribeStanding(w, ps, tribeIdx: number): number
	return Gossip.standing(w, ps, Gossip.villageKey(tribeIdx))
end

-- ---------- grudge: the scar (shared/Grudge.lua; re-exported under the names every caller already uses) ----------
Gossip.grudge, Gossip.grudgeGain, Gossip.multiplier = Grudge.grudge, Grudge.gain, Grudge.multiplier
Gossip.amend, Gossip.fadeGrudge = Grudge.amend, Grudge.fade

-- ---------- the ring ----------
local function compact(w, goneId: number)
	for _, h in ipairs(Gossip.holders(w)) do
		for i = #h.knows, 1, -1 do
			if h.knows[i] == goneId then
				table.remove(h.knows, i)
				table.remove(h.hops, i)
			end
		end
	end
end

--- Add a rumour, evicting the oldest and scrubbing its id out of every holder in the same call - so no dangling id
--- can ever reach Save.check, and `knows` needs no cap of its own.
function Gossip.push(w, r)
	w.rumours = w.rumours or {}
	w.meta.nextRumourId = (w.meta.nextRumourId or 0) + 1
	r.id = w.meta.nextRumourId
	table.insert(w.rumours, r)
	while #w.rumours > Gossip.MAX_RUMOURS do
		local gone = table.remove(w.rumours, 1)
		compact(w, gone.id)
	end
	return r
end

function Gossip.find(w, id: number)
	for _, r in ipairs(w.rumours or {}) do
		if r.id == id then return r end
	end
	return nil
end

--- Old news stops travelling. Called from the daily tick. Leaving the ring costs nobody anything: a rumour was
--- applied (or owed, below) at every holder the moment that holder heard it, so this is only the end of the
--- TELLING. Owed standing that has faded to nothing is dropped here too, which is what bounds `w.owed`.
function Gossip.dropStale(w, day: number)
	local ring = w.rumours or {}
	for i = #ring, 1, -1 do
		if day - ring[i].day > Gossip.STALE_DAYS then
			local gone = table.remove(ring, i)
			compact(w, gone.id)
		end
	end
	for uid, o in pairs(w.owed or {}) do
		local f, left = 0.5 ^ (math.max(0, day - o.day) / Config.REP_FADE_DAYS), false
		for _, v in pairs(o.rep) do left = left or math.abs(v * f) >= Gossip.OWED_MIN end
		if not left then w.owed[uid] = nil end
	end
end

-- ---------- applying what a holder has heard ----------
local function playersOf(w)
	return w.players or {}
end

--- How far one rumour moves one holder's number, or nil if it does not. The deltas are RE-DERIVED from the event
--- here (R4): a saved rumour stores what happened, never its consequences, so it can never disagree with
--- Reputation's rule. `hops` is how many hands it came through to reach this holder: the far tribe gets a weaker,
--- vaguer version of the same story.
function Gossip.delta(w, holderKey: string, r, hops: number): number?
	local tribeType = tribeTypeOf(w, holderKey)
	if not tribeType then return nil end
	local victimTribe = r.tribe and w.tribes[r.tribe] and w.tribes[r.tribe].tribeType or nil
	local d = Reputation.deltas(r.event, r.victim, victimTribe, { aggressor = r.aggressor, fleeing = r.fleeing })[tribeType]
	if not d or d == 0 then return nil end
	if d < 0 then d *= (r.mult or 1) end -- the scar multiplies harm, never kindness
	return d * Gossip.HOP_FADE ^ hops
end

--- Move an online player's number at one holder.
local function move(w, ps, holderKey: string, d: number, silent: boolean?)
	local before = Gossip.standing(w, ps, holderKey)
	local after = Reputation.clamp(before + d)
	ps.rep[holderKey] = after
	if Gossip.onChange and not silent then Gossip.onChange(ps, holderKey, before, after) end
end

--- An ABSENT player's standing moves too, the moment the holder hears it - into `w.owed`, the world's ledger of what
--- they have coming. A ledger, so it cannot depend on the ring (S1): leaving the ring must not launder a killing.
--- Faded by Reputation's closed form (P2); fade is linear, so fading the running sum is fading each part.
local function owe(w, uid: number, holderKey: string, d: number)
	local day = w.day or 1
	w.owed = w.owed or {}
	local o = w.owed[uid]
	if not o then
		o = { day = day, rep = {} }
		w.owed[uid] = o
	elseif day > o.day then
		for k, v in pairs(o.rep) do o.rep[k] = Reputation.fade(v, day - o.day) end
		o.day = day
	end
	-- bounded by a rep's widest swing; online clamps per step against a number the world does not have (RUNG3)
	local span = Reputation.MAX - Reputation.MIN
	o.rep[holderKey] = math.clamp((o.rep[holderKey] or 0) + d, -span, span)
end

--- Book a rumour at a holder, `hops` hands from the eyewitnesses: the ONE place a holder's opinion moves. Appending to
--- `knows` IS applying it, so no rumour can ever be booked twice at the same holder - which is also why no
--- per-player "already heard" set is needed any more. Returns true if this was new here.
--- The player may be offline: then it goes to `w.owed`, and Gossip.catchUpPlayer pays it when they come back. That
--- is how the news reaches a village while you are away and is waiting for you when you walk in.
function Gossip.tell(w, holderKey: string, id: number, hops: number?): boolean
	local row = rowOf(w, holderKey)
	if not row then return false end
	for _, k in ipairs(row.knows) do
		if k == id then return false end
	end
	local r = Gossip.find(w, id)
	if not r then return false end
	local h = hops or 0
	table.insert(row.knows, id)
	table.insert(row.hops, h)
	local d = Gossip.delta(w, holderKey, r, h)
	if not d then return true end
	local ps = playersOf(w)[r.about]
	if ps then move(w, ps, holderKey, d) else owe(w, r.about, holderKey, d) end
	return true
end

--- A thing just happened in front of these holders. Seeds the rumour at every one of them (hops 0: the full strength
--- of having seen it yourself) and scars the victim's people. NO HOLDERS MEANS NOBODY SAW IT: no rumour, and no
--- reputation change anywhere in the world. That is §7's "you can outrun your reputation", and it is deliberate.
--- Only a story that would MOVE somebody's number is news: a deer has no tribe, and an escape from hunters means
--- nothing to anyone, so neither takes a slot in the ring (QA round 1: a hunting trip evicted real news, and the
--- villagers then said "They say you killed someone." about a deer).
function Gossip.seed(w, uid: number, event: string, victimKind: string?, tribeIdx: number?, ctx, day: number, holderKeys)
	if not Gossip.TRAVELS[event] then return nil end
	local tribeType = tribeIdx and w.tribes[tribeIdx] and w.tribes[tribeIdx].tribeType or nil
	if not tribeType then return nil end
	local c = ctx or {}
	local moves = false
	for _, d in pairs(Reputation.deltas(event, victimKind, tribeType, { aggressor = c.aggressor, fleeing = c.fleeing })) do
		if d ~= 0 then moves = true end
	end
	if not moves then return nil end
	local keys = {}
	for k in pairs(holderKeys or {}) do table.insert(keys, k) end
	if #keys == 0 then return nil end
	table.sort(keys)
	local ps = playersOf(w)[uid]
	local r = Gossip.push(w, {
		about = uid, event = event, victim = victimKind, tribe = tribeIdx, day = day,
		mult = if ps then Gossip.multiplier(ps, tribeType, c.withGroup) else 1,
		aggressor = c.aggressor or nil, fleeing = c.fleeing or nil,
	})
	for _, k in ipairs(keys) do Gossip.tell(w, k, r.id) end
	if ps then
		local gain = Grudge.gain(event, victimKind, c) * (if c.withGroup then Grudge.GROUP else 1)
		if gain > 0 then Grudge.set(ps, tribeType, Grudge.grudge(ps, tribeType) + gain) end
	end
	return r
end

-- ---------- how it spreads ----------
--- Two holders swap every rumour the other has and they do not, each one hand further from the eyewitnesses.
function Gossip.exchange(w, a: string, b: string): number
	local ra, rb = rowOf(w, a), rowOf(w, b)
	if not ra or not rb or a == b then return 0 end
	local moved = 0
	for _, side in ipairs({ { ra, b }, { rb, a } }) do
		local ids, hops = table.clone(side[1].knows), table.clone(side[1].hops)
		for i, id in ipairs(ids) do
			if Gossip.tell(w, side[2], id, (hops[i] or 0) + 1) then moved += 1 end
		end
	end
	return moved
end

--- The tribe whose village covers this map tile, or nil (forest, road, an ambush spot). `world` is WorldGen's map.
function Gossip.villageAt(w, world, x: number, y: number): number?
	for i, t in ipairs(w.tribes) do
		local v = world and world.villages[t.villageId]
		if v and x >= v.x0 and x <= v.x1 and y >= v.y0 and y <= v.y1 then return i end
	end
	return nil
end

--- A group reached an end of its route (Tick.groupTurn, before it flips `dir`): it and the village AT THAT END swap
--- everything - `to` walking out, `from` walking home, nobody if that end is the forest or an ambush spot. Never
--- simply its own village, which may be a whole route away. The caravan arrives; the squad comes back.
function Gossip.arrive(w, g, world, standing): number
	local at = if g.dir == -1 then g.from else g.to
	local i = at and Gossip.villageAt(w, world, at.x, at.y)
	if not i then return 0 end
	-- a materialised leader (`standing`, from Bands.turn) must really be in that village (QA round 3, H6)
	if standing and Gossip.villageAt(w, world, standing.x, standing.y) ~= i then return 0 end
	return Gossip.exchange(w, tostring(g.id), Gossip.villageKey(i))
end

--- The tile a group stands on; nil with no route yet, or MATERIALISED (bodies are walking, so `pos` is stale).
local function tileOf(g)
	if g.materialised or not g.route then return nil end
	return g.route[g.pos or 1]
end

--- Groups that share a stretch of road swap news. Bucketed by MAP TILE (2x2 cells), never by `pos` (an index into
--- each group's OWN route), so it is O(groups), not O(groups^2). Fires only when the schedule derived from `now`
--- ticks over, so n live seconds and catchUp(n) produce the identical exchanges.
function Gossip.meet(w, now: number): number
	local slot = math.floor(now / Gossip.EVERY)
	if slot <= (w.meta.lastContactSlot or -1) then return 0 end
	w.meta.lastContactSlot = slot
	local ids, buckets = {}, {}
	for id in pairs(w.groups) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
	for _, id in ipairs(ids) do
		local at = tileOf(w.groups[id])
		if at then
			local b = ("%d,%d"):format(math.floor(at.x / 2), math.floor(at.y / 2))
			buckets[b] = buckets[b] or {}
			table.insert(buckets[b], tostring(id))
		end
	end
	local order = {}
	for b in pairs(buckets) do table.insert(order, b) end
	table.sort(order)
	local moved = 0
	for _, b in ipairs(order) do
		local list = buckets[b]
		for i = 1, #list - 1 do
			for j = i + 1, #list do moved += Gossip.exchange(w, list[i], list[j]) end
		end
	end
	return moved
end

-- ---------- a player who was away ----------
--- Pay everything the world learned about this player while they were offline: `w.owed`, faded for the days it
--- waited, landed silently - Headlines.welcome is what tells them what happened while they were gone. Called once by
--- Restore.player, after the away-fade and before the player is in `w.players`.
function Gossip.catchUpPlayer(w, ps, uid: number)
	local o = w.owed and w.owed[uid]
	if not o then return end
	w.owed[uid] = nil
	local wait = math.max(0, (w.day or o.day) - o.day)
	local keys = {}
	for k in pairs(o.rep) do table.insert(keys, k) end
	table.sort(keys)
	for _, k in ipairs(keys) do move(w, ps, k, Reputation.fade(o.rep[k], wait), true) end
end

--- The newest thing this holder has heard about the player, and how many hands it came through to reach them, for
--- Talk.Context.heard. nil if they know nothing.
function Gossip.latest(w, holderKey: string, uid: number)
	local row = rowOf(w, holderKey)
	if not row then return nil, nil end
	local best, bestHops = nil, nil
	for i, id in ipairs(row.knows) do
		local r = Gossip.find(w, id)
		if r and r.about == uid and (not best or r.day >= best.day) then best, bestHops = r, row.hops[i] end
	end
	return best, bestHops
end

return Gossip
