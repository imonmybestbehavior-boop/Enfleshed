--!strict

-- Evaluates only properties explicitly exposed by MagicConditionSpec. There is
-- no arbitrary Instance/property lookup in spell-authored condition data.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Spec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicConditionSpec)
local Interactions = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicElementalInteractionSpec)
local Evaluator = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicConditionEvaluator)
local LifetimeCondition = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicLifetimeConditionSpec)
local Relationships = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicRelationship)
local TargetConsent = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicTargetConsentSpec)
local EnvironmentZoneSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicEnvironmentZoneSpec)
local EnvironmentRequirementSpec =
	require(game:GetService("ReplicatedStorage").Shared.Modules.MagicEnvironmentRequirementSpec)
local SpellIdentitySpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicSpellIdentitySpec)
local ElementalMarkSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicElementalMarkSpec)
local SpecialResourceDefinitions =
	require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicLocus).SpecialResources
local Control = require(script.Parent.MagicControlService)
local StepCondition = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicStepCondition)
local RuntimeCounters = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicRuntimeCounters)

local MAX_ENVIRONMENT_ZONE_ID_LENGTH = 32

local Conditions = {}
Spec.configureSpecialResources(SpecialResourceDefinitions)

local function humanoidOf(model: Model?): Humanoid?
	return if model then model:FindFirstChildOfClass("Humanoid") else nil
end

local function rootOf(model: Model?): BasePart?
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function environmentZoneAt(position: Vector3): (string?, string?)
	local selectedId: string? = nil
	local selectedTags: string? = nil
	local selectedPriority = -math.huge
	for _, instance in CollectionService:GetTagged("MagicEnvironmentZone") do
		if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
			continue
		end
		local zoneId = instance:GetAttribute("MagicZoneId")
		if type(zoneId) ~= "string" or #zoneId == 0 or #zoneId > MAX_ENVIRONMENT_ZONE_ID_LENGTH then
			continue
		end
		local localPosition = instance.CFrame:PointToObjectSpace(position)
		local halfSize = instance.Size * 0.5
		if
			math.abs(localPosition.X) > halfSize.X
			or math.abs(localPosition.Y) > halfSize.Y
			or math.abs(localPosition.Z) > halfSize.Z
		then
			continue
		end
		local priority = instance:GetAttribute("MagicZonePriority")
		if type(priority) ~= "number" or priority ~= priority or math.abs(priority) == math.huge then
			priority = 0
		end
		if
			priority > selectedPriority
			or (priority == selectedPriority and (selectedId == nil or zoneId < selectedId))
		then
			selectedId = zoneId
			selectedTags = EnvironmentZoneSpec.encodeTags(instance:GetAttribute("MagicZoneTags"))
			selectedPriority = priority
		end
	end
	return selectedId, selectedTags
end

local function alignment(model: Model?): string?
	if not model then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	local ownerUserId = model:GetAttribute("MagicSummonOwnerUserId") or model:GetAttribute("SandboxOwnerUserId")
	local owner = if type(ownerUserId) == "number" then Players:GetPlayerByUserId(ownerUserId) else nil
	local alignedPlayer = player or owner
	local ownerAlignment = if alignedPlayer
		then if alignedPlayer.Team then alignedPlayer.Team.Name else "Human"
		else nil
	local value = model:GetAttribute("SandboxAlignment") or model:GetAttribute("MagicAlignment")
	return Relationships.resolveAlignment(value, ownerAlignment)
end

local function relationship(caster: Model?, target: Model?)
	local isSelf = caster ~= nil and target == caster
	local isHostile = target ~= nil
		and (CollectionService:HasTag(target, "Enfleshed") or CollectionService:HasTag(target, "MagicHostileTarget"))
	local casterAlignment = alignment(caster)
	local targetAlignment = alignment(target)
	return Relationships.classify(
		isSelf,
		isHostile,
		casterAlignment ~= nil and casterAlignment == targetAlignment,
		caster ~= nil
			and target ~= nil
			and CollectionService:HasTag(target, "SandboxAlly")
			and CollectionService:HasTag(caster, "SandboxAlly")
	)
