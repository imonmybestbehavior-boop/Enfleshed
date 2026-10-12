--!strict

-- Discrete world-manipulation operations. Authorization and target selection
-- remain in MagicService; this registry only applies the authored operation.
local Manipulation = {}

local directionByOperation = {
	Raise = 1,
	Lower = -1,
}

function Manipulation.offset(operation, distance)
	local direction = directionByOperation[operation]
	if not direction then
		return nil
	end
	return direction * distance
end

function Manipulation.execute(operation, target, distance)
	local verticalOffset = Manipulation.offset(operation, distance)
	if verticalOffset == nil then
		return false
	end
	target.Position = target.Position + Vector3.yAxis * verticalOffset
	return true
end

return Manipulation
