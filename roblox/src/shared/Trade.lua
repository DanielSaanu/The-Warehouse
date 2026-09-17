--!strict
-- Trade: four goods and coin. Prices are per village, move with stock, and take a multiplier from the player's
-- standing there (DESIGN.md §6). Each tribe type overproduces one good and needs another.
local Items = require(script.Parent.Items)

local Trade = {}

export type Stock = { [string]: number }

--- Comfortable stock levels per tribe type. Stock above this is cheap, below it is dear.
Trade.TARGET = {
	farmer = { food = 30, hide = 5, tool = 8, ore = 4 },
	hunter = { food = 10, hide = 25, tool = 5, ore = 6 },
	plunderer = { food = 4, hide = 8, tool = 10, ore = 12 },
} :: { [string]: Stock }

--- The good each tribe makes (restocks daily) and the one it never has enough of.
Trade.MAKES = { farmer = "food", hunter = "hide", plunderer = "ore" } :: { [string]: string }
Trade.NEEDS = { farmer = "tool", hunter = "food", plunderer = "food" } :: { [string]: string }

Trade.CAMPER_SET_PRICE = 15
--- Who sells camper sets (the first thing that gives you a reason to earn coin).
Trade.SELLS_CAMPER = { farmer = true, hunter = true } :: { [string]: boolean }

function Trade.newStock(tribeType: string): Stock
	local s: Stock = {}
	for good, n in pairs(Trade.TARGET[tribeType] or Trade.TARGET.farmer) do s[good] = n end
	return s
end

--- What the merchant charges you for one unit.
function Trade.buyPrice(good: string, stock: Stock, tribeType: string, repMult: number): number
	local base = Items.def(good).price or 1
	local target = (Trade.TARGET[tribeType] or Trade.TARGET.farmer)[good] or 10
	local have = stock[good] or 0
	local scarcity = math.clamp(1 + 0.6 * (target - have) / target, 0.5, 2.5)
	return math.max(1, math.round(base * scarcity * repMult))
end

--- What the merchant pays you for one unit (they take a cut; more when they already have plenty).
function Trade.sellPrice(good: string, stock: Stock, tribeType: string, repMult: number): number
	local buy = Trade.buyPrice(good, stock, tribeType, repMult)
	return math.max(1, math.floor(buy * 0.6))
end

function Trade.camperPrice(tribeType: string, repMult: number): number?
	if not Trade.SELLS_CAMPER[tribeType] then return nil end
	return math.max(1, math.round(Trade.CAMPER_SET_PRICE * repMult))
end

--- Daily economy: the tribe makes its good, consumes its need, and everything drifts toward target.
function Trade.dailyRestock(stock: Stock, tribeType: string)
	local target = Trade.TARGET[tribeType] or Trade.TARGET.farmer
	local makes, needs = Trade.MAKES[tribeType], Trade.NEEDS[tribeType]
	for good, t in pairs(target) do
		local have = stock[good] or 0
		if good == makes then
			have = math.min(math.floor(t * 1.5), have + math.max(1, math.floor(t * 0.15)))
		elseif good == needs then
			have = math.max(0, have - 1)
		end
		-- everyone trades a little on their own: drift a tenth of the way to target
		have += (t - have) * 0.1
		stock[good] = math.max(0, math.round(have))
	end
end

--- Price sheet for a UI or a merchant's talk line.
export type Quote = { good: string, label: string, buy: number, sell: number, stock: number }
function Trade.quotes(stock: Stock, tribeType: string, repMult: number): { Quote }
	local out: { Quote } = {}
	local goods: { string } = Items.GOODS
	for _, good in ipairs(goods) do
		table.insert(out, { good = good, label = Items.def(good).label, buy = Trade.buyPrice(good, stock, tribeType, repMult), sell = Trade.sellPrice(good, stock, tribeType, repMult), stock = stock[good] or 0 })
	end
	return out
end

return Trade