end

local function values(context: any): { [string]: any }
	local caster: Model? = context.Caster
	local target: Model? = context.Target
	local casterHumanoid = humanoidOf(caster)
	local targetHumanoid = humanoidOf(target)
	local statusHumanoid = targetHumanoid or casterHumanoid
	local statusModel = if targetHumanoid then target else caster
	local casterRoot = rootOf(caster)
	local targetRoot = rootOf(target)
	local delta = if casterRoot and targetRoot then targetRoot.Position - casterRoot.Position else nil
	local resource = context.Resources or {}
	local material: Instance? = context.Material
	local materialName: string? = nil
	local available: number? = nil
	if material then
		local name = material:GetAttribute("MagicMaterial")
		materialName = if type(name) == "string" then name else nil
		local amount = material:GetAttribute("AvailableAmount")
		available = if type(amount) == "number" then amount else nil
	end
	local targetShield = if statusHumanoid then statusHumanoid:GetAttribute("MagicShield") else nil
	local targetSlow = if statusHumanoid then statusHumanoid:GetAttribute("MagicSlowMultiplier") else nil
	local targetTimeRate = if statusHumanoid then statusHumanoid:GetAttribute("MagicTimeRate") else nil
	local targetArmorBonus = if statusHumanoid then statusHumanoid:GetAttribute("MagicArmorBonus") else nil
	local targetStrengthBonus = if statusHumanoid then statusHumanoid:GetAttribute("MagicStrengthBonus") else nil
	local targetBound = if statusHumanoid then statusHumanoid:GetAttribute("MagicMovementBound") else nil
	local targetElementalMarks = if statusHumanoid then statusHumanoid:GetAttribute("MagicElementalMarks") else nil
	local encodedElementalMarks = if type(targetElementalMarks) == "string" then targetElementalMarks else "||"
	local relation = relationship(caster, target)
	local casterAlignment = alignment(caster)
	local materialTarget = context.MaterialTarget
	local castState = context.SpellState or {}
	local spellId = castState.SpellId or context.SpellId
	local controlledMass = if caster and type(spellId) == "string" then Control.controlledMass(caster, spellId) else nil
	local environmentZone = context.EnvironmentZone
	local environmentZoneTags = context.EnvironmentZoneTags
	if environmentZone == nil then
		if casterRoot then
			environmentZone, environmentZoneTags = environmentZoneAt(casterRoot.Position)
		end
		context.EnvironmentZone = environmentZone or false
		context.EnvironmentZoneTags = environmentZoneTags or "||"
	elseif environmentZone == false then
		environmentZone = nil
	end
	local hitCount = castState.TargetsHit or 0
	if type(hitCount) == "table" then
		local count = 0
		for _, hit in pairs(hitCount) do
			if hit then
				count += 1
			end
		end
		hitCount = count
	end
	-- Runtime counters (MagicService.emit records TriggerCount/EventTargets).
	local areaOccupants = RuntimeCounters.occupants(castState)
	local activePosition = castState.Position
	local activeDistance = if casterRoot and typeof(activePosition) == "Vector3"
		then (activePosition - casterRoot.Position).Magnitude
		else nil
	local remainingDuration = castState.RemainingLifetime
	if
		type(remainingDuration) ~= "number"
		or remainingDuration ~= remainingDuration
		or remainingDuration <= -math.huge
		or remainingDuration >= math.huge
	then
		remainingDuration = nil
	elseif remainingDuration < 0 then
		remainingDuration = 0
	end
	local currentTarget = castState.CurrentTarget
	local hasCurrentTarget = typeof(context.Target) == "Instance" and context.Target:IsDescendantOf(workspace)
		or (
			typeof(currentTarget) == "Instance"
			and currentTarget.Parent ~= nil
			and currentTarget:IsDescendantOf(workspace)
		)
	local now = os.clock()
	local valuesByFamily = {
		Caster = {
			HealthPercent = if casterHumanoid and casterHumanoid.MaxHealth > 0
				then casterHumanoid.Health / casterHumanoid.MaxHealth
				else nil,
			IsAlive = casterHumanoid ~= nil and casterHumanoid.Health > 0,
			OnGround = casterHumanoid ~= nil and casterHumanoid.FloorMaterial ~= Enum.Material.Air,
			Team = casterAlignment,
		},
		Target = {
			HealthPercent = if targetHumanoid and targetHumanoid.MaxHealth > 0
				then targetHumanoid.Health / targetHumanoid.MaxHealth
				else nil,
			IsAlive = targetHumanoid ~= nil and targetHumanoid.Health > 0,
			IsPlayer = target ~= nil and Players:GetPlayerFromCharacter(target) ~= nil,
			HasLineOfSight = context.HasLineOfSight,
			Name = if target then target.Name else nil,
			Tags = EnvironmentZoneSpec.encodeTags(target and target:GetAttribute("MagicConditionTags") or ""),
		},
		Relationship = {
			IsSelf = relation == "Self",
			IsAlly = relation == "Ally",
			IsHostile = relation == "Hostile",
			IsNeutral = relation == "Neutral",
		},
		SpellState = {
			Age = castState.Age or 0,
			TargetsHit = hitCount,
			DistanceFromCaster = activeDistance,
			RemainingDuration = remainingDuration,
			PierceCount = castState.PierceCount or 0,
			BounceCount = castState.BounceCount or 0,
			AbsorbedEnergy = castState.AbsorbedEnergy or 0,
			ControlledMass = controlledMass,
			HasCurrentTarget = hasCurrentTarget,
			Tags = SpellIdentitySpec.encode(castState.SpellTags or {}),
			Phase = castState.CurrentPhase or "Casting",
			IsMaintained = castState.IsChannel == true,
			TriggerCount = castState.TriggerCount,
			AreaOccupants = areaOccupants,
			EventTargets = castState.EventTargets,
		},
		Resource = {
			Mana = resource.Mana,
			ManaPercent = if resource.Capacity and resource.Capacity > 0
				then resource.Mana / resource.Capacity
				else nil,
			Capacity = resource.Capacity,
			Efficiency = resource.Efficiency,
			Potency = resource.Potency,
			Strain = resource.Strain,
			StrainTolerance = resource.StrainTolerance,
			ComplexityCapacity = resource.ComplexityCapacity,
		},
		Environment = {
			ClockTime = Lighting.ClockTime,
			OnGround = casterHumanoid ~= nil and casterHumanoid.FloorMaterial ~= Enum.Material.Air,
			Zone = environmentZone or "",
			ZoneTags = environmentZoneTags or "||",
		},
		Material = {
			Type = materialName or (if materialTarget then materialTarget.Material else nil),
			AvailableAmount = available,
		},
		Status = {
			Shield = if type(targetShield) == "number" then targetShield else 0,
			SlowMultiplier = if type(targetSlow) == "number" then targetSlow else 1,
			TimeRate = if type(targetTimeRate) == "number" then targetTimeRate else 1,
			HasShield = type(targetShield) == "number" and targetShield > 0,
			IsSlowed = type(targetSlow) == "number" and targetSlow < 1,
			IsBound = targetBound == true,
			IsRevealed = statusModel ~= nil and CollectionService:HasTag(statusModel, "MagicRevealedTarget"),
			ElementalMarks = if type(targetElementalMarks) == "string" then targetElementalMarks else "||",
			Reaction = Interactions.recentReaction(
				if statusHumanoid then statusHumanoid:GetAttribute("MagicLastReaction") else nil,
				if statusHumanoid then statusHumanoid:GetAttribute("MagicLastReactionAt") else nil,
				workspace:GetServerTimeNow()
			),
			IsBurning = ElementalMarkSpec.hasEncoded(encodedElementalMarks, "Fire"),
			IsWet = ElementalMarkSpec.hasEncoded(encodedElementalMarks, "Water"),
			MagicArmorBonus = if type(targetArmorBonus) == "number" then targetArmorBonus else 0,
			MagicStrengthBonus = if type(targetStrengthBonus) == "number" then targetStrengthBonus else 0,
		},
		DistancePosition = {
			Distance = if delta then delta.Magnitude else nil,
			VerticalDistance = if delta then math.abs(delta.Y) else nil,
		},
		Time = {
			ClockTime = Lighting.ClockTime,
			SinceCast = castState.Age or math.max(0, now - (castState.StartedAt or now)),
		},
	}
	-- ModifyAttribute bonuses beyond armor/strength (CastSpeedBonus, MagicResistanceFireBonus, ...).
	for property in pairs(Spec.Properties.Status) do
		if valuesByFamily.Status[property] == nil and string.sub(property, -5) == "Bonus" then
			local value = if statusHumanoid then statusHumanoid:GetAttribute(property) else nil
			valuesByFamily.Status[property] = if type(value) == "number" then value else 0
		end
	end
	for id, definition in pairs(SpecialResourceDefinitions) do
		local amount = resource.SpecialResources and resource.SpecialResources[id]
		valuesByFamily.Resource[id] = amount
		valuesByFamily.Resource[id .. "Percent"] = if amount ~= nil and definition.Capacity > 0
			then amount / definition.Capacity
			else nil
	end
	return valuesByFamily
