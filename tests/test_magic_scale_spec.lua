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
	HealthPaid = 40, -- HP paid at cast
}
local expected = {
	TargetMissingHealthPercent = 75,
	ElementalMarkStacks = 3,
	DistanceFromCaster = 18,
	AreaOccupants = 4,
	TriggerCount = 6,
	ChargePercent = 60,
	HealthPaid = 40,
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

-- Extra projectiles: floor(charge x MaxExtraProjectiles).
local extra = { MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = 3 }
assert(Spec.extraProjectiles(extra, 0) == 0)
assert(Spec.extraProjectiles(extra, 0.32) == 0, "floor(0.96) = 0")
assert(Spec.extraProjectiles(extra, 1 / 3) == 1, "a third of the way: 1 extra")
assert(Spec.extraProjectiles(extra, 0.7) == 2)
assert(Spec.extraProjectiles(extra, 1) == 3, "full charge: all extras")
assert(Spec.extraProjectiles(extra, 5) == 3, "fraction clamps")
assert(Spec.extraProjectiles({ MinPotency = 1, MaxPotency = 2 }, 1) == 0, "default 0 extras")
assert(Spec.extraProjectiles(nil, 1) == 0)
-- Fan like Spread: alternate sides, and start past Spread's own side pairs.
assert(table.concat(Spec.extraOffsets(3, 16), ",") == "16,-16,32")
assert(table.concat(Spec.extraOffsets(2, 10, 1), ",") == "20,-20", "skips one Spread pair")
assert(#Spec.extraOffsets(0, 16) == 0)
-- Validation: Projectile only, whole number, 0..limit.
assert(Spec.validateChargeScaling(extra, true, "Projectile", 3))
assert(Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = 0 }, true, "Projectile", 3))
local okForm, formReason = Spec.validateChargeScaling(extra, true, "Beam", 3)
assert(not okForm and string.find(formReason, "Projectile", 1, true), "Projectile forms only")
assert(
	not Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = 4 }, true, "Projectile", 3)
)
assert(
	not Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = 1.5 }, true, "Projectile", 3)
)
assert(
	not Spec.validateChargeScaling({ MinPotency = 1, MaxPotency = 1, MaxExtraProjectiles = -1 }, true, "Projectile", 3)
)
-- HealthPaid (blood magic): units are the HP paid at cast.
assert(Spec.Sources.HealthPaid and table.find(Spec.SourceOrder, "HealthPaid"))
local paidScale = { Source = "HealthPaid", PerUnit = 0.5, Max = 50 }
assert(Spec.amount(
	50,
	paidScale,
	Spec.units(paidScale, function()
		return 40
	end)
) == 70, "50 damage, 40 HP paid -> x1.4")
assert(Spec.validateScaleBy(paidScale, "Damage", 100, function()
	return false
end))
print("Magic scale spec: charge potency mapping, ScaleBy sources, amounts and validation passed")
