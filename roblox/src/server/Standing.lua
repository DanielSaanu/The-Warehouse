--!nonstrict
-- Where a player stands with everyone, on the server (docs/RUNG3.md part 3; ARCHITECTURE R2 names `Standing` as the
-- owner of exactly this: memory on villages and groups, player rep, grudges). The RULE is pure and lives in
-- shared/Gossip.lua; this turns the simulation's entities and tribe indexes into that rule's holder keys, and says
-- the one line the player needs to understand what just changed.
--
-- Three calls replace every `ps.rep[t.tribeType]` in the server:
--   Standing.at(ps, holderKey)     -- where an ENTITY has the opinion (its group on the road, else its village)
--   Standing.tribe(ps, tribeIdx)   -- the tribe's seat, i.e. its village
--   Standing.event(ps, ...)        -- every write, local or travelling
--
-- It deliberately does not `require` Sim: Sim binds it, like Sides / Debug / Restore. `applyRep` MOVED here out of
-- Sim.lua, which was three lines under its allow-list ratchet - moving it bought headroom instead of spending it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Reputation = require(Shared:WaitForChild("Reputation"))
local Gossip = require(Shared:WaitForChild("Gossip"))
local Map = require(script.Parent:WaitForChild("Map"))

local Standing = {}

local S, text, hud

--- Say the one line that makes a standing change legible, wherever it came from. Shared by the local writes below
--- and by gossip arriving from the other side of the map, which is the case the player cannot otherwise see.
local function announce(ps, holderKey: string, before: number, after: number)
	if not text or Reputation.word(before) == Reputation.word(after) then return end
	local i = Gossip.tribeOf(S, holderKey)
	local t = i and S.tribes[i]
	if not t then return end
	-- Name the HOLDER, not the tribe type. A squad learning something and then their village learning it are two
	-- events minutes apart, and wording both "The hunters now think..." reads as the same line twice.
	local word = Reputation.word(after)
	-- the village's NAME is nicer, but it is only a label: if the map is not up yet, say it the plain way rather than
	-- turning a cosmetic line into an error on a path the player cannot see
	local ok, named = pcall(function() return Map.village(t.villageId).name end)
	if string.match(holderKey, "^v%d+$") and ok then
		text(ps, ("%s now thinks of you as %s."):format(named, word), "rep")
	elseif string.match(holderKey, "^v%d+$") then
		text(ps, ("The %ss now think of you as %s."):format(t.tribeType, word), "rep")
	else
		text(ps, ("The %ss who were there now think of you as %s."):format(t.tribeType, word), "rep")
	end
	if hud then hud(ps) end
end

function Standing.bind(ctx)
	S, text, hud = ctx.S, ctx.text, ctx.hud
	Gossip.onChange = announce -- a rumour that lands silently is a feature nobody can see
end

-- ---------- reading ----------
function Standing.at(ps, holderKey: string?): number
	return Gossip.standing(S, ps, holderKey)
end

--- What a tribe thinks of this player: its village's number.
function Standing.tribe(ps, tribeIdx: number?): number
	if not tribeIdx then return 0 end
	return Gossip.tribeStanding(S, ps, tribeIdx)
end

--- What THIS person thinks of the player - their group's opinion if they are on the road with one, else their
--- village's. This is the whole point of part 3: the squad that saw it and the village that has not heard yet are
--- two different numbers.
function Standing.of(ps, e): number
	return Gossip.standing(S, ps, Gossip.holderOf(e))
end

--- The three-key { farmer, hunter, plunderer } the HUD and the client still speak, built from the three villages.
--- The wire format did not change in part 3, so Hud.toggleStanding and Client.client.lua are untouched.
function Standing.hudRep(ps)
	local out = {}
	for i, t in ipairs(S.tribes) do out[t.tribeType] = Gossip.tribeStanding(S, ps, i) end
	return out
end

--- A new player's table: the three village holders, seeded from their tribe type's START.
function Standing.newRep()
	local seed = {}
	for i, t in ipairs(S.tribes) do seed[Gossip.villageKey(i)] = t.tribeType end
	return Reputation.newTable(seed)
end

-- ---------- writing ----------
--- One holder's number moves, and the player is told if the WORD changed. This is Sim's old `applyRep`, except that
--- it is one holder rather than every tribe of a type at once - which is what made the old number instant and global.
function Standing.apply(ps, holderKey: string?, deltas): boolean
	if not holderKey then return false end
	local i = Gossip.tribeOf(S, holderKey)
	local t = i and S.tribes[i]
	if not t then return false end
	local d = deltas[t.tribeType]
	if not d or d == 0 then return false end
	local before = Gossip.standing(S, ps, holderKey)
	ps.rep[holderKey] = Reputation.clamp(before + d)
	announce(ps, holderKey, before, ps.rep[holderKey])
	return Reputation.word(before) ~= Reputation.word(ps.rep[holderKey])
