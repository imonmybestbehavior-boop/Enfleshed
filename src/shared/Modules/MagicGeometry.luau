--!strict
-- Support distance of an oriented box along a surface normal.
local Geometry = {}
function Geometry.surfaceOffset(normal, right, up, forward, size)
	return math.abs(normal:Dot(right)) * size.X / 2
		+ math.abs(normal:Dot(up)) * size.Y / 2
		+ math.abs(normal:Dot(forward)) * size.Z / 2
end

function Geometry.withinCone(direction, offset, minimumDot)
	if offset.Magnitude < 0.0001 then
		return true
	end
	return direction:Dot(offset.Unit) >= minimumDot
end

function Geometry.areaSize(shape, area)
	if shape == "Sphere" then
		return Vector3.new(area.Radius * 2, area.Radius * 2, area.Radius * 2)
	elseif shape == "Capsule" then
		return Vector3.new(area.Radius * 2, area.Height, area.Radius * 2)
	elseif shape == "Cylinder" then
		return Vector3.new(area.Radius * 2, area.Height, area.Radius * 2)
	elseif shape == "Ring" then
		return Vector3.new(area.OuterRadius * 2, area.Height, area.OuterRadius * 2)
	elseif shape == "Cone" then
		local width = 2 * area.Range * math.tan(math.rad(area.Angle / 2))
		return Vector3.new(width, area.Height, area.Range)
	elseif shape == "Plane" then
		return Vector3.new(area.Width, area.Height, area.Thickness)
	elseif shape == "Line" then
		return Vector3.new(area.Width, area.Height, area.Range)
	end
	return Vector3.new(area.Width, area.Height, area.Depth)
end

function Geometry.areaQueryFrame(shape, frame, area)
	if shape == "Cone" or shape == "Line" then
		return frame * CFrame.new(0, 0, -area.Range / 2)
	end
	return frame
end

function Geometry.containsArea(shape, frame, worldPoint, area)
	local point = frame:PointToObjectSpace(worldPoint)
	if shape == "Sphere" then
		return point.X * point.X + point.Y * point.Y + point.Z * point.Z <= area.Radius * area.Radius
	elseif shape == "Capsule" then
		local halfSegment = math.max(area.Height / 2 - area.Radius, 0)
		local nearestY = math.max(-halfSegment, math.min(halfSegment, point.Y))
		local offsetY = point.Y - nearestY
		return point.X * point.X + offsetY * offsetY + point.Z * point.Z <= area.Radius * area.Radius
	elseif shape == "Cylinder" then
		return point.X * point.X + point.Z * point.Z <= area.Radius * area.Radius
			and math.abs(point.Y) <= area.Height / 2
	elseif shape == "Ring" then
		local radiusSquared = point.X * point.X + point.Z * point.Z
		return radiusSquared >= area.InnerRadius * area.InnerRadius
			and radiusSquared <= area.OuterRadius * area.OuterRadius
			and math.abs(point.Y) <= area.Height / 2
	elseif shape == "Cone" then
		local depth = -point.Z
		return depth >= 0
			and depth <= area.Range
			and math.abs(point.Y) <= area.Height / 2
			and math.abs(point.X) <= depth * math.tan(math.rad(area.Angle / 2))
	elseif shape == "Plane" then
		return math.abs(point.X) <= area.Width / 2
			and math.abs(point.Y) <= area.Height / 2
			and math.abs(point.Z) <= area.Thickness / 2
	elseif shape == "Line" then
		return math.abs(point.X) <= area.Width / 2
			and math.abs(point.Y) <= area.Height / 2
			and point.Z <= 0
			and point.Z >= -area.Range
	end
	return math.abs(point.X) <= area.Width / 2
		and math.abs(point.Y) <= area.Height / 2
		and math.abs(point.Z) <= area.Depth / 2
end

return Geometry
