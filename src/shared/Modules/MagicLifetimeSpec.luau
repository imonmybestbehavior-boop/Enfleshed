--!strict

-- Data-only lifetime compatibility shared by SpellSpec and the Magic Lab UI.
local Spec = {}

Spec.ModesByForm = {
	Projectile = { FixedDuration = true, UntilTargetLost = true, UntilConditionFails = true },
	Beam = { Instantaneous = true, FixedDuration = true, UntilConditionFails = true },
	Wave = { Instantaneous = true, FixedDuration = true, UntilConditionFails = true },
	Field = {
		FixedDuration = true,
		UntilDestroyed = true,
		UntilTargetLost = true,
		UntilToggledOff = true,
		UntilResourceDepleted = true,
		UntilConditionFails = true,
	},
	Aura = {
		FixedDuration = true,
		UntilDestroyed = true,
		UntilToggledOff = true,
		UntilTargetLost = true,
		UntilResourceDepleted = true,
		UntilConditionFails = true,
	},
	SelfEnhancement = {
		FixedDuration = true,
		UntilToggledOff = true,
		UntilResourceDepleted = true,
		UntilConditionFails = true,
	},
	Construct = {
		FixedDuration = true,
		Persistent = true,
		UntilDestroyed = true,
		UntilToggledOff = true,
		UntilTargetLost = true,
		UntilResourceDepleted = true,
		UntilConditionFails = true,
	},
	Manipulation = { Instantaneous = true },
}

function Spec.supports(form, mode)
	local modes = Spec.ModesByForm[form]
	return modes ~= nil and modes[mode] == true
end

function Spec.supportsTargeting(form, mode, targeting, followsTarget, maintainsTarget)
	if not Spec.supports(form, mode) then
		return false
	end
	if mode ~= "UntilTargetLost" then
		return true
	end
	if form == "Field" then
		return (targeting == "EntityTarget" or targeting == "ObjectTarget") and followsTarget == true
	elseif form == "Projectile" then
		return targeting == "EntityTarget" and maintainsTarget == true
	end
	return targeting == "EntityTarget" or targeting == "ObjectTarget"
end

function Spec.targetLost(mode, targetIsAlive)
	return mode == "UntilTargetLost" and targetIsAlive ~= true
end

function Spec.claimExpiry(state)
	if type(state) ~= "table" or state.ExpireEventFired == true then
		return false
	end
	state.ExpireEventFired = true
	return true
end

function Spec.effectiveDuration(mode, duration)
	if mode == "UntilConditionFails" then
		return duration or math.huge
	end
	if
		mode == "UntilToggledOff"
		or mode == "Persistent"
		or mode == "UntilDestroyed"
		or mode == "UntilTargetLost"
		or mode == "UntilResourceDepleted"
	then
		return math.huge
	end
	return duration
end

function Spec.validConditionDuration(form, duration, maximum)
	if form == "Projectile" and duration == nil then
		return false
	end
	return duration == nil
		or (type(duration) == "number" and duration == duration and duration >= 0.1 and duration <= maximum)
end

return Spec
