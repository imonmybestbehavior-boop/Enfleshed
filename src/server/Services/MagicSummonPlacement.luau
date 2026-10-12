-- Placement math shared by Event-triggered summons. Keep the summon behind
-- the impact surface relative to the incoming cast direction.
local Placement = {}

function Placement.behindImpact(eventPosition, sourceDirection, clearance)
	local awayFromImpact = Vector3.xAxis
	if sourceDirection.Magnitude > 0.001 then
		awayFromImpact = -sourceDirection.Unit
	end
	return eventPosition + awayFromImpact * clearance
end

return Placement
