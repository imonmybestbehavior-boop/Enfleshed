--!strict

-- Whitelisted condition language shared by server validation and the editor.
-- Values are resolved by explicit runtime adapters; spell data never supplies
-- property paths or executable code.
local ConditionSpec = {}
local registeredSpecialResourceProperties = {}

ConditionSpec.MaxDepth = 4
ConditionSpec.MaxNodes = 32
ConditionSpec.MaxChildren = 8
-- Families a trigger step may branch on. Environment and Material need world
-- queries the event context does not perform, so they are not offered.
ConditionSpec.StepConditionFamilies = {
	Caster = true,
	Target = true,
	Relationship = true,
	Status = true,
	Resource = true,
	SpellState = true,
	Time = true,
}
-- Properties inside allowed families that event contexts cannot resolve.
ConditionSpec.StepUnavailableProperties = {
	Target = { HasLineOfSight = true },
}
ConditionSpec.EndConditionFamilies = {
	Caster = true,
	Resource = true,
	Status = true,
	SpellState = true,
	Environment = true,
	Time = true,
}

local numeric = { "==", "!=", ">", ">=", "<", "<=", "Within", "Outside" }
local boolean = { "==", "!=", "Is", "IsNot" }
local stringComparison = { "==", "!=", "Is", "IsNot", "Has", "DoesNotHave" }
-- Counters also support cadence: "MultipleOf 3" passes on every third trigger.
local counter = { "==", "!=", ">", ">=", "<", "<=", "MultipleOf" }

