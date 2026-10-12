-- Pure helpers for creating and editing the bounded condition tree.
local Tree = {}

local function isGroup(node)
	return type(node) == "table" and (node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT")
end

Tree.isGroup = isGroup

function Tree.countNodes(node)
	if type(node) ~= "table" then
		return 0
	end
	local count = 1
	if isGroup(node) then
		for _, child in ipairs(node.Conditions or {}) do
			count = count + Tree.countNodes(child)
		end
	end
	return count
end

function Tree.maxDepth(node)
	if not isGroup(node) then
		return 1
	end
	local deepest = 0
	for _, child in ipairs(node.Conditions or {}) do
		deepest = math.max(deepest, Tree.maxDepth(child))
	end
	return 1 + deepest
end

function Tree.newRule()
	return { Family = "Caster", Property = "IsAlive", Operator = "Is", Value = true }
end

function Tree.newGroup(operator)
	if operator ~= "ALL" and operator ~= "ANY" then
		return nil, "Condition groups must use ALL or ANY"
	end
	return { Operator = operator, Conditions = { Tree.newRule() } }
end

function Tree.addRule(group, maxChildren, maxNodes, treeRoot)
	if not isGroup(group) or group.Operator == "NOT" then
		return false, "Rules can only be added to an ALL or ANY group"
	end
	if #(group.Conditions or {}) >= maxChildren then
		return false, "Condition group has reached its child limit"
	end
	if Tree.countNodes(treeRoot or group) + 1 > maxNodes then
		return false, "Condition tree has reached its node limit"
	end
	table.insert(group.Conditions, Tree.newRule())
	return true
end

function Tree.addGroup(group, operator, maxChildren, maxNodes, treeRoot)
	if not isGroup(group) or group.Operator == "NOT" then
		return false, "Groups can only be added to an ALL or ANY group"
	end
	if #(group.Conditions or {}) >= maxChildren then
		return false, "Condition group has reached its child limit"
	end
	local nested = Tree.newGroup(operator)
	if not nested then
		return false, "Condition groups must use ALL or ANY"
	end
	if Tree.countNodes(treeRoot or group) + Tree.countNodes(nested) > maxNodes then
		return false, "Condition tree has reached its node limit"
	end
	table.insert(group.Conditions, nested)
	return true
end

function Tree.wrapNot(node)
	if type(node) ~= "table" or isGroup(node) and node.Operator == "NOT" then
		return nil, "Only a non-negated condition can be wrapped in NOT"
	end
	return { Operator = "NOT", Conditions = { node } }
end

function Tree.unwrapNot(node)
	if not isGroup(node) or node.Operator ~= "NOT" or type(node.Conditions) ~= "table" then
		return nil, "Condition is not a NOT group"
	end
	return node.Conditions[1]
end

function Tree.replace(root, parent, index, replacement)
	if parent then
		if not isGroup(parent) or type(index) ~= "number" then
			return false
		end
		if parent.Operator == "NOT" and index ~= 1 then
			return false
		end
		parent.Conditions[index] = replacement
	else
		root = replacement
	end
	return true, root
end

function Tree.remove(parent, index)
	if not isGroup(parent) or parent.Operator == "NOT" or type(index) ~= "number" then
		return false
	end
	if #(parent.Conditions or {}) <= 1 then
		return false, "Condition groups must keep at least one child"
	end
	table.remove(parent.Conditions, index)
	return true
end

return Tree
