-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicScaleSpec.luau"))()

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- Charge mapping: (held - MinimumCharge) / (MaximumCharge - MinimumCharge), linear.
assert(near(Spec.chargeFraction(0.5, 0.5, 2.5), 0))
assert(near(Spec.chargeFraction(1.5, 0.5, 2.5), 0.5))
assert(near(Spec.chargeFraction(2.5, 0.5, 2.5), 1))
assert(near(Spec.chargeFraction(9, 0.5, 2.5), 1), "held past maximum clamps")
assert(near(Spec.chargeFraction(0.1, 0.5, 2.5), 0), "held under minimum clamps")
assert(near(Spec.chargeFraction(1, 1, 1), 1), "zero-length window: full charge once reached")
assert(near(Spec.chargeFraction(nil, 0.5, 2.5), 0))
local scaling = { MinPotency = 1, MaxPotency = 5 }
assert(near(Spec.chargePotency(scaling, 0.5, 0.5, 2.5), 1), "minimum charge -> MinPotency")
assert(near(Spec.chargePotency(scaling, 1.5, 0.5, 2.5), 3), "halfway -> halfway")
assert(near(Spec.chargePotency(scaling, 2.5, 0.5, 2.5), 5), "full charge -> MaxPotency (5x)")
assert(near(Spec.chargePotency({ MinPotency = 0.5, MaxPotency = 2 }, 1, 0, 2), 1.25))
assert(Spec.chargePotency(nil, 2.5, 0.5, 2.5) == 1, "no ChargeScaling: potency unchanged")
assert(near(Spec.chargePotency({ MinPotency = 0.01, MaxPotency = 50 }, 2.5, 0.5, 2.5), 5), "bounds clamp")

-- Charge validation: bounds 0.25..5, charge modes only, min <= max.
assert(Spec.validateChargeScaling(nil, false))
assert(Spec.validateChargeScaling({ MinPotency = 0.25, MaxPotency = 5 }, true))
assert(not Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 2 }, false), "Instant casts cannot use it")
assert(not Spec.validateChargeScaling({ MinPotency = 0.2, MaxPotency = 2 }, true))
assert(not Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 5.5 }, true))
assert(not Spec.validateChargeScaling({ MinPotency = 3, MaxPotency = 2 }, true))
assert(not Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 2, Extra = 1 }, true))

-- Each ScaleBy source turns its adapter value into units.
local raw = {
	TargetMissingHealthPercent = 0.25, -- Target.HealthPercent: 25% health left -> 75 units
	ElementalMarkStacks = 3,
	DistanceFromCaster = 18,
	AreaOccupants = 4,
	TriggerCount = 6,
	ChargePercent = 0.6, -- charge fraction -> 60 units
}
local expected = {
	TargetMissingHealthPercent = 75,
	ElementalMarkStacks = 3,
	DistanceFromCaster = 18,
	AreaOccupants = 4,
	TriggerCount = 6,
	ChargePercent = 60,
}
for _, source in ipairs(Spec.SourceOrder) do
	local seenElement
	local units = Spec.units({ Source = source, PerUnit = 1, Max = 100, Element = "Fire" }, function(s, element)
		assert(s == source)
		seenElement = element
		return raw[source]
	end)
	assert(near(units, expected[source]), source .. " units: " .. tostring(units))
	assert(seenElement == "Fire", "the element is passed through to the reader")
end
assert(Spec.units({ Source = "Nope" }, function()
	return 5
end) == 0, "unknown source scales by nothing")
assert(Spec.units({ Source = "TriggerCount" }, function()
	return 0 / 0
end) == 0, "NaN reads as zero")

-- Amount: authored + min(PerUnit * units, Max); never negative.
assert(Spec.amount(10, { PerUnit = 2, Max = 50 }, 3) == 16)
assert(Spec.amount(10, { PerUnit = 2, Max = 5 }, 3) == 15, "the bonus is capped by Max")
assert(Spec.amount(10, nil, 3) == 10, "no ScaleBy: authored amount")
assert(Spec.amount(0, { PerUnit = 10, Max = 100 }, 4) == 40, "consume 4 burn stacks for 10 each")

-- ScaleBy validation.
local function validElement(element)
	return element == "Fire" or element == "Ice"
end
assert(Spec.validateScaleBy(nil, "Damage", 100, validElement))
assert(Spec.validateScaleBy({ Source = "AreaOccupants", PerUnit = 2, Max = 20 }, "Heal", 100, validElement))
assert(not Spec.validateScaleBy({ Source = "AreaOccupants", PerUnit = 2, Max = 20 }, "Slow", 100, validElement))
assert(not Spec.validateScaleBy({ Source = "Bogus", PerUnit = 2, Max = 20 }, "Damage", 100, validElement))
assert(not Spec.validateScaleBy({ Source = "AreaOccupants", PerUnit = 200, Max = 20 }, "Damage", 100, validElement))
assert(not Spec.validateScaleBy({ Source = "AreaOccupants", PerUnit = -1, Max = 20 }, "Damage", 100, validElement))
assert(not Spec.validateScaleBy({ Source = "ElementalMarkStacks", PerUnit = 1, Max = 20 }, "Damage", 100, validElement))
assert(
	Spec.validateScaleBy(
		{ Source = "ElementalMarkStacks", PerUnit = 1, Max = 20, Element = "Fire" },
		"Damage",
		100,
		validElement
	)
)
assert(
	not Spec.validateScaleBy(
		{ Source = "TriggerCount", PerUnit = 1, Max = 20, Element = "Fire" },
		"Damage",
		100,
		validElement
	)
)
assert(
	not Spec.validateScaleBy({ Source = "TriggerCount", PerUnit = 1, Max = 20, Other = 1 }, "Damage", 100, validElement)
)
print("Magic scale spec: charge potency mapping, ScaleBy sources, amounts and validation passed")
