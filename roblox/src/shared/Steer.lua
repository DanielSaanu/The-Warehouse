--!strict
-- How a body gets round what is in its way, and when it stops trying (handoff H9). Pure Luau: no entities table,
-- no occupancy grid, no Roblox; the caller passes `free(x, y)` (walkable and nobody on it) and the bodies it means.
-- server/Walk.lua carries the answers out (followPath, groupStep); tested in test/luau/steer.test.luau.
-- Owns no data. Writes only the two give-up fields on the body it is handed (`missId`/`misses`, `shunId`/`shunUntil`).
-- Why it exists: steps are 4-way, and the old side-step wanted a neighbour strictly closer (by Chebyshev) to the
-- waypoint after the blocked one. On a straight road no side tile is closer, so it never fired, and a caravan master
-- ringed by his own guards stood still for minutes (Studio, 2026-10-05).
--   local act, p = Steer.unblock(x, y, path, i, free, canSwap) -- "swap" | "path" (a detour: p) | nil (wait)
--   Steer.maySwap(leader, other, g.leader)                      -- may this body trade places with that one?
--   local spot = Steer.followSpot(free, lx, ly, fx, fy, ahead, 2) -- where a follower stands
--   if Steer.missed(e, target.id, now) then ... end              -- a failed plan; true = give up on it
local Steer = {}

Steer.REACH = 4     -- a detour stays within this many tiles (Chebyshev) of where the body stands
Steer.REJOIN = 8    -- and rejoins the path at most this many waypoints past the blocked one
Steer.GIVE_UP = 3   -- failed plans toward one target before a body gives up on it
Steer.SHUN = 60     -- game seconds it then leaves that target alone

-- An ordered list, not Movement.DIRS (a dictionary): the same crowd must give the same detour every time.
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

type Pos = { x: number, y: number }

--- May `mover` trade places with `other`, who stands on its next tile? Only a group's leader, and only with one of
--- its own people who is idle: not fighting, not mid-swing, not broken and running. Strangers are walked round.
function Steer.maySwap(mover: any, other: any, leaderId: string?): boolean
	return mover.group ~= nil and other.group == mover.group and leaderId == mover.id and other.id ~= mover.id
		and other.state == "idle" and not other.broken and not other.windupAt
end

--- A body at (x, y) whose next step `path[i]` is taken. In order: trade places with one of its own on that tile
--- (`canSwap(x, y)`); else a detour (breadth first, within REACH) that rejoins the path at the nearest waypoint past
--- the blocked one, over free ground except that its FIRST step may be onto one of its own (the swap then happens
--- when it gets there: a leader boxed by strangers with its guard at its side goes out past the guard); else nil,
--- and it waits. Returns ("swap", nil), ("path", newPath) or nil.
function Steer.unblock(x: number, y: number, path: { Pos }, i: number, free: (number, number) -> boolean, canSwap: ((number, number) -> boolean)?): (string?, { Pos }?)
	local step = path[i]
	if canSwap and canSwap(step.x, step.y) then return "swap", nil end
	local want: { [string]: number } = {}
	for j = i + 1, math.min(#path, i + Steer.REJOIN) do
		local k = path[j].x .. "," .. path[j].y
		if want[k] == nil then want[k] = j end
	end
	local from: { [string]: string } = { [x .. "," .. y] = "" }
	local at: { [string]: Pos } = { [x .. "," .. y] = { x = x, y = y } }
	local queue, head = { x .. "," .. y }, 1
	while queue[head] do
		local ck = queue[head]
		head += 1
		local c = at[ck]
		for _, d in ipairs(DIRS) do
			local nx, ny = c.x + d[1], c.y + d[2]
			local nk = nx .. "," .. ny
			local first = ck == x .. "," .. y
			if from[nk] == nil and math.max(math.abs(nx - x), math.abs(ny - y)) <= Steer.REACH
				and (free(nx, ny) or (first and canSwap ~= nil and canSwap(nx, ny))) then
				from[nk], at[nk] = ck, { x = nx, y = ny }
				local j = want[nk]
				if j then
					local back = {}
					local k = nk
					while k ~= "" and k ~= x .. "," .. y do table.insert(back, 1, at[k]) k = from[k] end
					for n = j + 1, #path do table.insert(back, path[n]) end
					return "path", back
				end
				table.insert(queue, nk)
			end
		end
	end
	return nil, nil
end

--- Where a follower stands: a free tile within `r` of the leader, not on the leader's next tiles (`ahead`), and the
--- nearest such tile to the follower itself, so the ones behind stay behind instead of crossing in front.
function Steer.followSpot(free: (number, number) -> boolean, lx: number, ly: number, fx: number, fy: number, ahead: { Pos }?, r: number): Pos?
	local best, bestD = nil, math.huge
	for dy = -r, r do
		for dx = -r, r do
			local x, y = lx + dx, ly + dy
			local clear = free(x, y)
			for _, a in ipairs(ahead or {}) do if a.x == x and a.y == y then clear = false end end
			if clear then
				local d = math.abs(x - fx) + math.abs(y - fy)
				if d < bestD then best, bestD = { x = x, y = y }, d end
			end
		end
	end
	return best
end

--- A failed plan toward `id` (no path at all). Returns true when it is time to give up, and from then on
--- `shuns(e, id, now)` is true for SHUN seconds. Misses count per target; any other target starts again.
function Steer.missed(e: any, id: string, now: number): boolean
	if e.missId ~= id then e.missId, e.misses = id, 0 end
	e.misses += 1
	if e.misses < Steer.GIVE_UP then return false end
	e.missId, e.misses, e.shunId, e.shunUntil = nil, 0, id, now + Steer.SHUN
	return true
end

function Steer.shuns(e: any, id: string, now: number): boolean
	return e.shunId == id and now < (e.shunUntil or 0)
end

return Steer
