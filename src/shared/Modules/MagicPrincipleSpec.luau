--!strict

-- Data contract for Principle/Form support and named magical expressions.
-- Principle-specific payload requirements are declared in MagicSchema.
local function set(values)
	local result = {}
	for _, value in ipairs(values) do
		result[value] = true
	end
	return result
end

local materialForms = {
	"Projectile",
	"Beam",
	"Wave",
	"Field",
	"Aura",
	"Construct",
	"Manipulation",
}

local energyForms = {
	"Projectile",
	"Beam",
	"Wave",
	"Field",
	"Aura",
	"Construct",
	"Rush",
}

-- Rush (moving yourself) is open to every Principle except Matter.
local spaceForms = { "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Rush" }
local soulForms = { "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Rush" }
local timeForms = { "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Rush" }

local Registry = {
	Order = { "Matter", "Energy", "Body", "Soul", "Space", "Time" },
	Definitions = {
		Matter = {
			Label = "Matter",
			Description = "Magic for physical materials such as Earth and Water. Some targeting choices need a nearby material source set up for magic. Use Manipulation to act on those sources or movable objects.",
			Expressions = { "Earth", "Water" },
			DefaultExpression = "Earth",
			Forms = set(materialForms),
			Status = "SUPPORTED",
		},
		Energy = {
			Label = "Energy",
			Description = "Magic with Fire, Lightning, Force, or the legacy Unawakened source. Choose a Form to deliver it and Effects to decide what it does. Fire as a source does not add burning by itself.",
			Expressions = { "Fire", "Lightning", "Force", "Unawakened" },
			DefaultExpression = "Fire",
			Forms = set(energyForms),
			Status = "SUPPORTED",
		},
		Body = {
			Label = "Body",
			Description = "Magic for living bodies. Use direct hits, areas, or a spell on yourself. Add effects separately, such as healing or movement bonuses.",
			Expressions = { "BodyEnhancement" },
			DefaultExpression = "BodyEnhancement",
			Forms = set({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Rush" }),
			Status = "PARTIAL",
		},
		Soul = {
			Label = "Soul",
			Description = "Magic with the Spirit source. Damage effects can use the Soul damage channel, which checks soul protection instead of elemental protection.",
			Expressions = { "Spirit" },
			DefaultExpression = "Spirit",
			Forms = set(soulForms),
			Status = "PARTIAL",
		},
		Space = {
			Label = "Space",
			Description = "Magic that can move living targets to a nearby safe location. Add Spatial Displacement on Effects to use this; choosing Space alone does not teleport anything.",
			Expressions = { "SpatialFold" },
			DefaultExpression = "SpatialFold",
			Forms = set(spaceForms),
			Status = "PARTIAL",
		},
		Time = {
			Label = "Time",
			Description = "Magic that can slow or speed a target and its ongoing effects. Add Time Dilation on Effects to use this; choosing Time alone does not change anyone’s speed.",
			Expressions = { "TemporalShift" },
			DefaultExpression = "TemporalShift",
			Forms = set(timeForms),
			Status = "PARTIAL",
		},
	},
	LegacyExpressions = {
		Unawakened = { Principle = "Energy", Status = "LEGACY" },
	},
	ExpressionDescriptions = {
		Earth = "An Earth source for Matter magic. Material-targeted spells need a nearby source that the game has marked as usable.",
		Water = "A Water source for Matter magic. Material-targeted spells need a usable Water source. Choosing Water does not create flowing water or add damage.",
		Fire = "A Fire source for Energy magic. Add Damage or Damage over time on Effects if you want the spell to hurt targets.",
		Lightning = "A Lightning source for Energy magic. Add effects separately. Chain is a projectile behavior you can add; it is not automatic.",
		Force = "A source for Energy magic. Add the Force effect to push targets; choosing this source alone does not move anything.",
		BodyEnhancement = "Body expression. Choose a supported Form and add effects; selecting this source alone does not grant movement bonuses.",
		SpatialFold = "A source for Space magic. Add Spatial Displacement to move a target to a nearby safe position.",
		Spirit = "A source for Soul magic. Choose the effects you want on Effects.",
		TemporalShift = "A source for Time magic. Add Time Dilation to slow or speed a target.",
		Unawakened = "Legacy Energy source marker, also available in the testing Lab. It does not add effects.",
	},
}

function Registry.supportsForm(principle, form)
	local definition = Registry.Definitions[principle]
	return definition ~= nil and definition.Forms[form] == true
end

function Registry.expressionMatches(principle, expression)
	local definition = Registry.Definitions[principle]
	if not definition then
		return false
	end
	for _, candidate in ipairs(definition.Expressions) do
		if candidate == expression then
			return true
		end
	end
	local legacy = Registry.LegacyExpressions[expression]
	return legacy ~= nil and legacy.Principle == principle
end

return Registry
