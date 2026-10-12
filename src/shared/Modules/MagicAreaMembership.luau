--!strict

-- Pure set difference for sampled Field/Aura occupancy transitions.
local Membership = {}

function Membership.diff(previous, targets)
	local current = {}
	local entered = {}
	for _, target in ipairs(targets) do
		if not current[target] then
			current[target] = true
			if not previous[target] then
				table.insert(entered, target)
			end
		end
	end

	local exited = {}
	for target in pairs(previous) do
		if not current[target] then
			table.insert(exited, target)
		end
	end

	return current, entered, exited
end

function Membership.clear(previous)
	local exited = {}
	for target in pairs(previous) do
		table.insert(exited, target)
	end
	return exited
end

return Membership
