-- Convert a camera aim point into a ray from the actual casting origin.
-- Caller validates the point and direction; collision/range checks stay server-owned.
local Aim = {}
function Aim.direction(origin, fallback, point, minimumDot)
	if point then
		local delta = point - origin
		if delta.Magnitude > 0.001 and fallback:Dot(delta.Unit) >= (minimumDot or -1) then
			return delta.Unit
		end
	end
	return fallback
end
return Aim
