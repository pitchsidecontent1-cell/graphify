--!strict
-- Deterministic PRNG (so the map is identical whether it's baked into the
-- place file or built live on the server). Not for gameplay rolls.

export type Rng = {
	Next: (self: Rng) -> number,
	Range: (self: Rng, min: number, max: number) -> number,
	Int: (self: Rng, min: number, max: number) -> number,
	Pick: <T>(self: Rng, list: { T }) -> T,
	Chance: (self: Rng, p: number) -> boolean,
}

local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number): Rng
	local self = setmetatable({ _state = math.floor(seed) % 2147483647 }, Rng)
	if self._state <= 0 then
		self._state += 2147483646
	end
	return (self :: any) :: Rng
end

-- Park-Miller minimal standard generator
function Rng.Next(self: any): number
	self._state = (self._state * 16807) % 2147483647
	return (self._state - 1) / 2147483646
end

function Rng.Range(self: any, min: number, max: number): number
	return min + (max - min) * Rng.Next(self)
end

function Rng.Int(self: any, min: number, max: number): number
	return math.min(max, min + math.floor(Rng.Next(self) * (max - min + 1)))
end

function Rng.Pick(self: any, list: { any }): any
	return list[Rng.Int(self, 1, #list)]
end

function Rng.Chance(self: any, p: number): boolean
	return Rng.Next(self) < p
end

return Rng
