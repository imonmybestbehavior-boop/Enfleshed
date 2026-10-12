--!strict

-- Data-driven effects that are applied when an elemental mark is added.
local MagicLab = require(script.Parent.Parent.Configuration.MagicLab)
local Spec = {}

function Spec.effectsFor(element, markDuration)
	local configured = MagicLab.ElementalInteractions[element]
	if not configured then
		return {}
	end
	local effects = {}
	for _, configuredEffect in ipairs(configured) do
		local effect = {}
		for key, value in pairs(configuredEffect) do
			effect[key] = value
		end
		if effect.Duration == "Mark" then
			effect.Duration = markDuration
		end
		table.insert(effects, effect)
	end
	return effects
end

return Spec
