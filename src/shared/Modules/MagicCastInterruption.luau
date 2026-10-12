--!strict

-- Small pure rules for interrupting a cast before its server-timed release.
local Interruption = {}

function Interruption.damage(casting, amount)
	return casting.InterruptOnDamage == true and amount > 0 and amount == amount and amount < math.huge
end

function Interruption.movement(casting, distance)
	local threshold = casting.InterruptMoveDistance or 0
	return threshold > 0 and distance > threshold
end

return Interruption
