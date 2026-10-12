-- Cause filters for the OnTargetDeath lifecycle event.
local Spec = {}

Spec.Modes = { "Either", "KilledByThisSpell", "DiedWhileAffected" }

function Spec.matches(mode, cause)
	return mode == nil or mode == "Either" or mode == cause
end

function Spec.claim(runtime, target)
	if type(runtime) ~= "table" or target == nil then
		return true
	end
	local claims = runtime.TargetDeathClaims
	if type(claims) ~= "table" then
		claims = setmetatable({}, { __mode = "k" })
		runtime.TargetDeathClaims = claims
	end
	if claims[target] then
		return false
	end
	claims[target] = true
	return true
end

return Spec