end

local legacyCast = {
	OnGround = function(context)
		local humanoid = humanoidOf(context.Caster)
		return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	end,
}
local legacyTarget = {
	TargetIsSelf = function(context)
		return context.Target == context.Caster
	end,
	TargetWithinRange = function(context)
		return (context.Position - context.TargetRoot.Position).Magnitude <= context.Range
	end,
}

local function conditionUsesLineOfSight(node: any): boolean
	if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
		for _, child in ipairs(node.Conditions) do
			if conditionUsesLineOfSight(child) then
				return true
			end
		end
		return false
	end
	return node.Family == "Target" and node.Property == "HasLineOfSight"
end

local function conditionUsesEnvironmentZone(node: any): boolean
	if type(node) ~= "table" then
		return false
	end
	if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
		for _, child in ipairs(node.Conditions) do
			if conditionUsesEnvironmentZone(child) then
				return true
			end
		end
		return false
	end
	return node.Family == "Environment" and (node.Property == "Zone" or node.Property == "ZoneTags")
end

function Conditions.relationshipMatches(caster: Model?, target: Model?, rule: string?): boolean
	return Relationships.matches(relationship(caster, target), rule)
end

function Conditions.hasConsent(definition: any, target: Model?): boolean
	return TargetConsent.allows(definition.TargetRules.RequiresConsent, target, Players)
