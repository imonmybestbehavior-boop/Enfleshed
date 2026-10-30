-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicBloodCostSpec.luau"))()
local Limits = assert(loadfile("src/shared/Configuration/MagicLab.luau"))()

-- Mana replacement: 1 HP pays for 0.5 mana.
local mana, health = Spec.split(30, 100, Limits.HealthPerMana)
assert(mana == 0 and health == 60, "fully blood-powered: 0 mana, twice its mana value in HP")
mana, health = Spec.split(30, 50, Limits.HealthPerMana)
assert(mana == 15 and health == 30, "half and half")
mana, health = Spec.split(31, 50, Limits.HealthPerMana)
assert(mana == 16 and health == 30, "mana rounds up, health pays only the replaced whole mana")
mana, health = Spec.split(30, nil, Limits.HealthPerMana)
assert(mana == 30 and health == 0)

-- Sacrifice and charge.
assert(Spec.sacrifice({ Mode = "Flat", Amount = 30 }, 100) == 30)
assert(Spec.sacrifice({ Mode = "PercentMax", Amount = 40 }, 200) == 80)
assert(Spec.sacrifice({ Mode = "PercentMax", Amount = 40 }, 200, 30) == 60, "PvP percent cap")
assert(Spec.sacrifice(nil, 100) == 0)
assert(Spec.amount({ Health = { Mode = "Flat", Amount = 30 } }, 0, 100, 1) == 30, "flat 30 HP is exactly 30")
assert(Spec.amount({ Health = { Mode = "Flat", Amount = 20 } }, 10, 100, 1.5) == 45, "charge scales both parts")

-- The 10% floor: blood magic never kills.
assert(Spec.canPay(100, 100, 90, Limits.BloodHealthFloor), "landing exactly on the floor is allowed")
assert(not Spec.canPay(100, 100, 91, Limits.BloodHealthFloor), "below the floor is refused")
assert(not Spec.canPay(15, 100, 10, Limits.BloodHealthFloor))
assert(Spec.canPay(5, 100, 0, Limits.BloodHealthFloor), "a free cast is never refused")

-- Upkeep stops before the tick that would cross the floor.
assert(Spec.tick(50, 100, 10, 0.5, Limits.BloodHealthFloor) == 45)
assert(Spec.tick(14, 100, 10, 0.5, Limits.BloodHealthFloor) == nil)

-- PvP cap on the HealthPaid bonus.
assert(Spec.capPaidBonus(50, 90, 0.5) == 75 and Spec.capPaidBonus(50, 70, 0.5) == 70)
assert(Spec.capPaidBonus(50, 90, nil) == 90, "no cap outside PvP")

-- Validation.
assert(Spec.validate({ Health = { Mode = "Flat", Amount = 100 }, HealthForMana = 100, HealthPerSecond = 10 }, Limits))
assert(not Spec.validate({ Health = { Mode = "Flat", Amount = 101 } }, Limits))
assert(not Spec.validate({ Health = { Mode = "PercentMax", Amount = 41 } }, Limits))
assert(not Spec.validate({ Health = { Mode = "Blood", Amount = 5 } }, Limits))
assert(not Spec.validate({ Health = { Mode = "Flat", Amount = 5, Extra = 1 } }, Limits))
assert(not Spec.validate({ HealthForMana = 101 }, Limits))
assert(not Spec.validate({ HealthPerSecond = 0.2 }, Limits))
assert(Spec.uses({ HealthForMana = 20 }) and not Spec.uses({ ManaDemand = 5, HealthForMana = 0 }))

-- Editor and HUD cost line.
assert(Spec.costLabel({ ManaDemand = 20, ManaPaid = 20, HealthFromMana = 0 }) == "20 mana")
assert(Spec.costLabel({ ManaPaid = 20, HealthFromMana = 30 }) == "20 mana + 30 HP")
assert(
	Spec.costLabel({ ManaPaid = 0, HealthFromMana = 40, HealthCost = { Mode = "PercentMax", Amount = 15 } })
		== "0 mana + 15% HP + 40 HP"
)
assert(Spec.costLabel({ ManaPaid = 5, HealthCost = { Mode = "Flat", Amount = 12.5 } }) == "5 mana + 12.5 HP")
-- HealthPaid preset: x1.4 at 40 HP paid on 50 damage.
local preset = Spec.paidScalePreset(50, 100)
assert(preset.Source == "HealthPaid" and preset.PerUnit == 0.5 and preset.Max == 50)
assert(Spec.paidScalePreset(400, 100).Max == 100, "within the hard scaling limit")
print("Magic blood cost spec: mana split, sacrifice, charge, floor, upkeep, PvP bonus cap and validation passed")
