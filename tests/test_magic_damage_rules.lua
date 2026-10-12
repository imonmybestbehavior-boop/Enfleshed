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
print("Magic damage rules: elemental, physical, Soul, resistance and armor math passed")
