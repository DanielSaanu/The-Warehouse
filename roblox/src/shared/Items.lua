--!strict
-- Items and the 10-slot inventory. Goods stack; coin is a counter, not a slot. Pure Luau.
local Items = {}

export type Def = { name: string, label: string, sprite: string, stack: number, atk: number?, good: boolean?, price: number? }
export type Slot = { item: string, n: number }
export type Inventory = { slots: { Slot }, coin: number }

Items.SLOTS = 10

Items.Defs = {
	knife = { name = "knife", label = "knife", sprite = "item_knife", stack = 1, atk = 2 },
	waterskin = { name = "waterskin", label = "waterskin", sprite = "item_waterskin", stack = 1 },
	food = { name = "food", label = "food", sprite = "item_food", stack = 10, good = true, price = 3 },
	hide = { name = "hide", label = "hides", sprite = "item_hide", stack = 10, good = true, price = 6 },
	tool = { name = "tool", label = "tools", sprite = "item_tool", stack = 5, good = true, price = 8 },
	ore = { name = "ore", label = "ore", sprite = "item_ore", stack = 10, good = true, price = 6 },
	camper_set = { name = "camper_set", label = "camper set", sprite = "item_camper", stack = 2, price = 15 },
} :: { [string]: Def }

Items.GOODS = { "food", "hide", "tool", "ore" }

function Items.def(name: string): Def
	local d = Items.Defs[name]
	assert(d, "unknown item " .. tostring(name))
	return d
end

function Items.new(): Inventory
	return { slots = {}, coin = 0 }
end

--- What a person grabs when their village is plundered (DESIGN.md §11).
function Items.dayOneKit(): Inventory
	local inv = Items.new()
	Items.add(inv, "knife", 1)
	Items.add(inv, "waterskin", 1)
	Items.add(inv, "food", 2)
	Items.add(inv, "camper_set", 1)
	return inv
end

function Items.count(inv: Inventory, item: string): number
	local n = 0
	for _, s in ipairs(inv.slots) do
		if s.item == item then n += s.n end
	end
	return n
end

--- Add up to n of an item. Returns how many fitted (stacks fill first, then empty slots).
function Items.add(inv: Inventory, item: string, n: number): number
	local def = Items.def(item)
	local left = n
	for _, s in ipairs(inv.slots) do
		if left <= 0 then break end
		if s.item == item and s.n < def.stack then
			local take = math.min(left, def.stack - s.n)
			s.n += take
			left -= take
		end
	end
	while left > 0 and #inv.slots < Items.SLOTS do
		local take = math.min(left, def.stack)
		table.insert(inv.slots, { item = item, n = take })
		left -= take
	end
	return n - left
end

--- Remove n of an item. Returns false (and removes nothing) if there are not enough.
function Items.remove(inv: Inventory, item: string, n: number): boolean
	if Items.count(inv, item) < n then return false end
	local left = n
	for i = #inv.slots, 1, -1 do
		if left <= 0 then break end
		local s = inv.slots[i]
		if s.item == item then
			local take = math.min(left, s.n)
			s.n -= take
			left -= take
			if s.n == 0 then table.remove(inv.slots, i) end
		end
	end
	return true
end

--- Space left for an item (stack room plus empty slots).
function Items.room(inv: Inventory, item: string): number
	local def = Items.def(item)
	local room = (Items.SLOTS - #inv.slots) * def.stack
	for _, s in ipairs(inv.slots) do
		if s.item == item then room += def.stack - s.n end
	end
	return room
end

--- Attack bonus of the best weapon carried.
function Items.weaponAtk(inv: Inventory): number
	local best = 0
	for _, s in ipairs(inv.slots) do
		local d = Items.Defs[s.item]
		if d and d.atk and d.atk > best then best = d.atk end
	end
	return best
end

--- Everything a corpse leaves behind: the goods and gear, not the coin (coin is lost).
function Items.dropAll(inv: Inventory): { Slot }
	local dropped = inv.slots
	inv.slots = {}
	inv.coin = 0
	return dropped
end

--- Plain copy for sending over a remote.
function Items.snapshot(inv: Inventory): Inventory
	local slots = {}
	for i, s in ipairs(inv.slots) do slots[i] = { item = s.item, n = s.n } end
	return { slots = slots, coin = inv.coin }
end

return Items
