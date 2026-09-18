--!nonstrict
-- The test hooks (docs/qa/rung2-part2.md). Set the Workspace string attribute `Debug` to a command line and read
-- `DebugResult`; Server.server.lua wires that up and also exposes ServerStorage.Debug for scripts that can invoke
-- a BindableFunction.
--
-- It lives outside Sim.lua for two reasons: it is test-only code that has no business inflating a production
-- module, and Sim.lua had reached Luau's type-inference budget, which this block alone was enough to exceed.
-- It does not `require` Sim; Sim binds itself in during init, so the two never form a require cycle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Stats = require(Shared:WaitForChild("Stats"))
local WorldGen = require(Shared:WaitForChild("WorldGen"))
local Ecology = require(Shared:WaitForChild("Ecology"))
local Families = require(Shared:WaitForChild("Families"))

local Debug = {}

-- Bound by Sim.init: the simulation's own innards, which is exactly what a debug console is for.
local Sim, S, world
local cheb, collapse, endCalamity, hitEntity, killPlayer, morph, nearestFree, newEntity, startCalamity, tickFamilies, tidx

function Debug.bind(ctx)
	Sim, S, world = ctx.Sim, ctx.S, ctx.world
	cheb, collapse, endCalamity, hitEntity = ctx.cheb, ctx.collapse, ctx.endCalamity, ctx.hitEntity
	killPlayer, morph, nearestFree, newEntity = ctx.killPlayer, ctx.morph, ctx.nearestFree, ctx.newEntity
	startCalamity, tickFamilies, tidx = ctx.startCalamity, ctx.tickFamilies, ctx.tidx
end

