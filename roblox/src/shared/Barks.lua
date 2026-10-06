--!strict
-- Barks: the short lines a group says to its riders on the road (docs/plans/rung3-part4-belonging.md, phase 2, "the
-- guidance layer"). Pure Luau, tested in test/luau/barks.test.luau. The server (server/Ride.lua) gathers the facts
-- each second, picks who says it (a member the rider can see) and shows "Name: line" as an ordinary text notice.
-- Three rules: the most specific line wins (the rule matching the most of the fact's fields, the Left 4 Dead way);
-- nothing is said twice in a row; a TEACHING line is said TEACH times a session, then its short form SHORT times,
-- then never again. The memory (`Barks.new`) lives on the player's session state and is never saved.
--   local mem = Barks.new()
--   local line, fact = Barks.pick(mem, { { fact = "hostile", kind = "wolf", dir = "east" } }, now)
local Barks = {}

Barks.TEACH = 3   -- a teaching line in full this many times a session
Barks.SHORT = 3   -- then its short form this many times, then nothing
Barks.EVERY = 3   -- seconds between any two barks to one rider: one at a time, never a wall of text
-- seconds before the same fact may be said again; `road` is also how long the road must have been quiet
Barks.GAP = { hostile = 8, prey = 8, hurt = 8, lag = 10, spooked = 12, joined = 0, near = 0, arrived = 0, down = 0, road = 45 } :: { [string]: number }
-- most urgent first: of the facts true this second, the first that can be said is the one said
Barks.ORDER = { "down", "hurt", "spooked", "hostile", "prey", "lag", "joined", "near", "arrived", "road" }

export type Fact = { fact: string, kind: string?, group: string?, dir: string?, dest: string?, home: string?,
	scarce: string?, name: string?, boss: string? }
export type Rule = { fact: string, kind: string?, group: string?, lines: { string }, short: string?, teach: boolean? }
export type Memory = { said: { [number]: number }, at: { [string]: number }, last: string?, lastAt: number?, start: number }

-- A blank ({dest}) is filled from the fact; a line whose blank the fact cannot fill is skipped.
Barks.RULES = {
	{ fact = "joined", lines = { "Stick close. Do as we do." }, short = "Stay close.", teach = true },
	{ fact = "joined", group = "caravan", lines = { "Stay by the master. Watch the road." }, short = "Stay close.", teach = true },
	{ fact = "joined", group = "squad", lines = { "Stay close. Hit what we hit." }, short = "Stay close.", teach = true },
	{ fact = "lag", lines = { "Keep up! We're waiting on you.", "Come on, we won't wait long." }, short = "Keep up!", teach = true },
	{ fact = "hostile", lines = { "Trouble ahead. Close up.", "Eyes up. Trouble, {dir}." }, short = "Trouble!", teach = true },
	{ fact = "hostile", kind = "wolf", lines = { "Wolves! Close up.", "Wolves, {dir}! Close up." }, short = "Wolves!", teach = true },
	{ fact = "hostile", kind = "bandit", lines = { "Bandits! Stand with us.", "Bandits, {dir}! Stand with us." }, short = "Bandits!", teach = true },
	{ fact = "hostile", kind = "bandit", group = "caravan", lines = { "Bandits! Guard the master!", "Bandits, {dir}! Guard the master!" },
		short = "Bandits!", teach = true },
	{ fact = "prey", lines = { "Deer, {dir}! Hit what we hit.", "Deer! With us, now." }, short = "Deer!", teach = true },
	{ fact = "spooked", lines = { "{boss}'s spooked. We hold here.", "We hold here a moment." }, short = "Holding.", teach = true },
	{ fact = "hurt", lines = { "You're bleeding. Eat something.", "You're hurt. Stay behind us." }, short = "Eat, if you can.", teach = true },
	{ fact = "down", lines = { "They got {name}!", "We lost one!" } },
	{ fact = "near", lines = { "{dest}'s close now.", "Nearly at {dest}." } },
	{ fact = "arrived", lines = { "{dest}. Made it.", "Made it." } },
	{ fact = "road", lines = { "{dest}'s short of {scarce}, they say.", "Quiet road. Stay sharp.", "Watch the long grass.",
		"Long way from {home} now." } },
} :: { Rule }

--- A fresh memory for one player's session. `now` is when the session started (road talk waits for a quiet road).
function Barks.new(now: number?): Memory
	return { said = {}, at = {}, last = nil, lastAt = nil, start = now or 0 }
end

--- How urgent a fact is: its place in ORDER (lower is more urgent).
function Barks.urgent(fact: string): number
	return table.find(Barks.ORDER, fact) or #Barks.ORDER + 1
end

--- The rule for a fact: of the rules for this fact whose every field matches, the one matching the most fields.
function Barks.ruleFor(f: Fact): number?
	local best, bestScore = nil, -1
	for i, r in ipairs(Barks.RULES) do
		if r.fact == f.fact and (r.kind == nil or r.kind == f.kind) and (r.group == nil or r.group == f.group) then
			local score = (if r.kind then 1 else 0) + (if r.group then 1 else 0)
			if score > bestScore then best, bestScore = i, score end
		end
	end
	return best
end

--- Fill a line's blanks from the fact, or nil if one cannot be filled.
local function fill(line: string, f: Fact): string?
	local missing = false
	local out = line:gsub("{(%w+)}", function(key: string): string
		local v = (f :: any)[key]
		if type(v) ~= "string" or v == "" then missing = true return "" end
		return v
	end)
	return if missing then nil else out
end

--- The line this rule says now, given how often it has been said; nil if it has faded or would repeat the last line.
local function lineOf(mem: Memory, i: number, f: Fact): string?
	local r = Barks.RULES[i]
	local n = mem.said[i] or 0
	if r.teach and n >= Barks.TEACH + Barks.SHORT then return nil end
	if r.teach and n >= Barks.TEACH then
		return if r.short and r.short ~= mem.last then r.short else nil
	end
	for k = 0, #r.lines - 1 do -- the variants in turn, starting after the one said last time
		local l = fill(r.lines[(n + k) % #r.lines + 1], f)
		if l and l ~= mem.last then return l end
	end
	return nil
end

--- Of the facts true this second, the one line to say (most urgent fact that can be said), and its fact. Records it
--- in `mem`. nil means say nothing: too soon after the last bark, faded, or it would repeat.
function Barks.pick(mem: Memory, facts: { Fact }, now: number): (string?, Fact?)
	if mem.lastAt and now - mem.lastAt < Barks.EVERY then return nil, nil end
	local sorted = table.clone(facts)
	table.sort(sorted, function(a, b) return Barks.urgent(a.fact) < Barks.urgent(b.fact) end)
	for _, f in ipairs(sorted) do
		local gap = Barks.GAP[f.fact] or 0
		local quiet = if f.fact == "road" then now - (mem.lastAt or mem.start) >= gap else true
		local due = mem.at[f.fact] == nil or now - mem.at[f.fact] >= gap
		local i = Barks.ruleFor(f)
		if quiet and due and i then
			local line = lineOf(mem, i, f)
			if line then
				mem.said[i] = (mem.said[i] or 0) + 1
				mem.at[f.fact], mem.last, mem.lastAt = now, line, now
				return line, f
			end
		end
	end
	return nil, nil
end

return Barks
