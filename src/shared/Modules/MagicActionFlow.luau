--!strict
-- Pure presentation adapter for turning a SpellSpec trigger table into player-facing
-- action blocks. It never mutates or simplifies the saved spell definition.
local Flow = {}

local RELATION_LABELS = {
	First = "WHEN",
	Parallel = "ALSO",
}

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child)
	end
	return result
end

local OPERATOR_TEXT = {
	["=="] = "is",
	["!="] = "is not",
	Is = "is",
	IsNot = "is not",
	[">"] = ">",
	[">="] = "≥",
	["<"] = "<",
	["<="] = "≤",
	Within = "within",
	Outside = "beyond",
	Has = "has",
	DoesNotHave = "lacks",
	MultipleOf = "is a multiple of",
}

-- Readable one-line form of a condition tree for the action map, e.g.
-- "Target HealthPercent < 0.5 and SpellState AreaOccupants ≥ 3".
function Flow.conditionSummary(node): string
	if type(node) ~= "table" then
		return "?"
	end
	if node.Operator == "ALL" or node.Operator == "ANY" then
		local parts = {}
		for _, child in ipairs(node.Conditions or {}) do
			local text = Flow.conditionSummary(child)
			if child.Operator == "ALL" or child.Operator == "ANY" then
				text = "(" .. text .. ")"
			end
			table.insert(parts, text)
		end
		return table.concat(parts, if node.Operator == "ALL" then " and " else " or ")
	elseif node.Operator == "NOT" then
		return "not (" .. Flow.conditionSummary((node.Conditions or {})[1]) .. ")"
	end
	return string.format(
		"%s %s %s %s",
		tostring(node.Family),
		tostring(node.Property),
		OPERATOR_TEXT[node.Operator] or tostring(node.Operator),
		tostring(node.Value)
	)
end

-- Starter condition for a new IF branch; the player edits it afterwards.
function Flow.branchCondition()
	return {
		Operator = "ALL",
		Conditions = { { Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.5 } },
	}
end

-- "Stronger when you're hurt": a branch that runs while the caster's health
-- is below `percent` (the existing Caster.HealthPercent condition).
function Flow.casterHealthBelow(percent: number)
	return {
		Operator = "ALL",
		Conditions = {
			{ Family = "Caster", Property = "HealthPercent", Operator = "<", Value = math.clamp(percent, 1, 99) / 100 },
		},
	}
end

local function depth(node): number
	if type(node) ~= "table" or not (node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT") then
		return 1
	end
	local deepest = 0
	for _, child in ipairs(node.Conditions or {}) do
		deepest = math.max(deepest, depth(child))
	end
	return 1 + deepest
end

-- The condition for an OTHERWISE branch: the exact negation of `condition`.
-- Unwraps an existing NOT instead of stacking another one.
function Flow.otherwise(condition, maxDepth: number): (any?, string?)
	if type(condition) ~= "table" then
		return nil, "Only a conditional step can have an otherwise branch."
	end
	if condition.Operator == "NOT" then
		local inner = copy((condition.Conditions or {})[1])
		local isGroup = type(inner) == "table"
			and (inner.Operator == "ALL" or inner.Operator == "ANY" or inner.Operator == "NOT")
		if type(inner) == "table" and not isGroup then
			-- A bare rule must sit inside a group to be a step condition.
			inner = { Operator = "ALL", Conditions = { inner } }
		end
		return inner, nil
	end
	if depth(condition) + 1 > maxDepth then
		return nil, "This condition is too deeply nested to invert."
	end
	return { Operator = "NOT", Conditions = { copy(condition) } }, nil
end

local function payloadLabels(step, schema): { string }
	local labels = {}
	for _, payload in ipairs(step.Payloads or {}) do
		local definition = schema.Payloads[payload.Kind]
		table.insert(labels, if definition then definition.Label else payload.Kind or "Unknown effect")
	end
	if step.Behavior then
		local definition = schema.Behaviors[step.Behavior]
		table.insert(labels, if definition then definition.Label else step.Behavior)
	end
	if #labels == 0 then
		table.insert(labels, "Empty step")
	end
	return labels
end

function Flow.describeStep(eventName: string, stepIndex: number, step, schema)
	local eventLabel = schema.EventLabels[eventName] or eventName
	local labels = payloadLabels(step, schema)
	return {
		Event = eventName,
		EventLabel = eventLabel,
		StepIndex = stepIndex,
		Relation = if stepIndex == 1 then RELATION_LABELS.First else RELATION_LABELS.Parallel,
		Title = table.concat(labels, " + "),
		HasCondition = step.Condition ~= nil,
		ConditionLabel = if step.Condition then "IF " .. Flow.conditionSummary(step.Condition) else "Always",
		IsEmpty = #(step.Payloads or {}) == 0 and step.Behavior == nil,
	}
end

function Flow.build(definition, schema, eventOrder: { string }?)
	local result = {}
	local ordered = eventOrder or schema.EventOrder
	for _, eventName in ipairs(ordered) do
		for stepIndex, step in ipairs((definition.Triggers or {})[eventName] or {}) do
			table.insert(result, Flow.describeStep(eventName, stepIndex, step, schema))
		end
	end
	return result
end

function Flow.canAddStep(definition, eventName: string, maxSteps: number): (boolean, string?)
	local steps = (definition.Triggers or {})[eventName] or {}
	if #steps >= maxSteps then
		return false, string.format("This timing already has the limit of %d steps.", maxSteps)
	end
	return true, nil
end

return Flow
