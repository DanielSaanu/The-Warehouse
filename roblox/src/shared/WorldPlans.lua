--!strict
-- The plans: every village layout and every "place between villages" as ASCII, one character per 16 x 16 tile, plus
-- the legend that says what each character puts down. PURE DATA plus one validator (`check`), so a reader can see
-- a village at a glance and a test can prove every multi-tile footprint is drawn right. WorldVillages and WorldPlaces
-- stamp these onto the map; nothing here touches a World (docs/plans/world-expansion.md "Build notes for step 2").
--
-- Legend. Ground: `.` grass, `,` tall grass, `p` path, `@` spawn (path), `F` farm, `Z` scorched. Walls: `W` wall,
-- `G` gate, `P` palisade, `Q` palisade gate (a gate on the template's edge is where a road leaves). Single tiles:
-- `h` the tribe's house (3 x 2, as Kenney drew it, anchored like the halls), `B` burnt house (3 x 2), `S` stall (exactly one), `b` bed (exactly one), `w` well, `c` firepit, `k` knights
-- post, `o` watchtower, `s` smokehouse, `d` drying rack, `x` loot heap, `g` cage, `n` hiring board, `l` lantern, `y` hay,
-- `v` woodpile, `e` scarecrow, `i` beehive, `m` awning, `t` landmark (totem / skull post), `T` tree (tree / pine / dead
-- tree), `R` boulder, `D` rubble. Multi-tile objects stand on their ANCHOR, the bottom-left tile of the footprint, and
-- the rest of the footprint is `=`: `A` hall (the farmers' castle 4 x 3; longhouse / war hall 3 x 2), `1` granary, `2` storehouse,
-- `3` tannery, `4` trophy hall, `5` windmill, `7` lookout tree, `8` tent, `9` muster ring (all 2 x 2). Places add:
-- `*` shrine, `u` ruined watchtower, `U` broken wall, `f` broken fence, `a` ash, `j` bones, `K` skull, `r` arrows,
-- `q` debris, `+` grave cross, `|` tombstone, `C` cold camp, `L` fallen log, `M` mushrooms, `0` abandoned tent (2 x 2),
-- `6` broken cart (2 x 1). Rows run north to south, so a footprint's `=` tiles sit ABOVE its anchor and to its right.
local TileTypes = require(script.Parent.TileTypes)

local WorldPlans = {}

export type Tile = { ground: string?, object: string?, tribe: { [string]: string }?, spawn: boolean?, gate: boolean?, bed: boolean?, stall: boolean?, body: boolean? }
export type Plan = { tribe: string, tier: string, x: number, y: number }

WorldPlans.LEGEND = {
	["."] = { ground = "grass" }, [","] = { ground = "tall_grass" }, ["p"] = { ground = "path" }, ["@"] = { ground = "path", spawn = true },
	["F"] = { ground = "farm" }, ["Z"] = { ground = "scorched" }, ["="] = { ground = "grass", body = true },
	["W"] = { object = "wall" }, ["G"] = { ground = "path", object = "gate", gate = true },
	["P"] = { object = "palisade" }, ["Q"] = { ground = "path", object = "palisade_gate", gate = true },
	["h"] = { tribe = { farmer = "hut", hunter = "hut_hunter", plunderer = "hut_plunderer" } },
	["t"] = { tribe = { farmer = "lantern_post", hunter = "totem", plunderer = "skull_post" } },
	["T"] = { tribe = { farmer = "tree", hunter = "pine", plunderer = "dead_tree" } },
	["A"] = { tribe = { farmer = "town_hall", hunter = "longhouse", plunderer = "war_hall" } },
	["B"] = { object = "hut_burnt" }, ["S"] = { object = "stall", stall = true }, ["b"] = { object = "bed", bed = true },
	["w"] = { object = "well" }, ["c"] = { object = "firepit" }, ["k"] = { object = "knights_post" }, ["o"] = { object = "watchtower" },
	["s"] = { object = "smokehouse" }, ["d"] = { object = "drying_rack" }, ["x"] = { object = "loot_heap" }, ["g"] = { object = "cage" },
	["n"] = { object = "hiring_board" }, ["l"] = { object = "lantern_post" }, ["y"] = { object = "hay_bale" }, ["v"] = { object = "woodpile" },
	["e"] = { object = "scarecrow" }, ["i"] = { object = "beehive" }, ["m"] = { object = "market_awning" }, ["R"] = { object = "boulder" },
	["D"] = { object = "rubble" }, ["1"] = { object = "granary" }, ["2"] = { object = "storehouse" }, ["3"] = { object = "tannery" },
	["4"] = { object = "trophy_hall" }, ["5"] = { object = "windmill" }, ["7"] = { object = "lookout_tree" }, ["8"] = { object = "tent" },
	["9"] = { object = "muster_ring" },
	-- the places between villages
	["*"] = { object = "roadside_shrine" }, ["u"] = { object = "ruined_watchtower" }, ["U"] = { object = "broken_wall" },
	["f"] = { object = "broken_fence" }, ["a"] = { ground = "scorched", object = "ash_pile" }, ["j"] = { object = "bones" },
	["K"] = { object = "skull" }, ["r"] = { object = "arrows_in_ground" }, ["q"] = { object = "battle_debris" },
	["+"] = { object = "grave_cross" }, ["|"] = { object = "tombstone" }, ["C"] = { object = "camp_out" }, ["L"] = { object = "fallen_log" },
	["M"] = { object = "mushrooms" }, ["0"] = { object = "abandoned_tent" }, ["6"] = { object = "broken_cart" },
} :: { [string]: Tile }

-- ---------- villages: three tribes, three tiers (docs/plans/world-expansion.md "Village tiers") ----------
WorldPlans.VILLAGES = {
	farmer = {
		-- The walled town, the start: towers at the corners, double gates north, east and south, a two-tile main street
		-- and a plaza at the crossing; plundered (two burnt huts, the wall breached in the south-west corner where the
		-- raiders broke in). Hall, granary, storehouse, windmill, well, market row, knights post, lantern-lit.
		large = {
			"oWWWWWWWGGWWWWWWWo",
			"W.FFFFF.pp.==....W",
			"WeFFFFF.pp.1=.===W",
			"W.====..pp....h==W",
			"W.====.lpp.==....W",
			"W.A===..pp.2=....W",
			"W.......pp..b.===W",
			"W.mSm..pppppp.h==W",
			"W.l....ppppppppppG",
			"W......pp@pppppppG",
			"W===...pppppp.===W",
			"WB==.l.lpp.w..h==W",
			"W===k...pp.......W",
			"WB==....pp.....==W",
			"WyFFFFF.pp.FFFF5=W",
			"W.FFFFF.pp.FFFFi.W",
			"DZ......pp.......W",
			"WZDWWWWWGGWWWWWWWo",
		},
		-- A village: huts, fields, a market stall, a store.
		mid = {
			".FFFpy===.",
			"eFFFp.h==.",
			"....p.==..",
			"===.p.2=.b",
			"h==p@ppppp",
			"....pS....",
			"===wp.===.",
			"h==.p.h==.",
			"FFF.p....i",
		},
		-- A hamlet: a few huts, one field, a well. No walls.
		small = {
			"===.FF.",
			"h==.FF.",
			"...p.b.",
			"ppp@ppp",
			".w.p===",
			".S.ph==",
		},
	},
	hunter = {
		-- The great lodge in the pines: two-tile ways crossing at the fire, longhouse, trophy hall, tannery, muster
		-- ground, lookout tree, hiring board, smokehouse.
		large = {
			"TTT,....pp..,TTTTT",
			"T===....pp.....==T",
			"Th==.d..pp.d...7=T",
			",.......pp......,T",
			"T===....pp....===T",
			"Th==.===pp.==.h==T",
			"Td...A==pp.4=...dT",
			"T.......pp.......T",
			"pppppppppppppppppp",
			"pppppppp@ppppppppp",
			"T.t...c.pp.c...s.T",
			"T....==.pp.==....T",
			"T....3=.pp.9=....T",
			"T===....pp.b..===T",
			"Th==.n..pp..S.h==T",
			"T,......pp......,T",
			"TTTT,...pp..,TTTTT",
		},
		-- A lodge: huts, a tannery, a totem, a muster ground.
		mid = {
			"T===.p===T",
			".h==.ph==.",
			".==.tp.d..",
			".3=..p...b",
			"ppppp@pppp",
			"....cp===.",
			"===..ph==.",
			"h==S.p.==.",
			".....p.9=T",
		},
		-- A camp: a few huts, a drying rack, a fire.
		small = {
			"T===..T",
			".h==.d.",
			"...p.b.",
			"ppp@ppp",
			".===.S.",
			"Th==.cT",
		},
	},
	plunderer = {
		-- The stronghold: a palisade with towers at the corners, double gates north and south, a two-tile way between
		-- them, a war hall, tents, cages, loot heaps, skull posts.
		large = {
			"oPPPPPQQPPPPPo",
			"P.==...pp....P",
			"P.8=...pp....P",
			"P......pp.===P",
			"P.....gpp.h==P",
			"P.===..pp....P",
			"P.A==..pp...xP",
			"Pg.....pp...xP",
			"Pt...c.pp.cgtP",
			"Pxx....@p....P",
			"Pxx....pp.===P",
			"Pb.....pp.h==P",
			"PS.....pp....P",
			"P......pp....P",
			"P......pp....P",
			"oPPPPPQQPPPPPo",
		},
		-- A camp: huts in a stockade, a lookout, stolen goods.
		mid = {
			"oPPPPQPPPo",
			"P....p...P",
			"P===.p===P",
			"Ph==.ph==P",
			"P.x..p.xtP",
			"P...c@c..P",
			"P....p..bP",
			"P===.p.gSP",
			"Ph==.p...P",
			"oPPPPQPPPo",
		},
		-- A hideout: two tents, a skull post, a loot pile.
		small = {
			"R.==.==",
			"..8=.8=",
			"t..p..x",
			"ppp@ppp",
			"c..pS.x",
			"R.bp..R",
		},
	},
} :: { [string]: { [string]: { string } } }

--- Where the sixteen villages go on a 256 x 256 map (Danzo's sketch, scaled to the real size by WorldVillages),
--- in the order they take in `world.villages`: the three capitals first, because the server still reads
--- `villages[1]` as the farmers' home, `[2]` the hunters', `[3]` the plunderers' until step 3 teaches it a list.
WorldPlans.PLANS = {
	{ tribe = "farmer", tier = "large", x = 58, y = 188 },
	{ tribe = "hunter", tier = "large", x = 205, y = 140 },
	{ tribe = "plunderer", tier = "large", x = 108, y = 24 },
	{ tribe = "farmer", tier = "mid", x = 100, y = 218 }, { tribe = "farmer", tier = "mid", x = 42, y = 132 },
	{ tribe = "farmer", tier = "small", x = 20, y = 228 }, { tribe = "farmer", tier = "small", x = 108, y = 168 },
	{ tribe = "farmer", tier = "small", x = 78, y = 244 },
	{ tribe = "hunter", tier = "mid", x = 226, y = 200 }, { tribe = "hunter", tier = "mid", x = 176, y = 92 },
	{ tribe = "hunter", tier = "small", x = 240, y = 98 }, { tribe = "hunter", tier = "small", x = 192, y = 236 },
	{ tribe = "plunderer", tier = "mid", x = 196, y = 40 },
	{ tribe = "plunderer", tier = "small", x = 40, y = 70 }, { tribe = "plunderer", tier = "small", x = 156, y = 72 },
	{ tribe = "plunderer", tier = "small", x = 240, y = 20 },
} :: { Plan }

-- ---------- the places between villages (ruins and debris art) ----------
WorldPlans.PLACES = {
	-- cycled in this order along the roads; the shrine stands one tile off the road, the rest further out
	order = { "shrine", "burnt_village", "ruined_watchtower", "abandoned_camp", "battlefield" },
	shrine = { "l.l", ".*.", ",.," },
	burnt_village = {
		"Z===.D.",
		"ZB==.a.",
		"f.ZZ===",
		".aZZB==",
		".ZDZZZ.",
	},
	ruined_watchtower = {
		".DU..",
		"UDuD.",
		"..D.U",
		".R...",
	},
	abandoned_camp = {
		".==.T.",
		".0=C..",
		"..j.6=",
		".T..,.",
	},
	battlefield = {
		",r.q.K,",
		".j+.r.|",
		"q.,j.q.",
		".r.|.j,",
		",.K.r.,",
	},
} :: { [string]: any }

--- Rows a sprite reaches above its footprint (a 48-tall house on 2 rows: 1). Kept here, next to the layouts that
--- must leave that row clear; the renderer reads the real sprite size from the sheet.
WorldPlans.OVERHANG = { hut = 1, hut_hunter = 1, hut_plunderer = 1, windmill = 1, knights_post = 1, smokehouse = 1, watchtower = 1,
	ruined_watchtower = 1, lookout_tree = 1, pine = 1, pine_tall = 1, tree_autumn = 1, dead_tree_tall = 2, roadside_shrine = 1 } :: { [string]: number }
--- What may stand on the row a roof hangs over: the wild things. Never a wall (Danzo: walls do not cut through houses).
WorldPlans.BEHIND_OK = { tree = true, pine = true, pine_tall = true, dead_tree = true, boulder = true, rubble = true, broken_wall = true } :: { [string]: boolean }

--- The object a template character puts down for this tribe, by name, or nil for none.
function WorldPlans.objectName(ch: string, tribe: string): string?
	local t = WorldPlans.LEGEND[ch]
	if not t then return nil end
	if t.tribe then return t.tribe[tribe] end
	return t.object
end

--- Prove a layout is drawable: rectangular, every character known, every multi-tile footprint inside the layout
--- and made of exactly its anchor plus `=` tiles, every `=` owned by exactly one anchor, and (for a village) one
--- spawn, one bed, one stall, and every walkable tile reachable from the spawn (no sealed pocket a merchant could
--- be put in). Returns nil when it is fine, else what is wrong.
function WorldPlans.check(rows: { string }, tribe: string, village: boolean): string?
	local th = #rows
	if th == 0 then return "empty" end
	local tw = #rows[1]
	local owners: { [string]: number } = {}
	local solid: { [string]: boolean } = {}   -- footprint tiles of solid anchors
	local spawns, beds, stalls = 0, 0, 0
	local spawnAt: { number }? = nil
	for r, row in ipairs(rows) do
		if #row ~= tw then return ("row %d is %d wide, row 1 is %d"):format(r, #row, tw) end
		for c = 1, tw do
			local ch = row:sub(c, c)
			local t = WorldPlans.LEGEND[ch]
			if not t then return ("unknown character %q at %d,%d"):format(ch, c, r) end
			if t.spawn then spawns += 1; spawnAt = { c, r } end
			if t.bed then beds += 1 end
			if t.stall then stalls += 1 end
			local name = WorldPlans.objectName(ch, tribe)
			if name and not t.body then
				local def = TileTypes.ObjectByName[name]
				if not def then return ("no object %q for %q"):format(name, ch) end
				if def.foot then
					for dy = 0, def.foot.h - 1 do
						for dx = 0, def.foot.w - 1 do
							local cc, rr = c + dx, r - dy
							if cc > tw or rr < 1 then return ("%s at %d,%d sticks out of the layout"):format(name, c, r) end
							local key = cc .. "," .. rr
							if owners[key] then return ("two footprints share %s"):format(key) end
							owners[key] = 1
							if def.solid then solid[key] = true end
							if not (dx == 0 and dy == 0) and rows[rr]:sub(cc, cc) ~= "=" then
								return ("%s at %d,%d needs '=' at %d,%d"):format(name, c, r, cc, rr)
							end
						end
					end
				end
			end
		end
	end
	for r, row in ipairs(rows) do
		for c = 1, tw do
			if row:sub(c, c) == "=" and not owners[c .. "," .. r] then return ("'=' at %d,%d belongs to no anchor"):format(c, r) end
		end
	end
	if village and (spawns ~= 1 or beds ~= 1 or stalls ~= 1) then
		return ("a village needs one spawn, one bed, one stall (has %d, %d, %d)"):format(spawns, beds, stalls)
	end
	-- a tall sprite's roof must not land on another building: it would hide its door (walls, trees and rock may sit
	-- behind a roof; that is just what is behind it)
	for r, row in ipairs(rows) do
		for c = 1, tw do
			local name = WorldPlans.objectName(row:sub(c, c), tribe)
			local over = if name then WorldPlans.OVERHANG[name] else nil
			if over and name then
				local def = TileTypes.ObjectByName[name]
				local fw, fh = if def.foot then def.foot.w else 1, if def.foot then def.foot.h else 1
				for k = 1, over do
					local rr = r - fh - k + 1
					for cc = c, c + fw - 1 do
						if rr >= 1 and cc <= tw then
							local ch = rows[rr]:sub(cc, cc)
							local under = WorldPlans.objectName(ch, tribe)
							local tower = name == "watchtower" and (under == "wall" or under == "palisade") -- a tower stands IN the wall
							if ch == "=" or (under and not WorldPlans.BEHIND_OK[under] and not tower) then
								return ("%s at %d,%d hangs its roof over %s at %d,%d"):format(name, c, r, under or "a footprint", cc, rr)
							end
						end
					end
				end
			end
		end
	end
	-- every tile a person can stand on connects to the spawn inside the layout itself
	if village and spawnAt then
		local function open(c: number, r: number): boolean
			if c < 1 or r < 1 or c > tw or r > th then return false end
			local ch = rows[r]:sub(c, c)
			local t = WorldPlans.LEGEND[ch]
			if not t then return false end
			local g = TileTypes.GroundByName[t.ground or "grass"]
			if not g or not g.walk then return false end
			if t.body then return not solid[c .. "," .. r] end
			local name = WorldPlans.objectName(ch, tribe)
			local def = if name then TileTypes.ObjectByName[name] else nil
			return not (def and def.solid)
		end
		local seen: { [string]: boolean } = { [spawnAt[1] .. "," .. spawnAt[2]] = true }
		local queue = { spawnAt }
		while #queue > 0 do
			local cur = table.remove(queue) :: { number }
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local c, r = cur[1] + d[1], cur[2] + d[2]
				local key = c .. "," .. r
				if not seen[key] and open(c, r) then seen[key] = true; table.insert(queue, { c, r }) end
			end
		end
		for r = 1, th do
			for c = 1, tw do
				if open(c, r) and not seen[c .. "," .. r] then return ("tile %d,%d is a sealed pocket"):format(c, r) end
			end
		end
	end
	return nil
end

return WorldPlans
