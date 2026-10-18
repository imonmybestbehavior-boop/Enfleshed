local Aim = assert(loadfile("src/shared/Modules/MagicBeamAim.luau"))()
local vector
local mt = {
	__sub = function(a, b)
		return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end,
	__index = function(v, k)
		if k == "Magnitude" then
			return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		end
		if k == "Unit" then
			local m = v.Magnitude
			return vector(v.X / m, v.Y / m, v.Z / m)
		end
		if k == "Dot" then
			return function(a, b)
				return a.X * b.X + a.Y * b.Y + a.Z * b.Z
			end
		end
	end,
}
vector = function(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, mt)
end
local forward = vector(0, 0, -1)
local target = vector(0, 2, -10)
local hand = vector(2, 1, 0)
local result = Aim.direction(hand, forward, target)
local expected = (target - hand).Unit
assert((result - expected).Magnitude < 0.000001, "Hand-offset beam must converge on the aim point")
assert(result.X < 0 and result.Y > 0, "Correction must include horizontal and vertical hand offset")
local movedHand = vector(-3, 2, 1)
assert(
	(Aim.direction(movedHand, result, target) - (target - movedHand).Unit).Magnitude < 0.000001,
	"Channel movement must recompute from its new origin"
)
assert(Aim.direction(hand, forward, nil) == forward, "Direction-only clients remain supported")
assert(Aim.direction(hand, forward, hand) == forward, "Coincident aim points must not create NaNs")
assert(Aim.direction(hand, forward, vector(2, 1, 10), 0.2) == forward, "Rejected rearward aim must keep the fallback")
print("Beam aiming: hand convergence, moved origin, legacy input, coincident and rearward points passed")
