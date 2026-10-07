-- shared/Barks.lua: what a group says to its riders on the road (docs/plans/rung3-part4-belonging.md, phase 2).
-- The three rules the plan's done-when names: the most specific line wins, no line twice in a row, a teaching line
-- goes quiet after three. Plus the order between facts, the gaps, and the fade being session memory only.
local Barks = __require("Barks")
local Belong = __require("Belong")
local Talk = __require("Talk")

local function words(s: string): number
	local n = 0
	for _ in s:gmatch("%S+") do n += 1 end
	return n
end

-- ---------- every line is a bark: short ----------
for _, r in ipairs(Barks.RULES) do
	for _, l in ipairs(r.lines) do assert(words(l) <= 7, "a bark is short: " .. l) end
	if r.short then assert(words(r.short) <= 4, "the short form is shorter: " .. r.short) end
end
for _, f in ipairs({ "joined", "lag", "hostile", "prey", "near", "arrived", "down", "hurt" }) do
	assert(table.find(Barks.ORDER, f), "the plan's first eight facts are all there: " .. f)
end

-- ---------- the most specific line wins ----------
local mem = Barks.new()
local line, fact = Barks.pick(mem, { { fact = "hostile", kind = "wolf", group = "caravan" } }, 0)
assert(fact and fact.fact == "hostile" and line and line:find("Wolves"), "a wolf is wolves, not trouble: " .. tostring(line))
mem = Barks.new()
line = Barks.pick(mem, { { fact = "hostile", kind = "bandit", group = "caravan" } }, 0)
assert(line and line:find("master"), "bandits on the caravan: guard the master: " .. tostring(line))
mem = Barks.new()
line = Barks.pick(mem, { { fact = "hostile", kind = "bandit", group = "squad" } }, 0)
assert(line and line:find("Bandits") and not line:find("master"), "bandits on the squad: no master to guard")
-- H11 Studio: the master himself must never say "Guard the master!"; spoken by the leader, a member-only line yields
-- to the next most specific ("Bandits! Stand with us."), every time, through the fade too
mem = Barks.new()
for k = 1, 10 do
	line = Barks.pick(mem, { { fact = "hostile", kind = "bandit", group = "caravan", leader = true } }, k * 100)
	assert(line == nil or not line:find("master"), "the master does not tell you to guard himself: " .. tostring(line))
	if k == 1 then assert(line and line:find("Bandits"), "he still calls the bandits: " .. tostring(line)) end
end
mem = Barks.new()
line = Barks.pick(mem, { { fact = "hostile", kind = "boar", group = "squad" } }, 0)
assert(line == Barks.RULES[Barks.ruleFor({ fact = "hostile" })].lines[1], "nothing more specific: the plain hostile line")

-- ---------- between facts, the urgent one wins, and only one is said ----------
mem = Barks.new()
line, fact = Barks.pick(mem, { { fact = "near", dest = "Kenstow" }, { fact = "down" }, { fact = "hostile", kind = "wolf" } }, 0)
assert(fact.fact == "down", "a member down outranks wolves and the end of the road")
assert(Barks.urgent("down") < Barks.urgent("hostile") and Barks.urgent("hostile") < Barks.urgent("road"), "the order")

-- ---------- a teaching line: three times, then the short form, then nothing ----------
mem = Barks.new()
local said = {}
local t = 0
for _ = 1, 20 do
	t += 100 -- past every gap
	local l = Barks.pick(mem, { { fact = "lag" } }, t)
	if l then table.insert(said, l) end
	Barks.pick(mem, { { fact = "road", dest = "Kenstow", scarce = "food", home = "Glenworth" } }, t + 50) -- something between
