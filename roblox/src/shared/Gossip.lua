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
-- Owns: the rumour ring (`w.rumours`), `knows` on every village and group row, `meta.nextRumourId`, and grudge.
-- Does NOT own: what a number MEANS (Reputation's rule), who witnessed what (server/Sides.lua), or when contact
-- happens (Tick calls in, on a schedule derived from gameSeconds alone, so catch-up and live play agree exactly).
--   Gossip.seed(w, uid, "kill", "hunter", 2, ctx, day, { v2 = true, squad = true })
--   Gossip.arrive(w, g)                      -- a group reached an end of its route: it and that village swap
--   Gossip.meet(w, now)                      -- the EVERY schedule: groups sharing a stretch of road swap
local Config = require(script.Parent.Config)
local Reputation = require(script.Parent.Reputation)

local Gossip = {}

Gossip.MAX_RUMOURS = 64   -- the same ring size as Headlines.MAX: one number to remember. ~117 B each.
Gossip.HOP_FADE = 0.75    -- each exchange weakens the story. §7 says hops, not age.
Gossip.STALE_DAYS = 14    -- old news stops travelling: it leaves the ring at the daily tick
Gossip.EVERY = 60         -- game seconds between road-meeting sweeps (a tenth of an in-game day)
Gossip.GRUDGE_MAX = 3
Gossip.GRUDGE_GROUP = 0.25 -- the share of a grudge that lands on you for harm done while riding along (part 4)
Gossip.AMEND_GIFT = 0.1

--- Set by server/Standing.bind, so the player is TOLD when news moves a holder's opinion of them - a rumour that
--- arrives silently is a feature nobody can see. nil here keeps this module pure: the tests never set it, and
--- catch-up runs with `Gossip.quiet` on, because a returning player gets the welcome instead of forty lines.
Gossip.onChange = nil :: ((any, string, number, number) -> ())?
Gossip.quiet = false

--- Events that become a story somebody carries home. Everything else - a slap, a trade, a night's rest - is instant
--- and local: a -1 slap is not news, and one long fight's blows would fill the ring on their own.
Gossip.TRAVELS = { kill = true, mercy = true, escape = true, gift = true } :: { [string]: boolean }

-- ---------- holders ----------
function Gossip.villageKey(tribeIdx: number): string
	return "v" .. tostring(tribeIdx)
end

--- The holder whose opinion an entity carries: its group if it is on the road with one, else its village.
function Gossip.holderOf(e): string?
	if e.group then return tostring(e.group) end
	if e.tribe then return Gossip.villageKey(e.tribe) end
	return nil
end

--- Which tribe index a holder belongs to, so its tribe type can be read. nil if the holder is gone.
function Gossip.tribeOf(w, holderKey: string): number?
	local vi = string.match(holderKey, "^v(%d+)$")
	if vi then return tonumber(vi) end
	local g = w.groups[holderKey]
	return if g then g.tribe else nil
end

local function tribeTypeOf(w, holderKey: string): string?
	local i = Gossip.tribeOf(w, holderKey)
	local t = i and w.tribes[i]
	return if t then t.tribeType else nil
end

--- Every holder in the world, as { key, knows }. Villages first, then groups in id order, so a compaction sweep and
--- a debug dump are both deterministic.
function Gossip.holders(w)
	local out = {}
	for i in ipairs(w.tribes) do
		local v = w.villages and w.villages[i]
		if v then
			v.knows = v.knows or {}
			table.insert(out, { key = Gossip.villageKey(i), knows = v.knows })
		end
	end
	local ids = {}
	for id in pairs(w.groups) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
	for _, id in ipairs(ids) do
		local g = w.groups[id]
		g.knows = g.knows or {}
		table.insert(out, { key = tostring(id), knows = g.knows })
	end
	return out
end

local function knowsOf(w, holderKey: string)
	local vi = string.match(holderKey, "^v(%d+)$")
	if vi then
		local v = w.villages and w.villages[tonumber(vi)]
		if not v then return nil end
		v.knows = v.knows or {}
		return v.knows
	end
	local g = w.groups[holderKey]
	if not g then return nil end
	g.knows = g.knows or {}
	return g.knows
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

-- ---------- grudge: the scar ----------
--- Grudge is keyed by TRIBE TYPE, not by holder: a scar is what a people carry, and keying it per holder would let
--- it dilute away by eviction. 0 .. GRUDGE_MAX.
function Gossip.grudge(ps, tribeType: string?): number
	if not tribeType then return 0 end
	return (ps.grudge and ps.grudge[tribeType]) or 0
end

local function setGrudge(ps, tribeType: string, v: number)
	ps.grudge = ps.grudge or {}
	ps.grudge[tribeType] = math.clamp(v, 0, Gossip.GRUDGE_MAX)
end

--- What this act adds to the scar. Only serious harm scars; a slap and a hard bargain do not.
function Gossip.grudgeGain(event: string, victimKind: string?, ctx): number
	if event ~= "kill" then return 0 end
	local c = ctx or {}
	if victimKind == "bandit" then return 0.2 end
	if c.fleeing then return 0.5 end -- murder of a runner is the worst of it
	return 0.3
end

--- Harm multiplies by the scar the people already carried. Frozen into the rumour at creation, so what you did is
--- judged by the grudge you had when you did it, not the one you have when the news lands three days later.
function Gossip.multiplier(ps, tribeType: string?, withGroup: boolean?): number
	local g = Gossip.grudge(ps, tribeType)
	if withGroup then g *= Gossip.GRUDGE_GROUP end -- harm done riding with a band spreads thin (§7); part 4 sets this
	return 1 + g
end

--- Amends: a gift chips at the scar. Time alone barely helps, which is what the long fade below is for.
function Gossip.amend(ps, tribeType: string?)
	if not tribeType then return end
	local g = Gossip.grudge(ps, tribeType)
	if g > 0 then setGrudge(ps, tribeType, g - Gossip.AMEND_GIFT) end
end

--- Halve over GRUDGE_FADE_DAYS in-game days. A closed form over a day count, never a per-tick decrement: that is
--- what lets a decay measured in YEARS survive a world that slept past the four-week catch-up cap.
function Gossip.fadeGrudge(ps, days: number)
	if not ps.grudge or days <= 0 then return end
	for tribeType, v in pairs(ps.grudge) do
		local n = v * 0.5 ^ (days / Config.GRUDGE_FADE_DAYS)
		ps.grudge[tribeType] = if n < 0.01 then nil else n
	end
end

-- ---------- the ring ----------
local function compact(w, goneId: number)
	for _, h in ipairs(Gossip.holders(w)) do
		for i = #h.knows, 1, -1 do
			if h.knows[i] == goneId then table.remove(h.knows, i) end
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

--- Old news stops travelling. Called from the daily tick.
function Gossip.dropStale(w, day: number)
	local ring = w.rumours or {}
	for i = #ring, 1, -1 do
		if day - ring[i].day > Gossip.STALE_DAYS then
			local gone = table.remove(ring, i)
			compact(w, gone.id)
		end
	end
end

-- ---------- applying what a holder has heard ----------
local function playersOf(w)
	return w.players or {}
end

--- Move one holder's number by one rumour. `strength` falls with hops, so the far tribe gets a weaker, vaguer
--- version of the same story. The deltas are RE-DERIVED from the event here (R4): a saved rumour stores what
--- happened, never its consequences, so it can never disagree with Reputation's rule.
function Gossip.apply(w, ps, holderKey: string, r)
	local tribeType = tribeTypeOf(w, holderKey)
	if not tribeType then return end
	local victimTribe = r.tribe and w.tribes[r.tribe] and w.tribes[r.tribe].tribeType or nil
	local deltas = Reputation.deltas(r.event, r.victim, victimTribe, { aggressor = r.aggressor, fleeing = r.fleeing })
	local d = deltas[tribeType]
	-- Marked PER HOLDER, not per player: one rumour known in two villages has to move two numbers, and the offline
	-- replay below has no other way to tell which of those it has already done.
	ps.heard = ps.heard or {}
	ps.heard[holderKey] = ps.heard[holderKey] or {}
	ps.heard[holderKey][r.id] = true
	if not d or d == 0 then return end
	if d < 0 then d *= (r.mult or 1) end -- the scar multiplies harm, never kindness
	local before = Gossip.standing(w, ps, holderKey)
	local after = Reputation.clamp(before + d * Gossip.HOP_FADE ^ (r.hops or 0))
	ps.rep[holderKey] = after
	if Gossip.onChange and not Gossip.quiet then Gossip.onChange(ps, holderKey, before, after) end
end

--- Book a rumour at a holder: the ONE place a holder's opinion moves. Appending to `knows` IS applying it, so no
--- rumour can ever be booked twice at the same holder. Returns true if this was new here.
--- The player may be offline - then only `knows` moves, and Gossip.catchUpPlayer applies it when they come back.
--- That is how the news reaches a village while you are away and is waiting for you when you walk in.
function Gossip.tell(w, holderKey: string, id: number): boolean
	local knows = knowsOf(w, holderKey)
	if not knows then return false end
	for _, k in ipairs(knows) do
		if k == id then return false end
	end
	local r = Gossip.find(w, id)
	if not r then return false end
	table.insert(knows, id)
	local ps = playersOf(w)[r.about]
	if ps then Gossip.apply(w, ps, holderKey, r) end
	return true
end

--- A thing just happened in front of these holders. Seeds the rumour at every one of them (hops 0: the full strength
--- of having seen it yourself) and scars the victim's people. NO HOLDERS MEANS NOBODY SAW IT: no rumour, and no
--- reputation change anywhere in the world. That is §7's "you can outrun your reputation", and it is deliberate.
function Gossip.seed(w, uid: number, event: string, victimKind: string?, tribeIdx: number?, ctx, day: number, holderKeys)
	if not Gossip.TRAVELS[event] then return nil end
	local keys = {}
	for k in pairs(holderKeys or {}) do table.insert(keys, k) end
	if #keys == 0 then return nil end
	table.sort(keys)
	local ps = playersOf(w)[uid]
	local tribeType = tribeIdx and w.tribes[tribeIdx] and w.tribes[tribeIdx].tribeType or nil
	local c = ctx or {}
	local r = Gossip.push(w, {
		about = uid, event = event, victim = victimKind, tribe = tribeIdx, day = day, hops = 0,
		mult = if ps then Gossip.multiplier(ps, tribeType, c.withGroup) else 1,
		aggressor = c.aggressor or nil, fleeing = c.fleeing or nil,
	})
	for _, k in ipairs(keys) do Gossip.tell(w, k, r.id) end
	if ps and tribeType then
		local gain = Gossip.grudgeGain(event, victimKind, c) * (if c.withGroup then Gossip.GRUDGE_GROUP else 1)
		if gain > 0 then setGrudge(ps, tribeType, Gossip.grudge(ps, tribeType) + gain) end
	end
	return r
end

-- ---------- how it spreads ----------
--- Two holders swap every rumour the other has and they do not. `hops` lives on the shared row and counts
--- exchanges, so it rises once per hand-off however many holders were standing on each side.
function Gossip.exchange(w, a: string, b: string): number
	local ka, kb = knowsOf(w, a), knowsOf(w, b)
	if not ka or not kb or a == b then return 0 end
	local moved = 0
	for _, side in ipairs({ { ka, b }, { kb, a } }) do
		for _, id in ipairs(table.clone(side[1])) do
			local r = Gossip.find(w, id)
			if r then
				local before = r.hops or 0
				r.hops = before + 1
				if Gossip.tell(w, side[2], id) then moved += 1 else r.hops = before end
			end
		end
	end
	return moved
end

--- A group reached an end of its route: it and the village at that end tell each other everything. This is the main
--- channel and it costs nothing to find - Tick.groupTurn already fires exactly here. "A lone bandit tells his band
--- when he gets home"; the caravan arrives; the squad comes back.
function Gossip.arrive(w, g): number
	if not g.tribe then return 0 end
	return Gossip.exchange(w, tostring(g.id), Gossip.villageKey(g.tribe))
end

--- Groups that share a stretch of road swap news. Bucketed by route position so it is O(groups), not O(groups^2):
--- a pairwise sweep at 1 Hz would be 13 million comparisons over a full catch-up. Fires only when the schedule
--- derived from `now` ticks over, so n live seconds and catchUp(n) produce the identical sequence of exchanges.
function Gossip.meet(w, now: number): number
	local slot = math.floor(now / Gossip.EVERY)
	if slot <= (w.meta.lastContactSlot or -1) then return 0 end
	w.meta.lastContactSlot = slot
	local ids, buckets = {}, {}
	for id in pairs(w.groups) do table.insert(ids, id) end
	table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
	for _, id in ipairs(ids) do
		local b = tostring(math.floor((w.groups[id].pos or 1) / 2))
		buckets[b] = buckets[b] or {}
		table.insert(buckets[b], tostring(id))
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
--- Everything the world learned about this player while they were offline, applied from `knows` (the durable side),
--- skipping anything already in their own `heard` set. Called once by Restore.player, after the away-fade.
function Gossip.catchUpPlayer(w, ps, uid: number)
	ps.heard = ps.heard or {}
	local ring = {}
	for _, r in ipairs(w.rumours or {}) do ring[r.id] = true end
	-- a rumour that left the ring is forgotten having been heard, so the set stays bounded by the ring
	for holderKey, ids in pairs(ps.heard) do
		for id in pairs(ids) do
			if not ring[id] then ids[id] = nil end
		end
		if next(ids) == nil then ps.heard[holderKey] = nil end
	end
	-- quietly: they have been away, and Headlines.welcome is what tells them what happened while they were gone
	local was = Gossip.quiet
	Gossip.quiet = true
	for _, h in ipairs(Gossip.holders(w)) do
		local done = ps.heard[h.key]
		for _, id in ipairs(h.knows) do
			local r = Gossip.find(w, id)
			if r and r.about == uid and not (done and done[id]) then Gossip.apply(w, ps, h.key, r) end
		end
	end
	Gossip.quiet = was
end

--- The newest thing this holder has heard about the player, for Talk.Context.heard. nil if they know nothing.
function Gossip.latest(w, holderKey: string, uid: number)
	local knows = knowsOf(w, holderKey)
	if not knows then return nil end
	local best = nil
	for _, id in ipairs(knows) do
		local r = Gossip.find(w, id)
		if r and r.about == uid and (not best or r.day >= best.day) then best = r end
	end
	return best
end

return Gossip
