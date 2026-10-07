-- Handoff H9: a materialised leader stalled in a crowd while its `pos` walked on without it.
-- 1. The body: shared/Steer.lua decides what a blocked body does (server/Walk.lua's followPath carries it out).
-- 2. The record: Tick.leaderStep moves `pos` only on where the leader STANDS, never on a planned path (S6).
local Steer = __require("Steer")
local Tick = __require("Tick")

-- ---------- a tiny world: open ground, bodies on tiles, one walker following a path the way followPath does ----------
local W, H = 12, 12
local function key(x, y) return x .. "," .. y end

local function newWorld(walls)
	local occ = {}
	local function walkable(x, y) return x >= 1 and x <= W and y >= 1 and y <= H and not (walls and walls[key(x, y)]) end
	local function free(x, y) return walkable(x, y) and occ[key(x, y)] == nil end
	local function put(e) occ[key(e.x, e.y)] = e end
	return occ, free, put, walkable
end

-- The leader's brain re-plans to `to` after followPath drops a blocked path: a straight L along open ground that
-- ignores who is standing where, as WorldGen.route does.
local function plan(x, y, to)
	local p = {}
	while y ~= to.y do y += if to.y > y then 1 else -1 table.insert(p, { x = x, y = y }) end
	while x ~= to.x do x += if to.x > x then 1 else -1 table.insert(p, { x = x, y = y }) end
	return p
end

-- A straight route along y = 1, for the leaderStep tests.
local function line(n)
	local r = {}
	for i = 1, n do r[i] = { x = i, y = 1 } end
	return r
end

-- Walk `mover` toward `to` for `ticks` steps. Mirrors followPath: a free step is taken; a blocked one waits, asks
-- Steer from the second blocked tick on, and is dropped (then re-planned) after more than 4. Returns the tick it
-- arrived on, or nil. Asserts every move is one tile onto a free tile, so a "fix" cannot teleport through a crowd.
local function walk(occ, free, mover, to, ticks, leaderId)
	local path, i, blocked = plan(mover.x, mover.y, to), 1, 0
	local function canSwap(x, y)
		local o = occ[key(x, y)]
		return o ~= nil and Steer.maySwap(mover, o, leaderId)
	end
	local function moveTo(x, y)
		assert(math.abs(x - mover.x) + math.abs(y - mover.y) == 1, ("a move is one tile: %d,%d -> %d,%d"):format(mover.x, mover.y, x, y))
		occ[key(mover.x, mover.y)] = nil
		mover.x, mover.y = x, y
		occ[key(x, y)] = mover
	end
	for t = 1, ticks do
		if mover.x == to.x and mover.y == to.y then return t end
		if not path or i > #path then path, i = plan(mover.x, mover.y, to), 1 end
		local s = path[i]
		if free(s.x, s.y) then
			moveTo(s.x, s.y) i += 1 blocked = 0
		else
			blocked += 1
			if blocked >= 2 then
				local act, p = Steer.unblock(mover.x, mover.y, path, i, free, canSwap)
				if act == "swap" then
					local o = occ[key(s.x, s.y)]
					local ox, oy = mover.x, mover.y
					occ[key(ox, oy)] = nil
					o.x, o.y = ox, oy
					occ[key(ox, oy)] = o
					occ[key(s.x, s.y)] = nil
					moveTo(s.x, s.y) i += 1 blocked = 0
				elseif act == "path" then
					assert(p and #p > 0, "a detour has tiles")
					path, i, blocked = p, 1, 0
				end
			end
			if blocked > 4 then path, blocked = nil, 0 end
		end
	end
	return nil
end

-- 1a. Ringed by its own followers on a straight road (Glenworth's square): every side is taken by its own people.
--     The old rule (a strictly closer neighbour, by Chebyshev, with 4-way steps) can never fire on a straight road.
do
	local occ, free, put = newWorld()
	local leader = { id = "L", x = 3, y = 6, group = "caravan", state = "idle" }
	put(leader)
	for _, p in ipairs({ { 4, 6 }, { 3, 5 }, { 3, 7 }, { 2, 6 } }) do
		put({ id = "f" .. p[1] .. p[2], x = p[1], y = p[2], group = "caravan", state = "idle" })
	end
	local t = walk(occ, free, leader, { x = 10, y = 6 }, 60, "L")
	assert(t, "a leader ringed by its own followers gets out and down the road (it swaps with the one in front)")
	print(("   ringed by its own: out and at the end in %d ticks"):format(t))
end

-- 1b. Strangers on the road ahead (villagers, the merchant), open ground beside it: walk round them.
do
	local occ, free, put = newWorld()
	local leader = { id = "L", x = 3, y = 6, group = "caravan", state = "idle" }
	put(leader)
	for _, p in ipairs({ { 4, 6 }, { 5, 6 }, { 4, 5 } }) do put({ id = "v" .. p[1] .. p[2], x = p[1], y = p[2], state = "idle" }) end
	local t = walk(occ, free, leader, { x = 10, y = 6 }, 60, "L")
	assert(t, "a leader blocked by strangers walks round them")
	print(("   strangers on the road: round them in %d ticks"):format(t))
end

-- 1c. Walled in by strangers and nobody of its own: it waits. Nobody is walked through, nobody swapped.
do
	local occ, free, put = newWorld()
	local leader = { id = "L", x = 3, y = 6, group = "caravan", state = "idle" }
	put(leader)
	for _, p in ipairs({ { 4, 6 }, { 3, 5 }, { 3, 7 }, { 2, 6 } }) do put({ id = "s" .. p[1] .. p[2], x = p[1], y = p[2], state = "idle" }) end
	assert(walk(occ, free, leader, { x = 10, y = 6 }, 40, "L") == nil, "boxed in by strangers: it waits")
	assert(leader.x == 3 and leader.y == 6, "and stands where it was")
end

-- 1h. Studio, 2026-10-06: ringed by strangers on three sides and its OWN guard on the fourth, which is not the tile
--     its path wants next. Swapping only with whoever stands on the next step left it waiting for the guard to wander.
do
	local occ, free, put = newWorld()
	local leader = { id = "L", x = 3, y = 6, group = "caravan", state = "idle" }
	put(leader)
	for _, p in ipairs({ { 4, 6 }, { 3, 5 }, { 2, 6 } }) do put({ id = "s" .. p[1] .. p[2], x = p[1], y = p[2], state = "idle" }) end
	put({ id = "g", x = 3, y = 7, group = "caravan", state = "idle" })
	local t = walk(occ, free, leader, { x = 10, y = 6 }, 60, "L")
	assert(t, "out past its own guard, round the strangers")
end

-- 1d. Swaps are only for a group leader with its own idle people: never a follower, never a stranger, never
--     someone in a fight or broken.
do
	local L = { id = "L", group = "caravan", state = "idle" }
	local f = { id = "f", group = "caravan", state = "idle" }
	assert(Steer.maySwap(L, f, "L"), "the leader past its own follower")
	assert(not Steer.maySwap(f, L, "L"), "a follower does not push the leader")
	assert(not Steer.maySwap(L, { id = "v", state = "idle" }, "L"), "not a stranger")
	assert(not Steer.maySwap(L, { id = "b", group = "band", state = "idle" }, "L"), "not another group")
	assert(not Steer.maySwap(L, { id = "g", group = "caravan", state = "chase" }, "L"), "not one who is fighting")
	assert(not Steer.maySwap(L, { id = "g", group = "caravan", state = "idle", broken = true }, "L"), "not one who is broken")
	assert(not Steer.maySwap(L, { id = "g", group = "caravan", state = "idle", windupAt = 3 }, "L"), "not mid-swing")
end

-- 1e. A detour rejoins the path further on, and every tile of it is one step from the last.
do
	local occ, free, put = newWorld()
	put({ id = "v", x = 5, y = 6 })
	local path = plan(4, 6, { x = 10, y = 6 })
	local act, p = Steer.unblock(4, 6, path, 1, free, nil)
	assert(act == "path" and p, "a detour round one body on the road")
	local px, py = 4, 6
	for _, s in ipairs(p) do
		assert(math.abs(s.x - px) + math.abs(s.y - py) == 1 and free(s.x, s.y), "connected, over free ground")
		px, py = s.x, s.y
	end
	assert(px == 10 and py == 6, "and it still ends where the path ended")
	-- a one-tile path (the leader's single step onto the next route tile) has nothing further on to rejoin: wait
	assert(Steer.unblock(4, 6, { { x = 5, y = 6 } }, 1, free, nil) == nil, "nothing past a taken last tile")
end

-- 1f. A follower picks a spot near the leader that is NOT where the leader is about to walk, nearest to itself.
do
	local occ, free, put = newWorld()
	put({ id = "L", x = 6, y = 6 })
	local ahead = { { x = 6, y = 5 }, { x = 6, y = 4 } } -- the leader is walking north
	local s = Steer.followSpot(free, 6, 6, 6, 10, ahead, 2)
	assert(s, "a spot")
	assert(math.max(math.abs(s.x - 6), math.abs(s.y - 6)) <= 2, "within 2 of the leader")
	for _, a in ipairs(ahead) do assert(not (s.x == a.x and s.y == a.y), "never on the leader's next tiles") end
	assert(s.y > 6, "a follower coming from the south stays behind (south of) the leader: " .. s.x .. "," .. s.y)
end

-- 1g. A body that cannot reach what it is after gives up, and leaves it alone for a while (the squad stood on
--     `hunt` toward an unreachable boar for minutes).
do
	local e = {}
	local gaveUp = false
	for n = 1, Steer.GIVE_UP do gaveUp = Steer.missed(e, "e107", 100) end
	assert(gaveUp, "gives up after GIVE_UP failed plans")
	assert(Steer.shuns(e, "e107", 100 + Steer.SHUN - 1), "and leaves that one alone")
	assert(not Steer.shuns(e, "e108", 101), "but not anything else")
	assert(not Steer.shuns(e, "e107", 100 + Steer.SHUN + 1), "for a while, not for ever")
	local e2 = {}
	for n = 1, Steer.GIVE_UP - 1 do assert(not Steer.missed(e2, "a", 1)) end
	assert(not Steer.missed(e2, "b", 1), "misses count per target: a new target starts again")
end

-- ---------- 2. the record: `pos` follows the body ----------
-- 2a. Boxed in: a path to the next route tile is FOUND every think, but the body never moves. `pos` stays.
--     (Studio, 2026-10-05: the caravan master stood still for 60-110 s while `pos` ran 1 -> 56.)
do
	local g = { route = line(56), pos = 1, dir = 1 }
	local leader = { x = 1, y = 3 } -- two tiles off the road, so it is not beside the next tile: it has to plan
	local ops = { free = function() return true end, step = function() end, path = function() return true end }
	for _ = 1, 60 do Tick.leaderStep(g, leader.x, leader.y, false, ops) end
	assert(g.pos == 1, ("a planned path that is never walked does not move pos (pos %d)"):format(g.pos))
end

-- 2b. Walking for real: `pos` follows the body tile by tile, and the leader gets to the end and turns.
do
	local g = { route = line(20), pos = 1, dir = 1 }
	local leader = { x = 1, y = 1 }
	local ops = {
		free = function() return true end,
		step = function(r) leader.x, leader.y = r.x, r.y end,
		path = function(x, y) leader.x, leader.y = x, y return true end,
	}
	local turned = false
	for _ = 1, 60 do
		local before = g.pos
		local act = Tick.leaderStep(g, leader.x, leader.y, false, ops)
		assert(math.abs(g.route[g.pos].x - leader.x) <= 1, "pos is never ahead of the body")
		assert(g.pos >= before, "and never runs back")
		if act == "turn" then turned = true break end
	end
	assert(turned and g.pos == 20, "walks the route and turns at the end")
end

-- 2c. Somebody stands on the next route tile: after a few tries the leader walks round to the one after it, and
--     `pos` catches up only when the leader is standing there.
do
	local g = { route = line(10), pos = 3, dir = 1 }
	local leader = { x = 3, y = 1 }
	local planned
	local ops = {
		free = function(x) return x ~= 4 end,
		step = function(r) leader.x, leader.y = r.x, r.y end,
		path = function(x, y) planned = { x = x, y = y } return true end,
	}
	for _ = 1, 4 do Tick.leaderStep(g, leader.x, leader.y, false, ops) end
	assert(planned and planned.x == 5, "plans round to the tile after the taken one")
	assert(g.pos == 3, "but pos does not move on the plan")
	leader.x = 5 -- the walk round finished
	Tick.leaderStep(g, leader.x, leader.y, false, ops)
	assert(g.pos >= 5, "pos catches up to where the leader stands: " .. g.pos)
end

-- 2d. Studio, 2026-10-06: TWO route tiles in a row are taken. "Walk on to the one after it" planned onto a taken tile
--     every time; the leader aims for the first free route tile past them instead, and `pos` catches up there.
do
	local g = { route = line(12), pos = 3, dir = 1 }
	local leader = { x = 3, y = 1 }
	local planned
	local ops = {
		free = function(x) return x ~= 4 and x ~= 5 end,
		step = function(r) leader.x, leader.y = r.x, r.y end,
		path = function(x, y) planned = { x = x, y = y } return true end,
	}
	for _ = 1, 4 do Tick.leaderStep(g, leader.x, leader.y, false, ops) end
	assert(planned and planned.x == 6, "plans to the first free route tile past the crowd: " .. tostring(planned and planned.x))
	assert(g.pos == 3, "not on the plan")
	leader.x = 6
	Tick.leaderStep(g, leader.x, leader.y, false, ops)
	assert(g.pos >= 6, "pos catches up when it is standing there: " .. g.pos)
end
print("   steer: unblock, swap, detour, follow spot, give up; pos follows the body")
