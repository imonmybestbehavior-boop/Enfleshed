local effects = assert(loadfile("src/shared/Modules/MagicMovementEffects.luau"))()

assert(effects.multiplier({}, 10) == 1, "no movement status should preserve normal speed")
assert(
	effects.multiplier({ { Kind = "Slow", Multiplier = 0.7, ExpiresAt = 20 } }, 10) == 0.7,
	"a valid Slow should apply its multiplier"
)
assert(effects.multiplier({
	{ Kind = "Slow", Multiplier = 0.7, ExpiresAt = 20 },
	{ Kind = "Slow", Multiplier = 0.4, ExpiresAt = 20 },
}, 10) == 0.4, "overlapping Slows should use the strongest reduction")
assert(effects.multiplier({
	{ Kind = "Slow", Multiplier = 0.4, ExpiresAt = 20 },
	{ Kind = "Bind", ExpiresAt = 12 },
}, 10) == 0, "an active Bind should prevent movement")
assert(effects.multiplier({
	{ Kind = "Slow", Multiplier = 0.4, ExpiresAt = 20 },
	{ Kind = "Bind", ExpiresAt = 9 },
}, 10) == 0.4, "an expired Bind should restore the remaining Slow")
assert(
	effects.multiplier({ { Kind = "Bind", ExpiresAt = 9 } }, 10) == 1,
	"an expired Bind should restore normal movement"
)

print("Magic movement effects: Slow stacking and Bind expiry passed")
