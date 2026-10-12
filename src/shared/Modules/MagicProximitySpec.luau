--!strict

-- Shared bounds and per-effect de-duplication state for proximity events.
local Spec = {}

Spec.SupportedForms = {
	SelfEnhancement = true,
	Construct = true,
}

Spec.Defaults = {
	Radius = 8,
	Interval = 0.2,
	MaxTargets = 8,
}

function Spec.validate(value, maxRadius, minInterval, maxTargets)
	if type(value) ~= "table" then
		return false
	end
	local radius = value.Radius
	local interval = value.Interval
	local targetLimit = value.MaxTargets
	return type(radius) == "number"
		and radius == radius
		and radius >= 0.25
		and radius <= maxRadius
		and type(interval) == "number"
		and interval == interval
		and interval >= minInterval
		and interval <= 1
		and type(targetLimit) == "number"
		and targetLimit % 1 == 0
		and targetLimit >= 1
		and targetLimit <= maxTargets
end

function Spec.newState(now)
	return {
		NextCheckAt = now or 0,
		Targets = {},
		TargetCount = 0,
	}
end

function Spec.isDue(state, now, maximumTargets)
	return state.TargetCount < maximumTargets and now >= state.NextCheckAt
end

function Spec.beginSample(state, now, interval)
	state.NextCheckAt = now + interval
end

function Spec.claim(state, target, maximumTargets)
	if state.Targets[target] or state.TargetCount >= maximumTargets then
		return false
	end
	state.Targets[target] = true
	state.TargetCount = state.TargetCount + 1
	return true
end

return Spec
