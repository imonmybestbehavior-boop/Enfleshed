--!strict

-- Small pure classifier shared by target filters and condition evaluation.
local Relationships = {}

function Relationships.resolveAlignment(explicitAlignment, ownerAlignment)
	if type(ownerAlignment) == "string" and ownerAlignment ~= "" then
		return ownerAlignment
	end
	if type(explicitAlignment) == "string" and explicitAlignment ~= "" then
		return explicitAlignment
	end
	return nil
end

function Relationships.classify(isSelf, isHostile, sameAlignment, mutuallyAllied)
	if isSelf then
		return "Self"
	elseif isHostile then
		return "Hostile"
	elseif sameAlignment or mutuallyAllied then
		return "Ally"
	end
	return "Neutral"
end

function Relationships.matches(relationship, rule)
	return rule == nil or rule == "Any" or relationship == rule
end

return Relationships
