local configuration = {
	MagicLab = {
		MaxArmorModifier = 100,
		MinMagicStrengthModifier = -75,
		MaxMagicStrengthModifier = 100,
	},
}
local rules = assert(loadfile("src/shared/Modules/MagicDamageRules.luau"))()
local environment = setmetatable({
	script = { Parent = { MagicDamageRules = "rules", Parent = { Configuration = { MagicLab = "limits" } } } },
}, { __index = _G })
environment.require = function(ref)
	if ref == "rules" then
		return rules
	end
	return configuration.MagicLab
end
local spec = assert(loadfile("src/shared/Modules/MagicAttributeSpec.luau", "t", environment))()
assert(spec.supports("MagicArmor"))
assert(spec.supports("MagicStrength"))
assert(not spec.supports("WalkSpeed"), "unregistered engine attributes must stay inaccessible")
assert(spec.clamp("MagicArmor", 130) == 100)
assert(spec.clamp("MagicArmor", -130) == -100)
assert(spec.clamp("MagicStrength", -130) == -75)
assert(spec.clamp("MagicStrength", 130) == 100)
assert(spec.clamp("MagicArmor", math.huge) == nil)
assert(spec.clamp("WalkSpeed", 3) == nil)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicStrength", Amount = -25 },
	{ Kind = "ModifyAttribute", Attribute = "MagicStrength", Amount = -80 },
}, "MagicStrength") == -75)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 45 },
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 70 },
	{ Kind = "Slow", Attribute = "MagicArmor", Amount = 50 },
}, "MagicArmor") == 100)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = -20 },
}, "MagicArmor") == -20)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 50, ExpiresAt = 4 },
}, "MagicArmor", 5) == 0, "expired modifiers must not contribute")

-- Every attribute: registered, clamped to its own range, aggregated and capped.
local ranges = {
	MagicArmor = { -100, 100 },
	MagicStrength = { -75, 100 },
	PhysicalArmor = { -100, 100 },
	SoulArmor = { -100, 100 },
	Resistance = { -1, 1 },
	DamageTaken = { -50, 50 },
	HealingReceived = { -75, 50 },
	CastSpeed = { -50, 50 },
	CooldownRate = { -50, 50 },
	ManaRegen = { -100, 100 },
}
assert(#spec.Order == 10, "every attribute is listed in Order")
for _, attribute in ipairs(spec.Order) do
	local range = assert(ranges[attribute], attribute)
	local low, high = range[1], range[2]
	local definition = spec.Definitions[attribute]
	assert(definition.Minimum == low and definition.Maximum == high, attribute .. " range")
	assert(definition.Default >= low and definition.Default <= high, attribute .. " default in range")
	assert(spec.clamp(attribute, high * 10) == high, attribute .. " clamps high")
	assert(spec.clamp(attribute, low * 10 - 1) == low, attribute .. " clamps low")
	assert(spec.clamp(attribute, 0 / 0) == nil, attribute .. " rejects NaN")
	local element = if spec.requiresElement(attribute) then "Fire" else nil
	local effects = {
		{ Kind = "ModifyAttribute", Attribute = attribute, Element = element, Amount = high * 0.75 },
		{ Kind = "ModifyAttribute", Attribute = attribute, Element = element, Amount = high * 0.75 },
	}
	assert(spec.aggregate(effects, attribute, nil, element) == high, attribute .. " aggregate caps high")
	effects[1].Amount, effects[2].Amount = low * 0.75, low * 0.75
	assert(spec.aggregate(effects, attribute, nil, element) == low, attribute .. " aggregate caps low")
	effects[2].Amount = -low * 0.25
	local expected = low * 0.75 - low * 0.25
	assert(math.abs(spec.aggregate(effects, attribute, nil, element) - expected) < 1e-9, attribute .. " sums")
end

-- Storage names follow <Name>Bonus; Resistance is per element.
assert(spec.attributeName("MagicArmor") == "MagicArmorBonus")
assert(spec.attributeName("CastSpeed") == "CastSpeedBonus")
assert(spec.attributeName("Resistance", "Ice") == "MagicResistanceIceBonus")
assert(spec.requiresElement("Resistance") and not spec.requiresElement("DamageTaken"))
assert(spec.validElement("Fire") and not spec.validElement("Neutral") and not spec.validElement("Plasma"))
assert(not table.find(spec.Elements, "Neutral"), "Neutral has no resistance")

-- Resistance aggregates only the matching element.
local resist = {
	{ Kind = "ModifyAttribute", Attribute = "Resistance", Element = "Fire", Amount = 0.3 },
	{ Kind = "ModifyAttribute", Attribute = "Resistance", Element = "Ice", Amount = -0.4 },
}
assert(spec.aggregate(resist, "Resistance", nil, "Fire") == 0.3)
assert(spec.aggregate(resist, "Resistance", nil, "Ice") == -0.4)
assert(spec.aggregate(resist, "Resistance", nil, "Water") == 0)

-- Reading percent attributes back as multipliers.
local values = { CastSpeedBonus = 50, ManaRegenBonus = -300, HealingReceivedBonus = 0 / 0 }
local holder = {
	GetAttribute = function(_, key)
		return values[key]
	end,
}
assert(spec.multiplier(holder, "CastSpeed") == 1.5)
assert(spec.multiplier(holder, "ManaRegen") == 0, "ManaRegen clamps to -100 and never goes negative")
assert(spec.multiplier(holder, "HealingReceived") == 1, "NaN reads as no bonus")
assert(spec.multiplier(nil, "CooldownRate") == 1)

-- MagicDamageRules keeps literal copies of the ranges it reads; they must match.
assert(rules.DamageTakenRange[1] == spec.Definitions.DamageTaken.Minimum)
assert(rules.DamageTakenRange[2] == spec.Definitions.DamageTaken.Maximum)
assert(rules.ResistanceBonusRange[1] == spec.Definitions.Resistance.Minimum)
assert(rules.ResistanceBonusRange[2] == spec.Definitions.Resistance.Maximum)
for _, armor in ipairs({ "PhysicalArmor", "SoulArmor" }) do
	assert(rules.ArmorBonusRange[1] == spec.Definitions[armor].Minimum)
	assert(rules.ArmorBonusRange[2] == spec.Definitions[armor].Maximum)
end
print("Magic attribute spec: allowlist, finite bounds and aggregate caps passed")