ConditionSpec.Properties = {
	Caster = {
		HealthPercent = { Kind = "Number", Min = 0, Max = 1, Operators = numeric },
		IsAlive = { Kind = "Boolean", Operators = boolean },
		OnGround = { Kind = "Boolean", Operators = boolean },
		Team = { Kind = "String", MaxLength = 32, Operators = stringComparison },
	},
	Target = {
		HealthPercent = { Kind = "Number", Min = 0, Max = 1, Operators = numeric },
		IsAlive = { Kind = "Boolean", Operators = boolean },
		IsPlayer = { Kind = "Boolean", Operators = boolean },
		HasLineOfSight = { Kind = "Boolean", Operators = boolean },
		Name = { Kind = "String", MaxLength = 32, Operators = stringComparison },
		Tags = { Kind = "String", MaxLength = 24, Operators = { "Has", "DoesNotHave" } },
	},
	Relationship = {
		IsSelf = { Kind = "Boolean", Operators = boolean },
		IsAlly = { Kind = "Boolean", Operators = boolean },
		IsHostile = { Kind = "Boolean", Operators = boolean },
		IsNeutral = { Kind = "Boolean", Operators = boolean },
	},
	SpellState = {
		Age = { Kind = "Number", Min = 0, Max = 60, Operators = numeric },
		TargetsHit = { Kind = "Number", Min = 0, Max = 64, Integer = true, Operators = numeric },
		DistanceFromCaster = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		RemainingDuration = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		PierceCount = { Kind = "Number", Min = 0, Max = 64, Integer = true, Operators = numeric },
		BounceCount = { Kind = "Number", Min = 0, Max = 64, Integer = true, Operators = numeric },
		AbsorbedEnergy = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		ControlledMass = { Kind = "Number", Min = 0, Max = 3000000, Operators = numeric },
		HasCurrentTarget = { Kind = "Boolean", Operators = boolean },
		Tags = { Kind = "String", MaxLength = 48, Operators = { "Has", "DoesNotHave" } },
		Phase = { Kind = "String", MaxLength = 32, Operators = stringComparison },
		IsMaintained = { Kind = "Boolean", Operators = boolean },
		-- Runtime counters, kept per active effect by MagicService.emit.
		TriggerCount = { Kind = "Number", Min = 0, Max = 10000, Integer = true, Operators = counter },
		AreaOccupants = { Kind = "Number", Min = 0, Max = 64, Integer = true, Operators = numeric },
		EventTargets = { Kind = "Number", Min = 0, Max = 64, Integer = true, Operators = numeric },
	},
	-- The incoming hit, only on Before damage taken (Interception) steps.
	Hit = {
		Damage = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		Element = { Kind = "String", MaxLength = 32, Operators = stringComparison },
		AttackerIsPlayer = { Kind = "Boolean", Operators = boolean },
		IsMelee = { Kind = "Boolean", Operators = boolean },
	},
	Resource = {
		Mana = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		ManaPercent = { Kind = "Number", Min = 0, Max = 1, Operators = numeric },
		Capacity = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		Efficiency = { Kind = "Number", Min = 0.01, Max = 100, Operators = numeric },
		Potency = { Kind = "Number", Min = 0.01, Max = 100, Operators = numeric },
		Strain = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		StrainTolerance = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		ComplexityCapacity = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
	},
	Environment = {
		ClockTime = { Kind = "Number", Min = 0, Max = 24, Operators = numeric },
		OnGround = { Kind = "Boolean", Operators = boolean },
		Zone = { Kind = "String", MaxLength = 32, Operators = stringComparison },
		ZoneTags = { Kind = "String", MaxLength = 24, Operators = { "Has", "DoesNotHave" } },
	},
	Material = {
		Type = { Kind = "String", MaxLength = 32, Operators = stringComparison },
		AvailableAmount = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
	},
	Status = {
		Shield = { Kind = "Number", Min = 0, Max = 100000, Operators = numeric },
		SlowMultiplier = { Kind = "Number", Min = 0, Max = 1, Operators = numeric },
		TimeRate = { Kind = "Number", Min = 0.25, Max = 2, Operators = numeric },
		HasShield = { Kind = "Boolean", Operators = boolean },
		IsSlowed = { Kind = "Boolean", Operators = boolean },
		IsBound = { Kind = "Boolean", Operators = boolean },
		IsRevealed = { Kind = "Boolean", Operators = boolean },
		IsBurning = { Kind = "Boolean", Operators = boolean, Help = "True while a Fire mark is active." },
		IsWet = { Kind = "Boolean", Operators = boolean, Help = "True while a Water mark is active." },
		ElementalMarks = {
			Kind = "String",
			MaxLength = 48,
			Operators = { "Has", "DoesNotHave" },
			Help = "Checks whether the target has an active mark for an element, such as Fire or Ice.",
		},
		MagicArmorBonus = { Kind = "Number", Min = -100, Max = 100, Operators = numeric },
		MagicStrengthBonus = { Kind = "Number", Min = -75, Max = 100, Operators = numeric },
		Reaction = {
			Kind = "String",
			MaxLength = 24,
			Operators = stringComparison,
			Help = 'The last elemental reaction on the target within 5 s, such as "Freeze" or "Conduct"; empty otherwise.',
		},
		-- ModifyAttribute bonuses (ranges match MagicAttributeSpec).
		PhysicalArmorBonus = { Kind = "Number", Min = -100, Max = 100, Operators = numeric },
		SoulArmorBonus = { Kind = "Number", Min = -100, Max = 100, Operators = numeric },
		MagicResistanceFireBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		MagicResistanceIceBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		MagicResistanceLightningBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		MagicResistanceEarthBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		MagicResistanceWaterBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		MagicResistanceWindBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		MagicResistancePoisonBonus = { Kind = "Number", Min = -1, Max = 1, Operators = numeric },
		DamageTakenBonus = { Kind = "Number", Min = -50, Max = 50, Operators = numeric },
		HealingReceivedBonus = { Kind = "Number", Min = -75, Max = 50, Operators = numeric },
		CastSpeedBonus = { Kind = "Number", Min = -50, Max = 50, Operators = numeric },
		CooldownRateBonus = { Kind = "Number", Min = -50, Max = 50, Operators = numeric },
		ManaRegenBonus = { Kind = "Number", Min = -100, Max = 100, Operators = numeric },
	},
	DistancePosition = {
		Distance = { Kind = "Number", Min = 0, Max = 10000, Operators = numeric },
		VerticalDistance = { Kind = "Number", Min = 0, Max = 10000, Operators = numeric },
	},
	Time = {
		ClockTime = { Kind = "Number", Min = 0, Max = 24, Operators = numeric },
		SinceCast = { Kind = "Number", Min = 0, Max = 60, Operators = numeric },
	},
}

function ConditionSpec.configureSpecialResources(definitions)
	local resourceProperties = ConditionSpec.Properties.Resource
	for property in pairs(registeredSpecialResourceProperties) do
		resourceProperties[property] = nil
	end
	registeredSpecialResourceProperties = {}
	for id, definition in pairs(definitions or {}) do
		local descriptor = { Kind = "Number", Min = 0, Max = definition.Capacity, Operators = numeric }
		if resourceProperties[id] == nil then
			resourceProperties[id] = descriptor
			registeredSpecialResourceProperties[id] = true
		end
		local percentId = id .. "Percent"
		if resourceProperties[percentId] == nil then
			resourceProperties[percentId] = { Kind = "Number", Min = 0, Max = 1, Operators = numeric }
			registeredSpecialResourceProperties[percentId] = true
		end
	end
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function denseArrayLength(value, maximum)
	if type(value) ~= "table" then
		return nil
	end
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > maximum then
			return nil
		end
		count = count + 1
	end
	if count ~= #value then
		return nil
	end
	return count
end

