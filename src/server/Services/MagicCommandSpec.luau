--!strict

-- Shared matching semantics for optional named-command trigger filters.
local Spec = {}

function Spec.matches(filter, command)
	return filter == nil or filter == command
end

function Spec.canExecuteCompanionSpell(requiresCommand, commandIssued, command)
	if requiresCommand ~= true then
		return true
	end
	return commandIssued == true and (command == "Attack" or command == "Support")
end

function Spec.validSelectionId(id)
	return type(id) == "number" and id == id and id % 1 == 0 and id > 0
end

function Spec.validPointCoordinates(x, y, z)
	local function finiteBounded(value)
		return type(value) == "number" and value == value and math.abs(value) <= 1000000
	end
	return finiteBounded(x) and finiteBounded(y) and finiteBounded(z)
end

function Spec.matchesSelection(recordId, selectedId)
	return selectedId == nil or recordId == selectedId
end

function Spec.activeCommandCount(active, owner)
	local commandIds = {}
	for _, effect in ipairs(active) do
		if effect.Player == owner and effect.CommandCastId ~= nil then
			commandIds[effect.CommandCastId] = true
		end
	end
	local count = 0
	for _ in pairs(commandIds) do
		count = count + 1
	end
	return count
end

function Spec.canStartActiveCommand(active, owner, maximum)
	return type(maximum) == "number" and maximum >= 0 and Spec.activeCommandCount(active, owner) < maximum
end

function Spec.nextPatrolRoute(existing, waypoint)
	if type(existing) == "table" and #existing == 1 then
		return { existing[1], waypoint }, true
	end
	return { waypoint }, false
end

return Spec
