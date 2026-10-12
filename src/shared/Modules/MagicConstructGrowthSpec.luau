-- Shared pure-data bounds for time-scaled Construct geometry.
local Spec = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function bounded(value, minimum, maximum)
	return finite(value) and value >= minimum and value <= maximum
end

function Spec.validate(construct)
	if type(construct) ~= "table" then
		return false, "Invalid Construct"
	end
	local hasGrowth = (construct.GrowthStartScale ~= nil and construct.GrowthStartScale ~= 0)
		or (construct.GrowthEndScale ~= nil and construct.GrowthEndScale ~= 0)
		or (construct.GrowthDuration ~= nil and construct.GrowthDuration ~= 0)
	if not hasGrowth then
		return true
	end
	if
		not bounded(construct.GrowthStartScale, 0.1, 2)
		or not bounded(construct.GrowthEndScale, 0.1, 2)
		or not bounded(construct.GrowthDuration, 0.1, 30)
	then
		return false, "Construct expansion requires bounded start/end/time values"
	end
	local maximumScale = math.max(construct.GrowthStartScale, construct.GrowthEndScale)
	if
		construct.Width * maximumScale > 20
		or construct.Height * maximumScale > 20
		or construct.Depth * maximumScale > 20
		or construct.Width * construct.Height * construct.Depth * maximumScale ^ 3 > 2000
	then
		return false, "Expanded Construct dimensions exceed the configured size or volume"
	end
	return true
end

return Spec
