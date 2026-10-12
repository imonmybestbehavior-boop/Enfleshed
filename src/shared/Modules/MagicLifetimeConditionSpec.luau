--!strict

-- Defines the keep-alive meaning of condition-driven effect lifetimes.
local Spec = {}

function Spec.allowsStart(mode, conditionResult)
	return mode ~= "UntilConditionFails" or conditionResult == true
end

function Spec.shouldEnd(mode, conditionResult)
	if mode == "UntilConditionFails" then
		return conditionResult ~= true
	end
	return conditionResult == true
end

return Spec
