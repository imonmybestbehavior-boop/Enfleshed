-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicControlStateSpec.luau"))()

-- Decision order: Fear, then a valid Taunt, then the normal player scan.
assert(Spec.decide(10, nil, false, nil) == "Scan", "no control: scan for players")
assert(Spec.decide(10, 12, true, nil) == "Forced", "taunted: attack the taunter")
assert(Spec.decide(10, 12, false, nil) == "Scan", "taunter gone or dead: scan again")
assert(Spec.decide(10, 9, true, nil) == "Scan", "expired taunt")
assert(Spec.decide(10, nil, false, 11) == "Fear", "feared: disengage")
assert(Spec.decide(10, 12, true, 11) == "Fear", "fear wins over taunt")
assert(Spec.decide(10, 12, true, 10) == "Forced", "fear that just ended no longer applies")
assert(Spec.decide(10, "12", true, nil) == "Scan", "bad attribute values are ignored")

-- Strongest effect: the longest-lasting active one.
local effects = {
	{ Id = "short", ExpiresAt = 11 },
	{ Id = "long", ExpiresAt = 15 },
	{ Id = "expired", ExpiresAt = 9 },
}
assert(Spec.strongest(effects, 10).Id == "long")
assert(Spec.strongest(effects, 16) == nil, "nothing active")
assert(Spec.strongest({}, 10) == nil)
print("Magic control state spec: taunt/fear decision order and strongest effect passed")
