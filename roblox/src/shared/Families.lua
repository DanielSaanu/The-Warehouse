--!strict
-- Families (DESIGN.md §15): every person is a record with parents, children, birth day and, when it comes, death
-- day and cause. The human clock runs on the in-game calendar: a village with room and a couple conceives about
-- once a week; the mother is `pregnant` for a week; the `baby` exists for two weeks; then an adult villager who
-- can take a role. Villages refill by births only. Pure Luau: the server (Sim.lua) calls these on its clock and
-- turns the results into entities. Deterministic given an Rng.
local Rng = require(script.Parent.Rng)
local Names = require(script.Parent.Names)

local Families = {}

Families.GESTATION_DAYS = 7      -- pregnant for one in-game week (70 real minutes)
Families.BABY_DAYS = 14          -- a baby for two weeks
Families.CONCEIVE_CHANCE = 0.5   -- per couple per weekly roll, when the village has room
Families.REPAIR_DAYS = 30        -- widows and widowers re-pair after a month
-- Living named people per tribe, above which nobody conceives. It counts EVERYONE (guards and fighters too), so it
-- has to sit above the starting rosters in Sim's ROSTER (farmer 14, hunter 13, plunderer 12) or nobody is ever
-- born: at a flat 9 the family system idled from day 1 and a village could only shrink. Farmers are the biggest
-- tribes (ideas/INBOX.md), so they get the most room. 18 + 15 + 14 = 47, inside DESIGN §4's 60 people.
Families.MAX_PEOPLE = { farmer = 18, hunter = 15, plunderer = 14 } :: { [string]: number }

function Families.cap(tribeType: string?): number
	return Families.MAX_PEOPLE[tribeType or "farmer"] or Families.MAX_PEOPLE.farmer
end

export type Person = {
	id: number, first: string, last: string, sex: string, -- "m" | "f"
	tribe: number, village: number, -- the village ID (its index in world.villages), never its name: names are derived from the seed
	role: string,                   -- villager | guard | merchant | survivor | pregnant | baby | (group kinds)
	stage: string,                  -- adult | pregnant | baby
	born: number, alive: boolean, died: number?, cause: string?, killer: string?,
	father: number?, mother: number?, children: { number },
	spouse: number?, widowed: number?,
	due: number?,                   -- pregnant: the day the baby comes
	grown: number?,                 -- baby: the day it becomes an adult
	entity: string?,                -- the live entity id, if any
	group: string?,                 -- on the road with this group (caravan / squad / band): a person, but not a villager
}
export type Registry = { people: { [number]: Person }, nextId: number }

function Families.new(): Registry
	return { people = {}, nextId = 0 }
end

function Families.add(reg: Registry, p: {
	first: string, last: string, sex: string, tribe: number, village: number, role: string, born: number,
	father: number?, mother: number?, stage: string?,
}): Person
	reg.nextId += 1
	local person: Person = {
		id = reg.nextId, first = p.first, last = p.last, sex = p.sex, tribe = p.tribe, village = p.village,
		role = p.role, stage = p.stage or "adult", born = p.born, alive = true, died = nil, cause = nil, killer = nil,
		father = p.father, mother = p.mother, children = {}, spouse = nil, widowed = nil, due = nil, grown = nil, entity = nil,
	}
	reg.people[person.id] = person
	if p.father and reg.people[p.father] then table.insert(reg.people[p.father].children, person.id) end
	if p.mother and reg.people[p.mother] then table.insert(reg.people[p.mother].children, person.id) end
	return person
end

function Families.fullName(p: Person): string
	return p.first .. " " .. p.last
end

--- A fresh adult for a village: random first name, a surname from the village's pool (or a given one), random sex.
function Families.newAdult(reg: Registry, rng: Rng.Rng, tribe: number, village: number, role: string, born: number, surname: string?, sex: string?): Person
	local first, last = Names.person(rng, surname)
	return Families.add(reg, { first = first, last = last, sex = sex or (if rng:chance(0.5) then "m" else "f"), tribe = tribe, village = village, role = role, born = born })
end

--- Everyone alive AT HOME in a village (optionally only adults). People out with a group are of the tribe - they
--- keep its surnames, and `relatives` finds them - but they are on the road: they do not count toward the village's
--- cap, pair off, conceive or inherit a post. Without this the squad's four hunters would put Kenstow over its cap.
function Families.villagers(reg: Registry, tribe: number, adultsOnly: boolean?): { Person }
	local out: { Person } = {}
	for _, p in pairs(reg.people) do
		if p.alive and p.tribe == tribe and not p.group and (not adultsOnly or p.stage == "adult") then table.insert(out, p) end
	end
	table.sort(out, function(a: Person, b: Person) return a.id < b.id end)
	return out
end

