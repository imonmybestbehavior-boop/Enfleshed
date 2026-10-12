local TriggerSpec = dofile("src/shared/Modules/MagicTriggerSpec.luau")

local canonical = { { Payloads = { { Kind = "Force", Magnitude = 10 } } } }
local alias = { { Payloads = { { Kind = "Heal", Amount = 4 } } } }
local normalized = TriggerSpec.normalize({
	OnTick = canonical,
	OnInterval = alias,
	OnCast = { { Payloads = { { Kind = "Shield", Amount = 5, Duration = 2 } } } },
})

assert(normalized.OnTick[1] == canonical[1], "Canonical OnTick steps must be retained first")
assert(normalized.OnTick[2] == alias[1], "OnInterval steps must append after OnTick")
assert(normalized.OnCast[1].Payloads[1].Kind == "Shield", "Unrelated trigger events must remain unchanged")

local legacy = TriggerSpec.normalize({
	OnInterval = {
		{ Kind = "Damage", Amount = 3 },
		{ Kind = "Slow", Multiplier = 0.7, Duration = 2 },
	},
})
assert(#legacy.OnTick == 1, "Legacy flat payload lists should normalize into one trigger step")
assert(#legacy.OnTick[1].Payloads == 2, "All legacy interval payloads must be preserved")

local aliasOnly = TriggerSpec.normalize({ OnInterval = alias })
assert(#aliasOnly.OnTick == 1 and aliasOnly.OnInterval == nil, "Alias-only definitions must become OnTick")
assert(next(TriggerSpec.normalize(nil)) == nil, "Missing trigger data should normalize to an empty table")

print("Magic trigger normalization tests passed")
