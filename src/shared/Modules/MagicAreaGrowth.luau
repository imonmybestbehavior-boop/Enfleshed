--!strict

-- Shared scale math keeps server hit geometry and presentation dimensions in sync.
local Growth = {}

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

function Growth.scale(area, age)
	if area.GrowthDuration == nil or area.GrowthDuration <= 0 then
		return 1
	end
	local alpha = clamp(math.max(age, 0) / area.GrowthDuration, 0, 1)
	return area.GrowthStartScale + (area.GrowthEndScale - area.GrowthStartScale) * alpha
end

function Growth.area(area, scale)
	if scale == 1 then
		return area
	end
	local result = {}
	for key, value in pairs(area) do
		result[key] = value
	end
	for _, key in ipairs({
		"Radius",
		"Range",
		"Height",
		"Width",
		"Depth",
		"Thickness",
		"InnerRadius",
		"OuterRadius",
	}) do
		if type(result[key]) == "number" then
			result[key] = result[key] * scale
		end
	end
	return result
end

return Growth
