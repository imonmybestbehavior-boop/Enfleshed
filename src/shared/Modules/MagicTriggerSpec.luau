-- Pure trigger normalization shared by registered spells and the Magic Lab.
local TriggerSpec = {}

local function normalizeActions(actions)
	if type(actions) ~= "table" then
		return nil
	end
	local first = actions[1]
	if type(first) == "table" and first.Kind ~= nil then
		return { { Payloads = actions } }
	end
	return actions
end

function TriggerSpec.normalize(source)
	local result = {}
	if type(source) ~= "table" then
		return result
	end

	-- Process canonical keys first, then append aliases so unordered table
	-- iteration can never discard or reorder the alias steps.
	for event, actions in pairs(source) do
		if event ~= "OnInterval" then
			local normalized = normalizeActions(actions)
			if normalized then
				result[event] = normalized
			end
		end
	end

	local intervalActions = normalizeActions(source.OnInterval)
	if intervalActions then
		result.OnTick = result.OnTick or {}
		for _, action in ipairs(intervalActions) do
			table.insert(result.OnTick, action)
		end
	end

	return result
end

return TriggerSpec
