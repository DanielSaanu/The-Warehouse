--!strict
-- Seeded xorshift32. Pure Luau (no Roblox APIs) so world generation is reproducible and testable outside Studio.
local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { s: number }, Rng))

function Rng.new(seed: number): Rng
	local s = math.floor(seed) % 4294967296
	if s == 0 then s = 0x9E3779B9 end
	return setmetatable({ s = s }, Rng)
end

--- Next raw 32-bit value.
function Rng.nextU32(self: Rng): number
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x
end

--- Float in [0, 1).
function Rng.float(self: Rng): number
	return self:nextU32() / 4294967296
end

--- Integer in [lo, hi] inclusive.
function Rng.int(self: Rng, lo: number, hi: number): number
	return lo + math.floor(self:float() * (hi - lo + 1))
end

function Rng.chance(self: Rng, p: number): boolean
	return self:float() < p
end

function Rng.pick<T>(self: Rng, list: { T }): T
	return list[self:int(1, #list)]
end

--- Fork a child generator (for independent streams from one seed).
function Rng.fork(self: Rng, salt: number): Rng
	return Rng.new(bit32.bxor(self:nextU32(), math.floor(salt) * 2654435761 % 4294967296))
end

return Rng
