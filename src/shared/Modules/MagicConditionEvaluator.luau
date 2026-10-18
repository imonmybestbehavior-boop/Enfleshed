-- Pure condition-tree evaluator. Runtime adapters provide values through the
-- resolver; this module can be tested without Roblox services.
local Evaluator = {}

local function hasDelimitedTag(encoded, expected)
	if type(encoded) ~= "string" or type(expected) ~= "string" then
		return false
	end
	local tag = string.lower(expected)
	if #tag == 0 or #tag > 48 or string.find(tag, "[^%w_%-]") then
		return false
	end
	return string.find(encoded, "|" .. tag .. "|", 1, true) ~= nil
end

local function compare(actual, operator, expected)
	if actual == nil then
		return false
	end
	if operator == "==" or operator == "Is" then
		return actual == expected
	elseif operator == "!=" or operator == "IsNot" then
		return actual ~= expected
	elseif operator == ">" then
		return type(actual) == "number" and actual > expected
	elseif operator == ">=" then
		return type(actual) == "number" and actual >= expected
	elseif operator == "<" then
		return type(actual) == "number" and actual < expected
	elseif operator == "<=" then
		return type(actual) == "number" and actual <= expected
	elseif operator == "MultipleOf" then
		return type(actual) == "number" and type(expected) == "number" and expected >= 1 and actual % expected == 0
	elseif operator == "Within" then
		return type(actual) == "number" and actual <= expected
	elseif operator == "Outside" then
		return type(actual) == "number" and actual > expected
	elseif operator == "Has" then
		if type(actual) == "string" and string.sub(actual, 1, 1) == "|" then
			return hasDelimitedTag(actual, expected)
		end
		return type(actual) == "string" and string.find(string.lower(actual), string.lower(expected), 1, true) ~= nil
	elseif operator == "DoesNotHave" then
		if type(actual) == "string" and string.sub(actual, 1, 1) == "|" then
			return not hasDelimitedTag(actual, expected)
		end
		return type(actual) == "string" and string.find(string.lower(actual), string.lower(expected), 1, true) == nil
	end
	return false
end

local function evaluateNode(node, resolver, applicableFamilies)
	if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
		if node.Operator == "NOT" then
			local child = evaluateNode(node.Conditions[1], resolver, applicableFamilies)
			if child == nil then
				return nil
			end
			return not child
		end
		local applicable, omitted, passed = 0, 0, 0
		for _, childNode in ipairs(node.Conditions) do
			local result = evaluateNode(childNode, resolver, applicableFamilies)
			if result == nil then
				omitted = omitted + 1
			else
				applicable = applicable + 1
				if result then
					passed = passed + 1
				end
			end
		end
		if applicable == 0 then
			return nil
		end
		if node.Operator == "ALL" then
			if passed ~= applicable then
				return false
			end
			if omitted == 0 then
				return true
			end
			return nil
		end
		if passed > 0 then
			return true
		end
		if omitted == 0 then
			return false
		end
		return nil
	end
	if applicableFamilies and not applicableFamilies[node.Family] then
		return nil
	end
	return compare(resolver(node.Family, node.Property), node.Operator, node.Value)
end

function Evaluator.evaluate(tree, resolver, applicableFamilies)
	return evaluateNode(tree, resolver, applicableFamilies)
end

return Evaluator
