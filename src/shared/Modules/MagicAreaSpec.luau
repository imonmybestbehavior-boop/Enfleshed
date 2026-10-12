-- Shared pure-data validation for Field and Aura hit-volume geometry.
local Spec = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function bounded(value, minimum, maximum)
	return finite(value) and value >= minimum and value <= maximum
end

local function hasOnlyKeys(value, allowed)
	if type(value) ~= "table" then
		return false
	end
	for key in pairs(value) do
		if not allowed[key] then
			return false
		end
	end
	return true
end

function Spec.validate(form, shape, area, maxRadius, minInterval)
	if form ~= "Field" and form ~= "Aura" then
		return false, "Area geometry requires a Field or Aura"
	end
	local allowed = {
		Interval = true,
		Yaw = true,
		GrowthStartScale = true,
		GrowthEndScale = true,
		GrowthDuration = true,
	}
	if form == "Field" then
		allowed.DebugHeight, allowed.FollowTarget = true, true
	end
	if shape == "Sphere" then
		allowed.Radius = true
	elseif shape == "Capsule" then
		allowed.Radius, allowed.Height = true, true
	elseif shape == "Cylinder" then
		allowed.Radius, allowed.Height = true, true
	elseif shape == "Cone" then
		allowed.Range, allowed.Angle, allowed.Height = true, true, true
	elseif shape == "Ring" then
		allowed.InnerRadius, allowed.OuterRadius, allowed.Height = true, true, true
	elseif shape == "Box" then
		allowed.Width, allowed.Height, allowed.Depth = true, true, true
	elseif shape == "Plane" then
		allowed.Width, allowed.Height, allowed.Thickness = true, true, true
	elseif shape == "Line" then
		allowed.Width, allowed.Height, allowed.Range = true, true, true
	else
		return false, "Unsupported area geometry"
	end
	if not hasOnlyKeys(area, allowed) then
		return false, "Area contains settings unrelated to its selected geometry"
	end

	local dimensionsValid
	if shape == "Sphere" then
		dimensionsValid = bounded(area.Radius, 0.1, maxRadius)
	elseif shape == "Capsule" then
		dimensionsValid = bounded(area.Radius, 0.1, maxRadius) and bounded(area.Height, area.Radius * 2, maxRadius)
	elseif shape == "Cylinder" then
		dimensionsValid = bounded(area.Radius, 0.1, maxRadius) and bounded(area.Height, 0.1, maxRadius)
	elseif shape == "Cone" then
		dimensionsValid = bounded(area.Range, 0.1, maxRadius)
			and bounded(area.Height, 0.1, maxRadius)
			and bounded(area.Angle, 5, 120)
	elseif shape == "Ring" then
		dimensionsValid = bounded(area.InnerRadius, 0.1, maxRadius)
			and bounded(area.OuterRadius, 0.2, maxRadius)
			and area.InnerRadius < area.OuterRadius
			and bounded(area.Height, 0.1, maxRadius)
	elseif shape == "Plane" then
		dimensionsValid = bounded(area.Width, 0.1, maxRadius)
			and bounded(area.Height, 0.1, maxRadius)
			and bounded(area.Thickness, 0.1, math.min(maxRadius, 4))
	elseif shape == "Line" then
		dimensionsValid = bounded(area.Width, 0.1, maxRadius)
			and bounded(area.Height, 0.1, maxRadius)
			and bounded(area.Range, 0.1, maxRadius)
	else
		dimensionsValid = bounded(area.Width, 0.1, maxRadius)
			and bounded(area.Height, 0.1, maxRadius)
			and bounded(area.Depth, 0.1, maxRadius)
	end
	if not dimensionsValid then
		return false, "Area dimensions are invalid or outside the configured limit"
	end
	if not bounded(area.Interval, minInterval, 5) or not bounded(area.Yaw, -180, 180) then
		return false, "Area interval or yaw is outside the configured limit"
	end
	if area.FollowTarget ~= nil and type(area.FollowTarget) ~= "boolean" then
		return false, "Area follow-target setting must be true or false"
	end
	local hasGrowth = (area.GrowthStartScale ~= nil and area.GrowthStartScale ~= 0)
		or (area.GrowthEndScale ~= nil and area.GrowthEndScale ~= 0)
		or (area.GrowthDuration ~= nil and area.GrowthDuration ~= 0)
	if
		hasGrowth
		and (
			not bounded(area.GrowthStartScale, 0.1, 2)
			or not bounded(area.GrowthEndScale, 0.1, 2)
			or not bounded(area.GrowthDuration, 0.1, 30)
		)
	then
		return false, "Area expansion needs start/end scales from 0.1–2 and duration from 0.1–30 seconds"
	end
	if hasGrowth then
		local maximumScale = math.max(area.GrowthStartScale, area.GrowthEndScale)
		local maximumDimension
		if shape == "Sphere" then
			maximumDimension = area.Radius
		elseif shape == "Capsule" or shape == "Cylinder" then
			maximumDimension = math.max(area.Radius, area.Height)
		elseif shape == "Ring" then
			maximumDimension = area.OuterRadius
		elseif shape == "Cone" then
			maximumDimension = math.max(area.Range, area.Height, 2 * area.Range * math.tan(math.rad(area.Angle / 2)))
		elseif shape == "Line" then
			maximumDimension = math.max(area.Range, area.Height, area.Width)
		elseif shape == "Plane" then
			maximumDimension = math.max(area.Width, area.Height, area.Thickness)
		else
			maximumDimension = math.max(area.Width, area.Height, area.Depth)
		end
		if maximumDimension * maximumScale > maxRadius then
			return false, "Expanded area would exceed the configured maximum radius"
		end
	end
	if form == "Field" and not bounded(area.DebugHeight, 0.1, 1) then
		return false, "Field debug marker height is outside the configured limit"
	end
	return true, nil
end

return Spec