local function related(a: Person, b: Person): boolean
	if a.last == b.last then return true end
	if a.father and (a.father == b.father or a.father == b.id) then return true end
	if a.mother and (a.mother == b.mother or a.mother == b.id) then return true end
	if b.father == a.id or b.mother == a.id then return true end
	return false
end

--- Pair up unattached adults of a village: one man, one woman, unrelated. Widows re-pair after REPAIR_DAYS.
function Families.formCouples(reg: Registry, tribe: number, day: number): number
	local formed = 0
	local adults = Families.villagers(reg, tribe, true)
	local free: { Person } = {}
	for _, p in ipairs(adults) do
		local canPair = p.spouse == nil and p.stage == "adult" and (p.widowed == nil or day - p.widowed >= Families.REPAIR_DAYS)
		if canPair then table.insert(free, p) end
	end
	for _, a in ipairs(free) do
		if a.spouse == nil and a.sex == "m" then
			for _, b in ipairs(free) do
				if b.spouse == nil and b.sex == "f" and not related(a, b) then
					a.spouse, b.spouse = b.id, a.id
					formed += 1
					break
				end
			end
		end
	end
	return formed
end

--- The weekly roll: a village with room and a couple may conceive. Returns the mothers who fell pregnant.
function Families.weeklyConceive(reg: Registry, rng: Rng.Rng, tribe: number, day: number, tribeType: string?): { Person }
	local out: { Person } = {}
	local cap = Families.cap(tribeType)
	local alive = Families.villagers(reg, tribe)
	-- babies on the way count toward the cap
	local expecting = 0
	for _, p in ipairs(alive) do if p.stage == "pregnant" then expecting += 1 end end
	if #alive + expecting >= cap then return out end
	for _, p in ipairs(alive) do
		if p.sex == "f" and p.stage == "adult" and p.spouse and reg.people[p.spouse] and reg.people[p.spouse].alive and rng:chance(Families.CONCEIVE_CHANCE) then
			p.stage, p.role, p.due = "pregnant", "pregnant", day + Families.GESTATION_DAYS
			table.insert(out, p)
			if #alive + expecting + #out >= cap then break end
		end
	end
	return out
end

--- Daily: births come due, babies grow up. Returns { born = { babies }, grown = { adults } }.
function Families.daily(reg: Registry, rng: Rng.Rng, day: number): { born: { Person }, grown: { Person } }
	local born: { Person }, grown: { Person } = {}, {}
	for _, p in pairs(reg.people) do
		if p.alive and p.stage == "pregnant" and p.due and day >= p.due then
			local father = p.spouse and reg.people[p.spouse]
			local last = if father then father.last else p.last
			local baby = Families.add(reg, {
				first = Names.first(rng), last = last, sex = if rng:chance(0.5) then "m" else "f", tribe = p.tribe, village = p.village,
				role = "baby", stage = "baby", born = day, father = if father then father.id else nil, mother = p.id,
			})
			baby.grown = day + Families.BABY_DAYS
			p.stage, p.role, p.due = "adult", "villager", nil
			table.insert(born, baby)
		end
	end
	for _, p in pairs(reg.people) do
		if p.alive and p.stage == "baby" and p.grown and day >= p.grown then
			p.stage, p.role, p.grown = "adult", "villager", nil
			table.insert(grown, p)
		end
	end
	return { born = born, grown = grown }
end

--- Record a death. The spouse is widowed; the family tree keeps the person.
function Families.die(reg: Registry, id: number, day: number, cause: string, killer: string?)
	local p = reg.people[id]
	if not p or not p.alive then return end
	p.alive, p.died, p.cause, p.killer, p.entity = false, day, cause, killer, nil
	if p.spouse then
		local s = reg.people[p.spouse]
		if s then s.spouse, s.widowed = nil, day end
		p.spouse = nil
	end
end

--- Who takes a dead role-holder's place: a living adult relative first (same surname), else any adult villager.
function Families.successor(reg: Registry, dead: Person): Person?
	local adults = Families.villagers(reg, dead.tribe, true)
	local fallback: Person? = nil
	for _, p in ipairs(adults) do
		if p.role == "villager" then
			if p.last == dead.last then return p end
			fallback = fallback or p
		end
	end
	return fallback
end

--- Living relatives of a person (parents, children, spouse, same surname in the village), for gossip later.
function Families.relatives(reg: Registry, p: Person): { Person }
	local out: { Person } = {}
	for _, o in pairs(reg.people) do
		if o.id ~= p.id and o.alive and o.tribe == p.tribe and related(o, p) then table.insert(out, o) end
	end
	table.sort(out, function(a: Person, b: Person) return a.id < b.id end)
	return out
end

--- One line about a family event, for the village's knowledge bank.
function Families.describeBirth(baby: Person, mother: Person): string
	return ("%s %s had a baby. %s, they're calling it."):format(mother.first, mother.last, baby.first)
end

return Families
