--!strict

-- Small role/command targeting policy shared by the server and pure tests.
local Policy = {}

function Policy.targetMode(role, command, profileMode)
	if command == "Hold" or command == "Follow" then
		return "None"
	end
	if role.TargetMode == "AllySupport" then
		if profileMode == "Ally" then
			return "Ally"
		end
		return "None"
	end
	if command == "Attack" then
		return "Hostile"
	end
	if command == "Support" or profileMode == "Ally" then
		if profileMode == "Ally" then
			return "Ally"
		end
		return "None"
	end
	return "Hostile"
end

function Policy.canMelee(role, profileMode)
	return role.CanMelee == true and profileMode ~= "Ally"
end

function Policy.requiresOwnerProtectionRadius(role)
	return role.TargetMode == "GuardedHostile"
end

function Policy.noHostileTargetReason(role, facts, guardRadius)
	if not facts.HasTaggedHostile then
		return "No hostile Enfleshed or MagicHostileTarget is registered"
	elseif not facts.HasLivingHostile then
		return "No living hostile target is available"
	elseif Policy.requiresOwnerProtectionRadius(role) and not facts.WithinGuardRadius then
		return string.format("Guardian only protects hostiles within %d studs of you", guardRadius)
	elseif not facts.WithinScanRange then
		return "No hostile target is within the summon spell's scan range"
	elseif not facts.Visible then
		return "Hostile is in range but blocked from view"
	end
	return "No eligible hostile target is available"
end

function Policy.targetScanRange(authoredSpellRange, defaultRange, maximumRange)
	if type(authoredSpellRange) ~= "number" or authoredSpellRange <= 0 then
		return defaultRange
	end
	return math.min(authoredSpellRange, maximumRange)
end

function Policy.castRange(authoredSpellRange, defaultRange, maximumRange)
	if type(authoredSpellRange) ~= "number" or authoredSpellRange <= 0 then
		return defaultRange
	end
	return math.min(authoredSpellRange, maximumRange)
end

return Policy
