-- Generic named resource rules shared by SpellSpec, the server runtime, and tests.
local Spec = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Spec.order(definitions)
	local result = {}
	for id in pairs(definitions or {}) do
		table.insert(result, id)
	end
	table.sort(result)
	return result
end

function Spec.defaults(definitions)
	local result = {}
	for id, definition in pairs(definitions or {}) do
		result[id] = definition.Starting
	end
	return result
end

function Spec.validateDefinitions(definitions)
	if type(definitions) ~= "table" then
		return false, "Special resource definitions must be a table"
	end
	for id, definition in pairs(definitions) do
		if
			type(id) ~= "string"
			or not string.match(id, "^[%a][%w_]*$")
			or type(definition) ~= "table"
			or type(definition.Label) ~= "string"
			or #definition.Label < 1
			or #definition.Label > 32
			or not finite(definition.Capacity)
			or definition.Capacity <= 0
			or not finite(definition.Starting)
			or definition.Starting < 0
			or definition.Starting > definition.Capacity
			or not finite(definition.RecoveryPerSecond)
			or definition.RecoveryPerSecond < 0
			or type(definition.Attribute) ~= "string"
			or not string.match(definition.Attribute, "^Magic[%w_]+$")
		then
			return false, "Invalid special resource definition: " .. tostring(id)
		end
	end
	return true
end

function Spec.validateCosts(costs, definitions, maxTypes, maxCost)
	if costs == nil then
		return true
	end
	if type(costs) ~= "table" then
		return false, "Special resource costs must be a table"
	end
	local count = 0
	for id, amount in pairs(costs) do
		local definition = definitions and definitions[id]
		if not definition then
			return false, "Unknown special resource: " .. tostring(id)
		end
		if not finite(amount) or amount < 0 or amount > maxCost then
			return false, "Invalid special resource cost: " .. tostring(id)
		end
		count = count + 1
	end
	if count > maxTypes then
		return false, "Too many special resource costs"
	end
	return true
end

function Spec.validateCurrent(current, definitions)
	if type(current) ~= "table" then
		return false
	end
	for id, amount in pairs(current) do
		local definition = definitions and definitions[id]
		if not definition or not finite(amount) or amount < 0 or amount > definition.Capacity then
			return false
		end
	end
	for id in pairs(definitions or {}) do
		if current[id] == nil then
			return false
		end
	end
	return true
end

function Spec.mergeCurrent(current, definitions)
	local result = Spec.defaults(definitions)
	if type(current) == "table" then
		for id, value in pairs(current) do
			if definitions and definitions[id] then
				result[id] = value
			end
		end
	end
	return result
end

function Spec.canAfford(current, costs, definitions)
	local valid = Spec.validateCosts(costs, definitions, math.huge, math.huge)
	if not valid or not Spec.validateCurrent(current, definitions) then
		return false, nil
	end
	for id, amount in pairs(costs or {}) do
		if current[id] < amount then
			return false, id
		end
	end
	return true, nil
end

function Spec.spend(current, costs, definitions)
	local canAfford, missing = Spec.canAfford(current, costs, definitions)
	if not canAfford then
		return false, missing
	end
	for id, amount in pairs(costs or {}) do
		current[id] = current[id] - amount
	end
	return true, nil
end

function Spec.advance(current, definitions, delta)
	if delta <= 0 or not Spec.validateCurrent(current, definitions) then
		return false
	end
	local changed = false
	for id, definition in pairs(definitions or {}) do
		local before = current[id]
		current[id] = math.min(definition.Capacity, before + definition.RecoveryPerSecond * delta)
		changed = changed or current[id] ~= before
	end
	return changed
end

return Spec
