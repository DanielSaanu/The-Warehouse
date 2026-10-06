--!nonstrict
-- Road talk (rung 3 part 4 phase 2, docs/plans/rung3-part4-belonging.md "the guidance layer"): what a group says to
-- the players riding with it. The RULES (which line, the fade, never twice in a row) are pure in shared/Barks.lua;
-- this gathers the facts each second and picks who says it: a living member ON THE RIDER'S SCREEN, so every bark has
-- a face ("Bera: Wolves, east!"). Shown as the ordinary text notice (fades after 4 s, 3 at most): no client change.
-- Owns: `g.talk` (scratch: what was already news this leg) and `ps.barks` (one player's session memory). Neither is
-- saved: Save encodes groups and players by whitelist (test/luau/belong.test.luau proves it).
-- Does NOT own the ride (server/Ride.lua calls in) or any number: a bark never moves standing or pay.
--   RoadTalk.tick(g, l, now, lagger, where)  -- 1 Hz from Ride.tick, a materialised group with riders
--   RoadTalk.say(ps, g, facts, now)          -- one bark now (Ride.arrive's "Made it.")
--   RoadTalk.newLeg(g) / RoadTalk.drop(g)    -- a turn makes the road's news new again; no riders, no memory
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Barks = require(Shared:WaitForChild("Barks"))
local Items = require(Shared:WaitForChild("Items"))
local Trade = require(Shared:WaitForChild("Trade"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local State = require(script.Parent:WaitForChild("State"))

local RoadTalk = {}
local S = State.state
local cheb = State.cheb

local SEE = 8       -- tiles from the leader at which a wolf, a bandit or (for the squad) a deer is news
local NEAR_END = 12 -- route tiles from the end at which "nearly there" is said

--- On this rider's screen (the narrowest view, Config.COLS x ROWS): every bark has a face.
local function onScreen(ps, e): boolean
	return math.abs(e.x - ps.x) <= Config.COLS // 2 and math.abs(e.y - ps.y) <= Config.ROWS // 2
end

--- Who says it: of the group's living bodies on the rider's screen, the one nearest (x, y); with `who` "member",
--- anyone but the leader first. Nobody on screen: nobody says it.
local function speaker(g, ps, who: string?, x: number, y: number)
	local best, bestD = nil, math.huge
	for id in pairs(g.entities or {}) do
		local m = S.entities[id]
		if m and m.hp > 0 and onScreen(ps, m) then
			local d = cheb(m.x, m.y, x, y) + (if who == "member" and id == g.leader then 100 else 0)
			if d < bestD then best, bestD = m, d end
		end
	end
	return best
end

--- Say the one bark these facts call for (Barks.pick: most urgent, most specific, faded, never twice in a row). A
--- fact nobody on the rider's screen could say is dropped first, so the fade is spent only on lines that showed.
--- Returns the fact said, if any.
function RoadTalk.say(ps, g, facts, now: number)
	if ps.dialogue then return nil end -- reading a window: the road can wait
	ps.barks = ps.barks or Barks.new(now)
	local heard = {}
	for _, f in ipairs(facts) do
		f.by = f.by or speaker(g, ps, f.who, f.x or ps.x, f.y or ps.y)
		if f.by then
			if f.boss and f.by.id == g.leader then f.boss = nil end -- the master does not call himself spooked
			table.insert(heard, f)
		end
	end
	local line, f = Barks.pick(ps.barks, heard, now)
	if line and f then State.text(ps, (f.by.first or f.by.label or "") .. ": " .. line) end
	return f
end

--- What the group noticed this second, the same for every rider: a member down, the leader spooked (a witness flee
--- holds the ride: QA phase 1), a wolf / bandit / deer newly in sight, the end near. `g.talk` remembers what was news.
local function groupFacts(g, l, where): { any }
	local t = g.talk
	local out, crew = {}, {}
	for id in pairs(g.entities) do
		local m = S.entities[id]
		if m and m.hp > 0 then crew[id] = m.first or false end
	end
	for id, first in pairs(t.crew or {}) do
		if not crew[id] then table.insert(out, { fact = "down", name = first or nil, x = l.x, y = l.y }) end
	end
	t.crew = crew
	if l.state == "flee" and not t.spooked then table.insert(out, { fact = "spooked", boss = l.first, who = "member", x = l.x, y = l.y }) end
	t.spooked = l.state == "flee"
	for id, e in pairs(S.entities) do
		local seen = e.kind == "wolf" or (e.kind == "bandit" and e.group ~= g.id) or (e.kind == "deer" and g.kind == "squad")
		if seen and not t.seen[id] and e.hp > 0 and cheb(e.x, e.y, l.x, l.y) <= SEE then
			t.seen[id] = true
			table.insert(out, { fact = if e.kind == "deer" then "prey" else "hostile", kind = e.kind, group = g.kind, x = e.x, y = e.y })
		end
	end
	local togo = where.left
	if togo > 0 and togo <= NEAR_END and not t.near then
		t.near = true
		table.insert(out, { fact = "near", dest = where.dest, who = "member" })
	end
	return out
end

--- 1 Hz, a materialised group with riders (from Ride.tick): each rider's barks this second, the group's news plus
--- their own (joined, lagging, hurt) and road talk. `where` = { dest, ti, left, home } from Ride.
function RoadTalk.tick(g, l, now: number, lagger, where)
	g.talk = g.talk or { seen = {} }
	local news = groupFacts(g, l, where)
	local ti = where.ti
	local road = { fact = "road", dest = where.dest, home = where.home, who = "member",
		scarce = if ti then Items.def(Trade.NEEDS[S.tribes[ti].tribeType]).label else nil }
	for uid, r in pairs(g.riders) do
		local ps = S.players[uid]
		if ps and not ps.dead then
			local facts = {}
			for _, f in ipairs(news) do
				local mine = table.clone(f)
				if f.x then mine.dir = WorldGen.compass(f.x - ps.x, f.y - ps.y) end
				table.insert(facts, mine)
			end
			-- joined waits until it is said: the yes window is still open the second after the yes
			if r.joined then table.insert(facts, { fact = "joined", group = g.kind, who = "member" }) end
			-- the leader (who has turned to face you) says it, or whoever is nearest him on your screen
			if lagger == ps then table.insert(facts, { fact = "lag", x = l.x, y = l.y }) end
			if ps.hp < (r.hp or ps.hp) then table.insert(facts, { fact = "hurt" }) end
			r.hp = ps.hp
			table.insert(facts, table.clone(road))
			local said = RoadTalk.say(ps, g, facts, now)
			if said and said.fact == "joined" then r.joined = nil end
		end
	end
end

function RoadTalk.newLeg(g)
	if g.talk then g.talk.seen, g.talk.near = {}, false end
end

function RoadTalk.drop(g)
	g.talk = nil
end

return RoadTalk
