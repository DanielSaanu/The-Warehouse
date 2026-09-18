--!nonstrict
-- What happened in the world, for somebody who was not there (docs/ARCHITECTURE.md §8.6). A small ring of
-- world-level headlines in `meta.headlines` - NOT a diff per player: per-player anything in the world key is the
-- growth that kills it (§5). A player's own key holds `lastSeenDay`; on join, the headlines newer than that, from
-- the tribes that would actually tell them, become "You were gone eleven days. ...".
-- Owns: the ring's shape and its wording. Pure Luau. Writers: Tick.families (births - so catch-up writes them too),
-- Sim (deaths, calamities). A headline holds ids and kinds, never sentences: the words are made at read time, from
-- the registry, so a gravestone still has a name and nothing stale is ever saved.
--   Headlines.push(w.meta, { day = day, kind = "born", tribe = 1, id = baby.id })
--   local welcome = Headlines.welcome(w.meta, w.people, lastSeenDay, today, function(tribe) return true end, villageNames)
local Headlines = {}

Headlines.MAX = 64      -- ~40 B each in JSON: 2.5 KB of the world key, for ever
Headlines.SHOWN = 3     -- a welcome is a glance, not a newspaper

--- Add one. The oldest falls off the end.
function Headlines.push(meta, h)
	meta.headlines = meta.headlines or {}
	table.insert(meta.headlines, h)
	while #meta.headlines > Headlines.MAX do table.remove(meta.headlines, 1) end
end

local RANK = { died = 1, calamity = 2, born = 3 } -- a death matters more than a flood, a flood more than a birth

local function fullName(p): string
	return p.first .. " " .. p.last
end

--- One headline as a sentence, or nil if the registry no longer knows who it was about.
function Headlines.describe(h, people, villageNames: { [number]: string }): string?
	local where = h.tribe and villageNames[h.tribe]
	if h.kind == "calamity" then
		return if h.what == "flood" then "The river flooded the low ground." else "A beast tide came down from the north."
	end
	local p = h.id and people.people[h.id]
	if not p then return nil end
	if h.kind == "died" then
		local by = if p.killer and p.killer ~= "the wild" then " by " .. p.killer else "" -- the registry already keeps the killer, gravestones too
		return ("%s%s was killed%s."):format(fullName(p), if where then " of " .. where else "", by)
	elseif h.kind == "born" then
		local mother = p.mother and people.people[p.mother]
		if mother then return ("%s%s had a baby, %s."):format(fullName(mother), if where then " of " .. where else "", p.first) end
		return ("A baby, %s %s, was born%s."):format(p.first, p.last, if where then " in " .. where else "")
	end
	return nil
end

--- The welcome for somebody who last saw the world on `lastSeenDay`: { days, title, text, lines } or nil if they
--- were not gone a whole day. `tells(tribe)` says whether that tribe would tell this player its news (calamities
--- are everybody's). The most important SHOWN headlines, then newest first; `more` counts the rest. Each line is
--- { text, color } for Hud.notice.
function Headlines.welcome(meta, people, lastSeenDay: number, today: number, tells: (number) -> boolean, villageNames: { [number]: string })
	local days = today - lastSeenDay
	if days < 1 then return nil end
	local found = {}
	for i, h in ipairs(meta.headlines or {}) do
		if h.day > lastSeenDay and (h.kind == "calamity" or (h.tribe and tells(h.tribe))) then
			local text = Headlines.describe(h, people, villageNames)
			if text then table.insert(found, { h = h, text = text, i = i }) end
		end
	end
	table.sort(found, function(a, b)
		local ra, rb = RANK[a.h.kind] or 9, RANK[b.h.kind] or 9
		if ra ~= rb then return ra < rb end
		return a.i > b.i
	end)
	local shown = {}
	for i = 1, math.min(Headlines.SHOWN, #found) do shown[i] = found[i] end
	-- a massacre must not bury its own cause: three deaths in a beast tide would otherwise never mention the tide.
	-- The newest calamity always gets the last place if it did not earn one.
	local calamity, has = nil, false
	for _, f in ipairs(found) do
		if f.h.kind == "calamity" and (not calamity or f.i > calamity.i) then calamity = f end
	end
	for _, f in ipairs(shown) do if f == calamity then has = true end end
	if calamity and not has then shown[#shown] = calamity end
	local lines = {}
	for i, f in ipairs(shown) do lines[i] = { text = f.text, color = if f.h.kind == "born" then "good" else "warn" } end
	-- an honest empty: the world did tick, and nothing in it was news to this player
	if #lines == 0 then lines[1] = { text = "It was quiet while you were away.", color = "" } end
	return {
		days = days, title = "Welcome back",
		text = if days == 1 then "You were gone a day." else ("You were gone %d days."):format(days),
		lines = lines, more = math.max(0, #found - #shown),
	}
end

return Headlines