end

function Conditions.cast(definition: any, state: any, extras: any?): (boolean, string?)
	local conditionList = definition.Conditions
	local context = {
		Caster = state.Character,
		Player = extras and extras.Player,
		SpellId = definition.SpellId,
		Resources = extras and extras.Resources,
		Material = extras and extras.Material,
		MaterialTarget = extras and extras.MaterialTarget,
		SpellState = table.clone(extras and extras.SpellState or {}),
	}
	context.SpellState.SpellTags = definition.Tags or {}
	local zoneTags = "||"
	context.EnvironmentZone = false
	local requirements = definition.EnvironmentRequirements
	local zoneTagRequirements = requirements and requirements.ZoneTags
	local needsZone = conditionUsesEnvironmentZone(conditionList)
		or (
			zoneTagRequirements
			and (#(zoneTagRequirements.Required or {}) > 0 or #(zoneTagRequirements.Forbidden or {}) > 0)
		)
	if needsZone then
		local casterRoot = rootOf(state.Character)
		if casterRoot then
			local zoneId, tags = environmentZoneAt(casterRoot.Position)
			context.EnvironmentZone = zoneId or false
			zoneTags = tags or "||"
		end
	end
	context.EnvironmentZoneTags = zoneTags
	if conditionList.Operator then
		local result = Evaluator.evaluate(conditionList, function(familyName, propertyName)
			local family = values(context)[familyName]
			return family and family[propertyName]
		end, {
			Caster = true,
			Resource = true,
			Status = true,
			Environment = true,
			Material = true,
			SpellState = true,
			Time = true,
		})
		if result == false then
			return false, "Cast conditions were not met"
		end
	else
		for _, condition in ipairs(conditionList) do
			local check = legacyCast[condition]
			if check and not check(context) then
				return false, "OnGround condition requires standing on a surface"
			end
		end
	end
	local caster = state.Character
	local casterHumanoid = humanoidOf(caster)
	local requirementsMet, requirementReason = EnvironmentRequirementSpec.check(definition.EnvironmentRequirements, {
		OnGround = casterHumanoid ~= nil and casterHumanoid.FloorMaterial ~= Enum.Material.Air,
		ClockTime = Lighting.ClockTime,
		ZoneTags = zoneTags or "||",
	})
	if not requirementsMet then
		return false, requirementReason
	end
	return true
end

function Conditions.endWhen(definition: any, effect: any, resources: any?): boolean
	local rule = definition.Lifetime and definition.Lifetime.EndWhen
	if not rule then
		return false
	end
	local caster = effect.Caster or (effect.State and effect.State.Character)
	local context = {
		Caster = caster,
		Resources = resources,
		SpellId = definition.SpellId,
		SpellState = table.clone(effect),
	}
	context.SpellState.SpellTags = definition.Tags or {}
	local resolvedValues = values(context)
	local result = Evaluator.evaluate(rule, function(familyName, propertyName)
		local family = resolvedValues[familyName]
		return family and family[propertyName]
	end, Spec.EndConditionFamilies)
	return LifetimeCondition.shouldEnd(definition.Lifetime.Mode, result)
end

function Conditions.lifetimeAllowsStart(definition: any, state: any, resources: any?): boolean
	if definition.Lifetime.Mode ~= "UntilConditionFails" then
		return true
	end
	local effectState = {
		Caster = state.Character,
		State = state,
		Age = 0,
		SpellId = definition.SpellId,
		StartedAt = os.clock(),
		CurrentPhase = "Active",
		TargetsHit = 0,
		Position = state.Root.Position,
		RemainingLifetime = definition.Lifetime.Duration,
	}
	local rule = definition.Lifetime.EndWhen
	if not rule then
		return false
	end
	local resolvedValues = values({
		Caster = effectState.Caster,
		Resources = resources,
		SpellId = definition.SpellId,
		SpellState = table.clone(effectState),
	})
	resolvedValues.SpellState.Tags = SpellIdentitySpec.encode(definition.Tags or {})
	local result = Evaluator.evaluate(rule, function(familyName, propertyName)
		local family = resolvedValues[familyName]
		return family and family[propertyName]
	end, Spec.EndConditionFamilies)
	return LifetimeCondition.allowsStart(definition.Lifetime.Mode, result)
end

function Conditions.targets(
	definition: any,
	caster: Model,
	position: Vector3,
	targets: { Humanoid },
	extras: any?
): { Humanoid }
	local result = {}
	local rules = definition.TargetRules
	local legacyLineOfSight = not definition.Conditions.Operator
		and table.find(definition.Conditions, "HasLineOfSight") ~= nil
	local conditionLineOfSight = definition.Conditions.Operator and conditionUsesLineOfSight(definition.Conditions)
	local evaluateLineOfSight = rules.RequiresLineOfSight or legacyLineOfSight or conditionLineOfSight
	table.sort(targets, function(a, b)
		local rootA = a.Parent and rootOf(a.Parent)
		local rootB = b.Parent and rootOf(b.Parent)
		return rootA ~= nil
			and rootB ~= nil
			and (rootA.Position - position).Magnitude < (rootB.Position - position).Magnitude
	end)
	for _, humanoid in ipairs(targets) do
		local model = humanoid.Parent
		local target = if model and model:IsA("Model") then model else nil
		local root = rootOf(target)
		if not target or not root or (humanoid.Health <= 0 and not (extras and extras.AllowDeadTargets)) then
			continue
		end
		local hasLineOfSight = true
		if evaluateLineOfSight then
			local delta = root.Position - position
			if delta.Magnitude > 0.001 then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { caster, target }
				params.RespectCanCollide = true
				hasLineOfSight = workspace:Raycast(position, delta, params) == nil
			end
		end
		local context = {
			Caster = caster,
			Target = target,
			Player = extras and extras.Player,
			SpellId = definition.SpellId,
			Resources = extras and extras.Resources,
			Material = extras and extras.Material,
			MaterialTarget = extras and extras.MaterialTarget,
			Position = position,
			TargetRoot = root,
			Range = rules.Range,
			HasLineOfSight = hasLineOfSight,
			SpellState = table.clone(extras and extras.SpellState or {}),
		}
		context.SpellState.SpellTags = definition.Tags or {}
		local allowed = Conditions.relationshipMatches(caster, target, rules.Relationship)
			and Conditions.hasConsent(definition, target)
			and (
				target ~= caster
				or definition.Form == "SelfEnhancement"
				or (extras and extras.AllowCasterTarget == true)
				or rules.IncludeCaster == true
			)
		if definition.Conditions.Operator then
			allowed = allowed
				and Evaluator.evaluate(definition.Conditions, function(familyName, propertyName)
						local family = values(context)[familyName]
						return family and family[propertyName]
					end, nil)
					~= false
		else
			for _, condition in ipairs(definition.Conditions) do
				local check = legacyTarget[condition]
				if check and not check(context) then
					allowed = false
					break
				end
			end
		end
		if (rules.RequiresLineOfSight or legacyLineOfSight) and not hasLineOfSight then
			allowed = false
		end
		if allowed then
			table.insert(result, humanoid)
		end
		if #result >= rules.MaxTargets then
			break
		end
	end
	return result
end

-- Trigger-step condition adapter: filters the event's targets with the step's
-- rule tree. Values come from the same whitelisted resolver as cast rules.
-- Raw values for ScaleBy (MagicScaleSpec), read through the same value adapters
-- conditions use. Elemental mark stacks and charge come from MagicService.
local scaleReads = {
	TargetMissingHealthPercent = { "Target", "HealthPercent" },
	DistanceFromCaster = { "DistancePosition", "Distance" },
	AreaOccupants = { "SpellState", "AreaOccupants" },
	TriggerCount = { "SpellState", "TriggerCount" },
}
function Conditions.scaleValue(source: string, context: any): any
	local path = scaleReads[source]
	if not path then
		return nil
	end
	context.EnvironmentZone = false -- not a scaling source; skip the zone lookup
	local family = values(context)[path[1]]
	return family and family[path[2]]
end

function Conditions.stepTargets(condition: any, context: any): { Humanoid }?
	local spellState = table.clone(context.SpellState or {})
	spellState.SpellTags = context.SpellTags or {}
	return StepCondition.filter(condition, context.Targets or {}, function(humanoid)
		local model = if typeof(humanoid) == "Instance" then humanoid.Parent else nil
		local target = if model and model:IsA("Model") then model else nil
		local resolved = values({
			Caster = context.Caster,
			Target = target,
			Player = context.Player,
			SpellId = context.SpellId,
			Resources = context.Resources,
			Position = context.Origin,
			TargetRoot = rootOf(target),
			-- Environment is not a step family; skip the zone lookup.
			EnvironmentZone = false,
			SpellState = spellState,
		})
		return function(familyName, propertyName)
			-- Hit: the incoming hit on Before damage taken steps.
			if familyName == "Hit" then
				return context.IncomingHit and context.IncomingHit[propertyName]
			end
			local family = resolved[familyName]
			return family and family[propertyName]
		end
	end)
end

return Conditions
