local spec = assert(loadfile("src/shared/Modules/MagicStatusEffectSpec.luau", "t", _G))()

assert(not spec.isExpired("TimeDilation", 12, nil, 10, true, true), "Time Dilation remains before its server deadline")
assert(spec.isExpired("TimeDilation", 10, nil, 10, true, true), "Time Dilation expires at its server deadline")
assert(spec.isExpired("TimeDilation", 12, nil, 10, false, true), "Caster death expires Time Dilation")
assert(spec.isExpired("TimeDilation", 12, nil, 10, true, false), "Viewer removal expires viewer-scoped effects")

assert(not spec.isExpired("DamageOverTime", 0, 2, 10, true, true), "Timed statuses remain while local duration remains")
assert(spec.isExpired("DamageOverTime", 0, 0, 10, true, true), "Timed statuses expire when local duration is depleted")
assert(spec.isExpired("Restoration", 0, nil, 10, true, true), "Missing local duration fails closed")
assert(spec.isExpired("Shield", 0, 1, 10, false, true), "Caster removal expires every temporary status")
assert(spec.isExpired("Revealed", 0, 1, 10, true, false), "Viewer removal expires every viewer-scoped status")
assert(spec.isExpired("Slow", 0, 0 / 0, 10, true, true), "Malformed local duration fails closed")

print("Magic status effect expiry checks passed")
