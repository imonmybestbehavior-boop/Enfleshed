--!strict
-- Per-effect runtime counters exposed to conditions as SpellState values.
-- MagicService.emit records each event on the effect's persistent record
-- (RuntimeOrigin); MagicConditions reads them back when resolving rules.
local Counters = {}

-- Counts one firing of `event` on `holder` and returns
-- (TriggerCount including this firing, number of event targets).
function Counters.record(holder: any, event: string, targets: { any }?): (number, number)
	holder.EventCounts = holder.EventCounts or {}
	local triggerCount = (holder.EventCounts[event] or 0) + 1
	holder.EventCounts[event] = triggerCount
	return triggerCount, #(targets or {})
end

-- Targets currently inside a Field/Aura, or nil for effects without an area.
-- Reactive events carry the area record as RuntimeOrigin.
function Counters.occupants(castState: any): number?
	local origin = if type(castState.RuntimeOrigin) == "table" then castState.RuntimeOrigin else nil
	local present = castState.PresentTargets or (origin and origin.PresentTargets)
	if type(present) ~= "table" then
		return nil
	end
	local count = 0
	for _, inside in pairs(present) do
		if inside then
			count += 1
		end
	end
	return count
end

return Counters
