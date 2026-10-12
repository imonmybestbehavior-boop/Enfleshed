local limits = {
	MaxProjectileMotionPhases = 4,
	MaxDuration = 15,
	MinInterval = 0.1,
	MaxAcceleration = 100,
	MaxGravity = 100,
	ProjectileMotionModes = {
		"Linear",
		"Arcing",
		"Bezier",
		"Falling",
		"Orbiting",
		"Stationary",
		"Expanding",
		"Attached",
	},
	MaxProjectileArcHeight = 40,
	MaxProjectileBezierOffset = 30,
	MaxProjectileOrbitRadius = 20,
	MaxProjectileOrbitSpeed = 8,
	MaxProjectileExpansion = 8,
	MaxProjectileExpansionSpeed = 12,
}
local Vector3 = {}
local vectorMeta = {}
vectorMeta.__index = function(value, key)
	if key == "Magnitude" then
		return math.sqrt(value.X * value.X + value.Y * value.Y + value.Z * value.Z)
	elseif key == "Unit" then
		local magnitude = value.Magnitude
		return Vector3.new(value.X / magnitude, value.Y / magnitude, value.Z / magnitude)
	elseif key == "Cross" then
		return function(self, other)
			return Vector3.new(
				self.Y * other.Z - self.Z * other.Y,
				self.Z * other.X - self.X * other.Z,
				self.X * other.Y - self.Y * other.X
			)
		end
	end
	return nil
end
vectorMeta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vectorMeta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vectorMeta.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	end
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
function Vector3.new(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
end
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.zero = Vector3.new(0, 0, 0)
local moduleScript = { Parent = { Parent = { Configuration = { MagicLab = "limits" } } } }
local motion = assert(loadfile(
	"src/shared/Modules/MagicProjectileMotion.luau",
	"t",
	setmetatable({
		script = moduleScript,
		Vector3 = Vector3,
		require = function(reference)
			assert(reference == "limits")
			return limits
		end,
	}, { __index = _G })
))()

local phases = {
	{ Duration = 0.5, SpeedMultiplier = 1, Acceleration = 0, Gravity = 0 },
	{ Duration = 1, SpeedMultiplier = 2, Acceleration = 20, Gravity = 0 },
	{ Duration = 0.5, SpeedMultiplier = 0.5, Acceleration = -10, Gravity = 8 },
}
assert(motion.validate(phases, 2))
assert(not motion.validate(phases, 1.9), "Motion phases cannot outlast projectile lifetime")
assert(not motion.validate({ { Duration = 0.05 } }, 2), "Phase duration must respect minimum tick interval")
assert(not motion.validate({ { Duration = 1, SpeedMultiplier = 4 } }, 2), "Speed multiplier must stay bounded")
assert(not motion.validate({ { Duration = 1, Unknown = 1 } }, 2), "Unknown phase fields must fail")
assert(
	motion.validate({ { Mode = "Arcing", Duration = 1, ArcHeight = 8 } }, 2),
	"Arcing phases need a bounded arc height"
)
assert(not motion.validate({ { Mode = "Arcing", Duration = 1 } }, 2), "Arcing phases must specify their height")
assert(motion.validate({ { Mode = "Falling", Duration = 1, Gravity = 40 } }, 2), "Falling phases need positive gravity")
assert(
	motion.validate({ { Mode = "Orbiting", Duration = 1, OrbitRadius = 3, OrbitAngularSpeed = 2 } }, 2),
	"Orbiting phases need a radius and angular speed"
)
assert(motion.validate({ { Mode = "Stationary", Duration = 1 } }, 2), "Stationary phases need no extra geometry")
assert(motion.validate({ { Mode = "Attached", Duration = 1 } }, 2), "Attached phases travel without geometry overrides")
assert(
	motion.validate({ { Mode = "Expanding", Duration = 1, ExpandMultiplier = 3 } }, 2),
	"Expanding phases need a bounded collision expansion"
)
assert(
	motion.validate({ { Mode = "Bezier", Duration = 1, BezierSide = 8, BezierHeight = 3 } }, 2),
	"Bezier phases accept bounded side and vertical offsets"
)
assert(not motion.validate({ { Mode = "Bezier", Duration = 1 } }, 2), "Bezier phases must author a visible curve")
assert(
	not motion.validate({ { Mode = "Bezier", Duration = 1, BezierSide = 31 } }, 2),
	"Bezier offsets must remain bounded"
)
assert(
	not motion.validate({ { Mode = "Bezier", Duration = 1, BezierHeight = 4, Gravity = 1 } }, 2),
	"Bezier phases cannot combine with acceleration or gravity"
)
assert(
	not motion.validate({ { Mode = "Expanding", Duration = 0.5, ExpandMultiplier = 8 } }, 2, 20),
	"Expanding phases must not grow faster than swept hit detection can sample"
)
assert(not motion.validate({ { Mode = "Warp", Duration = 1 } }, 2), "Unknown motion modes must fail")

local index, elapsed, phase = motion.advance(phases, 1, 0, 0.3)
assert(index == 1 and math.abs(elapsed - 0.3) < 1e-6 and phase == phases[1])
index, elapsed, phase = motion.advance(phases, index, elapsed, 0.4)
assert(index == 2 and math.abs(elapsed - 0.2) < 1e-6 and phase == phases[2])
index, elapsed, phase = motion.advance(phases, index, elapsed, 2)
assert(index == 3 and math.abs(elapsed - 1.2) < 1e-6 and phase == phases[3])
assert(motion.initialSpeed(100, phases) == 100)
assert(motion.initialSpeed(100, { { SpeedMultiplier = 1.5 } }) == 150)
assert(math.abs(motion.arcOffset(10, 2, 1) - 10) < 1e-6, "Arc peaks at authored phase midpoint")
assert(motion.arcOffset(10, 2, 0) == 0 and motion.arcOffset(10, 2, 2) == 0, "Arc rejoins its phase path")
assert(math.abs(motion.expansion(4, 2, 1) - 2.5) < 1e-6, "Expansion scales linearly across phase")
local origin = Vector3.new(2, 3, 4)
local direction = Vector3.new(0, 0, -1)
local side = Vector3.new(1, 0, 0)
local start = motion.bezierPosition(origin, direction, side, 60, 8, 4, 0)
local middle = motion.bezierPosition(origin, direction, side, 60, 8, 4, 0.5)
local finish = motion.bezierPosition(origin, direction, side, 60, 8, 4, 1)
assert(start.X == origin.X and start.Y == origin.Y and start.Z == origin.Z, "Bezier begins at the phase origin")
assert(finish.X == 2 and finish.Y == 3 and finish.Z == -56, "Bezier rejoins its forward endpoint")
assert(math.abs(middle.X - 8) < 1e-6 and math.abs(middle.Y - 6) < 1e-6, "Bezier reaches its authored curve")
assert(motion.bezierTangent(direction, side, 60, 8, 4, 1).Magnitude > 0, "Bezier provides an exit tangent")

print("Magic projectile motion: validation, ordered transitions, and speed scaling passed")