end
local lagRule = Barks.RULES[Barks.ruleFor({ fact = "lag" })]
assert(#said == Barks.TEACH + Barks.SHORT, ("lag said %d times, then quiet"):format(#said))
for i = 1, Barks.TEACH do assert(table.find(lagRule.lines, said[i]), "the full line first: " .. said[i]) end
for i = Barks.TEACH + 1, #said do assert(said[i] == lagRule.short, "then the short form: " .. said[i]) end
assert(Barks.pick(mem, { { fact = "lag" } }, t + 1000) == nil, "and then nothing, for the rest of the session")
-- news never fades: a member down is said every time it happens
mem = Barks.new()
for i = 1, 8 do assert(Barks.pick(mem, { { fact = "down", name = if i % 2 == 0 then "Tam" else "Bera" } }, i * 100), "down " .. i) end

-- ---------- nothing said twice in a row ----------
mem = Barks.new()
-- (Ride always sends where it is: the second wolf line names the way)
local a = Barks.pick(mem, { { fact = "hostile", kind = "wolf", dir = "east" } }, 0)
local b = Barks.pick(mem, { { fact = "hostile", kind = "wolf", dir = "east" } }, 100)
assert(a and b and a ~= b, "the second wolf gets the other line: " .. tostring(a) .. " / " .. tostring(b))
mem = Barks.new()
mem.last = "Made it."
assert(Barks.pick(mem, { { fact = "arrived", dest = "Kenstow", home = "Glenworth" } }, 0) ~= "Made it.", "never the last line again")
-- a single-line rule says nothing rather than repeat, and that costs it nothing
mem = Barks.new()
local first = Barks.pick(mem, { { fact = "spooked" } }, 0)
local n = mem.said[Barks.ruleFor({ fact = "spooked" })]
if #Barks.RULES[Barks.ruleFor({ fact = "spooked" })].lines == 1 then
	assert(Barks.pick(mem, { { fact = "spooked" } }, 100) == nil, "one line, just said: silence")
	assert(mem.said[Barks.ruleFor({ fact = "spooked" })] == n, "and the silence is not counted")
end
assert(first, "the master spooked is said (QA phase 1 deferred: a ride held with no word)")

-- ---------- gaps: the same fact is not said every second ----------
mem = Barks.new()
assert(Barks.pick(mem, { { fact = "hostile", kind = "wolf" } }, 0), "the first wolf")
assert(Barks.pick(mem, { { fact = "hostile", kind = "wolf" } }, Barks.GAP.hostile - 1) == nil, "not again within the gap")
assert(Barks.pick(mem, { { fact = "hurt" } }, 1) == nil, "nor anything within the gap between any two barks")
assert(Barks.pick(mem, { { fact = "hurt" } }, Barks.EVERY) ~= nil, "after it, another fact may speak")
-- road talk waits for a quiet road
mem = Barks.new()
assert(Barks.pick(mem, { { fact = "road", dest = "Kenstow", scarce = "food", home = "Glenworth" } }, 5) == nil, "not straight away")
local road = Barks.pick(mem, { { fact = "road", dest = "Kenstow", scarce = "food", home = "Glenworth" } }, Barks.GAP.road)
assert(road and not road:find("{"), "road talk on a quiet road, every blank filled: " .. tostring(road))

-- ---------- blanks are filled from the fact ----------
mem = Barks.new()
line = Barks.pick(mem, { { fact = "near", dest = "Kenstow" } }, 0)
assert(line and line:find("Kenstow"), "the end near names it: " .. tostring(line))
mem = Barks.new()
line = Barks.pick(mem, { { fact = "down", name = "Tam" } }, 0)
assert(line and line:find("Tam"), "a member down is named: " .. tostring(line))
mem = Barks.new()
line = Barks.pick(mem, { { fact = "down" } }, 0)
assert(line and not line:find("{"), "and without a name, no blank shows: " .. tostring(line))

-- ---------- "what now": the plan and how far, from the leader; what they know, from a member ----------
local lead = Talk.whatNow("leader", { kind = "caravan", dest = "Kenstow", home = "Glenworth", left = 40 })
assert(lead:find("Kenstow") and lead:find("40") and lead:find("bandit"), "the leader: where, how far, the job: " .. lead)
local mem2 = Talk.whatNow("member", { kind = "caravan", dest = "Kenstow", home = "Glenworth", left = 40, boss = "Bram" })
assert(mem2:find("Bram") and mem2:find("Kenstow"), "a member: what the boss said: " .. mem2)
assert(Talk.whatNow("leader", { kind = "caravan", dest = "Kenstow", home = "Glenworth", left = 0, pause = true }):find("rest"),
	"at an end: rest, then back")
assert(Talk.whatNow("leader", { kind = "squad", dest = "the woods", home = "Kenstow", left = 20 }):find("deer"), "the squad: deer")
assert(Talk.whatNow("leader", { kind = "squad", dest = "Kenstow", home = "Kenstow", left = 20, homeward = true }):find("home"),
	"the squad laden: home")
assert(Talk.whatNow("member", { kind = "squad", dest = "the woods", home = "Kenstow", left = 4, boss = "Maren" }):find("Not far"),
	"close: not far now")
assert(Talk.TOPIC_LABELS.whatnow, "the client gets a label for 'what now'")

-- ---------- a walk-off is remembered on the re-ask, and the line teaches why (QA phase 1 deferred) ----------
local f = { kind = "caravan", busy = false, askedToday = true, walkedOff = true, riders = 0, cap = 2, grudge = 0,
	groupRep = 20, villageRep = 20, farmerRep = 20 }
assert(Belong.ask(f) == "walked", "asked again after walking off: they say so")
f.walkedOff = false
assert(Belong.ask(f) == "asked", "a plain no is still 'I gave you my answer'")
assert(Talk.joinNo("walked", { dest = "", home = "" }) == "You walked off on us. Not today.", "the line")

print("    barks ok")