function Debug.run(cmd: string, ...): any
	local args = { ... }
	local ps
	for _, p in pairs(S.players) do ps = p break end
	if cmd == "state" then
		local n, g = 0, 0
		for _ in pairs(S.entities) do n += 1 end
		for _, gr in pairs(S.groups) do g += 1 end
		local t = Ecology.totals(S.regions)
		local out = { day = S.day, entities = n, groups = g, deer = t.deer, boar = t.boar, wolf = t.wolf, calamity = S.calamity.kind, active = S.calamity.active }
		for id, gr in pairs(S.groups) do
			local live = 0
			for _ in pairs(gr.entities) do live += 1 end
			out[id] = ("%d members (%d visible) at %d,%d, route %d/%d"):format(#gr.members, live, Sim.groupPos(gr).x, Sim.groupPos(gr).y, gr.pos, #gr.route)
		end
		return out
	elseif cmd == "calamity" then
		endCalamity()
		startCalamity(args[1] or "flood")
		return "started " .. (args[1] or "flood")
	elseif cmd == "teleport" and ps then
		local p = nearestFree(args[1], args[2], 4)
		if not p then return "no free tile there" end
		Sim.occupied[tidx(ps.x, ps.y)] = nil
		ps.x, ps.y = p.x, p.y
		Sim.occupied[tidx(ps.x, ps.y)] = ps.player.UserId
		ps.snap(ps)
		return ("at %d,%d"):format(p.x, p.y)
	elseif cmd == "give" and ps then
		if args[1] == "coin" then ps.inv.coin += args[2] or 10 else Items.add(ps.inv, args[1], args[2] or 1) end
		Sim.hud(ps)
		return "ok"
	elseif cmd == "rep" and ps then
		local t = S.tribes[args[1] or 1]
		ps.rep[t.tribeType] = args[2] or 0
		Sim.hud(ps)
		return t.tribeType .. " = " .. tostring(ps.rep[t.tribeType])
	elseif cmd == "night" then
		S.dayStart = os.clock() - Config.DAY_SECONDS * (1 - Config.NIGHT_FRACTION + 0.01)
		return "dusk"
	elseif cmd == "jump" then
		-- set the calendar: `jump 6` = morning of day 6 (the warning), `jump 7 0.29` = a moment before the calamity
		local day, frac = args[1] or 7, args[2] or 0.1
		S.day = day
		S.dayStart = os.clock() - Config.DAY_SECONDS * frac
		S.lastDailyTick = day -- one jump does not run six days of births and breeding
		return ("day %d, %.0f%% through it"):format(day, frac * 100)
	elseif cmd == "day" then
		S.dayStart = os.clock() - Config.DAY_SECONDS * (args[1] or 0.1)
		return "morning"
	elseif cmd == "hurt" and ps then
		ps.hp = math.max(1, ps.hp - (args[1] or 4))
		Sim.hud(ps)
		return ps.hp
	elseif cmd == "kill" and ps then
		killPlayer(ps, nil)
		return "dead"
	elseif cmd == "group" then
		local g = S.groups[args[1] or "band"]
		if not g then return "no such group" end
		local p = Sim.groupPos(g)
		local carry = {}
		for item, n in pairs(g.carry or {}) do table.insert(carry, ("%d %s"):format(n, item)) end
		table.sort(carry)
		return ("%s at %d,%d dir %d pos %d/%d%s carrying[%s]%s"):format(g.id, p.x, p.y, g.dir, g.pos, #g.route,
			if g.materialised then " visible" else "", table.concat(carry, ", "),
			if os.clock() < (g.retreatUntil or 0) then " RETREATING" else "")
	elseif cmd == "summon" and ps then
		-- bring a group next to the player
		local g = S.groups[args[1] or "band"]
		if not g then return "no such group" end
		if g.materialised then collapse(g) end
		local bestI, bestD = 1, math.huge
		for i, r in ipairs(g.route) do
			local d = cheb(r.x, r.y, ps.x, ps.y)
			if d < bestD then bestI, bestD = i, d end
		end
		g.pos = bestI
		g.pauseUntil = 0
		return ("%s moved to route index %d (%d tiles away)"):format(g.id, bestI, bestD)
	elseif cmd == "freeze" then
		Sim.frozen = (args[1] or 1) ~= 0
		return "frozen " .. tostring(Sim.frozen)
	elseif cmd == "spawn" and ps then
		-- `spawn <kind> [x] [y] [tribe]`. A person without a tribe is nobody's, which makes every side-taking
		-- test lie: a witness reads them as an unaffiliated stranger rather than as a bandit. So a tribal kind
		-- gets the tribe its kind implies unless one is named.
		local p = nearestFree(args[2] or (ps.x + 3), args[3] or ps.y, 3)
		if not p then return "no room" end
		local kind = args[1] or "wolf"
		local animal = Stats.get(kind).animal
		local r = Ecology.at(S.regions, world, p.x, p.y)
		local tribe = args[4]
		if not animal and not tribe then
			local wantType = if kind == "bandit" then "plunderer" elseif kind == "hunter" then "hunter" else nil
			local here = WorldGen.villageAt(world, p.x, p.y, 3)
			for i, t in ipairs(S.tribes) do
				if (wantType and t.tribeType == wantType) or (not wantType and t.village == here) then tribe = i break end
			end
			tribe = tribe or 1
		end
		local e = newEntity(kind, p.x, p.y, { species = if animal then kind else nil, region = if animal then r.id else nil,
			tribe = tribe, radius = 4 })
		if e.species then r.live[kind] += 1 r[kind] += 1 end
		return ("%s (%s%s)"):format(e.id, kind, if tribe then ", " .. S.tribes[tribe].tribeType else "")
	elseif cmd == "entity" then
		local e = S.entities[args[1]]
		if not e then return "no entity " .. tostring(args[1]) end
		return { id = e.id, kind = e.kind, hp = e.hp, x = e.x, y = e.y, state = e.state, target = tostring(e.target),
			npcTarget = tostring(e.npcTarget), alarmTo = tostring(e.alarm and e.alarm.to),
			facing = e.facing, group = e.group, region = e.region, label = e.label }
	elseif cmd == "list" then
		local out = {}
		for id, e in pairs(S.entities) do
			if not args[1] or e.kind == args[1] or e.role == args[1] then
				local at = if e.target then " ->" .. tostring(e.target) elseif e.npcTarget then " ->" .. tostring(e.npcTarget) else ""
				table.insert(out, ("%s %s hp%d @%d,%d %s%s"):format(id, e.kind, e.hp, e.x, e.y, e.state, at))
			end
		end
		table.sort(out)
		return out
	elseif cmd == "player" and ps then
		local slots = {}
		for _, sl in ipairs(ps.inv.slots) do table.insert(slots, sl.item .. "x" .. sl.n) end
		return { x = ps.x, y = ps.y, hp = ps.hp, facing = ps.facing, dead = ps.dead, coin = ps.inv.coin, inv = table.concat(slots, ","), rep = ps.rep, rest = ps.restText, epoch = ps.epoch }
	elseif cmd == "verbose" then
		Sim.verbose = (args[1] or 1) ~= 0
		return "verbose " .. tostring(Sim.verbose)
	elseif cmd == "strike" and ps then
		-- the player's blow lands on an entity through the real path (contexts, break points, mercy)
		local e = S.entities[args[1]]
		if not e then return "no entity " .. tostring(args[1]) end
		e.invulnUntil = 0
		hitEntity(e, args[2] or 3, ps.x, ps.y, ps)
		local live = S.entities[e.id]
		return if live then ("%s hp %d state %s broken %s beatenBy %s"):format(e.id, e.hp, e.state, tostring(e.broken), tostring(e.beatenBy)) else e.id .. " dead"
	elseif cmd == "people" then
		local out = {}
		for i, t in ipairs(S.tribes) do
			if not args[1] or args[1] == i then
				for _, p in ipairs(Families.villagers(S.people, i)) do
					table.insert(out, ("%d %s %s (%s, %s, %s%s%s) %s"):format(p.id, p.first, p.last, p.sex, p.role, p.stage,
						if p.spouse then ", spouse " .. p.spouse else "", if p.father then ", child of " .. p.father else "", tostring(p.entity)))
				end
			end
		end
		return out
	elseif cmd == "family" then
		local p = S.people.people[args[1]]
		if not p then return "no person " .. tostring(args[1]) end
		local rel = {}
		for _, o in ipairs(Families.relatives(S.people, p)) do table.insert(rel, o.first .. " " .. o.last) end
		return { name = Families.fullName(p), alive = p.alive, cause = p.cause, killer = p.killer, born = p.born, spouse = p.spouse, father = p.father, mother = p.mother, children = table.concat(p.children, ","), relatives = table.concat(rel, ", ") }
	elseif cmd == "birth" then
		-- force: the first couple in the player's village (or village 1) conceives and gives birth now
		local ti = args[1] or 1
		local made = 0
		Families.formCouples(S.people, ti, S.day)
		for _, p in ipairs(Families.villagers(S.people, ti, true)) do
			if p.sex == "f" and p.spouse then
				p.stage, p.role, p.due = "pregnant", "pregnant", S.day
				local me = p.entity and S.entities[p.entity]
				if me then morph(me, "pregnant", { role = "pregnant", radius = 2 }) end
				made += 1
				break
			end
		end
		if made == 0 then return "no couple in village " .. ti end
		if args[2] == "now" then tickFamilies() return "born" end
		return "pregnant, due now: run `birth " .. ti .. " now` or wait for the daily tick"
	elseif cmd == "goal" and ps then
		-- `goal` reads the tutorial line, `goal 3` jumps to a stage, `goal 0` retires it
		if args[1] ~= nil then
			if args[1] == 0 then Sim.clearGoal(ps) else ps.goalStage = args[1] - 1 Sim.setGoal(ps, args[1]) end
		end
		return { stage = ps.goalStage, goal = ps.goal, done = ps.goalDone, metSurvivor = ps.metSurvivor, held = ps.selected }
	elseif cmd == "camp" and ps then
		return tostring(S.camps[ps.player.UserId] and (S.camps[ps.player.UserId].x .. "," .. S.camps[ps.player.UserId].y .. (if S.camps[ps.player.UserId].out then " out" else " lit")) or "none")
	end
	return "unknown command " .. tostring(cmd)
end


return Debug
