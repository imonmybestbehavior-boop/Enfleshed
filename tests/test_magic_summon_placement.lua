local vectorMetatable = {}
vectorMetatable.__index = function(value, key)
	if key == "Magnitude" then
		return math.sqrt(value.X * value.X + value.Y * value.Y + value.Z * value.Z)
	elseif key == "Unit" then
		local magnitude = value.Magnitude
		return setmetatable(
			{ X = value.X / magnitude, Y = value.Y / magnitude, Z = value.Z / magnitude },
			vectorMetatable
		)
	end
	return nil
end
vectorMetatable.__add = function(left, right)
	return { X = left.X + right.X, Y = left.Y + right.Y, Z = left.Z + right.Z }
end
vectorMetatable.__unm = function(value)
	return setmetatable({ X = -value.X, Y = -value.Y, Z = -value.Z }, vectorMetatable)
end
vectorMetatable.__mul = function(value, scale)
	return setmetatable({ X = value.X * scale, Y = value.Y * scale, Z = value.Z * scale }, vectorMetatable)
end

local function vector(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMetatable)
end

Vector3 = { xAxis = vector(1, 0, 0) }
local Placement = dofile("src/server/Services/MagicSummonPlacement.luau")
local surface = vector(10, 20, 30)
local clearance = 2

local downwardBeam = Placement.behindImpact(surface, vector(0, -1, 0), clearance)
assert(
	downwardBeam.X == 10 and downwardBeam.Y == 22 and downwardBeam.Z == 30,
	"Downward beams place Event summons above contact"
)

local forwardProjectile = Placement.behindImpact(surface, vector(1, 0, 0), clearance)
assert(forwardProjectile.X == 8 and forwardProjectile.Y == 20 and forwardProjectile.Z == 30)

local fallback = Placement.behindImpact(surface, vector(0, 0, 0), clearance)
assert(fallback.X == 12 and fallback.Y == 20 and fallback.Z == 30, "Zero direction uses the stable fallback")

print("Magic Event summon placement direction tests passed")
