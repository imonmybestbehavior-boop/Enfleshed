local geometry = assert(loadfile("src/shared/Modules/MagicGeometry.luau"))()
Vector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
CFrame = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
local function vector(x, y, z)
	local magnitude = math.sqrt(x * x + y * y + z * z)
	local function direction(a, b, c)
		return {
			X = a,
			Y = b,
			Z = c,
			Dot = function(first, second)
				return first.X * second.X + first.Y * second.Y + first.Z * second.Z
			end,
		}
	end
	local unit = magnitude > 0 and direction(x / magnitude, y / magnitude, z / magnitude) or direction(0, 0, 0)
	local result = {
		X = x,
		Y = y,
		Z = z,
		Magnitude = magnitude,
		Unit = unit,
	}
	result.Dot = unit.Dot
	return result
end
local right, up, forward = vector(1, 0, 0), vector(0, 1, 0), vector(0, 0, -1)
local size = vector(10, 8, 2)
assert(geometry.surfaceOffset(up, right, up, forward, size) == 4)
assert(geometry.surfaceOffset(forward, right, up, forward, size) == 1)
assert(geometry.surfaceOffset(right, right, up, forward, size) == 5)
assert(geometry.withinCone(forward, vector(0, 0, -10), 0.8), "forward targets should be within the cone")
assert(not geometry.withinCone(forward, vector(10, 0, 0), 0.1), "side targets should leave the cone")
assert(not geometry.withinCone(forward, vector(0, 10, 0), 0.8), "vertical targets should leave a horizontal cone")
assert(geometry.withinCone(up, vector(0, 10, 0), 0.8), "upward aim should include targets above the caster")
assert(geometry.withinCone(up, vector(0, 7, -7), 0.6), "the cone should accept targets inside its 3D angle")
assert(not geometry.withinCone(up, vector(0, 7, -7), 0.8), "the cone should reject targets outside its 3D angle")
local identity = {
	PointToObjectSpace = function(_, point)
		return point
	end,
}
local sphereArea = { Radius = 3 }
local sphereBounds = geometry.areaSize("Sphere", sphereArea)
assert(sphereBounds.X == 6 and sphereBounds.Y == 6 and sphereBounds.Z == 6)
assert(geometry.containsArea("Sphere", identity, vector(1, 2, 1), sphereArea))
assert(not geometry.containsArea("Sphere", identity, vector(3, 3, 0), sphereArea))
local capsuleArea = { Radius = 2, Height = 8 }
local capsuleBounds = geometry.areaSize("Capsule", capsuleArea)
assert(capsuleBounds.X == 4 and capsuleBounds.Y == 8 and capsuleBounds.Z == 4)
assert(
	geometry.containsArea("Capsule", identity, vector(2, 0, 0), capsuleArea),
	"Capsule includes the cylindrical side"
)
assert(
	geometry.containsArea("Capsule", identity, vector(0, 4, 0), capsuleArea),
	"Capsule includes its upper rounded cap"
)
assert(
	not geometry.containsArea("Capsule", identity, vector(0, 4.01, 0), capsuleArea),
	"Capsule rejects points above its cap"
)
assert(
	not geometry.containsArea("Capsule", identity, vector(2.01, 0, 0), capsuleArea),
	"Capsule rejects points outside its radius"
)
local cylinderArea = { Radius = 2, Height = 6 }
local cylinderBounds = geometry.areaSize("Cylinder", cylinderArea)
assert(cylinderBounds.X == 4 and cylinderBounds.Y == 6 and cylinderBounds.Z == 4)
assert(geometry.containsArea("Cylinder", identity, vector(2, 3, 0), cylinderArea))
assert(not geometry.containsArea("Cylinder", identity, vector(2.01, 0, 0), cylinderArea))
assert(not geometry.containsArea("Cylinder", identity, vector(0, 3.01, 0), cylinderArea))
local ringArea = { InnerRadius = 2, OuterRadius = 5, Height = 4 }
local ringBounds = geometry.areaSize("Ring", ringArea)
assert(ringBounds.X == 10 and ringBounds.Y == 4 and ringBounds.Z == 10)
assert(geometry.containsArea("Ring", identity, vector(2, 0, 0), ringArea), "Ring should include its inner boundary")
assert(geometry.containsArea("Ring", identity, vector(0, 1, 3), ringArea), "Ring should include its annular band")
assert(geometry.containsArea("Ring", identity, vector(5, 0, 0), ringArea), "Ring should include its outer boundary")
assert(not geometry.containsArea("Ring", identity, vector(1.99, 0, 0), ringArea), "Ring should leave its center safe")
assert(not geometry.containsArea("Ring", identity, vector(5.01, 0, 0), ringArea), "Ring should reject targets outside")
assert(not geometry.containsArea("Ring", identity, vector(3, 2.01, 0), ringArea), "Ring should enforce height")
local coneArea = { Range = 10, Angle = 90, Height = 4 }
local coneBounds = geometry.areaSize("Cone", coneArea)
assert(coneBounds.X > 19.9 and coneBounds.X < 20.1 and coneBounds.Y == 4 and coneBounds.Z == 10)
assert(geometry.containsArea("Cone", identity, vector(9.99, 0, -10), coneArea), "Cone should include its far edge")
assert(
	not geometry.containsArea("Cone", identity, vector(10.1, 0, -10), coneArea),
	"Cone should reject outside its angle"
)
assert(
	geometry.containsArea("Cone", identity, vector(0.99, 0, -1), coneArea),
	"Cone should widen continuously from its apex"
)
assert(not geometry.containsArea("Cone", identity, vector(0, 2.1, -5), coneArea), "Cone should enforce vertical height")
assert(not geometry.containsArea("Cone", identity, vector(0, 0, 0.1), coneArea), "Cone should not hit behind its apex")
assert(not geometry.containsArea("Cone", identity, vector(0, 0, -10.1), coneArea), "Cone should enforce reach")
local boxArea = { Width = 4, Height = 6, Depth = 8 }
local boxBounds = geometry.areaSize("Box", boxArea)
assert(boxBounds.X == 4 and boxBounds.Y == 6 and boxBounds.Z == 8)
assert(geometry.containsArea("Box", identity, vector(2, 3, 4), boxArea))
assert(not geometry.containsArea("Box", identity, vector(2.01, 0, 0), boxArea))
local planeArea = { Width = 8, Height = 10, Thickness = 1 }
local planeBounds = geometry.areaSize("Plane", planeArea)
assert(planeBounds.X == 8 and planeBounds.Y == 10 and planeBounds.Z == 1)
assert(geometry.containsArea("Plane", identity, vector(4, 5, 0.5), planeArea))
assert(not geometry.containsArea("Plane", identity, vector(0, 0, 0.51), planeArea))
assert(not geometry.containsArea("Plane", identity, vector(4.01, 0, 0), planeArea))
local lineArea = { Width = 4, Height = 6, Range = 12 }
local lineBounds = geometry.areaSize("Line", lineArea)
assert(lineBounds.X == 4 and lineBounds.Y == 6 and lineBounds.Z == 12)
local lineFrame = setmetatable({}, {
	__mul = function(_, offset)
		return offset
	end,
})
local lineQueryFrame = geometry.areaQueryFrame("Line", lineFrame, lineArea)
assert(lineQueryFrame.Z == -6, "Broad-phase Line query should center halfway down its forward reach")
assert(geometry.containsArea("Line", identity, vector(2, 3, -12), lineArea), "Line should include its far corner")
assert(geometry.containsArea("Line", identity, vector(0, 0, 0), lineArea), "Line should include its origin")
assert(not geometry.containsArea("Line", identity, vector(2.01, 0, -6), lineArea), "Line should reject side overflow")
assert(not geometry.containsArea("Line", identity, vector(0, 3.01, -6), lineArea), "Line should reject height overflow")
assert(
	not geometry.containsArea("Line", identity, vector(0, 0, 0.01), lineArea),
	"Line should reject space behind its origin"
)
assert(not geometry.containsArea("Line", identity, vector(0, 0, -12.01), lineArea), "Line should reject beyond reach")
local rotatedFrame = {
	PointToObjectSpace = function(_, point)
		return vector(-point.Z, point.Y, point.X)
	end,
}
assert(
	geometry.containsArea("Box", rotatedFrame, vector(4, 0, 0), { Width = 2, Height = 2, Depth = 10 }),
	"yaw-rotated box volume should accept points along its rotated long axis"
)
-- For wall/floor/sloped contacts, every corner must remain on the outward side.
for _, normal in ipairs({ up, forward, right, vector(0, -1, 0), vector(0.6, 0.8, 0), vector(0, 0.6, -0.8) }) do
	local offset = geometry.surfaceOffset(normal, right, up, forward, size)
	local nearest = math.huge
	for _, x in ipairs({ -1, 1 }) do
		for _, y in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				local distance = offset + x * 5 * normal:Dot(right) + y * 4 * normal:Dot(up) + z * normal:Dot(forward)
				assert(distance >= -1e-9, "Construct corner penetrates attachment plane")
				nearest = math.min(nearest, distance)
			end
		end
	end
	assert(math.abs(nearest) < 1e-9, "Construct floats away from attachment plane")
end
print("PASS: area shape bounds/membership and construct floor, wall, ceiling and slope contact")
