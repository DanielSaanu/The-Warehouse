--!nonstrict
-- A villager's day (DESIGN.md §20): out to the plot in the morning, home to a hut door at night, and straight home
-- when a wolf or a strange bandit is near. Before this a villager's whole life was `wanderStep`.
-- Owns: the walk, and nothing durable. What the farms YIELD is shared/Farms.lua, a pure rule over records that
-- counts living villagers, so nothing here changes a number: this is the projection of that rule you can watch.
-- `homeTile` / `workTile` are scratch on the entity, handed out lazily on a villager's first idle thought, which is
-- why neither initTribes, Restore nor morph has to know about them. Hut doors and plots are scanned off the map
-- once per tribe (derived, never saved); the scan also gives the tribe its plot rows (Farms.ensure).
-- Bound, not required, for pathTo / wanderStep / isNight, which still live in Sim (Track B2 moves them).
--   if e.role == "villager" then Villagers.step(e, now) return end      -- from Sim's think, when idle
--   Villagers.flooded()                                                  -- from startCalamity("flood")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local TileTypes = require(Shared:WaitForChild("TileTypes"))
local Farms = require(Shared:WaitForChild("Farms"))
local Map = require(script.Parent:WaitForChild("Map"))
local State = require(script.Parent:WaitForChild("State"))

local Villagers = {}

local S, cheb = State.state, State.cheb
local G = TileTypes.GroundByName
local pathTo, wanderStep, isNight
local sites = {} -- [tribe index] = { huts, plots, next }

function Villagers.bind(ctx)
	pathTo, wanderStep, isNight = ctx.pathTo, ctx.wanderStep, ctx.isNight
	sites = {}
end

--- Tribe `i`'s hut doors and plots, scanned on first use. Also makes sure the tribe row has its plot rows.
function Villagers.site(i: number)
	local site = sites[i]
	if not site then
		site = Farms.scan(Map.get(), Map.village(S.tribes[i].villageId))
		site.next = 0
		sites[i] = site
		Farms.ensure(S.tribes[i], #site.plots)
	end
	return site
end

--- Every tribe scanned and given its plots: once the world exists, so the first daily tick has fields to work.
function Villagers.ready()
	for i in ipairs(S.tribes) do Villagers.site(i) end
end

-- Where the n-th person sleeps relative to their hut door. A village can have more people than standing huts
-- (Glenworth has three burnt and one whole), and only one body fits on a tile, so they bed down around the door
-- rather than all walking at the same square all night.
local DOOR_SPREAD = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 1, 1 }, { -1, 1 } }

--- Somewhere to sleep and somewhere to work. Farmers get a plot; everyone else a spot by the stall.
local function assign(e)
	local world, site = Map.get(), Villagers.site(e.tribe)
	site.next += 1
	local n = site.next
	local door = (#site.huts > 0 and site.huts[(n - 1) % #site.huts + 1]) or e.home
	local off = DOOR_SPREAD[(n - 1) % #DOOR_SPREAD + 1]
	local cand = { x = door.x + off[1], y = door.y + off[2] }
	e.homeTile = if WorldGen.walkable(world, cand.x, cand.y) then cand else door
	if #site.plots > 0 then
		e.workTile, e.farm = site.plots[(n - 1) % #site.plots + 1], true
	else
		local st = Map.village(S.tribes[e.tribe].villageId).stall
		e.workTile = WorldGen.nearestWalkable(world, st.x + (n % 3) - 1, st.y + 1, 3) or e.home
	end
end

--- A wolf, or a bandit from somewhere else. Not their own tribe's fighters, who are the neighbours.
local function danger(e): boolean
	for _, o in pairs(S.entities) do
		if (o.species == "wolf" or (o.kind == "bandit" and o.tribe ~= e.tribe)) and cheb(e.x, e.y, o.x, o.y) <= 6 then
			return true
		end
	end
	return false
end

--- One idle thought of a villager.
function Villagers.step(e, now: number)
	if not e.homeTile then assign(e) end
	local scared = danger(e)
	local goHome = scared or isNight()
	local want = if goHome then e.homeTile else e.workTile
	-- A plot is stood ON, unless a neighbour already is; a doorway only needs to be near. Insisting on the exact
	-- tile left people re-pathing to an occupied one for the rest of the night.
	local reach = 1
	if not goHome and e.farm and not State.occupied[State.tidx(want.x, want.y)] then reach = 0 end
	if cheb(e.x, e.y, want.x, want.y) <= reach then
		e.path = nil
		return
	end
	if not e.path and now >= (e.nextRouteAt or 0) then
		e.nextRouteAt = now + (if scared then 0.6 else 2.5)
		-- nowhere to go (walled in, or the way is blocked): mill about rather than stand rigid
		if not pathTo(e, want.x, want.y, 300) then wanderStep(e, now) end
	end
end

--- What Tick.daily brought in (`ev.harvests[tribe] = { harvested, food }`): the log gets a line, and anybody standing
--- in that village at dawn is told. Not a headline: a harvest every other day would push births and deaths out of
--- the 64-entry ring.
function Villagers.harvested(harvests)
	local world = Map.get()
	for i, h in pairs(harvests or {}) do
		local v = Map.village(S.tribes[i].villageId)
		print(("[Sim] %s brought in %d plots: %d food, %d in the store"):format(v.name, h.harvested, h.food, S.tribes[i].stock.food or 0))
		for _, ps in pairs(S.players) do
			if not ps.dead and WorldGen.villageAt(world, ps.x, ps.y, 1) == v then
				State.text(ps, ("The fields came in at dawn: %d food to %s's store."):format(h.food, v.name))
			end
		end
	end
end

--- Forget what was scanned and scan again: a restore swaps the tribe rows under this module.
function Villagers.reset()
	sites = {}
	Villagers.ready()
end

--- The flood has come: plots under water lose the season on them, and the village says so.
function Villagers.flooded()
	local world = Map.get()
	for i, t in ipairs(S.tribes) do
		Farms.drown(t, Villagers.site(i).plots, function(x, y) return WorldGen.ground(world, x, y) == G.flood.id end)
	end
end

--- For the Debug console: what every village's fields are doing.
function Villagers.report()
	local out = {}
	for i, t in ipairs(S.tribes) do
		local site, grown = Villagers.site(i), 0
		for _, plot in ipairs(t.plots) do grown += plot.growth end
		local atWork, atHome, all = 0, 0, 0
		for _, e in pairs(S.entities) do
			if e.tribe == i and e.role == "villager" and e.workTile then
				all += 1
				if cheb(e.x, e.y, e.workTile.x, e.workTile.y) <= 1 then atWork += 1
				elseif cheb(e.x, e.y, e.homeTile.x, e.homeTile.y) <= 1 then atHome += 1 end
			end
		end
		out[Map.village(t.villageId).name] = ("%d huts, %d plots (%.2f grown), %d hands, %d food; of %d villagers %d at work, %d at home"):format(
			#site.huts, #site.plots, grown, Farms.workers(S, i), t.stock.food or 0, all, atWork, atHome)
	end
	return out
end

return Villagers
