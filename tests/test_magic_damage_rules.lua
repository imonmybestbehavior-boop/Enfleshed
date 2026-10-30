local rules = assert(loadfile("src/shared/Modules/MagicDamageRules.luau"))()
assert(rules.mitigate(40, 0) == 40)
assert(rules.mitigate(40, 0.25) == 30)
assert(rules.mitigate(40, 0.25, 5) == 25)
assert(rules.mitigate(40, 0, 5) == 35)
assert(rules.mitigate(40, 0, 200) == 0)
assert(rules.mitigate(40, 1) == 0)
assert(rules.mitigate(-5, 0) == 0)
assert(rules.mitigate(40, 2) == 0)
assert(rules.mitigate(40, "bad") == 40)

local attributes = {
	MagicResistanceFire = 0.4,
	MagicResistanceIce = 2,
	MagicResistanceWater = 0.5,
	SoulResistance = 0.25,
	SoulArmor = 6,
	PhysicalResistance = 0.25,
	PhysicalArmor = 4,
}
local target = {
	GetAttribute = function(_, key)
		return attributes[key]
	end,
}
assert(rules.resistance(target, "Fire") == 0.4)
assert(rules.resistance(target, "Ice") == 1)
assert(rules.resistance(target, "Water") == 0.5)
assert(rules.KnownElements.Water, "Water must be a recognized elemental damage channel")
assert(rules.defaultElementForExpression("Water") == "Water", "Water expression should default to Water damage")
assert(rules.defaultElementForExpression("Unknown") == "Neutral", "Unknown expressions must have neutral fallback")
assert(rules.resistance(target, "Neutral") == 0)
assert(rules.resistance(target, "Unknown") == 0)
assert(rules.soulResistance(target) == 0.25)
assert(rules.soulArmor(target) == 6)
assert(rules.mitigate(40, rules.soulResistance(target), rules.soulArmor(target)) == 24)
assert(rules.physicalResistance(target) == 0.25)
assert(rules.physicalArmor(target) == 4)
assert(rules.mitigate(40, rules.physicalResistance(target), rules.physicalArmor(target)) == 26)
assert(rules.applyChannel(40, target, "Physical") == 26)
assert(rules.applyChannel(40, target, "Soul") == 24)
assert(rules.applyChannel(40, target, "Elemental", "Fire") == 24)
assert(rules.applyChannel(40, target, "Elemental", "Water") == 20)
assert(rules.applyOutgoingStrength(20, -20) == 16, "a strength debuff should reduce outgoing damage")
assert(rules.applyOutgoingStrength(20, 25) == 25, "a strength bonus should scale outgoing damage")
assert(rules.applyOutgoingStrength(20, -100) == 5, "outgoing strength must retain a safety floor")
attributes.SoulResistance = 3
attributes.SoulArmor = 200
assert(rules.soulResistance(target) == 1 and rules.soulArmor(target) == 100)
attributes.MagicArmor = 12
attributes.MagicArmorBonus = 18
assert(rules.armor(target) == 30, "temporary attribute modifiers should add to the base armor")
attributes.MagicArmorBonus = -30
assert(rules.armor(target) == 0, "armor reduction must not make the final armor negative")
attributes.MagicArmor = 95
attributes.MagicArmorBonus = 80
assert(rules.armor(target) == 100, "combined armor must respect the shared damage cap")
assert(rules.mitigate(80, 0.25, rules.armor(target)) == 0, "computed armor should feed elemental damage mitigation")
attributes.PhysicalResistance = 3
attributes.PhysicalArmor = 200
assert(rules.physicalResistance(target) == 1 and rules.physicalArmor(target) == 100)
attributes.PhysicalResistance = -1
attributes.PhysicalArmor = -20
assert(rules.physicalResistance(target) == 0 and rules.physicalArmor(target) == 0)

-- Spell-driven bonuses (ModifyAttribute): armor bonuses add to the base armor.
attributes.PhysicalArmor = 4
attributes.PhysicalArmorBonus = 16
assert(rules.physicalArmor(target) == 20, "PhysicalArmorBonus adds to base physical armor")
attributes.PhysicalArmorBonus = -50
assert(rules.physicalArmor(target) == 0, "a physical armor debuff floors at zero")
attributes.PhysicalArmorBonus = nil
attributes.SoulArmor = 6
attributes.SoulArmorBonus = 14
assert(rules.soulArmor(target) == 20, "SoulArmorBonus adds to base soul armor")
attributes.SoulArmorBonus = 500
assert(rules.soulArmor(target) == 100, "soul armor keeps its cap")
attributes.SoulArmorBonus = nil

-- Negative resistance is a vulnerability: -0.5 means x1.5 damage.
assert(rules.mitigate(40, -0.5) == 60, "negative resistance amplifies damage")
assert(rules.mitigate(40, -5) == 80, "vulnerability is capped at double damage")
attributes.MagicArmor = 0
attributes.MagicArmorBonus = 0
attributes.MagicResistanceFireBonus = -0.9
assert(math.abs(rules.resistance(target, "Fire") - -0.5) < 1e-9, "base 0.4 + bonus -0.9 = -0.5")
assert(math.abs(rules.applyChannel(40, target, "Elemental", "Fire") - 60) < 1e-9, "Fire vulnerability")
attributes.MagicResistanceFireBonus = -3
assert(rules.resistance(target, "Fire") == -0.6, "the bonus itself is clamped to -1 before adding")
attributes.MagicResistanceFireBonus = 0.9
assert(rules.resistance(target, "Fire") == 1, "total resistance never exceeds 1")
attributes.MagicResistanceFireBonus = nil
attributes.MagicResistanceWindBonus = -0.25
assert(rules.resistance(target, "Wind") == -0.25, "a bonus works without a base resistance")
assert(rules.resistance(target, "Neutral") == 0, "Neutral damage has no resistance")
attributes.MagicResistanceWindBonus = nil

-- DamageTaken scales damage after mitigation, for spells and melee.
attributes.DamageTakenBonus = 20
assert(rules.applyDamageTaken(50, target) == 60, "vulnerability +20% after mitigation")
assert(rules.applyChannel(40, target, "Elemental", "Water") == 24, "Water: 40 * (1-0.5) = 20, then +20%")
attributes.DamageTakenBonus = -50
assert(rules.applyDamageTaken(50, target) == 25, "protection -50%")
attributes.DamageTakenBonus = 400
assert(rules.applyDamageTaken(50, target) == 75, "DamageTaken is clamped to +50%")
attributes.DamageTakenBonus = -400
assert(rules.applyDamageTaken(50, target) == 25, "DamageTaken is clamped to -50%")
attributes.DamageTakenBonus = 0 / 0
assert(rules.applyDamageTaken(50, target) == 50, "NaN is ignored")
attributes.DamageTakenBonus = nil
assert(rules.applyDamageTaken(-5, target) == 0 and rules.applyDamageTaken(50, nil) == 50)
print("Magic damage rules: elemental, physical, Soul, resistance and armor math passed")
