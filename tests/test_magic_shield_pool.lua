local Pool = assert(loadfile("src/shared/Modules/MagicShieldPool.luau"))()

local partial = { { Kind = "Shield", Amount = 10 } }
local remaining, absorbed, broken = Pool.consume(partial, 4)
assert(remaining == 0 and absorbed == 4, "Partial shield absorption should absorb the incoming hit")
assert(#broken == 0 and partial[1].Amount == 6, "A partly filled pool should not break")

local stacked = {
	{ Kind = "Shield", Amount = 4, ExpiresAt = 1 },
	{ Kind = "Slow", Amount = 100 },
	{ Kind = "Shield", Amount = 10, ExpiresAt = 2 },
}
remaining, absorbed, broken = Pool.consume(stacked, 7)
assert(remaining == 0 and absorbed == 7, "Stacked shields should absorb in caller-provided order")
assert(#broken == 1 and broken[1] == stacked[1], "Only the depleted shield should be returned")
assert(stacked[3].Amount == 7, "The later shield should only absorb the remaining damage")

local both = { { Kind = "Shield", Amount = 3 }, { Kind = "Shield", Amount = 5 } }
remaining, absorbed, broken = Pool.consume(both, 12)
assert(remaining == 4 and absorbed == 8, "Damage beyond all shields should pass through")
assert(#broken == 2, "One hit can break multiple shield pools")

remaining, absorbed, broken = Pool.consume({}, 0)
assert(remaining == 0 and absorbed == 0 and #broken == 0, "Zero damage should not break a shield")

print("Magic shield pool tests passed")
