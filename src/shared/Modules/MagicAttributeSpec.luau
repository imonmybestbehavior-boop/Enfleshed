-- Explicit allowlist for temporary spell-driven numeric attributes.
local Limits = require(script.Parent.Parent.Configuration.MagicLab)
local Spec = {}

Spec.Definitions = {
	MagicArmor = {
		Label = "Magic armor",
		Minimum = -Limits.MaxArmorModifier,
		Maximum = Limits.MaxArmorModifier,
	},
	MagicStrength = {
		Label = "Strength",
		Minimum = Limits.MinMagicStrengthModifier,
		Maximum = Limits.MaxMagicStrengthModifier,
	},
}

function Spec.supports(attribute)
	return Spec.Definitions[attribute] ~= nil
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

function Spec.aggregate(effects, attribute, now)
	local total = 0
	for _, effect in ipairs(effects) do
		if
			effect.Kind == "ModifyAttribute"
			and effect.Attribute == attribute
			and (now == nil or effect.ExpiresAt == nil or effect.ExpiresAt > now)
		then
			total = total + (effect.Amount or 0)
		end
	end
	local definition = Spec.Definitions[attribute]
	if not definition then
		return 0
	end
	return math.max(definition.Minimum, math.min(definition.Maximum, total))
end

return Spec
