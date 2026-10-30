-- Explicit allowlist for temporary spell-driven numeric attributes.
-- Each attribute is stored on the target as "<Name>Bonus" (Resistance is per
-- element: "MagicResistance<Element>Bonus"). Percent attributes are
-- percentage points: +20 means x1.2.
local Limits = require(script.Parent.Parent.Configuration.MagicLab)
local DamageRules = require(script.Parent.MagicDamageRules)
local Spec = {}

Spec.Order = {
	"MagicArmor",
	"MagicStrength",
	"PhysicalArmor",
	"SoulArmor",
	"Resistance",
	"DamageTaken",
	"HealingReceived",
	"CastSpeed",
	"CooldownRate",
	"ManaRegen",
}

Spec.Definitions = {
	MagicArmor = {
		Label = "Magic armor",
		Minimum = -Limits.MaxArmorModifier,
		Maximum = Limits.MaxArmorModifier,
		Default = 15,
	},
	MagicStrength = {
		Label = "Strength",
		Minimum = Limits.MinMagicStrengthModifier,
		Maximum = Limits.MaxMagicStrengthModifier,
		Default = 15,
	},
	PhysicalArmor = { Label = "Physical armor", Minimum = -100, Maximum = 100, Default = 15 },
	SoulArmor = { Label = "Soul armor", Minimum = -100, Maximum = 100, Default = 15 },
	Resistance = {
		Label = "Elemental resistance",
		Minimum = -1,
		Maximum = 1,
		Default = 0.2,
		RequiresElement = true,
	},
	DamageTaken = { Label = "Damage taken %", Minimum = -50, Maximum = 50, Default = 10, Percent = true },
	HealingReceived = { Label = "Healing received %", Minimum = -75, Maximum = 50, Default = 10, Percent = true },
	CastSpeed = { Label = "Cast speed %", Minimum = -50, Maximum = 50, Default = 10, Percent = true },
	CooldownRate = { Label = "Cooldown rate %", Minimum = -50, Maximum = 50, Default = 10, Percent = true },
	ManaRegen = { Label = "Mana regeneration %", Minimum = -100, Maximum = 100, Default = 10, Percent = true },
}

-- Elements a Resistance modifier can target (every damage element except Neutral).
Spec.Elements = {}
for _, element in ipairs(DamageRules.Elements) do
	if element ~= "Neutral" then
		table.insert(Spec.Elements, element)
	end
end

function Spec.supports(attribute)
	return Spec.Definitions[attribute] ~= nil
end

function Spec.requiresElement(attribute)
	local definition = Spec.Definitions[attribute]
	return definition ~= nil and definition.RequiresElement == true
end

function Spec.validElement(element)
	return element ~= "Neutral" and DamageRules.KnownElements[element] == true
end

-- Attribute name written on the target Humanoid and Model.
function Spec.attributeName(attribute, element)
	if Spec.requiresElement(attribute) then
		return "MagicResistance" .. tostring(element) .. "Bonus"
	end
	return attribute .. "Bonus"
end

function Spec.clamp(attribute, amount)
	local definition = Spec.Definitions[attribute]
	if
		not definition
		or type(amount) ~= "number"
		or amount ~= amount
		or amount == math.huge
		or amount == -math.huge
	then
		return nil
	end
	return math.max(definition.Minimum, math.min(definition.Maximum, amount))
end

-- Sum of active modifiers for one attribute, clamped to its range. Resistance
-- sums only the modifiers for the given element.
function Spec.aggregate(effects, attribute, now, element)
	local definition = Spec.Definitions[attribute]
	if not definition then
		return 0
	end
	local byElement = definition.RequiresElement == true
	local total = 0
	for _, effect in ipairs(effects) do
		if
			effect.Kind == "ModifyAttribute"
			and effect.Attribute == attribute
			and (not byElement or effect.Element == element)
			and (now == nil or effect.ExpiresAt == nil or effect.ExpiresAt > now)
		then
			total = total + (effect.Amount or 0)
		end
	end
	return math.max(definition.Minimum, math.min(definition.Maximum, total))
end

-- Current clamped bonus read from an instance (anything with GetAttribute).
function Spec.read(instance, attribute, element)
	local definition = Spec.Definitions[attribute]
	if not instance or not definition then
		return 0
	end
	local value = instance:GetAttribute(Spec.attributeName(attribute, element))
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(definition.Minimum, math.min(definition.Maximum, value))
end

-- 1 + bonus/100 for percent attributes (DamageTaken, HealingReceived, CastSpeed,
-- CooldownRate, ManaRegen). Never negative.
function Spec.multiplier(instance, attribute)
	return math.max(0, 1 + Spec.read(instance, attribute) / 100)
end

return Spec
