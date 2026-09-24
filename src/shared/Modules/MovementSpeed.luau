--!strict
-- One calculation for server speed, validation budgets and client prediction.
local Speed = {}
function Speed.calculate(walk, sprint, sprinting, bonus, multiplier)
	return ((sprinting and sprint or walk) + bonus) * multiplier
end
return Speed
