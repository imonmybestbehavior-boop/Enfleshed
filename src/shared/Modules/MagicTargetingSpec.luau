--!strict

-- Target selection cannot reach farther than either the authored targeting
-- range or the maximum distance of the Form's actual cast geometry.
local Spec = {}

function Spec.entityRange(definition)
	local targetingRange = definition.TargetRules.Range
	local formRange = nil
	if definition.Form == "Projectile" then
		formRange = definition.Projectile.MaxDistance
	elseif definition.Form == "Beam" then
		formRange = definition.Beam.Range
	elseif definition.Form == "Wave" then
		formRange = definition.Wave.Range
	elseif definition.Form == "Construct" then
		formRange = definition.Construct.Distance
	end
	if type(formRange) == "number" then
		return math.min(targetingRange, formRange)
	end
	return targetingRange
end

return Spec