end

--- Something the player did, judged by whoever was there.
--- `holders` is the set of holder keys that SAW it. For an event that travels (a kill, a mercy, an escape, a gift)
--- this seeds a rumour at each of them and it spreads from there; for an event that does not (a blow, a trade, a
--- night's rest) it lands on them and stops.
--- An empty `holders` for a travelling event means NOBODY SAW IT: nothing happens, anywhere. That is deliberate
--- (§7, "you can outrun your reputation"), and `Standing.sawIt` is what makes it legible to the player.
function Standing.event(ps, event: string, victimKind: string?, tribeIdx: number?, ctx, holders)
	if Gossip.TRAVELS[event] then
		local r = Gossip.seed(S, ps.player.UserId, event, victimKind, tribeIdx, ctx, S.day, holders or {})
		return r ~= nil
	end
	local t = tribeIdx and S.tribes[tribeIdx]
	local deltas = Reputation.deltas(event, victimKind, t and t.tribeType or nil, ctx)
	local changed = false
	for key in pairs(holders or {}) do
		if Standing.apply(ps, key, deltas) then changed = true end
	end
	return changed
end

--- The common case: the only holder that matters is the person in front of you. A blow lands on their group or
--- village and stops there; a mercy or an escape is a story THEY carry, because they are the one it happened to.
function Standing.eventAt(ps, event: string, e, ctx)
	local h = Gossip.holderOf(e)
	if not h then return false end
	return Standing.event(ps, event, e.kind, e.tribe, ctx, { [h] = true })
end

--- The one-liner that makes the whole mechanic visible. Without it part 3 reads as nothing happening.
function Standing.sawIt(ps, seen: boolean)
	if not text then return end
	text(ps, if seen then "Someone saw that." else "Nobody saw that.", if seen then "warn" else "good")
end

--- A gift is amends as well as a story: it chips at the scar the people carry.
function Standing.amend(ps, tribeIdx: number?)
	local t = tribeIdx and S.tribes[tribeIdx]
	if t then Gossip.amend(ps, t.tribeType) end
end

-- ---------- time ----------
--- The daily fade, for everybody online: standing drifts back toward neutral in a month, a grudge halves in a year.
function Standing.fadeDaily()
	for _, ps in pairs(S.players) do
		for holder, v in pairs(ps.rep) do ps.rep[holder] = Reputation.fade(v, 1) end
		Gossip.fadeGrudge(ps, 1)
	end
end

--- A player who was away: fade for the days they missed, then apply everything the world learned about them while
--- they were gone. Order matters - the fade is for time passing, the rumours are things that happened in it.
function Standing.away(ps, days: number)
	if days > 0 then
		for holder, v in pairs(ps.rep) do ps.rep[holder] = Reputation.fade(v, days) end
		Gossip.fadeGrudge(ps, days)
	end
	Gossip.catchUpPlayer(S, ps, ps.player.UserId)
end

--- A v2 player key is keyed by tribe TYPE. Copy each onto that tribe's village holder, keep anything already a
--- holder key, and drop the old keys. Lossless, and it runs once per returning player (no PLAYER_VERSION bump,
--- because applyPlayer discards the whole record on a mismatch).
function Standing.rekey(ps)
	local byType = {}
	for i, t in ipairs(S.tribes) do byType[t.tribeType] = Gossip.villageKey(i) end
	for key, v in pairs(table.clone(ps.rep)) do
		local holder = byType[key]
		if holder then
			if ps.rep[holder] == nil then ps.rep[holder] = v end
			ps.rep[key] = nil
		end
	end
end

-- ---------- what a village has heard, in words ----------
local SAID = {
	kill = "They say you killed someone.",
	mercy = "They say you let someone live.",
	escape = "They say the bandits could not catch you.",
	gift = "They say you gave freely.",
}

--- The newest thing this holder has heard about the player, as a line for Talk.Context.heard. A rumour that has been
--- through several hands is hedged, because that is what a weak rumour is.
function Standing.heard(ps, holderKey: string?): string?
	if not holderKey then return nil end
	local r = Gossip.latest(S, holderKey, ps.player.UserId)
	if not r then return nil end
	local line = SAID[r.event]
	if not line then return nil end
	if (r.hops or 0) >= 2 then return "There is talk about you, though nobody here is sure of it." end
	return line
end

return Standing
