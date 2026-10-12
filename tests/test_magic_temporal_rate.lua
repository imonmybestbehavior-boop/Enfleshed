local rate = assert(loadfile("src/shared/Modules/MagicTemporalRate.luau"))()

assert(rate.clamp(0.5) == 0.5)
assert(rate.clamp(0) == rate.Minimum)
assert(rate.clamp(3) == rate.Maximum)
assert(rate.clamp(0 / 0) == 1)
assert(rate.advance(5, 2, 0.5) == 4)
assert(rate.advance(5, 2, 1.5) == 2)
local cooldownRemaining = rate.advance(2, 1, 0.5)
cooldownRemaining = rate.advance(cooldownRemaining, 0.5, 2)
assert(cooldownRemaining == 0.5, "Cooldowns should accumulate caster-local elapsed time as rate effects change")
assert(rate.worldDuration(5, 0.5) == 10)
assert(rate.worldDuration(5, 2) == 2.5)
assert(rate.combine({
	{ Kind = "TimeDilation", Multiplier = 0.5, ExpiresAt = 10 },
	{ Kind = "TimeDilation", Multiplier = 0.5, ExpiresAt = 10 },
}, 1) == rate.Minimum)
assert(rate.combine({
	{ Kind = "TimeDilation", Multiplier = 2, ExpiresAt = 10 },
	{ Kind = "TimeDilation", Multiplier = 2, ExpiresAt = 10 },
}, 1) == rate.Maximum)
assert(rate.combine({ { Kind = "TimeDilation", Multiplier = 0.5, ExpiresAt = 0 } }, 1) == 1)

print("Magic temporal rate: bounded stacking, duration and elapsed-time scaling passed")
