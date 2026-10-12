-- Pure bounds for aerial movement authoring and client-input validation.
local Spec = {}

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Spec.clampSpeed(value, maximum)
	if not finite(value) or not finite(maximum) or maximum <= 0 then
		return nil
	end
	return math.max(0, math.min(value, maximum))
end

function Spec.normalizeInput(x, y, z, maximumMagnitude)
	if not finite(x) or not finite(y) or not finite(z) or not finite(maximumMagnitude) or maximumMagnitude <= 0 then
		return nil
	end
	local magnitude = math.sqrt(x * x + y * y + z * z)
	if not finite(magnitude) or magnitude > maximumMagnitude then
		return nil
	end
	if magnitude > 1 then
		return x / magnitude, y / magnitude, z / magnitude
	end
	return x, y, z
end

return Spec
