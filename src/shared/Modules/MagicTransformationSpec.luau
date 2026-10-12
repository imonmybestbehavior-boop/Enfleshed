-- Bounded model-scale transformation rules shared by validation and runtime.
local Limits = require(script.Parent.Parent.Configuration.MagicLab)

local Spec = {}

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

function Spec.clampScale(multiplier)
	if type(multiplier) ~= "number" or multiplier ~= multiplier or math.abs(multiplier) == math.huge then
		return nil
	end
	return clamp(multiplier, Limits.MinTransformScale, Limits.MaxTransformScale)
end

function Spec.aggregate(effects, now)
	local scale = 1
	for _, effect in ipairs(effects) do
		if effect.Kind == "Transformation" and (now == nil or effect.ExpiresAt == nil or effect.ExpiresAt > now) then
			scale = scale * (effect.Multiplier or 1)
		end
	end
	return clamp(scale, 1 / Limits.MaxCombinedTransformScale, Limits.MaxCombinedTransformScale)
end

return Spec