local function validateNode(node, depth, budget)
	budget[1] = budget[1] + 1
	if budget[1] > ConditionSpec.MaxNodes or depth > ConditionSpec.MaxDepth then
		return false, "Condition tree exceeds its depth or size limit"
	end
	if type(node) ~= "table" then
		return false, "Condition entry must be a table"
	end
	if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
		for key in pairs(node) do
			if key ~= "Operator" and key ~= "Conditions" then
				return false, "Unsupported condition group field"
			end
		end
		local children = node.Conditions
		local childCount = denseArrayLength(children, ConditionSpec.MaxChildren)
		if not childCount or childCount == 0 then
			return false, "Condition groups need 1–8 rules"
		end
		if node.Operator == "NOT" and childCount ~= 1 then
			return false, "NOT groups need exactly one rule"
		end
		for index, child in ipairs(children) do
			if index > ConditionSpec.MaxChildren then
				return false, "Condition group is too large"
			end
			local ok, reason = validateNode(child, depth + 1, budget)
			if not ok then
				return false, reason
			end
		end
		return true
	end

	local descriptor = ConditionSpec.Properties[node.Family] and ConditionSpec.Properties[node.Family][node.Property]
	if not descriptor then
		return false, "Condition property is not exposed by the runtime"
	end
	for key in pairs(node) do
		if key ~= "Family" and key ~= "Property" and key ~= "Operator" and key ~= "Value" then
			return false, "Unsupported condition rule field"
		end
	end
	local operatorFound = false
	for _, operator in ipairs(descriptor.Operators) do
		if operator == node.Operator then
			operatorFound = true
			break
		end
	end
	if type(node.Operator) ~= "string" or not operatorFound then
		return false, "Unsupported comparison for condition property"
	end
	local value = node.Value
	if descriptor.Kind == "Number" then
		if not finite(value) or value < descriptor.Min or value > descriptor.Max then
			return false, "Condition number is outside its supported range"
		end
		if descriptor.Integer and value % 1 ~= 0 then
			return false, "Condition value must be a whole number"
		end
		if node.Operator == "MultipleOf" and value < 1 then
			return false, "MultipleOf needs a whole number of at least 1"
		end
	elseif descriptor.Kind == "Boolean" then
		if type(value) ~= "boolean" then
			return false, "Condition value must be true or false"
		end
	elseif type(value) ~= "string" or #value > descriptor.MaxLength then
		return false, "Condition text value is invalid"
	end
	return true
end

function ConditionSpec.validate(conditions)
	if type(conditions) ~= "table" then
		return false, "Conditions must be a list or a rule group"
	end
	-- Preserve the original V1 checkbox identifiers without changing their meaning.
	if conditions.Operator == nil then
		if #conditions > 5 then
			return false, "Too many legacy conditions"
		end
		return true
	end
	return validateNode(conditions, 1, { 0 })
end

local function usesOnlyFamilies(node, families)
	if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
		for _, child in ipairs(node.Conditions) do
			if not usesOnlyFamilies(child, families) then
				return false
			end
		end
		return true
	end
	return families[node.Family] == true
end

function ConditionSpec.validateForFamilies(conditions, families)
	local valid, reason = ConditionSpec.validate(conditions)
	if not valid then
		return false, reason
	end
	if not usesOnlyFamilies(conditions, families) then
		return false, "Condition uses a target-only family in a caster lifetime rule"
	end
	return true
end

local function usesUnavailableStepProperty(node)
	if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
		for _, child in ipairs(node.Conditions) do
			if usesUnavailableStepProperty(child) then
				return true
			end
		end
		return false
	end
	local unavailable = ConditionSpec.StepUnavailableProperties[node.Family]
	return unavailable ~= nil and unavailable[node.Property] == true
end

-- A trigger-step condition must be a rule tree (not the legacy list form)
-- built only from values an event context can resolve.
-- `allowHit`: the step belongs to OnBeforeDamageTaken, so the Hit family is offered.
function ConditionSpec.validateStep(conditions, allowHit: boolean?)
	if type(conditions) ~= "table" or conditions.Operator == nil then
		return false, "Step conditions must be an ALL, ANY, or NOT rule group"
	end
	local families = ConditionSpec.StepConditionFamilies
	if allowHit then
		families = table.clone(families)
		families.Hit = true
	end
	local ok, reason = ConditionSpec.validateForFamilies(conditions, families)
	if not ok then
		return false,
			if reason == "Condition uses a target-only family in a caster lifetime rule"
				then "Step condition uses a value that trigger events cannot check"
				else reason
	end
	if usesUnavailableStepProperty(conditions) then
		return false, "Step condition uses a value that trigger events cannot check"
	end
	return true
end

return ConditionSpec
