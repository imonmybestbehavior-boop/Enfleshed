--!strict

-- Server-owned interpreter for normalized registered and development spell data.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared.Configuration.Sandbox)
local DevelopmentSandbox = require(Shared.Configuration.DevelopmentSandbox)
local ResourceBalance = if RunService:IsStudio() and DevelopmentSandbox.Enabled
	then Sandbox.Magic.SandboxResources
	else Sandbox.Magic.CombatResources
local LocusConfiguration = require(Shared.Configuration.MagicLocus)
local LocusProfile = if RunService:IsStudio() and DevelopmentSandbox.Enabled
	then LocusConfiguration.Default
	else LocusConfiguration.Combat
local LocusModel = require(Shared.Modules.MagicLocusModel)
local SpecialResourceSpec = require(Shared.Modules.MagicSpecialResourceSpec)
local SpecialResourceDefinitions = LocusConfiguration.SpecialResources
local specialResourcesValid, specialResourcesReason =
	SpecialResourceSpec.validateDefinitions(SpecialResourceDefinitions)
assert(specialResourcesValid, specialResourcesReason)
local Definitions = require(Shared.Configuration.Spells)
local Generated = require(Shared.Configuration.GeneratedSpellStress)
local Validator = require(Shared.Modules.SpellDefinitionValidator)
local HitDetection = require(script.Parent.HitDetectionService)
local Forms = require(script.Parent.MagicFormExecutors)
local Payloads = require(script.Parent.MagicPayloadExecutors)
local Movement = require(script.Parent.MovementService)
local Spec = require(Shared.Modules.SpellSpec)
local Geometry = require(Shared.Modules.MagicGeometry)
local AreaGrowth = require(Shared.Modules.MagicAreaGrowth)
local BeamAim = require(Shared.Modules.MagicBeamAim)
local Limits = require(Shared.Configuration.MagicLab)
local Triggers = require(script.Parent.MagicTriggerExecutors)
local ProjectileBehaviors = require(script.Parent.MagicProjectileBehaviorExecutors)
local Conditions = require(script.Parent.MagicConditions)
local ConstructGeometry = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicConstructGeometrySpec)
local AreaMembership = require(Shared.Modules.MagicAreaMembership)
local ProximitySpec = require(Shared.Modules.MagicProximitySpec)
local Presentation = require(script.Parent.MagicPresentation)
local PersistentConstructStore = require(script.Parent.MagicPersistentConstructStore)
local Summons = require(script.Parent.SummonService)
local Damage = require(script.Parent.DamageService)
local CompanionSpellPolicy = require(Shared.Modules.MagicCompanionSpellPolicy)
local CastingSpec = require(Shared.Modules.MagicCastingSpec)
local CommandSpec = require(script.Parent.MagicCommandSpec)
local Manipulation = require(script.Parent.MagicManipulationExecutors)
local SummonConfiguration = require(Shared.Configuration.MagicSummons)
local LifetimeSpec = require(Shared.Modules.MagicLifetimeSpec)
local CastInterruption = require(Shared.Modules.MagicCastInterruption)
local TargetingSpec = require(Shared.Modules.MagicTargetingSpec)
local ObjectTargetSpec = require(Shared.Modules.MagicObjectTargetSpec)
local TargetDeathSpec = require(Shared.Modules.MagicTargetDeathSpec)
local OperationBudget = require(Shared.Modules.MagicOperationBudget)
local RuntimeCounters = require(Shared.Modules.MagicRuntimeCounters)
local ProjectileMotion = require(Shared.Modules.MagicProjectileMotion)
local TemporalRate = require(Shared.Modules.MagicTemporalRate)
local StatusEffects = require(script.Parent.MagicStatusEffectService)
local Equipment = require(script.Parent.EquipmentService)
local FeatureFlags = require(script.Parent.FeatureFlagService)
local LoadBudget = require(Shared.Modules.MagicLoadBudget)
local Telemetry = require(script.Parent.TelemetryService)
local MagicWorldQuery = require(script.Parent.MagicWorldQuery)
local MagicConstructBuilder = require(script.Parent.MagicConstructBuilder)
local buildConstructModel, watchPersistentConstruct, persistentConstructRecord, restorePersistentConstruct =
	MagicConstructBuilder.buildConstructModel,
	MagicConstructBuilder.watchPersistentConstruct,
	MagicConstructBuilder.persistentConstructRecord,
	MagicConstructBuilder.restorePersistentConstruct
local validVector, hasHumanoidAncestor, isValidObjectInteractionTarget, findMaterial, findManipulable, acquireEntityTarget, sweep, targetFrom, objectTargetHit, objectTargetRange, constructPlacement, finalChannelTargets =
	MagicWorldQuery.validVector,
	MagicWorldQuery.hasHumanoidAncestor,
	MagicWorldQuery.isValidObjectInteractionTarget,
	MagicWorldQuery.findMaterial,
	MagicWorldQuery.findManipulable,
	MagicWorldQuery.acquireEntityTarget,
	MagicWorldQuery.sweep,
	MagicWorldQuery.targetFrom,
	MagicWorldQuery.objectTargetHit,
	MagicWorldQuery.objectTargetRange,
	MagicWorldQuery.constructPlacement,
	MagicWorldQuery.finalChannelTargets
local Magic = {}

type State = { Character: Model, Humanoid: Humanoid, Root: BasePart }
type CastContext = { Origin: Vector3, CommandCast: boolean?, CommandId: number? }?
type Charge = {
	SpellId: string,
	BeganAt: number,
	Definition: any,
	Character: Model,
	StartPosition: Vector3,
	State: State,
	Intent: any,
	AimDirection: Vector3,
	Remote: RemoteEvent,
	Context: CastContext,
}
type Active = {
	SpellId: string,
	Caster: Model,
	Age: number,
	CurrentPhase: string,
	TargetsHit: { [Humanoid]: boolean },
	RemainingLifetime: number,
	Definition: any,
	Position: Vector3,
	Direction: Vector3,
	Visual: BasePart,
	Player: Player,
	Remote: RemoteEvent,
}

local playerData: { [Player]: any } = {}
local companionSpells: { [Player]: { [number]: any } } = {}
local active: { any } = {}
local nextCommandCastId = 0

local function isSpellCooling(stats, spellId: string, now: number): boolean
	local cooldown = stats.Ready[spellId]
	if type(cooldown) == "table" then
		return cooldown.Remaining > 0
	end
	-- Accept old in-memory timestamp entries while the service is hot-reloaded.
	return type(cooldown) == "number" and now < cooldown
end
local enhancements: {
	[Player]: {
		[string]: {
			State: State,
			ExpiresAt: number,
			WalkSpeedBonus: number,
			JumpPowerBonus: number,
			SpeedMultiplier: number,
		},
	},
} =
	{}

local function feedback(remote: RemoteEvent, player: Player, result: string, spell: any?, data: { [string]: any }?)
	remote:FireClient(player, {
		Kind = "Magic",
		Result = result,
		SpellId = if spell then spell.SpellId else nil,
		Name = if spell then spell.Name else nil,
		Mana = data and data.Mana or nil,
		Capacity = data and data.Capacity or nil,
		Strain = data and data.Strain or nil,
		StrainTolerance = data and data.StrainTolerance or nil,
		Efficiency = data and data.Efficiency or nil,
		Potency = data and data.Potency or nil,
		Complexity = data and data.Complexity or nil,
		ComplexityCapacity = data and data.ComplexityCapacity or nil,
		ManaDemand = data and data.ManaDemand or nil,
		Reason = data and data.Reason or nil,
		Damage = data and data.Damage or nil,
		Effect = data and data.Effect or nil,
		Amount = data and data.Amount or nil,
		Target = data and data.Target or nil,
		SpecialResources = data and data.SpecialResources or nil,
	})
end

local function isSolidWorldSurfaceTarget(target: BasePart): boolean
	return ObjectTargetSpec.isSolidWorldSurfaceTarget({
		InWorkspace = target:IsDescendantOf(workspace),
		CanCollide = target.CanCollide,
		HasHumanoidAncestor = hasHumanoidAncestor(target),
	})
end

local function isLiveHomingTarget(root: BasePart?): boolean
	if not root or not root:IsDescendantOf(workspace) then
		return false
	end
	local model = root:FindFirstAncestorOfClass("Model")
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	return model ~= nil and humanoid ~= nil and humanoid.Health > 0
end

local function getDefinition(id: any): any?
	if typeof(id) ~= "string" then
		return nil
	end
	local definition = Definitions[id] or Generated.Definitions[id]
	if
		not definition
		or not (if definition.Version == 3 then Spec.validate(definition) else Validator.validate(definition))
	then
		return nil
	end
	return Spec.normalize(definition)
end

local function costs(definition: any, charge: number, resources: any): (number, number, number)
	return LocusModel.cost(definition.Cost, charge, Sandbox.Magic.ChargeCostScale, resources)
end

local function setCastingMovement(player: Player, state: State?, definition: any?, direction: Vector3?)
	if not state or state.Character ~= player.Character then
		return
	end
	local multiplier = if definition then CastingSpec.movementMultiplier(definition.Casting) else 1
	Movement.setMagicCasting(state, multiplier)
	Movement.setMagicRotation(state, definition ~= nil and CastingSpec.rotationLocked(definition.Casting), direction)
end

local function resourceSnapshot(stats: any?): any
	if not stats then
		return nil
	end
	return {
		Mana = stats.Mana,
		Capacity = stats.Capacity,
		Strain = stats.Strain,
		StrainTolerance = stats.StrainTolerance,
		Efficiency = stats.Efficiency,
		Potency = stats.Potency,
		ComplexityCapacity = stats.ComplexityCapacity,
		SpecialResources = stats.SpecialResources,
	}
end

local function syncSpecialResourceAttributes(player: Player)
	local stats = playerData[player]
	if not stats or not player.Parent then
		return
	end
	for id, definition in pairs(SpecialResourceDefinitions) do
		player:SetAttribute(definition.Attribute, stats.SpecialResources[id])
		player:SetAttribute(definition.Attribute .. "Capacity", definition.Capacity)
	end
end

local function syncHUDResourceAttributes(player: Player, stats: any)
	if not player.Parent then
		return
	end
	for attribute, value in
		{
			MagicMana = stats.Mana,
			MagicCapacity = stats.Capacity,
			MagicStrain = stats.Strain,
			MagicStrainTolerance = stats.StrainTolerance,
		}
	do
		if player:GetAttribute(attribute) ~= value then
			player:SetAttribute(attribute, value)
		end
	end
end

local function locusPotency(player: Player): number
	local stats = playerData[player]
	return if stats then stats.Potency else LocusProfile.Potency
end

local function hasPayload(definition, event: string, kind: string): boolean
	for _, step in definition.Triggers[event] or {} do
		for _, payload in step.Payloads or {} do
			if payload.Kind == kind then
				return true
			end
		end
	end
	return false
end

local function hasPayloadAnywhere(definition, kind: string): boolean
	for _, steps in definition.Triggers or {} do
		for _, step in steps do
			for _, payload in step.Payloads or {} do
				if payload.Kind == kind then
					return true
				end
			end
		end
	end
	return false
end

local function validate(
	player: Player,
	state: State,
	intent: any,
	definition: any,
	charge: number
): (string, string?, Instance?, Vector3?, Model?, Vector3?)
	if not definition or not validVector(intent.AimDirection) then
		return "IMPOSSIBLE", "Invalid spell or aim"
	end
	local spellAllowed, disabledReason = FeatureFlags.spellAllowed(definition)
	if not spellAllowed then
		return "IMPOSSIBLE", disabledReason
	end
	if not CastingSpec.hasFreeHand(definition.Casting, Equipment.freeHandCount(player)) then
		return "IMPOSSIBLE", "This spell requires at least one free hand"
	end
	local direction = intent.AimDirection
	if direction.Magnitude < 0.9 or direction.Magnitude > 1.1 then
		return "IMPOSSIBLE", "Invalid aim direction"
	end
	direction = direction.Unit
	-- Constructs are aim-placed primitives. Their ray may attach them to a surface
	-- or character, but the cast itself must never depend on having a target.
	local targeting = if definition.Form == "Construct" then "AimDirection" else definition.Targeting
	local worldPoint = intent.WorldPoint
	local material: Instance? = nil
	local selectedTarget: Model? = nil
	local objectPosition: Vector3? = nil
	if targeting == "EntityTarget" then
		local policy = definition.TargetPolicy or "Aim"
		local target = if policy == "LockOn" then nil else intent.TargetModel
		local function validTarget(candidate: any): (Model?, Vector3?, string?)
			if
				typeof(candidate) ~= "Instance"
				or not candidate:IsA("Model")
				or not candidate:IsDescendantOf(workspace)
			then
				return nil, nil, "Aim at a living target"
			end
			local humanoid = candidate:FindFirstChildOfClass("Humanoid")
			local root = candidate:FindFirstChild("HumanoidRootPart")
			if
				candidate == state.Character
				or not humanoid
				or humanoid.Health <= 0
				or not root
				or not root:IsA("BasePart")
			then
				return nil, nil, "Target is not a living character"
			end
			if not Conditions.relationshipMatches(state.Character, candidate, definition.TargetRules.Relationship) then
				return nil, nil, "Target does not match the spell relationship rule"
			end
			if not Conditions.hasConsent(definition, candidate) then
				return nil, nil, "Target has not opted in to consent-gated spells"
			end
			local origin = state.Root.Position + Vector3.new(0, 1.5, 0)
			local delta = root.Position - origin
			if delta.Magnitude < 0.001 or delta.Magnitude > TargetingSpec.entityRange(definition) then
				return nil, nil, "Target is outside spell range"
			end
			if direction:Dot(delta.Unit) < Sandbox.Magic.MinimumEntityAimDot then
				return nil, nil, "Target is outside aim direction"
			end
			if definition.TargetRules.RequiresLineOfSight then
				local ray = RaycastParams.new()
				ray.FilterType = Enum.RaycastFilterType.Exclude
				ray.FilterDescendantsInstances = { state.Character, candidate }
				ray.RespectCanCollide = true
				if workspace:Raycast(origin, delta, ray) then
					return nil, nil, "Target is obstructed"
				end
			end
			return candidate, delta.Unit, nil
		end
		local targetDirection: Vector3? = nil
		local targetReason: string? = nil
		if target then
			selectedTarget, targetDirection, targetReason = validTarget(target)
		end
		if not selectedTarget and (policy == "LockOn" or policy == "AimOrLockOn") then
			local acquired = acquireEntityTarget(state, direction, definition)
			if acquired then
				selectedTarget, targetDirection, targetReason = validTarget(acquired)
			end
		end
		if not selectedTarget then
			return "IMPOSSIBLE", targetReason or "No valid target in the aim cone"
		end
		direction = targetDirection or direction
	elseif targeting == "WorldPoint" or targeting == "Area" then
		if
			not validVector(worldPoint)
			or (worldPoint - state.Root.Position).Magnitude > definition.TargetRules.Range
		then
			return "IMPOSSIBLE", "Invalid world target"
		end
		if
			definition.Form == "Construct"
			and (
				(worldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))).Magnitude < 0.001
				or (worldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))).Magnitude
					> definition.Construct.Distance
			)
		then
			return "IMPOSSIBLE", "World point is outside Construct placement range"
		end
		local aimedDelta = worldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))
		if aimedDelta.Magnitude > 0 and direction:Dot(aimedDelta.Unit) < Sandbox.Magic.MinimumWorldAimDot then
			return "IMPOSSIBLE", "World target is outside aim direction"
		end
	elseif targeting == "MaterialTarget" then
		if
			not validVector(worldPoint)
			or (worldPoint - state.Root.Position).Magnitude > definition.TargetRules.Range
		then
			return "IMPOSSIBLE", "Invalid material target"
		end
		-- Use a server-known spell origin for the anti-spoof comparison rather than
		-- trusting a client-provided camera position. This preserves camera pitch.
		local aimedDelta = worldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))
		if aimedDelta.Magnitude > 0 and direction:Dot(aimedDelta.Unit) < Sandbox.Magic.MinimumWorldAimDot then
			return "IMPOSSIBLE", "Material target is outside aim direction"
		end
		material = if definition.Form == "Manipulation"
			then findManipulable(definition, worldPoint)
			else findMaterial(definition, worldPoint)
		if not material then
			return "IMPOSSIBLE", "No eligible material source with enough available amount is in range"
		end
	elseif targeting == "ObjectTarget" then
		local targetInstance = intent.TargetInstance
		if
			typeof(targetInstance) ~= "Instance"
			or not targetInstance:IsA("BasePart")
			or not targetInstance:IsDescendantOf(workspace)
		then
			return "IMPOSSIBLE", "Aim at a valid world object"
		end
		local origin = state.Root.Position + Vector3.new(0, 1.5, 0)
		if definition.Form == "Construct" then
			if not isSolidWorldSurfaceTarget(targetInstance) then
				return "IMPOSSIBLE", "Constructs can attach only to solid world geometry"
			end
			local reach = math.min(definition.TargetRules.Range, definition.Construct.Distance)
			local obstructionRay = RaycastParams.new()
			obstructionRay.FilterType = Enum.RaycastFilterType.Exclude
			obstructionRay.FilterDescendantsInstances = { state.Character }
			obstructionRay.RespectCanCollide = true
			local hit = workspace:Raycast(origin, direction * reach, obstructionRay)
			if not hit or hit.Instance ~= targetInstance then
				return "IMPOSSIBLE", "Selected surface is out of reach or obstructed"
			end
			material = targetInstance
			objectPosition = hit.Position
		elseif definition.Form == "Field" or definition.Form == "Aura" then
			if not isSolidWorldSurfaceTarget(targetInstance) then
				return "IMPOSSIBLE", "Area spells can target only solid world surfaces"
			end
			local reach = definition.TargetRules.Range
			local obstructionRay = RaycastParams.new()
			obstructionRay.FilterType = Enum.RaycastFilterType.Exclude
			obstructionRay.FilterDescendantsInstances = { state.Character }
			obstructionRay.RespectCanCollide = true
			local hit = workspace:Raycast(origin, direction * reach, obstructionRay)
			if not hit or hit.Instance ~= targetInstance then
				return "IMPOSSIBLE", "Selected surface is out of reach or obstructed"
			end
			material = targetInstance
			objectPosition = hit.Position
		elseif definition.Form == "Projectile" or definition.Form == "Beam" or definition.Form == "Wave" then
			local hasObjectForce = hasPayloadAnywhere(definition, "Force")
			local hasObjectControl = hasPayloadAnywhere(definition, "Control")
			local hasObjectManipulation = hasPayloadAnywhere(definition, "Manipulation")
			if
				not (hasObjectForce or hasObjectControl or hasObjectManipulation)
				or not isValidObjectInteractionTarget(definition, targetInstance)
			then
				return "IMPOSSIBLE",
					"Selected object is not authorized for this spell's Force, Control, or material Manipulation effects"
			end
			local formReach = if definition.Form == "Projectile"
				then definition.Projectile.MaxDistance
				elseif definition.Form == "Beam" then definition.Beam.Range * math.max(
					definition.Beam.GrowthStartScale or 1,
					definition.Beam.GrowthEndScale or 1
				)
				else definition.Wave.Range * math.max(
					definition.Wave.GrowthStartScale or 1,
					definition.Wave.GrowthEndScale or 1
				)
			local reach = math.min(
				definition.TargetRules.Range,
				formReach,
				if definition.Material then definition.Material.SearchRadius else definition.TargetRules.Range
			)
			local obstructionRay = RaycastParams.new()
			obstructionRay.FilterType = Enum.RaycastFilterType.Exclude
			obstructionRay.FilterDescendantsInstances = { state.Character }
			obstructionRay.RespectCanCollide = true
			local hit = workspace:Raycast(origin, direction * reach, obstructionRay)
			if not hit or hit.Instance ~= targetInstance then
				return "IMPOSSIBLE", "Selected movable object is out of reach or obstructed"
			end
			material = targetInstance
			objectPosition = hit.Position
		else
			local hasOperation = hasPayload(definition, "OnCast", "Manipulation")
			local hasObjectForce = hasPayload(definition, "OnCast", "Force")
			local hasObjectControl = hasPayload(definition, "OnCast", "Control")
			local hasObjectPhysics = hasObjectForce or hasObjectControl
			local manipulationTargetValid = ObjectTargetSpec.isValidManipulationTarget({
				InWorkspace = targetInstance:IsDescendantOf(workspace),
				CanCollide = targetInstance.CanCollide,
				HasHumanoidAncestor = hasHumanoidAncestor(targetInstance),
				Tagged = CollectionService:HasTag(targetInstance, "MagicManipulable"),
				Anchored = targetInstance.Anchored,
				AssemblyMass = targetInstance.AssemblyMass,
				MaterialMatches = definition.Material ~= nil
					and targetInstance:GetAttribute("MagicMaterial") == definition.Material.Material,
				RaiseAuthorized = targetInstance:GetAttribute("MagicRaise") == true,
			}, hasOperation, hasObjectPhysics)
			if not manipulationTargetValid then
				return "IMPOSSIBLE", "Aim at a tagged material or movable object supported by this spell"
			end
			local reach = math.min(
				definition.TargetRules.Range,
				if definition.Material then definition.Material.SearchRadius else definition.TargetRules.Range
			)
			local obstructionRay = RaycastParams.new()
			obstructionRay.FilterType = Enum.RaycastFilterType.Exclude
			obstructionRay.FilterDescendantsInstances = { state.Character }
			obstructionRay.RespectCanCollide = true
			local hit = workspace:Raycast(origin, direction * reach, obstructionRay)
			if not hit or hit.Instance ~= targetInstance then
				return "IMPOSSIBLE", "Selected object is out of reach or obstructed"
			end
			material = targetInstance
			objectPosition = hit.Position
		end
	end
	if
		definition.Form == "Manipulation"
		and (hasPayload(definition, "OnCast", "Force") or hasPayload(definition, "OnCast", "Control"))
		and (not material or material.Anchored or material.AssemblyMass == math.huge)
	then
		return "IMPOSSIBLE", "Physical force requires a movable object"
	end
	local stats = playerData[player]
	local groundOK, groundReason = Conditions.cast(definition, state, {
		Player = player,
		Resources = resourceSnapshot(stats),
		Material = material,
		MaterialTarget = worldPoint and (material and material:GetAttribute("MagicMaterial") or nil),
	})
	if not groundOK then
		return "IMPOSSIBLE", groundReason
	end
	if not Conditions.lifetimeAllowsStart(definition, state, resourceSnapshot(stats)) then
		return "IMPOSSIBLE", "The effect's keep-alive condition is not currently satisfied"
	end
	if
		definition.TargetRules.RequiresLineOfSight
		and (targeting == "WorldPoint" or targeting == "Area" or targeting == "MaterialTarget")
	then
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { state.Character }
		ray.RespectCanCollide = true
		local origin = state.Root.Position + Vector3.new(0, 1.5, 0)
		local delta = worldPoint - origin
		local hit = workspace:Raycast(origin, delta, ray)
		if hit and (hit.Position - worldPoint).Magnitude > 2 then
			return "IMPOSSIBLE", "Target is obstructed"
		end
	end
	local stats = playerData[player]
	if not stats then
		return "IMPOSSIBLE", "Locus state unavailable"
	end
	local specialAffordable, missingSpecial = SpecialResourceSpec.canAfford(
		stats.SpecialResources,
		definition.Cost.SpecialResources,
		SpecialResourceDefinitions
	)
	if not specialAffordable then
		local label = SpecialResourceDefinitions[missingSpecial] and SpecialResourceDefinitions[missingSpecial].Label
		return "IMPOSSIBLE", "Insufficient " .. tostring(label or "special resource")
	end
	if definition.Development then
		return "VALID", nil, material, direction, selectedTarget, objectPosition
	end
	local mana, strain, complexity = costs(definition, charge, stats)
	local result, reason = LocusModel.evaluate(stats, mana, strain, complexity, ResourceBalance)
	return result, reason, material, direction, selectedTarget, objectPosition
end

local function updateEnhancement(player: Player, fallbackState: any?)
	local walkSpeedBonus, jumpPowerBonus = 0, 0
	local multiplier = 1
	local aerialSpeed = 0
	for _, effect in enhancements[player] or {} do
		walkSpeedBonus += effect.WalkSpeedBonus
		jumpPowerBonus += effect.JumpPowerBonus
		multiplier = math.max(multiplier, effect.SpeedMultiplier)
		aerialSpeed = math.max(aerialSpeed, effect.AerialSpeed or 0)
	end
	walkSpeedBonus = math.min(walkSpeedBonus, 30)
	jumpPowerBonus = math.min(jumpPowerBonus, Limits.MaxJumpBonus)
	multiplier = math.min(multiplier, Limits.MaxMultiplier)
	local _, effect = next(enhancements[player] or {})
	if effect then
		Movement.setMagicEnhancement(effect.State, walkSpeedBonus, jumpPowerBonus, multiplier)
		Movement.setMagicAerial(effect.State, aerialSpeed)
	elseif fallbackState then
		Movement.setMagicEnhancement(fallbackState, 0, 0, 1)
		Movement.setMagicAerial(fallbackState, 0)
	end
end

local emit: any
local finishBeamChannel: any
local spawnEffect: any
-- Spends from the cascade budget carried by runtimeState; reports exhaustion once.
local function spendOperations(runtimeState, cost: number, definition, remote, player): boolean
	local budget = runtimeState and runtimeState.OperationBudget
	if not budget or OperationBudget.spend(budget, cost) then
		return true
	end
	if OperationBudget.takeReport(budget) and remote and player then
		feedback(remote, player, "IMPOSSIBLE", definition, {
			Reason = "Spell reactions stopped: this chain reached its per-cast operation budget",
		})
	end
	return false
end
local function context(definition, caster, position, targets, direction, remote, player, potency, runtimeState)
	local stats = playerData[player]
	local eventDepth = runtimeState and runtimeState.EventDepth or 0
	local resolvedPotency = potency or (if stats then stats.Potency else LocusProfile.Potency)
	local ctx = {
		Caster = caster,
		Player = player,
		SpellId = definition.SpellId,
		Color = definition.Visual.Color,
		Targets = if runtimeState and (runtimeState.UsePreviousTargetSet or runtimeState.AllowObjectTarget)
			then targets
			else Conditions.targets(definition, caster, position, targets, {
				Player = player,
				Resources = resourceSnapshot(stats),
				SpellState = runtimeState,
				AllowDeadTargets = runtimeState
					and (
						runtimeState.EventName == "OnTargetDeath"
						or runtimeState.EventName == "OnDamageTaken"
						or runtimeState.EventName == "OnBreak"
						or runtimeState.EventName == "OnCasterDeath"
						or runtimeState.EventName == "OnExit"
					),
				AllowCasterTarget = runtimeState
					and (
						runtimeState.EventName == "OnDamageTaken"
						or runtimeState.EventName == "OnBreak"
						or runtimeState.EventName == "OnThreshold"
						or runtimeState.EventName == "OnCasterDeath"
					),
			}),
		Direction = direction,
		Potency = resolvedPotency,
		Origin = position,
		EventDepth = eventDepth,
		-- Read by per-step conditions (MagicConditions.stepTargets).
		Resources = resourceSnapshot(stats),
		SpellState = runtimeState,
		SpellTags = definition.Tags,
		HealthThreshold = runtimeState and runtimeState.HealthThreshold or nil,
		Command = runtimeState and runtimeState.Command or nil,
		DeathCause = runtimeState and runtimeState.DeathCause or nil,
		TrackAffected = function(humanoid)
			if
				runtimeState
				and type(runtimeState.TargetsHit) == "table"
				and typeof(humanoid) == "Instance"
				and humanoid:IsA("Humanoid")
			then
				runtimeState.TargetsHit[humanoid] = true
			end
		end,
		HitFeedback = function(humanoid, dealt)
			feedback(
				remote,
				player,
				"HIT",
				definition,
				{ Reason = humanoid.Parent and humanoid.Parent.Name, Damage = dealt, Target = humanoid.Parent }
			)
		end,
		EffectFeedback = function(effect, humanoid, amount)
			local target = humanoid.Parent
			feedback(remote, player, "EFFECT", definition, {
				Effect = effect,
				Amount = amount,
				Reason = target and target.Name,
				Target = target,
			})
			if
				(
					effect == "Heal"
					or effect == "Shield"
					or effect == "Control"
					or effect == "Displacement"
					or effect == "TimeDilation"
					or effect == "Transformation"
					or effect == "MagicArmor"
					or effect == "Bind"
				)
				and target
				and target:IsA("Model")
			then
				remote:FireAllClients({ Kind = "ImpactNumber", Effect = effect, Amount = amount, Target = target })
			end
		end,
		Summon = function(payload)
			local created, count, message = Summons.apply(
				player,
				caster,
				definition.SpellId,
				payload,
				definition.Visual.Color,
				Spec.copy(definition),
				remote,
				direction,
				resolvedPotency,
				position
			)
			if message or not created then
				feedback(remote, player, if created then "SUMMONED" else "IMPOSSIBLE", definition, {
					Reason = message
						or "No new summon was created; check whether this spell already has its configured summon count",
					Count = count,
				})
			end
		end,
	}
	ctx.ApplyManipulation = function(operation)
		local target = runtimeState and runtimeState.ObjectTarget
		if
			runtimeState
			and runtimeState.AllowObjectTarget == true
			and typeof(target) == "Instance"
			and target:IsA("BasePart")
			and table.find(ctx.Targets, target)
			and isValidObjectInteractionTarget(definition, target)
		then
			Manipulation.execute(operation.Operation, target, operation.Distance)
		end
	end
	ctx.DamageContext = {
		Depth = eventDepth,
		SourceRuntimeState = runtimeState and runtimeState.RuntimeOrigin or nil,
		HitPart = runtimeState and runtimeState.HitPart or nil,
		Element = definition.Element or "Neutral",
		ThresholdSteps = definition.Triggers.OnThreshold,
		EmitEvent = function(eventName, targetHumanoid, eventData)
			if eventDepth >= Limits.MaxMagicEventDepth or not emit then
				return
			end
			local runtime = runtimeState and (runtimeState.RuntimeOrigin or runtimeState)
			if eventName == "OnTargetDeath" and not TargetDeathSpec.claim(runtime, targetHumanoid) then
				return
			end
			local eventState = {
				RuntimeOrigin = runtimeState and (runtimeState.RuntimeOrigin or runtimeState) or nil,
				Age = runtimeState and runtimeState.Age or 0,
				CurrentPhase = eventName,
				TargetsHit = runtimeState and runtimeState.TargetsHit or {},
				Position = runtimeState and runtimeState.Position or position,
				RemainingLifetime = runtimeState and runtimeState.RemainingLifetime or nil,
				PierceCount = runtimeState and runtimeState.PierceCount or 0,
				BounceCount = runtimeState and runtimeState.BounceCount or 0,
				AbsorbedEnergy = runtimeState and runtimeState.AbsorbedEnergy or 0,
				CurrentTarget = runtimeState and runtimeState.CurrentTarget or targetHumanoid,
				StartedAt = runtimeState and runtimeState.StartedAt or os.clock(),
				EventDepth = eventDepth + 1,
				EventName = eventName,
				OperationBudget = runtimeState and runtimeState.OperationBudget or nil,
				DeathCause = if eventName == "OnTargetDeath"
					then (eventData and eventData.DeathCause or "KilledByThisSpell")
					else nil,
				HealthThreshold = eventData and eventData.HealthThreshold or nil,
				UsePreviousTargetSet = eventName == "OnBreak",
			}
			local eventPosition = position
			if
				(eventName == "OnBreak" or eventName == "OnThreshold" or eventName == "OnTargetDeath")
				and targetHumanoid
			then
				local targetModel = targetHumanoid.Parent
				local targetRoot = targetModel and targetModel:FindFirstChild("HumanoidRootPart")
				if targetRoot and targetRoot:IsA("BasePart") then
					eventPosition = targetRoot.Position
				end
			end
			emit(
				definition,
				eventName,
				caster,
				eventPosition,
				if targetHumanoid then { targetHumanoid } else {},
				direction,
				remote,
				player,
				potency,
				eventState
			)
		end,
	}
	ctx.SpawnEffect = function(step, eventTargets)
		spawnEffect(definition, step, caster, position, direction, remote, player, potency, runtimeState, eventTargets)
	end
	ctx.TargetDeathCallback = function(targetHumanoid)
		if not definition.Triggers or not definition.Triggers.OnTargetDeath then
			return nil
		end
		return function()
			ctx.DamageContext.EmitEvent("OnTargetDeath", targetHumanoid, { DeathCause = "DiedWhileAffected" })
		end
	end
	ctx.ApplySpherePayloads = function(radius, payloads)
		Presentation.marker(
			"MagicExplosionDebug",
			position,
			Vector3.new(0.2, radius * 2, radius * 2),
			definition.Visual.Color,
			0.2
		)
		local candidates = HitDetection.findSphere(caster, CFrame.new(position), radius, {
			OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
			RequireLineOfSight = definition.TargetRules.RequiresLineOfSight,
			IncludeAttacker = definition.TargetRules.IncludeCaster,
		})
		local targets = Conditions.targets(definition, caster, position, candidates, {
			Player = player,
			Resources = resourceSnapshot(stats),
			SpellState = runtimeState,
		})
		if not spendOperations(runtimeState, 1 + #targets, definition, remote, player) then
			return
		end
		local validatedState = table.clone(runtimeState or {})
		validatedState.UsePreviousTargetSet = true
		Payloads.execute(
			payloads,
			context(definition, caster, position, targets, direction, remote, player, potency, validatedState)
		)
	end
	return ctx
end
emit = function(definition, event, caster, position, targets, direction, remote, player, potency, runtimeState)
	definition._VFXCaster = caster
	local eventState = table.clone(runtimeState or {})
	eventState.EventName = event
	eventState.RuntimeOrigin = if runtimeState then runtimeState.RuntimeOrigin or runtimeState else nil
	-- Runtime counters for conditions: how many times this event has fired on
	-- this effect (kept on the persistent record) and how many targets it has.
	eventState.TriggerCount, eventState.EventTargets =
		RuntimeCounters.record(eventState.RuntimeOrigin or eventState, event, targets)
	eventState.OperationBudget = OperationBudget.resolve(runtimeState, Limits.MaxOperationsPerCascade)
	if not spendOperations(eventState, 1 + #(targets or {}), definition, remote, player) then
		return
	end
	local audioCue = if event == "OnImpact"
		then "ImpactSoundId"
		elseif event == "OnExpire" then "EndSoundId"
		elseif event == "OnBreak" then "BreakSoundId"
		else nil
	if audioCue then
		Presentation.playSound(definition, audioCue, position)
	end
	Triggers.execute(
		definition,
		event,
		context(definition, caster, position, targets, direction, remote, player, potency, eventState)
	)
end

local function hasEvent(definition: any, event: string): boolean
	local steps = definition.Triggers[event]
	return type(steps) == "table" and #steps > 0
end

local lifecycleState

local function dispatchClaimedExpiry(
	effect: any,
	position: Vector3,
	targets: { any },
	potency: number?,
	casterOverride: Model?,
	playerOverride: Player?
)
	if not hasEvent(effect.Definition, "OnExpire") then
		return
	end
	effect.CurrentPhase = "Expired"
	local eventState = lifecycleState(effect, "OnExpire", effect.EventDepth or 0)
	eventState.Position = position
	emit(
		effect.Definition,
		"OnExpire",
		effect.Caster or casterOverride,
		position,
		targets,
		effect.Direction or Vector3.zero,
		effect.Remote,
		effect.Player or playerOverride,
		potency,
		eventState
	)
end

local function emitExpiry(
	effect: any,
	position: Vector3,
	targets: { any },
	potency: number?,
	casterOverride: Model?,
	playerOverride: Player?
): boolean
	if not LifetimeSpec.claimExpiry(effect) then
		return false
	end
	dispatchClaimedExpiry(effect, position, targets, potency, casterOverride, playerOverride)
	return true
end

lifecycleState = function(source: any, event: string, depth: number)
	local runtime = source.RuntimeOrigin or source
	return {
		RuntimeOrigin = runtime,
		Age = source.Age or runtime.Age or 0,
		CurrentPhase = event,
		TargetsHit = runtime.TargetsHit or source.TargetsHit or {},
		Position = runtime.Position or source.Position,
		RemainingLifetime = runtime.RemainingLifetime or source.RemainingLifetime,
		PierceCount = runtime.PierceCount or source.PierceCount or 0,
		BounceCount = runtime.BounceCount or source.BounceCount or 0,
		AbsorbedEnergy = runtime.AbsorbedEnergy or source.AbsorbedEnergy or 0,
		CurrentTarget = runtime.CurrentTarget or source.CurrentTarget,
		ObjectTarget = runtime.ObjectTarget or source.ObjectTarget,
		AllowObjectTarget = runtime.AllowObjectTarget == true or source.AllowObjectTarget == true,
		StartedAt = source.StartedAt or runtime.StartedAt or os.clock(),
		EventDepth = depth,
		EventName = event,
	}
end

local function interruptWindupForDamage(target: Humanoid, amount: number)
	if amount <= 0 then
		return
	end
	for player, stats in playerData do
		for _, key in { "Charge", "Pending" } do
			local windup = stats[key]
			if
				windup
				and windup.State.Humanoid == target
				and CastInterruption.damage(windup.Definition.Casting, amount)
			then
				stats[key] = nil
				setCastingMovement(player, windup.State, nil)
				Presentation.cancel(windup.State.Character, windup.Definition)
				feedback(windup.Remote, player, "IMPOSSIBLE", windup.Definition, {
					Reason = "Cast interrupted by health damage",
				})
			end
		end
	end
end

Damage.Applied:Connect(function(attacker: Model, target: Humanoid, amount: number, killed: boolean, damageContext: any?)
	interruptWindupForDamage(target, amount)
	if damageContext and type(damageContext.EmitEvent) == "function" then
		local maxHealth = target.MaxHealth
		local healthBefore = 0
		local healthAfter = 0
		if maxHealth > 0 then
			healthBefore = math.min(maxHealth, target.Health + amount) / maxHealth * 100
			healthAfter = target.Health / maxHealth * 100
		end
		damageContext.EmitEvent("OnDamageDealt", target)
		if maxHealth > 0 then
			for _, step in ipairs(damageContext.ThresholdSteps or {}) do
				local threshold = step.HealthPercent
				if threshold and healthBefore > threshold and healthAfter <= threshold then
					damageContext.EmitEvent("OnThreshold", target, { HealthThreshold = threshold })
				end
			end
		end
		if killed then
			damageContext.EmitEvent("OnTargetDeath", target)
		end
	end
	local targetModel = target.Parent
	if not targetModel or not targetModel:IsA("Model") then
		return
	end
	local depth = if damageContext and type(damageContext.Depth) == "number" then damageContext.Depth else 0
	if depth >= Limits.MaxMagicEventDepth then
		return
	end
	for _, spell in active do
		if spell.Caster == targetModel and hasEvent(spell.Definition, "OnDamageTaken") then
			emit(
				spell.Definition,
				"OnDamageTaken",
				spell.Caster,
				spell.Position,
				{ target },
				spell.Direction,
				spell.Remote,
				spell.Player,
				nil,
				lifecycleState(spell, "OnDamageTaken", depth + 1)
			)
		end
	end
	for player, effects in enhancements do
		for _, effect in effects do
			if
				effect.State.Character == targetModel
				and effect.State.Humanoid.Health > 0
				and effect.Definition
				and hasEvent(effect.Definition, "OnDamageTaken")
			then
				emit(
					effect.Definition,
					"OnDamageTaken",
					targetModel,
					effect.State.Root.Position,
					{ target },
					effect.Direction,
					effect.Remote,
					player,
					nil,
					lifecycleState(effect, "OnDamageTaken", depth + 1)
				)
			end
		end
	end
	if killed then
		local seen = table.clone(active)
		for _, spell in seen do
			local sameSource = damageContext and damageContext.SourceRuntimeState == spell
			if
				not sameSource
				and spell.TargetsHit
				and spell.TargetsHit[target]
				and hasEvent(spell.Definition, "OnTargetDeath")
				and TargetDeathSpec.claim(spell.RuntimeOrigin or spell, target)
			then
				local root = targetModel:FindFirstChild("HumanoidRootPart")
				local position = if root and root:IsA("BasePart")
					then root.Position
					else targetModel:GetPivot().Position
				local eventState = lifecycleState(spell, "OnTargetDeath", depth + 1)
				eventState.DeathCause = "DiedWhileAffected"
				emit(
					spell.Definition,
					"OnTargetDeath",
					spell.Caster,
					position,
					{ target },
					spell.Direction or Vector3.zero,
					spell.Remote,
					spell.Player,
					nil,
					eventState
				)
			end
		end
		for player, effects in enhancements do
			for _, effect in effects do
				local sameSource = damageContext and damageContext.SourceRuntimeState == effect
				if
					not sameSource
					and effect.TargetsHit
					and effect.TargetsHit[target]
					and effect.Definition
					and hasEvent(effect.Definition, "OnTargetDeath")
					and TargetDeathSpec.claim(effect.RuntimeOrigin or effect, target)
				then
					local root = targetModel:FindFirstChild("HumanoidRootPart")
					local position = if root and root:IsA("BasePart")
						then root.Position
						else targetModel:GetPivot().Position
					local eventState = lifecycleState(effect, "OnTargetDeath", depth + 1)
					eventState.DeathCause = "DiedWhileAffected"
					emit(
						effect.Definition,
						"OnTargetDeath",
						effect.State.Character,
						position,
						{ target },
						effect.Direction or Vector3.zero,
						effect.Remote,
						player,
						nil,
						eventState
					)
				end
			end
		end
	end
end)

local function sphereTargets(definition, caster, position, radius)
	return HitDetection.findSphere(caster, CFrame.new(position), radius, {
		MaxDistance = if definition.Form == "Aura" then radius else nil,
		OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
		RequireLineOfSight = definition.TargetRules.RequiresLineOfSight,
		IncludeAttacker = definition.TargetRules.IncludeCaster,
	})
end

local function areaTargets(spell, position, radius)
	local stats = playerData[spell.Player]
	return Conditions.targets(
		spell.Definition,
		spell.Caster,
		position,
		sphereTargets(spell.Definition, spell.Caster, position, radius),
		{
			Player = spell.Player,
			Resources = resourceSnapshot(stats),
			SpellState = spell,
		}
	)
end

local function expireProjectile(spell)
	local targets = if spell.Kind == "ProjectileLinger"
		then areaTargets(spell, spell.Position, spell.LingerRadius)
		else {}
	emitExpiry(spell, spell.Position, targets, locusPotency(spell.Player) * (spell.PotencyMultiplier or 1))
end

local function formAreaCandidates(definition, caster, position, age)
	local area = if definition.Form == "Field" then definition.Field else definition.Aura
	area = AreaGrowth.area(area, AreaGrowth.scale(area, age or 0))
	if definition.Geometry == "Sphere" then
		return sphereTargets(definition, caster, position, area.Radius)
	end
	local frame = CFrame.new(position) * CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
	return HitDetection.findArea(caster, frame, definition.Geometry, area, {
		OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
		RequireLineOfSight = definition.TargetRules.RequiresLineOfSight,
		IncludeAttacker = definition.TargetRules.IncludeCaster,
	})
end

local function formAreaTargets(spell, position)
	local stats = playerData[spell.Player]
	return Conditions.targets(
		spell.Definition,
		spell.Caster,
		position,
		formAreaCandidates(spell.Definition, spell.Caster, position, spell.Age),
		{
			Player = spell.Player,
			Resources = resourceSnapshot(stats),
			SpellState = spell,
		}
	)
end

local function updateActiveProximity(effect, position: Vector3, now: number)
	local definition = effect.Definition
	local proximity = definition.Proximity
	if not proximity or not hasEvent(definition, "OnProximity") then
		return
	end
	local state = effect.ProximityState
	if not state then
		state = ProximitySpec.newState(now)
		effect.ProximityState = state
	end
	if not ProximitySpec.isDue(state, now, proximity.MaxTargets) then
		return
	end
	ProximitySpec.beginSample(state, now, proximity.Interval)
	local candidates = HitDetection.findSphere(effect.Caster, CFrame.new(position), proximity.Radius, {
		OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
		RequireLineOfSight = definition.TargetRules.RequiresLineOfSight,
		IncludeAttacker = definition.TargetRules.IncludeCaster,
	})
	local targets = Conditions.targets(definition, effect.Caster, position, candidates, {
		Player = effect.Player,
		Resources = resourceSnapshot(playerData[effect.Player]),
		SpellState = effect,
	})
	for _, humanoid in ipairs(targets) do
		if ProximitySpec.claim(state, humanoid, proximity.MaxTargets) then
			effect.CurrentPhase = "Proximity"
			effect.CurrentTarget = humanoid
			emit(
				definition,
				"OnProximity",
				effect.Caster,
				position,
				{ humanoid },
				effect.Direction,
				effect.Remote,
				effect.Player,
				locusPotency(effect.Player) * (effect.PotencyMultiplier or 1),
				lifecycleState(effect, "OnProximity", effect.EventDepth or 0)
			)
			effect.CurrentTarget = nil
			effect.CurrentPhase = "Active"
		end
	end
end

local emitAreaTransition
local function updateAreaMembership(spell, targets)
	local previous = spell.PresentTargets or {}
	local validTargets = {}
	for _, humanoid in targets do
		if humanoid.Health > 0 and humanoid:IsDescendantOf(workspace) then
			table.insert(validTargets, humanoid)
		end
	end
	local current, entered, exited = AreaMembership.diff(previous, validTargets)
	-- Update occupancy first so OnEnter/OnExit conditions see the new count.
	spell.PresentTargets = current
	for _, humanoid in ipairs(entered) do
		emitAreaTransition(spell, "OnEnter", humanoid)
	end
	for _, humanoid in ipairs(exited) do
		emitAreaTransition(spell, "OnExit", humanoid)
	end
end

emitAreaTransition = function(spell, event, humanoid)
	if not humanoid:IsDescendantOf(workspace) then
		return
	end
	local eventState = table.clone(spell)
	eventState.UsePreviousTargetSet = event == "OnExit"
	-- Keep the area record as the origin so per-effect counters persist.
	eventState.RuntimeOrigin = spell.RuntimeOrigin or spell
	emit(
		spell.Definition,
		event,
		spell.Caster,
		spell.Position,
		{ humanoid },
		spell.Direction,
		spell.Remote,
		spell.Player,
		nil,
		eventState
	)
end

local function closeAreaMembership(spell)
	local exited = AreaMembership.clear(spell.PresentTargets or {})
	spell.PresentTargets = {}
	for _, humanoid in ipairs(exited) do
		emitAreaTransition(spell, "OnExit", humanoid)
	end
end

local function finishInterruptedArea(spell)
	local wasChannel = spell.IsChannel == true
	spell.IsChannel = false
	local targets = {}
	for humanoid in pairs(spell.PresentTargets or {}) do
		if humanoid:IsDescendantOf(workspace) then
			table.insert(targets, humanoid)
		end
	end
	emitExpiry(spell, spell.Position, targets)
	closeAreaMembership(spell)
	local stats = playerData[spell.Player]
	if stats and stats.Channel == spell then
		stats.Channel = nil
	end
	if spell.Visual then
		Presentation.finish(spell.Visual)
	end
	if wasChannel then
		Presentation.cancel(spell.Caster, spell.Definition)
	end
end

local function expireSelfEnhancement(player: Player, effect: any)
	if not LifetimeSpec.claimExpiry(effect) then
		return
	end
	local state = effect.State
	local humanoid = state.Humanoid
	local character = state.Character
	local position = state.Root.Position
	if humanoid.Health <= 0 and not effect.CasterDeathEventFired and hasEvent(effect.Definition, "OnCasterDeath") then
		effect.CurrentPhase = "CasterDeath"
		emit(
			effect.Definition,
			"OnCasterDeath",
			character,
			position,
			{ humanoid },
			effect.Direction,
			effect.Remote,
			player,
			nil,
			lifecycleState(effect, "OnCasterDeath", 0)
		)
	end
	if effect.ComposedVisual then
		Presentation.finish(effect.ComposedVisual)
	end
	dispatchClaimedExpiry(effect, position, { humanoid }, nil, character, player)
end

local function stopToggledEffect(player: Player, caster: Model, definition: any): boolean
	local stopped = false
	for index = #active, 1, -1 do
		local spell = active[index]
		if
			spell.Player == player
			and spell.Caster == caster
			and spell.Definition.SpellId == definition.SpellId
			and (
				spell.Kind == "Field"
				or spell.Kind == "Aura"
				or (spell.Kind == "Construct" and definition.Form == "Construct")
			)
		then
			if spell.Kind == "Field" or spell.Kind == "Aura" then
				local wasChannel = spell.IsChannel == true
				local area = spell.Definition.Field or spell.Definition.Aura
				local targets = formAreaTargets(spell, spell.Position)
				updateAreaMembership(spell, targets)
				spell.IsChannel = false
				emitExpiry(spell, spell.Position, targets)
				closeAreaMembership(spell)
				if wasChannel then
					Presentation.cancel(spell.Caster, spell.Definition)
				end
			elseif spell.Kind == "Construct" then
				local target = spell.AttachedHumanoid
				emitExpiry(spell, spell.Position, if target then { target } else {}, nil)
			end
			Presentation.finish(spell.Visual)
			table.remove(active, index)
			stopped = true
		end
	end
	return stopped
end

local function configuredLifetime(definition: any): number
	return LifetimeSpec.effectiveDuration(definition.Lifetime.Mode, definition.Lifetime.Duration)
end

local function isSpawnFloorClip(part, start, direction, caster, visualPart, radius)
	-- Large visuals may begin with their lower surface slightly inside the floor.
	-- Treat only the supporting surface directly beneath a mostly level/upward cast
	-- as launch clearance; walls, characters, and downward casts still impact.
	if radius <= 0 or direction.Y < -0.35 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if visualPart then { caster, visualPart } else { caster }
	params.RespectCanCollide = true
	local support = workspace:Raycast(start + Vector3.yAxis * 0.05, -Vector3.yAxis * (radius + 0.1), params)
	return support ~= nil and support.Instance == part and support.Position.Y <= start.Y
end

local function resolveBeamCascadeStrike(spell, strikeIndex: number)
	local definition = spell.Definition
	local beam = definition.Beam
	local count = beam.StrikeCount
	local angle = (strikeIndex - 1) * 2.399963229728653
	local radial = if count > 1 then beam.SpreadRadius * math.sqrt((strikeIndex - 1) / (count - 1)) else 0
	local center = spell.Center + Vector3.new(math.cos(angle) * radial, 0, math.sin(angle) * radial)
	if (center - spell.Caster:GetPivot().Position).Magnitude > definition.TargetRules.Range + beam.SpreadRadius then
		return
	end
	local start = center + Vector3.yAxis * beam.DropHeight
	local delta = -Vector3.yAxis * (beam.DropHeight + 8)
	local hit = sweep(start, delta, spell.Caster, nil, beam.Width / 2)
	local endpoint = if hit then start + delta.Unit * hit.Distance else start + delta
	Presentation.beam(start, endpoint, beam.Width, definition.Visual.Color, definition.Beam.DebugDuration, definition)
	if hit then
		-- RuntimeOrigin keeps this beam's per-effect counters across strikes.
		local runtimeState = { HitPart = hit.Instance, RuntimeOrigin = spell }
		emit(
			definition,
			"OnImpact",
			spell.Caster,
			endpoint,
			targetFrom(hit),
			-Vector3.yAxis,
			spell.Remote,
			spell.Player,
			nil,
			runtimeState
		)
	end
end

local hasCapacity: (Player) -> boolean

local function initializeProjectileMotion(projectile, definition)
	local phases = definition.Projectile.MotionPhases or {}
	projectile.BaseSpeed = definition.Projectile.Speed
	projectile.MotionPhaseIndex = 1
	projectile.MotionPhaseElapsed = 0
	projectile.InitialVisualSize = projectile.Visual.Size
	projectile.Velocity = projectile.Direction * ProjectileMotion.initialSpeed(definition.Projectile.Speed, phases)
	if projectile.Velocity.Magnitude > 0.001 then
		projectile.Visual.CFrame = CFrame.lookAt(projectile.Position, projectile.Position + projectile.Velocity.Unit)
	end
end

local function projectileHasBehavior(projectile, kind: string): boolean
	for _, behavior in ipairs(projectile.Definition.Projectile.Behaviors or {}) do
		if behavior.Kind == kind then
			return true
		end
	end
	return false
end

local function projectileBehaviorContext(spell)
	local definition = spell.Definition
	local function findTargetsAt(projectile, position, radius, maxTargets)
		local nearby = HitDetection.findSphere(spell.Caster, CFrame.new(position), radius, {
			OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
			RequireLineOfSight = false,
		})
		local candidates = {}
		for _, humanoid in ipairs(nearby) do
			if not (projectile.HitHumanoids and projectile.HitHumanoids[humanoid]) then
				table.insert(candidates, humanoid)
			end
		end
		local valid = Conditions.targets(definition, spell.Caster, position, candidates)
		local configuredLos = definition.TargetRules.RequiresLineOfSight
			or (not definition.Conditions.Operator and table.find(definition.Conditions, "HasLineOfSight") ~= nil)
		local visible = {}
		for _, humanoid in ipairs(valid) do
			local model = humanoid.Parent
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local unobstructed = configuredLos
				if not configuredLos then
					local ray = RaycastParams.new()
					ray.FilterType = Enum.RaycastFilterType.Exclude
					ray.FilterDescendantsInstances = { spell.Caster, model }
					ray.RespectCanCollide = true
					unobstructed = workspace:Raycast(position, root.Position - position, ray) == nil
				end
				if unobstructed then
					table.insert(visible, { Humanoid = humanoid, Distance = (root.Position - position).Magnitude })
				end
			end
		end
		table.sort(visible, function(a, b)
			return a.Distance < b.Distance
		end)
		local results = {}
		for index = 1, math.min(maxTargets or #visible, #visible) do
			table.insert(results, visible[index].Humanoid)
		end
		return results
	end
	local function findTargetAt(projectile, position, radius)
		return findTargetsAt(projectile, position, radius, 1)[1]
	end
	return {
		Now = workspace:GetServerTimeNow(),
		ReturnTargetPosition = function(projectile)
			local humanoid = projectile.Caster:FindFirstChildOfClass("Humanoid")
			local root = projectile.Caster:FindFirstChild("HumanoidRootPart")
			if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
				return nil
			end
			return root.Position + Vector3.new(0, 1.5, 0)
		end,
		FindProximityTargets = function(projectile, radius, maxTargets)
			local candidates = areaTargets(spell, projectile.Position, radius)
			local targets = {}
			for _, humanoid in ipairs(candidates) do
				if
					not (projectile.ProximityTargets and projectile.ProximityTargets[humanoid])
					and not (projectile.HitHumanoids and projectile.HitHumanoids[humanoid])
				then
					table.insert(targets, humanoid)
					if #targets >= maxTargets then
						break
					end
				end
			end
			return targets
		end,
		OnProximity = function(projectile, humanoid)
			emit(
				definition,
				"OnProximity",
				spell.Caster,
				projectile.Position,
				{ humanoid },
				projectile.Direction,
				spell.Remote,
				spell.Player,
				locusPotency(spell.Player) * (projectile.PotencyMultiplier or 1),
				projectile
			)
		end,
		FindIncomingProjectile = function(projectile, radius, maxReflections)
			local closest = nil
			local closestDistance = math.huge
			for _, candidate in ipairs(active) do
				if
					candidate ~= projectile
					and candidate.Kind == "Projectile"
					and not candidate.AbsorbedBy
					and candidate.Caster ~= projectile.Caster
					and (maxReflections == nil or (candidate.ReflectionCount or 0) < maxReflections)
					and candidate.Caster:IsDescendantOf(workspace)
					and Conditions.relationshipMatches(projectile.Caster, candidate.Caster, "Hostile")
				then
					local separation = (candidate.Position - projectile.Position).Magnitude
					local contactRange = radius + definition.Projectile.Radius + candidate.Definition.Projectile.Radius
					if separation <= contactRange and separation < closestDistance then
						closest = candidate
						closestDistance = separation
					end
				end
			end
			return closest
		end,
		ShowAbsorption = function(projectile)
			Presentation.marker(
				"MagicProjectileAbsorb",
				projectile.Position,
				Vector3.new(0.16, definition.Projectile.Radius * 2.6, definition.Projectile.Radius * 2.6),
				definition.Visual.Color,
				0.22
			)
		end,
		ReflectProjectile = function(projectile, incoming)
			local originalCaster = incoming.Caster
			local originalHumanoid = originalCaster:FindFirstChildOfClass("Humanoid")
			local originalRoot = originalCaster:FindFirstChild("HumanoidRootPart")
			local reflectorHumanoid = projectile.Caster:FindFirstChildOfClass("Humanoid")
			local reflectorRoot = projectile.Caster:FindFirstChild("HumanoidRootPart")
			if
				not originalHumanoid
				or originalHumanoid.Health <= 0
				or not originalRoot
				or not originalRoot:IsA("BasePart")
				or not reflectorHumanoid
				or reflectorHumanoid.Health <= 0
				or not reflectorRoot
				or not reflectorRoot:IsA("BasePart")
			then
				return false
			end
			local towardSource = originalRoot.Position - incoming.Position
			if towardSource.Magnitude < 0.001 or incoming.Velocity.Magnitude < 0.001 then
				return false
			end
			incoming.Caster = projectile.Caster
			incoming.Player = projectile.Player
			incoming.Remote = projectile.Remote
			incoming.Direction = towardSource.Unit
			incoming.Velocity = incoming.Direction * incoming.Velocity.Magnitude
			incoming.HomingTarget = originalRoot
			incoming.FixedTarget = true
			incoming.ReflectionCount = (incoming.ReflectionCount or 0) + 1
			incoming.TargetsHit = {}
			incoming.CurrentPhase = "Reflected"
			return true
		end,
		ShowReflection = function(projectile)
			Presentation.marker(
				"MagicProjectileReflect",
				projectile.Position,
				Vector3.new(0.16, definition.Projectile.Radius * 2.6, definition.Projectile.Radius * 2.6),
				definition.Visual.Color,
				0.22
			)
		end,
		Pulse = function(projectile, behavior)
			local targets = areaTargets(spell, projectile.Position, behavior.Radius)
			Presentation.marker(
				"MagicProjectilePulse",
				projectile.Position,
				Vector3.new(0.12, behavior.Radius * 2, behavior.Radius * 2),
				definition.Visual.Color,
				0.18
			)
			emit(
				definition,
				"OnTick",
				spell.Caster,
				projectile.Position,
				targets,
				projectile.Direction,
				spell.Remote,
				spell.Player,
				locusPotency(spell.Player) * (projectile.PotencyMultiplier or 1),
				projectile
			)
		end,
		FindTarget = function(projectile, radius)
			return findTargetAt(projectile, projectile.Position, radius)
		end,
		FindTargetAt = findTargetAt,
		FindTargetsAt = findTargetsAt,
		TargetFromHit = function(hit)
			local humanoid = targetFrom(hit)[1]
			return humanoid, humanoid and humanoid.Parent or nil
		end,
		Link = function(from, to)
			Presentation.beam(
				from,
				to,
				math.max(1.4, definition.Projectile.Radius * 2),
				definition.Visual.Color,
				0.12,
				definition
			)
		end,
		ApplyImpact = function(projectile, humanoid, position, falloff)
			emit(
				definition,
				"OnImpact",
				spell.Caster,
				position,
				{ humanoid },
				projectile.Direction,
				spell.Remote,
				spell.Player,
				locusPotency(spell.Player) * (projectile.PotencyMultiplier or 1) * falloff,
				-- Shares the projectile's per-effect counters.
				{ RuntimeOrigin = projectile }
			)
		end,
		SpawnSplit = function(projectile, hit, behavior, directions, ignoredTargets)
			local normal = hit.Normal
			if typeof(normal) ~= "Vector3" or normal.Magnitude < 0.001 then
				return false
			end
			local start = hit.Position + normal.Unit * (definition.Projectile.Radius + 0.05)
			local spawned = 0
			local ignoredHumanoids = {}
			for _, model in ipairs(ignoredTargets) do
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					ignoredHumanoids[humanoid] = true
				end
			end
			local childHitHumanoids = table.clone(projectile.HitHumanoids or {})
			for humanoid in ignoredHumanoids do
				childHitHumanoids[humanoid] = true
			end
			for _, childDirection in ipairs(directions) do
				if not hasCapacity(spell.Player) then
					break
				end
				local child = {
					Kind = "Projectile",
					SpellId = definition.SpellId,
					Caster = spell.Caster,
					Age = 0,
					CurrentPhase = "Traveling",
					TargetsHit = {},
					HitHumanoids = table.clone(childHitHumanoids),
					StartedAt = os.clock(),
					RemainingLifetime = configuredLifetime(definition),
					Definition = definition,
					Position = start,
					Direction = childDirection,
					Velocity = childDirection * definition.Projectile.Speed,
					Distance = 0,
					IgnoredTargetModels = table.clone(ignoredTargets),
					SplitDepth = (projectile.SplitDepth or 0) + 1,
					PotencyMultiplier = (projectile.PotencyMultiplier or 1) * behavior.DamageFalloff,
					HomingTarget = projectile.HomingTarget,
					FixedTarget = projectile.FixedTarget,
					CommandCastId = projectile.CommandCastId,
					Visual = Presentation.projectile(definition, start),
					Player = spell.Player,
					Remote = spell.Remote,
				}
				initializeProjectileMotion(child, definition)
				emit(definition, "OnSpawn", spell.Caster, start, {}, childDirection, spell.Remote, spell.Player)
				table.insert(active, child)
				spawned += 1
			end
			return spawned > 0
		end,
		SpawnSpread = function(projectile, behavior, pair, angleDegrees)
			if not hasCapacity(spell.Player) then
				return false
			end
			local forward = projectile.Direction.Unit
			local rotationAxis = Vector3.yAxis
			if math.abs(forward:Dot(rotationAxis)) > 0.95 then
				rotationAxis = Vector3.xAxis
			end
			local direction = CFrame.fromAxisAngle(rotationAxis, math.rad(angleDegrees))
				:VectorToWorldSpace(forward).Unit
			local child = table.clone(projectile)
			child.Age = 0
			child.CurrentPhase = "Traveling"
			child.TargetsHit = {}
			child.HitHumanoids = {}
			child.IgnoredTargetModels = {}
			child.StartedAt = os.clock()
			child.RemainingLifetime = configuredLifetime(definition)
			child.Position = projectile.Position
			child.Direction = direction
			child.Velocity = direction * definition.Projectile.Speed
			child.Distance = 0
			child.SplitDepth = projectile.SplitDepth or 0
			child.BounceCount = 0
			child.PotencyMultiplier = (projectile.PotencyMultiplier or 1) * behavior.DamageFalloff ^ pair
			child.Visual = Presentation.projectile(definition, child.Position)
			initializeProjectileMotion(child, definition)
			emit(definition, "OnSpawn", spell.Caster, child.Position, {}, direction, spell.Remote, spell.Player)
			table.insert(active, child)
			return true
		end,
	}
end
-- Smoothed server frame time (ms) for the load budget; updated every Heartbeat.
local serverFrameMs = 1000 / 60
local function activeLoad(): number
	local load = 0
	for _, effect in active do
		load += LoadBudget.weight(effect.Definition)
	end
	return load
end

hasCapacity = function(player, additional: number?)
	local required = additional or 1
	if #active + required > Limits.MaxActiveGlobal then
		return false
	end
	local count = 0
	for _, effect in active do
		if effect.Player == player then
			count += 1
		end
	end
	return count + required <= Limits.MaxActivePerPlayer
end

-- Applies a SelfEnhancement to the caster's combat state: runs its OnCast
-- payloads, records the enhancement, and refreshes movement. Shared by the
-- cast path (formContext.ApplySelf) and spawned effects.
local function startSelfEnhancement(d, state, direction, remote, player)
	local ctx = context(d, state.Character, state.Root.Position, { state.Humanoid }, direction, remote, player)
	local combined = { WalkSpeedBonus = 0, JumpPowerBonus = 0, SpeedMultiplier = 1, AerialSpeed = 0 }
	ctx.ApplyEnhancement = function(payload)
		combined.WalkSpeedBonus += payload.WalkSpeedBonus or 0
		combined.JumpPowerBonus += payload.JumpPowerBonus or 0
		combined.SpeedMultiplier = math.max(combined.SpeedMultiplier, payload.SpeedMultiplier or 1)
	end
	ctx.ApplyAerialMovement = function(payload)
		combined.AerialSpeed = math.max(combined.AerialSpeed, payload.Speed or 0)
	end
	Triggers.execute(d, "OnCast", ctx)
	enhancements[player] = enhancements[player] or {}
	local previousVisual = enhancements[player][d.SpellId] and enhancements[player][d.SpellId].ComposedVisual
	if previousVisual then
		Presentation.finish(previousVisual)
	end
	enhancements[player][d.SpellId] = {
		State = state,
		Definition = d,
		Remote = remote,
		Direction = direction,
		Age = 0,
		CurrentPhase = "Active",
		TargetsHit = {},
		StartedAt = os.clock(),
		ExpiresAt = if d.Lifetime.Mode == "UntilToggledOff"
				or d.Lifetime.Mode == "UntilResourceDepleted"
				or d.Lifetime.Mode == "UntilConditionFails"
			then math.huge
			else workspace:GetServerTimeNow() + d.Lifetime.Duration,
		WalkSpeedBonus = combined.WalkSpeedBonus,
		JumpPowerBonus = combined.JumpPowerBonus,
		SpeedMultiplier = combined.SpeedMultiplier,
		AerialSpeed = combined.AerialSpeed,
		ProximityState = if d.Proximity then ProximitySpec.newState(workspace:GetServerTimeNow()) else nil,
		IsChannel = d.Casting.Mode == "Channeled",
		AmbientSound = Presentation.attachLoop(d, "AmbientLoopSoundId", state.Root),
		ComposedVisual = Presentation.follow(d, state.Root, Vector3.new(5, 6, 5)),
	}
	updateEnhancement(player)
end

-- Latest combat state per player, so a spawned SelfEnhancement can reach the
-- caster's movement state (only used while state.Character is the caster).
local castStates = setmetatable({}, { __mode = "k" })

-- SpawnEffect: start a validated child effect (any Form but Manipulation) at an event.
-- The child definition is expanded from the step's compact Effect once and
-- cached; its own triggers run through the ordinary emit path. Spawning is
-- bounded by the active-effect caps, the cascade operation budget, and the
-- validator's static nesting limit (Limits.MaxSpawnNesting).
local spawnedDefinitions = setmetatable({}, { __mode = "k" })
spawnEffect = function(parent, step, caster, position, direction, remote, player, potency, runtimeState, eventTargets)
	local child = spawnedDefinitions[step.Effect]
	if child == nil then
		child = Spec.expandSpawnEffect(parent, step.Effect) or false
		spawnedDefinitions[step.Effect] = child
	end
	if not child or not caster or not caster.Parent or typeof(position) ~= "Vector3" then
		return
	end
	local count = if child.Form == "Projectile" then math.clamp(step.Count or 1, 1, Limits.MaxSpawnCount) else 1
	if not hasCapacity(player, count) then
		return
	end
	if not spendOperations(runtimeState, count, parent, remote, player) then
		return
	end
	local forward = if typeof(direction) == "Vector3" and direction.Magnitude > 0.001 then direction.Unit else nil
	if not forward then
		local casterRoot = caster:FindFirstChild("HumanoidRootPart")
		forward = if casterRoot and casterRoot:IsA("BasePart") then casterRoot.CFrame.LookVector else Vector3.zAxis
	end

	if child.Form == "Projectile" then
		local spread = math.rad(math.clamp(step.SpreadAngle or 0, 0, Limits.MaxSpawnSpreadAngle))
		local axis = if math.abs(forward:Dot(Vector3.yAxis)) > 0.95 then Vector3.xAxis else Vector3.yAxis
		-- Start just behind the event point so a child spawned on a wall
		-- impact does not begin inside that wall.
		local start = position - forward * (child.Projectile.Radius + 0.5)
		for index = 1, count do
			local alpha = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
			local childDirection = CFrame.fromAxisAngle(axis, spread * alpha):VectorToWorldSpace(forward).Unit
			emit(child, "OnCast", caster, start, {}, childDirection, remote, player, potency)
			emit(child, "OnSpawn", caster, start, {}, childDirection, remote, player, potency)
			local projectile = {
				Kind = "Projectile",
				SpellId = child.SpellId,
				Caster = caster,
				Age = 0,
				CurrentPhase = "Traveling",
				TargetsHit = {},
				StartedAt = os.clock(),
				RemainingLifetime = configuredLifetime(child),
				Definition = child,
				Position = start,
				Direction = childDirection,
				Velocity = childDirection * child.Projectile.Speed,
				Distance = 0,
				Visual = Presentation.projectile(child, start),
				Player = player,
				Remote = remote,
			}
			initializeProjectileMotion(projectile, child)
			table.insert(active, projectile)
		end
	elseif child.Form == "Field" then
		local initialField = AreaGrowth.area(child.Field, AreaGrowth.scale(child.Field, 0))
		local marker = Presentation.areaMarker(
			"MagicFieldDebug",
			CFrame.new(position) * CFrame.Angles(0, math.rad(child.Field.Yaw or 0), 0),
			child.Geometry,
			Geometry.areaSize(child.Geometry, initialField),
			child.Visual.Color,
			child.Field.DebugHeight,
			child
		)
		Presentation.attachLoop(child, "AmbientLoopSoundId", marker)
		local targets = formAreaCandidates(child, caster, position, 0)
		local field = {
			Kind = "Field",
			Caster = caster,
			Player = player,
			Remote = remote,
			Definition = child,
			FollowTarget = false,
			Age = 0,
			CurrentPhase = "Active",
			TargetsHit = {},
			PresentTargets = {},
			StartedAt = os.clock(),
			Position = position,
			Direction = forward,
			RemainingLifetime = configuredLifetime(child),
			NextInterval = 0,
			Visual = marker,
		}
		table.insert(active, field)
		emit(child, "OnCast", caster, position, targets, forward, remote, player, potency, field)
		emit(child, "OnSpawn", caster, position, targets, forward, remote, player, potency, field)
	elseif child.Form == "Wave" then
		local wave = AreaGrowth.area(child.Wave, AreaGrowth.scale(child.Wave, 0))
		local waveRange = math.min(wave.Range, child.TargetRules.Range)
		local frame = CFrame.lookAt(position, position + forward)
		local targetRules = {
			OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
			RequireLineOfSight = child.TargetRules.RequiresLineOfSight,
			IncludeAttacker = child.TargetRules.IncludeCaster,
		}
		local targets = if child.Geometry == "Sphere"
			then HitDetection.findSphere(caster, frame, waveRange, targetRules)
			else HitDetection.findCone(caster, frame, waveRange, child.Wave.Dot, targetRules)
		emit(child, "OnCast", caster, position, targets, forward, remote, player, potency)
		Presentation.wave(child, frame, waveRange, child.Wave.DebugDuration)
	elseif child.Form == "Beam" then
		-- Fired from the event point along the event direction.
		local beam = AreaGrowth.area(child.Beam, AreaGrowth.scale(child.Beam, 0))
		local beamRange = math.min(beam.Range, child.TargetRules.Range)
		local hit = sweep(position, forward * beamRange, caster, nil, beam.Width / 2)
		local endpoint = if hit then position + forward * hit.Distance else position + forward * beamRange
		local eventState = { HitPart = if hit then hit.Instance else nil }
		if child.Beam.Pattern == "Cascade" then
			emit(child, "OnCast", caster, position, targetFrom(hit), forward, remote, player, potency, eventState)
			local cascade = {
				Kind = "BeamCascade",
				SpellId = child.SpellId,
				Caster = caster,
				Definition = child,
				Player = player,
				Remote = remote,
				Center = endpoint,
				Position = endpoint,
				Direction = forward,
				Age = 0,
				StrikeIndex = 1,
				NextInterval = workspace:GetServerTimeNow() + child.Beam.StrikeInterval,
				RemainingLifetime = child.Beam.StrikeInterval * (child.Beam.StrikeCount - 1) + 0.25,
				StartedAt = workspace:GetServerTimeNow(),
				TargetsHit = {},
			}
			resolveBeamCascadeStrike(cascade, 1)
			table.insert(active, cascade)
		else
			Presentation.beam(position, endpoint, beam.Width, child.Visual.Color, child.Beam.DebugDuration, child)
			emit(child, "OnCast", caster, position, targetFrom(hit), forward, remote, player, potency, eventState)
			emit(child, "OnImpact", caster, endpoint, targetFrom(hit), forward, remote, player, potency, eventState)
		end
	elseif child.Form == "Aura" then
		-- An Aura follows something: the event's first target if it has one
		-- (a curse that travels with the enemy hit), otherwise the caster.
		local followTarget = caster
		for _, target in eventTargets or {} do
			if typeof(target) == "Instance" and target:IsA("Humanoid") and target.Parent then
				followTarget = target.Parent
				break
			end
		end
		local followRoot = followTarget:FindFirstChild("HumanoidRootPart")
		if not followRoot or not followRoot:IsA("BasePart") then
			return
		end
		local point = followRoot.Position
		local initialAura = AreaGrowth.area(child.Aura, AreaGrowth.scale(child.Aura, 0))
		local marker = Presentation.areaMarker(
			"MagicAuraDebug",
			CFrame.new(point) * CFrame.Angles(0, math.rad(child.Aura.Yaw or 0), 0),
			child.Geometry,
			Geometry.areaSize(child.Geometry, initialAura),
			child.Visual.Color,
			nil,
			child
		)
		Presentation.attachLoop(child, "AmbientLoopSoundId", marker)
		local targets = formAreaCandidates(child, caster, point, 0)
		local aura = {
			Kind = "Aura",
			Caster = caster,
			Player = player,
			Remote = remote,
			Definition = child,
			FollowTarget = followTarget,
			Age = 0,
			CurrentPhase = "Active",
			TargetsHit = {},
			PresentTargets = {},
			StartedAt = os.clock(),
			Position = point,
			Direction = Vector3.zero,
			RemainingLifetime = configuredLifetime(child),
			NextInterval = 0,
			Visual = marker,
		}
		table.insert(active, aura)
		emit(child, "OnCast", caster, point, targets, Vector3.zero, remote, player, potency, aura)
		emit(child, "OnSpawn", caster, point, targets, Vector3.zero, remote, player, potency, aura)
	elseif child.Form == "Construct" then
		-- Built at the event point, upright, facing along the event direction.
		local components = ConstructGeometry.components(
			child.Geometry,
			child.Construct.Width,
			child.Construct.Height,
			child.Construct.Depth,
			child.Construct.Components
		)
		if not components then
			return
		end
		local flat = Vector3.new(forward.X, 0, forward.Z)
		flat = if flat.Magnitude > 0.001 then flat.Unit else Vector3.zAxis
		local frame = CFrame.lookAt(position, position + flat)
		local model, pivot, componentLifetimes, startScale = buildConstructModel(child, components, frame, true)
		Presentation.attachLoop(child, "AmbientLoopSoundId", pivot)
		emit(child, "OnCast", caster, position, {}, flat, remote, player, potency)
		table.insert(active, {
			Kind = "Construct",
			AnchorPoint = position,
			AnchorNormal = Vector3.yAxis,
			BaseSize = Vector3.new(child.Construct.Width, child.Construct.Height, child.Construct.Depth),
			CurrentScale = startScale,
			GrowthEnabled = child.Construct.GrowthDuration ~= nil and child.Construct.GrowthDuration > 0,
			GrowthCheckAccumulator = 0.1,
			Caster = caster,
			Position = position,
			Direction = flat,
			Player = player,
			Remote = remote,
			Definition = child,
			Age = 0,
			CurrentPhase = "Active",
			TargetsHit = {},
			ProximityState = if child.Proximity then ProximitySpec.newState(workspace:GetServerTimeNow()) else nil,
			StartedAt = os.clock(),
			RemainingLifetime = configuredLifetime(child),
			Visual = model,
			ComponentLifetimes = componentLifetimes,
		})
	elseif child.Form == "SelfEnhancement" then
		-- Applies to the caster, using the combat state of their latest cast.
		local state = player and castStates[player]
		if
			not state
			or state.Character ~= caster
			or not state.Root
			or not state.Root:IsDescendantOf(workspace)
			or state.Humanoid.Health <= 0
		then
			return
		end
		startSelfEnhancement(child, state, forward, remote, player)
	end
end

local function spawnChannelProjectile(channel): boolean
	if not hasCapacity(channel.Player) then
		return false
	end
	local definition = channel.Definition
	local root = channel.Caster:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local fallback = root.Position + Vector3.new(0, 1.5, 0)
	local start = Presentation.handOrigin(channel.Caster, fallback)
	if start ~= fallback and sweep(fallback, start - fallback, channel.Caster, nil, 0) then
		start = fallback
	end
	local targetRoot = nil
	local targetModel = channel.TargetModel
	if targetModel and targetModel:IsDescendantOf(workspace) then
		local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
		local candidateRoot = targetModel:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and candidateRoot and candidateRoot:IsA("BasePart") then
			targetRoot = candidateRoot
		end
	end
	local projectile = {
		Kind = "Projectile",
		SpellId = definition.SpellId,
		Caster = channel.Caster,
		Age = 0,
		CurrentPhase = "Traveling",
		TargetsHit = {},
		StartedAt = os.clock(),
		RemainingLifetime = definition.Lifetime.Duration,
		Definition = definition,
		Position = start,
		Direction = channel.Direction,
		Velocity = channel.Direction * definition.Projectile.Speed,
		Distance = 0,
		HomingTarget = if definition.TargetPolicy == "MaintainTarget" then targetRoot else nil,
		ObjectTarget = if definition.Targeting == "ObjectTarget" then channel.ObjectTarget else nil,
		FixedTarget = definition.TargetPolicy == "MaintainTarget",
		Visual = Presentation.projectile(definition, start),
		Player = channel.Player,
		Remote = channel.Remote,
	}
	initializeProjectileMotion(projectile, definition)
	emit(definition, "OnSpawn", channel.Caster, start, {}, projectile.Direction, channel.Remote, channel.Player)
	table.insert(active, projectile)
	ProjectileBehaviors.spawn(projectile, projectileBehaviorContext(projectile))
	return true
end

local function execute(
	player,
	state,
	remote,
	definition,
	intent,
	charge,
	material,
	direction,
	result,
	reason,
	castContext,
	selectedTarget,
	objectPosition
)
	local stats = playerData[player]
	local channelProjectile = definition.Form == "Projectile" and definition.Casting.Mode == "Channeled"
	local persistentConstruct = definition.Form == "Construct" and definition.Lifetime.Mode == "Persistent"
	if not stats or (not persistentConstruct and not hasCapacity(player, if channelProjectile then 2 else 1)) then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Active spell safety limit" })
		return
	end
	if
		not persistentConstruct and not LoadBudget.canAdd(activeLoad(), LoadBudget.weight(definition), serverFrameMs)
	then
		feedback(
			remote,
			player,
			"IMPOSSIBLE",
			definition,
			{ Reason = "Too much magic is active here; try again shortly" }
		)
		return
	end
	local constructFrame, constructSize, constructAttachment, constructHumanoid, constructAnchorPoint, constructAnchorNormal
	local constructComponents
	local persistentRecordId
	if definition.Form == "Construct" then
		constructFrame, constructSize, constructAttachment, constructHumanoid, constructAnchorPoint, constructAnchorNormal =
			constructPlacement(state, definition, direction, intent)
		if not constructFrame then
			feedback(remote, player, "IMPOSSIBLE", definition, {
				Reason = "The Construct placement could not be created",
			})
			return
		end
		constructComponents = ConstructGeometry.components(
			definition.Geometry,
			definition.Construct.Width,
			definition.Construct.Height,
			definition.Construct.Depth,
			definition.Construct.Components
		)
		if not constructComponents then
			feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Construct geometry is invalid" })
			return
		end
		if definition.Targeting == "EntityTarget" and selectedTarget then
			local targetHumanoid = selectedTarget:FindFirstChildOfClass("Humanoid")
			if not targetHumanoid or constructHumanoid ~= targetHumanoid then
				feedback(remote, player, "IMPOSSIBLE", definition, {
					Reason = "Construct could not reach the selected character without obstruction",
				})
				return
			end
		end
		if definition.Lifetime.Mode == "Persistent" then
			if constructHumanoid or (constructAttachment and not constructAttachment.Anchored) then
				feedback(remote, player, "IMPOSSIBLE", definition, {
					Reason = "Persistent Constructs can only be placed on static world geometry or in open air",
				})
				return
			end
		end
	end
	local mana, strain, complexity = costs(definition, charge, stats)
	if CastingSpec.isHeldMode(definition.Casting.Mode) and stats.Mana < mana then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Not enough mana to begin the held spell" })
		return
	end
	local specialCosts = definition.Cost.SpecialResources or {}
	local specialAffordable, missingSpecial =
		SpecialResourceSpec.canAfford(stats.SpecialResources, specialCosts, SpecialResourceDefinitions)
	if not specialAffordable then
		local label = SpecialResourceDefinitions[missingSpecial] and SpecialResourceDefinitions[missingSpecial].Label
		feedback(remote, player, "IMPOSSIBLE", definition, {
			Reason = "Insufficient " .. tostring(label or "special resource"),
			SpecialResources = stats.SpecialResources,
		})
		return
	end
	local materialAmount = if material
			and definition.Material
			and definition.Form ~= "Manipulation"
		then definition.Material.Amount
		else nil
	local materialAvailable = if material then material:GetAttribute("AvailableAmount") else nil
	if
		materialAmount
		and (
			not material
			or not material:IsDescendantOf(workspace)
			or not CollectionService:HasTag(material, "MagicMaterialSource")
			or material:GetAttribute("MagicMaterial") ~= definition.Material.Material
			or type(materialAvailable) ~= "number"
			or materialAvailable ~= materialAvailable
			or materialAvailable <= -math.huge
			or materialAvailable >= math.huge
			or materialAvailable < materialAmount
		)
	then
		feedback(
			remote,
			player,
			"IMPOSSIBLE",
			definition,
			{ Reason = "Material source no longer has enough available amount" }
		)
		return
	end
	if definition.Lifetime.Mode == "Persistent" then
		stats.PersistentConstructCastInProgress = true
		local saved, id, saveReason = pcall(
			PersistentConstructStore.add,
			persistentConstructRecord(player, constructFrame, constructComponents, definition)
		)
		stats.PersistentConstructCastInProgress = nil
		if not saved or not id then
			feedback(remote, player, "IMPOSSIBLE", definition, {
				Reason = tostring(saveReason or id or "Persistent Construct storage is unavailable"),
			})
			return
		end
		persistentRecordId = id
	end
	if not definition.Development or CastingSpec.isHeldMode(definition.Casting.Mode) then
		LocusModel.spend(stats, mana, strain)
	end
	local paidSpecialResources = false
	if next(specialCosts) then
		local spent = SpecialResourceSpec.spend(stats.SpecialResources, specialCosts, SpecialResourceDefinitions)
		if not spent then
			if persistentRecordId then
				task.spawn(function()
					PersistentConstructStore.remove(persistentRecordId)
				end)
			end
			feedback(
				remote,
				player,
				"IMPOSSIBLE",
				definition,
				{ Reason = "Special resource state changed before release" }
			)
			return
		end
		paidSpecialResources = true
		syncSpecialResourceAttributes(player)
	end
	Summons.clearDismissal(player, definition.SpellId)
	stats.Ready[definition.SpellId] = {
		Remaining = math.max(definition.Casting.Cooldown, definition.Casting.RecoveryTime),
		Caster = state.Humanoid,
	}
	if materialAmount and material then
		material:SetAttribute("AvailableAmount", materialAvailable - materialAmount)
	end
	feedback(remote, player, result, definition, {
		Reason = reason,
		Mana = stats.Mana,
		Capacity = stats.Capacity,
		Strain = stats.Strain,
		StrainTolerance = stats.StrainTolerance,
		Efficiency = stats.Efficiency,
		Potency = stats.Potency,
		Complexity = complexity,
		ComplexityCapacity = stats.ComplexityCapacity,
		ManaDemand = mana,
		SpecialResources = stats.SpecialResources,
	})
	local origin = castContext and castContext.Origin or state.Root.Position + Vector3.new(0, 1.5, 0)
	local commandCastId = if castContext
			and castContext.CommandCast == true
			and CompanionSpellPolicy.requiresCommandSlot(d)
		then castContext.CommandId
		else nil
	local function registerActiveEffect(effect)
		if commandCastId ~= nil then
			effect.CommandCastId = commandCastId
		end
		table.insert(active, effect)
	end
	if not castContext and (definition.Form == "Projectile" or definition.Form == "Beam") then
		local hand = intent.CastOrigin
		if not validVector(hand) or (hand - state.Root.Position).Magnitude > 3.5 then
			hand = Presentation.handOrigin(state.Character, origin)
		end
		if not sweep(origin, hand - origin, state.Character, nil, 0) then
			origin = hand
		end
		if validVector(intent.WorldPoint) then
			local delta = intent.WorldPoint - origin
			if delta.Magnitude > 0.001 and direction:Dot(delta.Unit) >= Sandbox.Magic.MinimumWorldAimDot then
				direction = delta.Unit
			end
		end
	end
	local formContext = {}
	formContext.CreateConstruct = function(d)
		local components = constructComponents
			or ConstructGeometry.components(
				d.Geometry,
				d.Construct.Width,
				d.Construct.Height,
				d.Construct.Depth,
				d.Construct.Components
			)
		if not components then
			return
		end
		local model, pivot, componentLifetimes, constructStartScale =
			buildConstructModel(d, components, constructFrame, constructHumanoid == nil)
		if d.Lifetime.Mode == "Persistent" and persistentRecordId then
			model.Name = "MagicPersistentConstruct"
			model:SetAttribute("MagicPersistentConstruct", true)
			model:SetAttribute("MagicPersistentConstructId", persistentRecordId)
			model:SetAttribute("MagicPersistentConstructOwner", player.UserId)
			watchPersistentConstruct(model, persistentRecordId)
			return
		end
		Presentation.attachLoop(d, "AmbientLoopSoundId", pivot)
		emit(d, "OnCast", state.Character, constructFrame.Position, {}, direction, remote, player)
		local attachmentPoint = if constructAnchorPoint and constructAttachment
			then constructAttachment.CFrame:PointToObjectSpace(constructAnchorPoint)
			else constructAnchorPoint
		local attachmentNormal = if constructAnchorNormal and constructAttachment
			then constructAttachment.CFrame:VectorToObjectSpace(constructAnchorNormal)
			else constructAnchorNormal
		local attachmentRotation = if constructAttachment
			then constructAttachment.CFrame.Rotation:ToObjectSpace(constructFrame.Rotation)
			else constructFrame.Rotation
		local construct = {
			Kind = "Construct",
			Attachment = constructAttachment,
			AttachedHumanoid = constructHumanoid,
			AttachmentOffset = constructAttachment and constructAttachment.CFrame:ToObjectSpace(constructFrame),
			AttachmentPoint = attachmentPoint,
			AttachmentNormal = attachmentNormal,
			AttachmentRotation = attachmentRotation,
			AnchorPoint = if constructAttachment then nil else constructAnchorPoint,
			AnchorNormal = if constructAttachment then nil else constructAnchorNormal,
			BaseSize = Vector3.new(d.Construct.Width, d.Construct.Height, d.Construct.Depth),
			CurrentScale = constructStartScale,
			GrowthEnabled = d.Construct.GrowthDuration ~= nil and d.Construct.GrowthDuration > 0,
			GrowthCheckAccumulator = 0.1,
			Caster = state.Character,
			Position = constructFrame.Position,
			Direction = direction,
			Player = player,
			Remote = remote,
			Definition = d,
			Age = 0,
			CurrentPhase = "Active",
			TargetsHit = {},
			ProximityState = if d.Proximity then ProximitySpec.newState(workspace:GetServerTimeNow()) else nil,
			StartedAt = os.clock(),
			RemainingLifetime = configuredLifetime(d),
			State = state,
			Visual = model,
			ComponentLifetimes = componentLifetimes,
		}
		registerActiveEffect(construct)
		formContext.RegisterChannel(construct)
	end
	formContext.CreateAura = function(d)
		local followPart = if d.Targeting == "ObjectTarget"
				and material
				and material:IsA("BasePart")
			then material
			else nil
		local followTarget = if d.Targeting == "EntityTarget" then selectedTarget else state.Character
		local followRoot = if followPart then nil else followTarget:FindFirstChild("HumanoidRootPart")
		if
			(not followPart and (not followRoot or not followRoot:IsA("BasePart")))
			or (followPart and not objectPosition)
		then
			feedback(remote, player, "IMPOSSIBLE", d, { Reason = "Aura follow target is no longer available" })
			return
		end
		local point: Vector3
		if followPart then
			point = objectPosition :: Vector3
		else
			point = (followRoot :: BasePart).Position
		end
		local initialAura = AreaGrowth.area(d.Aura, AreaGrowth.scale(d.Aura, 0))
		local marker = Presentation.areaMarker(
			"MagicAuraDebug",
			CFrame.new(point) * CFrame.Angles(0, math.rad(d.Aura.Yaw or 0), 0),
			d.Geometry,
			Geometry.areaSize(d.Geometry, initialAura),
			d.Visual.Color,
			nil,
			d
		)
		Presentation.attachLoop(d, "AmbientLoopSoundId", marker)
		local targets = formAreaCandidates(d, state.Character, point, 0)
		local aura = {
			Kind = "Aura",
			Caster = state.Character,
			Player = player,
			Remote = remote,
			Definition = d,
			FollowTarget = followTarget,
			FollowPart = followPart,
			FollowPartOffset = if followPart then followPart.CFrame:PointToObjectSpace(point) else nil,
			Age = 0,
			CurrentPhase = "Active",
			TargetsHit = {},
			PresentTargets = {},
			StartedAt = os.clock(),
			Position = point,
			Direction = Vector3.zero,
			RemainingLifetime = configuredLifetime(d),
			NextInterval = 0,
			Visual = marker,
		}
		registerActiveEffect(aura)
		formContext.RegisterChannel(aura)
		emit(d, "OnCast", state.Character, point, targets, Vector3.zero, remote, player, nil, aura)
		emit(d, "OnSpawn", state.Character, point, targets, Vector3.zero, remote, player, nil, aura)
	end
	formContext.ExecuteBeam = function(d)
		local targetRoot = selectedTarget and selectedTarget:FindFirstChild("HumanoidRootPart")
		local beamAimPoint = if targetRoot and targetRoot:IsA("BasePart")
			then targetRoot.Position
			else if validVector(intent.WorldPoint) then intent.WorldPoint else nil
		direction = BeamAim.direction(origin, direction, beamAimPoint)
		local objectTarget = if d.Targeting == "ObjectTarget"
				and material
				and material:IsA("BasePart")
			then material
			else nil
		if d.Casting.Mode == "Channeled" then
			local beam = AreaGrowth.area(d.Beam, AreaGrowth.scale(d.Beam, 0))
			local beamRange = math.min(beam.Range, d.TargetRules.Range)
			local channel = {
				Kind = "BeamChannel",
				SpellId = d.SpellId,
				Caster = state.Character,
				Age = 0,
				CurrentPhase = "Channeling",
				TargetsHit = {},
				StartedAt = workspace:GetServerTimeNow(),
				RemainingLifetime = d.Lifetime.Duration,
				NextInterval = 0,
				Definition = d,
				ObjectTarget = objectTarget,
				AimPoint = beamAimPoint,
				Position = origin,
				Direction = direction,
				Player = player,
				Remote = remote,
				Visual = nil,
				IsChannel = true,
			}
			channel.AmbientSound = Presentation.attachLoop(d, "AmbientLoopSoundId", state.Root)
			local hit = sweep(origin, direction * beamRange, state.Character, nil, beam.Width / 2)
			local endpoint = hit and (origin + direction * hit.Distance) or origin + direction * beamRange
			channel.Visual =
				Presentation.beam(origin, endpoint, beam.Width, d.Visual.Color, d.Beam.DebugDuration, d, nil, true)
			local targetHit = if hit and hit.Instance == objectTarget
				then objectTargetHit(
					state.Character,
					origin,
					direction,
					math.min(objectTargetRange(d), beamRange),
					objectTarget,
					d
				)
				else nil
			channel.AllowObjectTarget = targetHit ~= nil
			channel.HitPart = if not objectTarget and hit then hit.Instance else nil
			emit(
				d,
				"OnCast",
				state.Character,
				origin,
				if objectTarget then if targetHit then { objectTarget } else {} else targetFrom(hit),
				direction,
				remote,
				player,
				nil,
				channel
			)
			if hit then
				emit(
					d,
					"OnImpact",
					state.Character,
					endpoint,
					if objectTarget then if targetHit then { objectTarget } else {} else targetFrom(hit),
					direction,
					remote,
					player,
					nil,
					channel
				)
			end
			channel.HitPart = nil
			channel.AllowObjectTarget = nil
			stats.Channel = channel
			registerActiveEffect(channel)
			return
		end
		local beam = AreaGrowth.area(d.Beam, AreaGrowth.scale(d.Beam, 0))
		local beamRange = math.min(beam.Range, d.TargetRules.Range)
		local hit = sweep(origin, direction * beamRange, state.Character, nil, beam.Width / 2)
		local endpoint = hit and (origin + direction * hit.Distance) or origin + direction * beamRange
		if d.Beam.Pattern == "Cascade" then
			if not hasCapacity(player) then
				feedback(remote, player, "IMPOSSIBLE", d, { Reason = "Too many active spells" })
				return
			end
			local eventState = { HitPart = if hit then hit.Instance else nil }
			emit(d, "OnCast", state.Character, origin, targetFrom(hit), direction, remote, player, nil, eventState)
			local cascade = {
				Kind = "BeamCascade",
				SpellId = d.SpellId,
				Caster = state.Character,
				Definition = d,
				Player = player,
				Remote = remote,
				Center = endpoint,
				Position = endpoint,
				Direction = direction,
				Age = 0,
				StrikeIndex = 1,
				NextInterval = workspace:GetServerTimeNow() + d.Beam.StrikeInterval,
				RemainingLifetime = d.Beam.StrikeInterval * (d.Beam.StrikeCount - 1) + 0.25,
				StartedAt = workspace:GetServerTimeNow(),
				TargetsHit = {},
			}
			resolveBeamCascadeStrike(cascade, 1)
			registerActiveEffect(cascade)
			return
		end
		Presentation.beam(origin, endpoint, beam.Width, d.Visual.Color, d.Beam.DebugDuration, d)
		local targetHit = if hit and hit.Instance == objectTarget
			then objectTargetHit(
				state.Character,
				origin,
				direction,
				math.min(objectTargetRange(d), beamRange),
				objectTarget,
				d
			)
			else nil
		local eventState = {
			HitPart = if not objectTarget and hit then hit.Instance else nil,
			AllowObjectTarget = objectTarget ~= nil and targetHit ~= nil,
			ObjectTarget = objectTarget,
		}
		emit(
			d,
			"OnCast",
			state.Character,
			origin,
			if targetHit then { objectTarget } elseif objectTarget then {} else targetFrom(hit),
			direction,
			remote,
			player,
			nil,
			eventState
		)
		-- An instant Beam always resolves at a server-known endpoint. If nothing
		-- obstructs it, that endpoint is the maximum-range end of the visible Beam;
		-- target-dependent payloads still receive an empty target list there.
		emit(
			d,
			"OnImpact",
			state.Character,
			endpoint,
			if targetHit then { objectTarget } elseif objectTarget then {} else targetFrom(hit),
			direction,
			remote,
			player,
			nil,
			eventState
		)
	end
	formContext.ExecuteWave = function(d)
		local waveDirection = if direction.Magnitude > 0.001 then direction.Unit else state.Root.CFrame.LookVector
		local objectTarget = if d.Targeting == "ObjectTarget"
				and material
				and material:IsA("BasePart")
			then material
			else nil
		local function pulse(eventName: string, age: number)
			local wave = AreaGrowth.area(d.Wave, AreaGrowth.scale(d.Wave, age))
			local waveRange = math.min(wave.Range, d.TargetRules.Range)
			local point = state.Root.Position
			local frame = CFrame.lookAt(point, point + waveDirection)
			local objectHit = objectTargetHit(
				state.Character,
				point + Vector3.new(0, 1.5, 0),
				waveDirection,
				math.min(objectTargetRange(d), waveRange),
				objectTarget,
				d
			)
			local targetRules = {
				OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
				RequireLineOfSight = d.TargetRules.RequiresLineOfSight,
				IncludeAttacker = d.TargetRules.IncludeCaster,
			}
			local targets = if objectTarget
				then if objectHit then { objectTarget } else {}
				elseif d.Geometry == "Sphere" then HitDetection.findSphere(
					state.Character,
					frame,
					waveRange,
					targetRules
				)
				else HitDetection.findCone(state.Character, frame, waveRange, d.Wave.Dot, targetRules)
			local eventState = if objectTarget
				then { AllowObjectTarget = objectHit ~= nil, ObjectTarget = objectTarget }
				else nil
			emit(d, eventName, state.Character, point, targets, waveDirection, remote, player, nil, eventState)
			Presentation.wave(d, frame, waveRange, d.Wave.DebugDuration)
			return targets, point
		end
		local _, point = pulse("OnCast", 0)
		if d.Casting.Mode == "Channeled" then
			local channel = {
				Kind = "WaveChannel",
				SpellId = d.SpellId,
				Caster = state.Character,
				Age = 0,
				CurrentPhase = "Channeling",
				TargetsHit = {},
				StartedAt = workspace:GetServerTimeNow(),
				RemainingLifetime = d.Lifetime.Duration,
				NextInterval = d.Wave.Interval or 0.4,
				Definition = d,
				ObjectTarget = objectTarget,
				Position = point,
				Direction = waveDirection,
				Player = player,
				Remote = remote,
				Visual = nil,
				IsChannel = true,
			}
			channel.AmbientSound = Presentation.attachLoop(d, "AmbientLoopSoundId", state.Root)
			stats.Channel = channel
			registerActiveEffect(channel)
		end
	end
	formContext.CreateField = function(d)
		local point = intent.WorldPoint
		local followPart: BasePart? = nil
		local followTargetModel: Model? = nil
		if d.Targeting == "ObjectTarget" then
			if not objectPosition then
				feedback(remote, player, "IMPOSSIBLE", d, { Reason = "Selected surface is no longer available" })
				return
			end
			point = objectPosition
			if d.Field.FollowTarget and material and material:IsA("BasePart") then
				followPart = material
			end
		end
		if d.Targeting == "EntityTarget" and selectedTarget then
			local targetRoot = selectedTarget:FindFirstChild("HumanoidRootPart")
			if not targetRoot or not targetRoot:IsA("BasePart") then
				feedback(remote, player, "IMPOSSIBLE", d, { Reason = "Field target is no longer available" })
				return
			end
			point = targetRoot.Position
			if d.Field.FollowTarget then
				followTargetModel = selectedTarget
			end
		end
		if d.Field.FollowTarget and not followPart and not followTargetModel then
			feedback(remote, player, "IMPOSSIBLE", d, { Reason = "Field follow target is no longer available" })
			return
		end
		local initialField = AreaGrowth.area(d.Field, AreaGrowth.scale(d.Field, 0))
		local marker = Presentation.areaMarker(
			"MagicFieldDebug",
			CFrame.new(point) * CFrame.Angles(0, math.rad(d.Field.Yaw or 0), 0),
			d.Geometry,
			Geometry.areaSize(d.Geometry, initialField),
			d.Visual.Color,
			d.Field.DebugHeight,
			d
		)
		Presentation.attachLoop(d, "AmbientLoopSoundId", marker)
		local targets = formAreaCandidates(d, state.Character, point, 0)
		local field = {
			Kind = "Field",
			Caster = state.Character,
			Player = player,
			Remote = remote,
			Definition = d,
			FollowTarget = d.Field.FollowTarget == true,
			FollowTargetModel = followTargetModel,
			FollowPart = followPart,
			FollowPartOffset = if followPart then followPart.CFrame:PointToObjectSpace(point) else nil,
			Age = 0,
			CurrentPhase = "Active",
			TargetsHit = {},
			PresentTargets = {},
			StartedAt = os.clock(),
			Position = point,
			Direction = direction,
			RemainingLifetime = configuredLifetime(d),
			NextInterval = 0,
			Visual = marker,
		}
		registerActiveEffect(field)
		formContext.RegisterChannel(field)
		emit(d, "OnCast", state.Character, point, targets, direction, remote, player, nil, field)
		emit(d, "OnSpawn", state.Character, point, targets, direction, remote, player, nil, field)
	end
	formContext.RegisterChannel = function(spell)
		if CastingSpec.isHeldMode(d.Casting.Mode) then
			spell.SpellId = d.SpellId
			spell.IsChannel = true
			stats.Channel = spell
		end
	end
	formContext.ApplySelf = function(d)
		startSelfEnhancement(d, state, direction, remote, player)
		if d.Casting.Mode == "Channeled" then
			local channel = {
				Kind = "SelfEnhancementChannel",
				SpellId = d.SpellId,
				Caster = state.Character,
				State = state,
				Player = player,
				Remote = remote,
				Definition = d,
				Age = 0,
				CurrentPhase = "Channeling",
				TargetsHit = {},
				StartedAt = workspace:GetServerTimeNow(),
				RemainingLifetime = d.Lifetime.Duration,
				Position = state.Root.Position,
				Direction = direction,
				Visual = nil,
				IsChannel = true,
			}
			channel.AmbientSound = enhancements[player][d.SpellId].AmbientSound
			stats.Channel = channel
			registerActiveEffect(channel)
		end
	end
	formContext.ApplyManipulation = function(d)
		local target = if material and material:IsA("BasePart") then material else nil
		local ctx = context(
			d,
			state.Character,
			origin,
			if target then { target } else {},
			direction,
			remote,
			player,
			nil,
			{ AllowObjectTarget = target ~= nil, ObjectTarget = target }
		)
		Triggers.execute(d, "OnCast", ctx)
		if target then
			Presentation.follow(d, target, target.Size, 2)
		end
	end
	formContext.CreateProjectile = function(d)
		-- Begin at the server-known origin so a large projectile cannot skip a nearby wall.
		local start = origin
		if castContext and validVector(intent.WorldPoint) then
			local delta = intent.WorldPoint - start
			if delta.Magnitude > 0.001 then
				direction = delta.Unit
			end
		end
		local targetRoot = selectedTarget and selectedTarget:FindFirstChild("HumanoidRootPart")
		emit(d, "OnCast", state.Character, start, {}, direction, remote, player)
		emit(d, "OnSpawn", state.Character, start, {}, direction, remote, player)
		local projectile = {
			Kind = "Projectile",
			SpellId = d.SpellId,
			Caster = state.Character,
			Age = 0,
			CurrentPhase = "Traveling",
			TargetsHit = {},
			StartedAt = os.clock(),
			RemainingLifetime = configuredLifetime(d),
			Definition = d,
			Position = start,
			Direction = direction,
			Velocity = direction * d.Projectile.Speed,
			Distance = 0,
			HomingTarget = if d.TargetPolicy == "MaintainTarget"
					and targetRoot
					and targetRoot:IsA("BasePart")
				then targetRoot
				else nil,
			FixedTarget = d.TargetPolicy == "MaintainTarget",
			Visual = Presentation.projectile(d, start),
			Player = player,
			Remote = remote,
			ObjectTarget = if d.Targeting == "ObjectTarget"
					and material
					and material:IsA("BasePart")
				then material
				else nil,
			CommandCastId = commandCastId,
		}
		initializeProjectileMotion(projectile, d)
		registerActiveEffect(projectile)
		if d.Casting.Mode == "Channeled" then
			local channel = {
				Kind = "ProjectileChannel",
				SpellId = d.SpellId,
				Caster = state.Character,
				Age = 0,
				CurrentPhase = "Channeling",
				TargetsHit = {},
				StartedAt = workspace:GetServerTimeNow(),
				RemainingLifetime = d.Lifetime.Duration,
				NextInterval = d.Projectile.ChannelInterval or 0.4,
				Definition = d,
				Position = start,
				Direction = direction,
				TargetModel = selectedTarget,
				ObjectTarget = if d.Targeting == "ObjectTarget"
						and material
						and material:IsA("BasePart")
					then material
					else nil,
				Player = player,
				Remote = remote,
				Visual = nil,
				IsChannel = true,
			}
			channel.AmbientSound = Presentation.attachLoop(d, "AmbientLoopSoundId", state.Root)
			stats.Channel = channel
			registerActiveEffect(channel)
		end
		ProjectileBehaviors.spawn(projectile, projectileBehaviorContext(projectile))
	end
	Forms.execute(definition.Form, definition, formContext)
	Telemetry.spellCast(player, definition)
	if CastingSpec.isHeldMode(definition.Casting.Mode) then
		local channel = stats.Channel
		if channel and channel.Caster == state.Character and channel.SpellId == definition.SpellId then
			Presentation.sustain(state.Character, definition)
		end
	end
end
local function castNow(player, state, intent, remote, definition, charge, castContext)
	local result, reason, material, direction, selectedTarget, objectPosition =
		validate(player, state, intent, definition, charge)
	if result == "IMPOSSIBLE" or not direction then
		setCastingMovement(player, state, nil)
		local stats = playerData[player]
		feedback(remote, player, "IMPOSSIBLE", definition, {
			Reason = reason,
			Mana = stats and stats.Mana,
			Capacity = stats and stats.Capacity,
			Strain = stats and stats.Strain,
			StrainTolerance = stats and stats.StrainTolerance,
			ComplexityCapacity = stats and stats.ComplexityCapacity,
		})
		return
	end
	execute(
		player,
		state,
		remote,
		definition,
		intent,
		charge,
		material,
		direction,
		result,
		reason,
		castContext,
		selectedTarget,
		objectPosition
	)
	local stats = playerData[player]
	if not stats or not stats.Channel then
		setCastingMovement(player, state, nil)
	end
end
local function queueCast(player, state, intent, remote, definition, charge, castContext, startPosition: Vector3?)
	local result, reason, _, validatedDirection = validate(player, state, intent, definition, charge)
	if result == "IMPOSSIBLE" then
		setCastingMovement(player, state, nil)
		local stats = playerData[player]
		feedback(remote, player, result, definition, {
			Reason = reason,
			Mana = stats and stats.Mana,
			Capacity = stats and stats.Capacity,
			Strain = stats and stats.Strain,
			StrainTolerance = stats and stats.StrainTolerance,
			ComplexityCapacity = stats and stats.ComplexityCapacity,
		})
		return false, reason
	end
	local timing = Presentation.timing(definition)
	local now = workspace:GetServerTimeNow()
	local windup = definition.Casting.CastTime + timing.Gather
	local releaseAt = now + windup
	local impactAt = releaseAt + timing.Release
	local pendingIntent = Spec.copy(intent)
	if CastingSpec.rotationLocked(definition.Casting) and validatedDirection then
		pendingIntent.AimDirection = validatedDirection
	end
	Presentation.gather(state.Character, definition, windup + timing.Release + timing.Recovery, windup)
	playerData[player].Pending = {
		At = impactAt,
		ReleaseAt = releaseAt,
		Released = false,
		State = state,
		Intent = pendingIntent,
		Remote = remote,
		Definition = definition,
		Charge = charge,
		Context = castContext,
		StartPosition = startPosition or state.Root.Position,
	}
	setCastingMovement(player, state, definition, validatedDirection)
	feedback(remote, player, "CHARGING", definition, { Reason = "Gathering · server-timed release" })
	return true, nil
end

local function movementInterrupted(windup): boolean
	local root = windup.State.Root
	return root.Parent ~= nil
		and CastInterruption.movement(windup.Definition.Casting, (root.Position - windup.StartPosition).Magnitude)
end

function Magic.start(player, state, intent, remote, castContext, temporaryDefinition): (boolean, string?)
	castStates[player] = state
	local definition = temporaryDefinition or getDefinition(intent.SpellId)
	local stats = playerData[player]
	if not definition or not stats then
		feedback(remote, player, "IMPOSSIBLE", nil, { Reason = "Unknown spell" })
		return false, "Unknown spell or unavailable Locus resources"
	end
	if stats.PersistentConstructCastInProgress then
		local reason = "A Persistent Construct save is already in progress"
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = reason })
		return false, reason
	end
	if definition.Casting.Mode == "CommandCast" and (not castContext or castContext.CommandCast ~= true) then
		feedback(remote, player, "IMPOSSIBLE", definition, {
			Reason = "CommandCast spells must be assigned to a summon and activated with Attack or Support",
		})
		return false, "CommandCast requires an owner-issued summon order"
	end
	if stats.ResourceProfileReady == false then
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Locus resources are still loading" })
		return false, "Locus resources are still loading"
	end
	local effects = enhancements[player]
	if definition.Lifetime.Mode == "UntilToggledOff" then
		if definition.Form == "SelfEnhancement" and effects and effects[definition.SpellId] then
			local effect = effects[definition.SpellId]
			expireSelfEnhancement(player, effect)
			Presentation.stopSound(effect.AmbientSound)
			effects[definition.SpellId] = nil
			updateEnhancement(player, state)
			feedback(remote, player, "OFF", definition, nil)
			return true
		elseif stopToggledEffect(player, state.Character, definition) then
			feedback(remote, player, "OFF", definition, nil)
			return true
		end
	end
	local now = workspace:GetServerTimeNow()
	if stats.Pending or stats.Channel or isSpellCooling(stats, definition.SpellId, now) then
		local reason = if stats.Pending
			then "Owner is already completing another cast"
			elseif stats.Channel then "Owner has another active channel"
			else "Spell is cooling down"
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = reason })
		return false, reason
	end
	if CastingSpec.isChargeMode(definition.Casting.Mode) then
		if stats.Charge then
			return false, "Owner is already charging another spell"
		end
		local chargeResult, chargeReason, _, chargeDirection = validate(player, state, intent, definition, 0)
		if chargeResult == "IMPOSSIBLE" or not chargeDirection then
			feedback(remote, player, "IMPOSSIBLE", definition, { Reason = chargeReason })
			return false, chargeReason
		end
		local chargeIntent = Spec.copy(intent)
		chargeIntent.AimDirection = chargeDirection
		stats.Charge = {
			SpellId = definition.SpellId,
			Definition = definition,
			Character = state.Character,
			BeganAt = now,
			State = state,
			Intent = chargeIntent,
			AimDirection = chargeDirection,
			Remote = remote,
			Context = castContext,
			StartPosition = state.Root.Position,
		}
		Presentation.gather(
			state.Character,
			definition,
			definition.Casting.MaximumCharge,
			definition.Casting.MaximumCharge,
			"Charge"
		)
		feedback(remote, player, "CHARGING", definition, nil)
		setCastingMovement(player, state, definition, chargeDirection)
		return true
	end
	return queueCast(player, state, intent, remote, definition, 0, castContext)
end

local function expireConstruct(spell)
	local target = spell.AttachedHumanoid
	local targets = if target and target.Health > 0 and target.Parent then { target } else {}
	emitExpiry(spell, spell.Position or spell.Caster:GetPivot().Position, targets, nil)
end

finishBeamChannel = function(channel)
	-- Expiration triggers run after maintenance has ended.
	channel.IsChannel = false
	local definition = channel.Definition
	if channel.Kind == "Field" or channel.Kind == "Aura" then
		local targets = formAreaTargets(channel, channel.Position)
		updateAreaMembership(channel, targets)
		emitExpiry(channel, channel.Position, targets)
		closeAreaMembership(channel)
	elseif channel.Kind == "SelfEnhancementChannel" then
		local effects = enhancements[channel.Player]
		local effect = effects and effects[channel.SpellId]
		if effect then
			expireSelfEnhancement(channel.Player, effect)
		elseif definition then
			emitExpiry(channel, channel.Position, { channel.State.Humanoid })
		end
	elseif channel.Kind == "Construct" then
		expireConstruct(channel)
	elseif definition then
		local position, targets = finalChannelTargets(channel)
		emitExpiry(channel, position, targets)
		channel.AllowObjectTarget = nil
	end
	local stats = playerData[channel.Player]
	if stats and stats.Channel == channel then
		stats.Channel = nil
	end
	if channel.Kind == "SelfEnhancementChannel" then
		local effects = enhancements[channel.Player]
		if effects and effects[channel.SpellId] then
			effects[channel.SpellId] = nil
			updateEnhancement(channel.Player, channel.State)
		end
	end
	if channel.Visual then
		Presentation.finish(channel.Visual)
	end
	Presentation.cancel(channel.Caster, definition)
	Presentation.stopSound(channel.AmbientSound)
	setCastingMovement(channel.Player, channel.State, nil)
end

function Magic.release(player, state, intent, remote)
	local stats = playerData[player]
	local spellId = intent and intent.SpellId
	local pending = stats and stats.Pending
	if
		pending
		and CastingSpec.isHeldMode(pending.Definition.Casting.Mode)
		and spellId == pending.Definition.SpellId
	then
		setCastingMovement(player, pending.State, nil)
		Presentation.cancel(pending.State.Character, pending.Definition)
		stats.Pending = nil
		return
	end
	local channel = stats and stats.Channel
	if channel and spellId == channel.SpellId then
		for index = #active, 1, -1 do
			if active[index] == channel then
				finishBeamChannel(channel)
				table.remove(active, index)
				break
			end
		end
		feedback(remote, player, "OFF", channel.Definition, nil)
		return
	end
	local charge = stats and stats.Charge
	if not charge or not intent or intent.SpellId ~= charge.SpellId or state.Character ~= charge.Character then
		return
	end
	stats.Charge = nil
	local definition = charge.Definition
	if not definition then
		setCastingMovement(player, charge.State, nil)
		return
	end
	local elapsed = math.clamp(workspace:GetServerTimeNow() - charge.BeganAt, 0, definition.Casting.MaximumCharge)
	if elapsed < definition.Casting.MinimumCharge then
		setCastingMovement(player, state, nil)
		Presentation.cancel(state.Character, definition)
		feedback(remote, player, "IMPOSSIBLE", definition, { Reason = "Charge was released too early" })
		return
	end
	local releaseIntent = if CastingSpec.rotationLocked(definition.Casting) then charge.Intent else intent
	queueCast(player, state, releaseIntent, remote, definition, elapsed, nil, charge.StartPosition)
end

function Magic.updateAim(player, state, intent): boolean
	local stats = playerData[player]
	local channel = stats and stats.Channel
	local direction = intent and intent.AimDirection
	local expectedKind = if channel
			and channel.Definition
			and channel.Definition.Form == "Projectile"
		then "ProjectileChannel"
		else "BeamChannel"
	if
		not intent
		or not state
		or state.MagicRotationLocked == true
		or not channel
		or not channel.IsChannel
		or channel.Kind ~= expectedKind
		or channel.Player ~= player
		or channel.Caster ~= state.Character
		or channel.SpellId ~= intent.SpellId
		or not channel.Definition
		or CastingSpec.rotationLocked(channel.Definition.Casting)
		or not CastingSpec.supportsAimUpdate(channel.Definition.Form, channel.Definition.Casting.Mode)
		or not validVector(direction)
	then
		return false
	end
	local magnitude = direction.Magnitude
	if magnitude < 0.9 or magnitude > 1.1 then
		return false
	end
	channel.Direction = direction.Unit
	channel.AimPoint = nil
	if channel.Kind == "BeamChannel" and validVector(intent.WorldPoint) then
		local delta = intent.WorldPoint - (state.Root.Position + Vector3.new(0, 1.5, 0))
		if delta.Magnitude > 0.001 and direction.Unit:Dot(delta.Unit) >= Sandbox.Magic.MinimumWorldAimDot then
			channel.AimPoint = intent.WorldPoint
		end
	end
	return true
end

function Magic.clearTemporary(player, state, spellId)
	local stats = playerData[player]
	if stats and stats.Pending and stats.Pending.Definition.SpellId == spellId then
		local pending = stats.Pending
		stats.Pending = nil
		setCastingMovement(player, pending.State, nil)
		Presentation.cancel(pending.State.Character, pending.Definition)
	end
	if stats and stats.Charge and stats.Charge.Definition.SpellId == spellId then
		local charge = stats.Charge
		stats.Charge = nil
		setCastingMovement(player, charge.State, nil)
		Presentation.cancel(charge.State.Character, charge.Definition)
	end
	for index = #active, 1, -1 do
		local spell = active[index]
		if spell.Player ~= player or spell.SpellId ~= spellId then
			continue
		end
		local lifetimeMode = spell.Definition.Lifetime.Mode
		if spell.IsChannel then
			finishBeamChannel(spell)
		elseif
			(spell.Kind == "Field" or spell.Kind == "Aura" or spell.Kind == "Construct")
			and lifetimeMode ~= "FixedDuration"
		then
			if spell.Kind == "Field" or spell.Kind == "Aura" then
				finishInterruptedArea(spell)
			else
				expireConstruct(spell)
				Presentation.finish(spell.Visual)
			end
		else
			continue
		end
		if spell.LingerVisual then
			Presentation.finish(spell.LingerVisual)
		end
		table.remove(active, index)
	end
	local playerEnhancements = enhancements[player]
	local effect = playerEnhancements and playerEnhancements[spellId]
	if effect then
		expireSelfEnhancement(player, effect)
		Presentation.stopSound(effect.AmbientSound)
		playerEnhancements[spellId] = nil
		updateEnhancement(player, state or effect.State)
	end
	-- Expiry triggers can create summons, so dismiss after all old-definition
	-- callbacks have run.
	Summons.clearSpell(player, spellId)
end

local function summonSpellProfile(definition): (any?, string?)
	if not definition then
		return nil, "No spell assigned"
	end
	local profile, reason = CompanionSpellPolicy.classify(definition)
	if not profile then
		return nil, reason
	end
	if definition.Conditions.Operator then
		local function containsForbidden(node)
			if node.Operator == "ALL" or node.Operator == "ANY" or node.Operator == "NOT" then
				for _, child in ipairs(node.Conditions) do
					if containsForbidden(child) then
						return true
					end
				end
				return false
			end
			return (node.Family == "Caster" or node.Family == "Environment") and node.Property == "OnGround"
				or node.Family == "Relationship" and node.Property == "IsSelf"
		end
		if containsForbidden(definition.Conditions) then
			return nil, "Companion spells cannot depend on caster-grounded or self-target conditions"
		end
	else
		for _, condition in ipairs(definition.Conditions) do
			if condition == "OnGround" or condition == "TargetIsSelf" then
				return nil, "Companion spells cannot depend on caster-grounded or self-target conditions"
			end
		end
	end
	return profile, nil
end

local function isHostileSummonTarget(target: Model): boolean
	return CollectionService:HasTag(target, "Enfleshed") or CollectionService:HasTag(target, "MagicHostileTarget")
end

function Magic.setCompanionSpell(player: Player, slot: number, definition: any)
	companionSpells[player] = companionSpells[player] or {}
	companionSpells[player][slot] = Spec.copy(definition)
end

function Magic.getCompanionSpellProfile(player: Player, slot: number): (any?, string?)
	return summonSpellProfile(companionSpells[player] and companionSpells[player][slot])
end

function Magic.executeSummonCommand(
	player: Player,
	caster: Model,
	definition: any,
	remote: RemoteEvent,
	direction: Vector3,
	potency: number,
	command: string,
	targets: { Humanoid }
)
	if
		player.Character ~= caster
		or not hasEvent(definition, "OnCommand")
		or not table.find(Spec.Schema.CommandOrder, command)
	then
		return
	end
	local root = caster:FindFirstChild("HumanoidRootPart")
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	emit(definition, "OnCommand", caster, root.Position, targets, direction, remote, player, potency, {
		Age = 0,
		CurrentPhase = "Command",
		TargetsHit = {},
		StartedAt = workspace:GetServerTimeNow(),
		EventDepth = 0,
		EventName = "OnCommand",
		Command = command,
	})
end

function Magic.castSummonSpell(
	player: Player,
	caster: Model,
	slot: number,
	summonId: number,
	target: Model,
	remote: RemoteEvent
): (boolean, number, boolean, string?, number?)
	local definition = companionSpells[player] and companionSpells[player][slot]
	local profile, profileReason
	if definition then
		profile, profileReason = summonSpellProfile(definition)
	else
		profileReason = "No spell assigned"
	end
	if not definition or not profile then
		return false, 0, false, profileReason or "Assigned spell is not valid for companions"
	end
	local spellAllowed, disabledReason = FeatureFlags.spellAllowed(definition)
	if not spellAllowed then
		return false, 0, false, disabledReason
	end
	if caster:GetAttribute("MagicSummonOwnerUserId") ~= player.UserId then
		return false, 0, false, "Summon belongs to another player"
	end
	if profile.Mode == "Hostile" and not isHostileSummonTarget(target) then
		return false, 0, false, "Target is not hostile"
	end
	if profile.Mode == "Ally" and not Conditions.relationshipMatches(caster, target, "Ally") then
		return false, 0, false, "Target is not an ally"
	end
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local root = caster:FindFirstChild("HumanoidRootPart")
	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if
		not humanoid
		or humanoid.Health <= 0
		or not root
		or not root:IsA("BasePart")
		or not targetHumanoid
		or targetHumanoid.Health <= 0
		or not targetRoot
		or not targetRoot:IsA("BasePart")
	then
		return false, 0, false, "Summon or target is no longer alive"
	end
	local stats = playerData[player]
	local spellId = string.format("Summon_%d_Slot_%d", summonId, slot)
	local cooldown = math.max(definition.Casting.Cooldown, definition.Casting.RecoveryTime, 0.2)
	if not stats then
		return false, cooldown, true, "Owner Locus resources are unavailable"
	end
	if stats.Pending then
		return false, cooldown, true, "Owner is already completing another cast"
	end
	if stats.Channel then
		return false, cooldown, true, "Owner has another active channel"
	end
	if
		CompanionSpellPolicy.requiresCommandSlot(definition)
		and not CommandSpec.canStartActiveCommand(active, player, SummonConfiguration.MaxActiveCommands)
	then
		return false, cooldown, true, "Owner already has an active CommandCast spell"
	end
	local now = workspace:GetServerTimeNow()
	if isSpellCooling(stats, spellId, now) then
		return false, cooldown, true, "Companion spell is cooling down"
	end
	local point = targetRoot.Position
	local core = caster:FindFirstChild("WispCore")
	local origin = if core and core:IsA("BasePart") then core.Position else root.Position
	local delta = point - origin
	if delta.Magnitude < 0.001 or delta.Magnitude > definition.TargetRules.Range then
		return false, cooldown, true, "Target is outside assigned spell range"
	end
	local summonDefinition = CompanionSpellPolicy.executionDefinition(Spec.copy(definition), spellId)
	local state: State = { Character = caster, Humanoid = humanoid, Root = root }
	local commandId: number? = nil
	if CompanionSpellPolicy.requiresCommandSlot(definition) then
		nextCommandCastId += 1
		commandId = nextCommandCastId
	end
	local intent = {
		SpellId = spellId,
		-- Companions have no camera input. Their server-selected target supplies both
		-- the aim vector and world point used by the ordinary Form executor.
		AimDirection = delta.Unit,
		WorldPoint = point,
		TargetModel = target,
		CastOrigin = origin,
	}
	local started, reason = Magic.start(player, state, intent, remote, {
		Origin = origin,
		CommandCast = definition.Casting.Mode == "CommandCast",
		CommandId = commandId,
	}, summonDefinition)
	local timing = Presentation.timing(definition)
	local castDuration = CompanionSpellPolicy.castLockDuration(definition, timing.Gather, timing.Release)
	return started == true, cooldown, true, reason, if started then castDuration else nil
end

local function clearActive(player)
	for i = #active, 1, -1 do
		if active[i].Player == player then
			if active[i].IsChannel then
				finishBeamChannel(active[i])
			elseif active[i].Kind == "Field" or active[i].Kind == "Aura" then
				finishInterruptedArea(active[i])
			elseif active[i].Kind == "ProjectileLinger" then
				local spell = active[i]
				expireProjectile(spell)
				Presentation.finish(spell.Visual)
			elseif active[i].Kind == "Projectile" then
				local spell = active[i]
				expireProjectile(spell)
				Presentation.finish(spell.Visual)
			elseif active[i].Kind == "Construct" then
				local spell = active[i]
				expireConstruct(spell)
				Presentation.finish(spell.Visual)
			elseif active[i].Visual then
				Presentation.finish(active[i].Visual)
			end
			if active[i].LingerVisual then
				Presentation.finish(active[i].LingerVisual)
			end
			table.remove(active, i)
		end
	end
end

-- Mana, Strain and special resources live only for this server session and start from
-- the fixed Locus profile. (Cross-session Locus persistence was removed.)
function Magic.bind(player)
	if playerData[player] then
		return
	end
	local state = LocusModel.newState(LocusProfile, ResourceBalance.StartingMana)
	state.SpecialResources = SpecialResourceSpec.defaults(SpecialResourceDefinitions)
	state.Strain = 0
	state.ResourceProfileReady = true
	state.Ready = {}
	playerData[player] = state
	syncSpecialResourceAttributes(player)
	syncHUDResourceAttributes(player, state)
end
function Magic.reset(player)
	clearActive(player)
	for _, effect in enhancements[player] or {} do
		expireSelfEnhancement(player, effect)
		Presentation.stopSound(effect.AmbientSound)
		Movement.setMagicEnhancement(effect.State, 0, 0, 1)
		Movement.setMagicAerial(effect.State, 0)
	end
	enhancements[player] = nil
	-- Active spell and Self Enhancement expiry triggers can contain Summon
	-- payloads, so dismiss groups after every final event has run.
	Summons.clearOwner(player)
	local old = playerData[player]
	if old then
		if old.Charge then
			setCastingMovement(player, old.Charge.State, nil)
			Presentation.cancel(old.Charge.Character, old.Charge.Definition)
		end
		if old.Pending then
			setCastingMovement(player, old.Pending.State, nil)
			Presentation.cancel(old.Pending.State.Character, old.Pending.Definition)
		end
	end
	if old then
		local profile = {
			Capacity = old.Capacity,
			Efficiency = old.Efficiency,
			Potency = old.Potency,
			StrainTolerance = old.StrainTolerance,
			ComplexityCapacity = old.ComplexityCapacity,
		}
		local state = LocusModel.newState(profile, old.Mana)
		state.Strain = old.Strain
		state.SpecialResources = SpecialResourceSpec.mergeCurrent(old.SpecialResources, SpecialResourceDefinitions)
		state.ResourceProfileReady = old.ResourceProfileReady
		state.Ready = {}
		playerData[player] = state
		syncSpecialResourceAttributes(player)
	end
end
-- Explicit development command; does not change normal cast resource rules.
function Magic.restoreTestingResources(player)
	if not game:GetService("RunService"):IsStudio() then
		return false
	end
	local stats = playerData[player]
	if not stats or not stats.ResourceProfileReady then
		return false
	end
	stats.Mana, stats.Strain = stats.Capacity, 0
	for id, definition in pairs(SpecialResourceDefinitions) do
		if type(definition) == "table" and definition.Capacity then
			stats.SpecialResources[id] = definition.Capacity
		end
	end
	syncSpecialResourceAttributes(player)
	return true
end
function Magic.remove(player)
	Magic.reset(player)
	playerData[player] = nil
	companionSpells[player] = nil
end

local loadPublishedAt = 0
RunService.Heartbeat:Connect(function(delta)
	serverFrameMs = LoadBudget.smooth(serverFrameMs, delta)
	if os.clock() - loadPublishedAt >= 0.25 then
		-- Profiling aid: watch these on Workspace in a server view or the Developer Console.
		loadPublishedAt = os.clock()
		workspace:SetAttribute("MagicLoad", math.floor(activeLoad() * 10) / 10)
		workspace:SetAttribute("MagicLoadLimit", math.floor(LoadBudget.allowed(serverFrameMs)))
		workspace:SetAttribute("ServerFrameMs", math.floor(serverFrameMs * 10) / 10)
		workspace:SetAttribute("MagicActiveCount", #active)
	end
	local now = workspace:GetServerTimeNow()
	for player, stats in playerData do
		local hudSyncAt = stats.HUDSyncAt or 0
		if now - hudSyncAt >= 0.25 then
			stats.HUDSyncAt = now
			syncHUDResourceAttributes(player, stats)
		end
		for spellId, cooldown in stats.Ready do
			if type(cooldown) == "number" then
				stats.Ready[spellId] = { Remaining = math.max(0, cooldown - now), Caster = nil }
				cooldown = stats.Ready[spellId]
			end
			if type(cooldown) == "table" then
				local casterHumanoid = cooldown.Caster
				local timeRate = if casterHumanoid and casterHumanoid.Parent
					then StatusEffects.timeRate(casterHumanoid)
					else 1
				cooldown.Remaining = TemporalRate.advance(cooldown.Remaining, delta, timeRate)
				if cooldown.Remaining <= 0 then
					stats.Ready[spellId] = nil
				end
			end
		end
		local manaBefore, strainBefore = stats.Mana, stats.Strain
		LocusModel.advance(
			stats,
			delta,
			ResourceBalance.ManaRegenerationPerSecond,
			ResourceBalance.StrainRecoveryPerSecond
		)
		local specialResourcesChanged =
			SpecialResourceSpec.advance(stats.SpecialResources, SpecialResourceDefinitions, delta)
		if specialResourcesChanged then
			syncSpecialResourceAttributes(player)
		end
		local charge = stats.Charge
		if charge and movementInterrupted(charge) then
			stats.Charge = nil
			setCastingMovement(player, charge.State, nil)
			Presentation.cancel(charge.State.Character, charge.Definition)
			feedback(charge.Remote, player, "IMPOSSIBLE", charge.Definition, {
				Reason = "Cast interrupted by movement",
			})
			charge = nil
		end
		if
			charge
			and CompanionSpellPolicy.autoReleasesAtFullCharge(
				charge.Definition,
				charge.Context and charge.Context.CommandCast == true
			)
			and now - charge.BeganAt >= charge.Definition.Casting.MaximumCharge
		then
			stats.Charge = nil
			queueCast(
				player,
				charge.State,
				charge.Intent,
				charge.Remote,
				charge.Definition,
				charge.Definition.Casting.MaximumCharge,
				charge.Context,
				charge.StartPosition
			)
		elseif
			charge
			and charge.Definition.Casting.Mode == "HoldAndRelease"
			and now - charge.BeganAt >= charge.Definition.Casting.MaximumCharge + Limits.MaxChargeReadyHoldSeconds
		then
			stats.Charge = nil
			setCastingMovement(player, charge.State, nil)
			Presentation.cancel(charge.State.Character, charge.Definition)
			feedback(charge.Remote, player, "IMPOSSIBLE", charge.Definition, {
				Reason = "Prepared cast expired before release",
			})
		end
		local pending = stats.Pending
		if pending then
			local pendingCaster = pending.State.Character
			local isPlayerCharacter = pendingCaster == player.Character
			local isOwnedSummon = pendingCaster:GetAttribute("MagicSummonOwnerUserId") == player.UserId
				and pendingCaster:IsDescendantOf(workspace)
			if (not isPlayerCharacter and not isOwnedSummon) or pending.State.Humanoid.Health <= 0 then
				stats.Pending = nil
				setCastingMovement(player, pending.State, nil)
				Presentation.cancel(pending.State.Character, pending.Definition)
			elseif movementInterrupted(pending) then
				stats.Pending = nil
				setCastingMovement(player, pending.State, nil)
				Presentation.cancel(pending.State.Character, pending.Definition)
				feedback(pending.Remote, player, "IMPOSSIBLE", pending.Definition, {
					Reason = "Cast interrupted by movement",
				})
			else
				if not pending.Released and now >= pending.ReleaseAt then
					pending.Released = true
					Presentation.release(pending.State.Character, pending.Definition)
				end
				if now >= pending.At then
					stats.Pending = nil
					castNow(
						player,
						pending.State,
						pending.Intent,
						pending.Remote,
						pending.Definition,
						pending.Charge or 0,
						pending.Context
					)
				end
			end
		end
	end
	for i = #active, 1, -1 do
		local spell = active[i]
		local d = spell.Definition
		if spell.AbsorbedBy then
			emitExpiry(spell, spell.Position, {})
			Presentation.finish(spell.Visual)
			if spell.LingerVisual then
				Presentation.finish(spell.LingerVisual)
			end
			table.remove(active, i)
			continue
		end
		local humanoid = spell.Caster:FindFirstChildOfClass("Humanoid")
		local playerCaster = spell.Player.Character == spell.Caster
		local ownedSummon = spell.Caster:GetAttribute("MagicSummonOwnerUserId") == spell.Player.UserId
		if
			(not playerCaster and not ownedSummon)
			or not spell.Caster:IsDescendantOf(workspace)
			or not humanoid
			or humanoid.Health <= 0
		then
			if humanoid and humanoid.Health <= 0 and hasEvent(d, "OnCasterDeath") then
				spell.CurrentPhase = "CasterDeath"
				if spell.Kind == "SelfEnhancementChannel" then
					local effects = enhancements[spell.Player]
					local effect = effects and effects[spell.SpellId]
					if effect then
						effect.CasterDeathEventFired = true
					end
				end
				emit(
					d,
					"OnCasterDeath",
					spell.Caster,
					spell.Position or spell.Caster:GetPivot().Position,
					{ humanoid },
					spell.Direction or Vector3.zero,
					spell.Remote,
					spell.Player,
					nil,
					lifecycleState(spell, "OnCasterDeath", spell.EventDepth or 0)
				)
			end
			if spell.IsChannel then
				finishBeamChannel(spell)
			elseif spell.Kind == "Field" or spell.Kind == "Aura" then
				finishInterruptedArea(spell)
			elseif spell.Kind == "Construct" then
				expireConstruct(spell)
				if spell.Visual then
					Presentation.finish(spell.Visual)
				end
			elseif spell.Kind == "Projectile" or spell.Kind == "ProjectileLinger" then
				expireProjectile(spell)
				if spell.Visual then
					Presentation.finish(spell.Visual)
				end
			elseif spell.Visual then
				Presentation.finish(spell.Visual)
			end
			if spell.LingerVisual then
				Presentation.finish(spell.LingerVisual)
			end
			table.remove(active, i)
			continue
		end
		local step = if spell.Kind == "BeamCascade" then delta else math.min(delta, spell.RemainingLifetime)
		spell.Age += step
		local stats = playerData[spell.Player]
		if d.Casting.RequiresFreeHand and spell.IsChannel and Equipment.freeHandCount(spell.Player) < 1 then
			spell.ResourceEnded = true
			spell.RemainingLifetime = 0
			feedback(spell.Remote, spell.Player, "EXPIRED", d, {
				Reason = "Channel ended · no free hand available",
			})
		end
		local manaRate = d.Casting.ManaUpkeepPerSecond or 0
		local strainRate = d.Casting.StrainPerSecond or 0
		local paid = true
		if manaRate > 0 or strainRate > 0 then
			paid = stats ~= nil and LocusModel.upkeep(stats, manaRate, strainRate, step)
		end
		-- Exact depletion is also exhaustion even when the final payment was fully covered.
		if not paid or (stats and manaRate > 0 and stats.Mana <= 0) then
			spell.ResourceEnded = true
			spell.RemainingLifetime = 0
			feedback(spell.Remote, spell.Player, "EXPIRED", d, {
				Reason = if stats and stats.Mana <= 0
					then "Active spell ended · mana depleted"
					else "Active spell ended · ongoing Locus resources depleted",
				Mana = stats and stats.Mana,
				Capacity = stats and stats.Capacity,
				Strain = stats and stats.Strain,
				StrainTolerance = stats and stats.StrainTolerance,
			})
		end
		if not spell.ResourceEnded and spell.Kind ~= "BeamCascade" then
			spell.RemainingLifetime -= delta
		end
		if not spell.EndConditionEnded and Conditions.endWhen(d, spell, stats) then
			spell.EndConditionEnded = true
			spell.RemainingLifetime = 0
		end
		if spell.Kind == "SelfEnhancementChannel" then
			if spell.RemainingLifetime <= 0 then
				finishBeamChannel(spell)
				if not spell.ResourceEnded then
					feedback(spell.Remote, spell.Player, "EXPIRED", d, {
						Reason = if not stats or stats.Mana <= 0
							then "Self Enhancement ended · mana depleted"
							else "Self Enhancement channel limit reached",
					})
				end
				table.remove(active, i)
			end
		elseif spell.Kind == "BeamCascade" then
			if not stats or spell.StrikeIndex >= d.Beam.StrikeCount then
				table.remove(active, i)
			elseif now >= spell.NextInterval then
				spell.StrikeIndex += 1
				spell.NextInterval = now + d.Beam.StrikeInterval
				resolveBeamCascadeStrike(spell, spell.StrikeIndex)
				if spell.StrikeIndex >= d.Beam.StrikeCount then
					table.remove(active, i)
				end
			end
		elseif spell.Kind == "BeamChannel" then
			local ended = not stats or stats.Mana <= 0 or spell.RemainingLifetime <= 0
			if not ended and now >= spell.NextInterval then
				spell.NextInterval = now + (d.Beam.Interval or 0.15)
				local root = spell.Caster:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local beam = AreaGrowth.area(d.Beam, AreaGrowth.scale(d.Beam, spell.Age))
					local beamRange = math.min(beam.Range, d.TargetRules.Range)
					spell.Position = Presentation.handOrigin(spell.Caster, root.Position + Vector3.new(0, 1.5, 0))
					spell.Direction = BeamAim.direction(spell.Position, spell.Direction, spell.AimPoint)
					local hit = sweep(spell.Position, spell.Direction * beamRange, spell.Caster, nil, beam.Width / 2)
					local endpoint = hit and (spell.Position + spell.Direction * hit.Distance)
						or spell.Position + spell.Direction * beamRange
					spell.Visual = Presentation.beam(
						spell.Position,
						endpoint,
						beam.Width,
						d.Visual.Color,
						math.max(d.Beam.DebugDuration, d.Beam.Interval * 1.5),
						d,
						spell.Visual,
						true
					)
					local targetHit = if hit and hit.Instance == spell.ObjectTarget
						then objectTargetHit(
							spell.Caster,
							spell.Position,
							spell.Direction,
							math.min(objectTargetRange(d), beamRange),
							spell.ObjectTarget,
							d
						)
						else nil
					spell.AllowObjectTarget = targetHit ~= nil
					spell.HitPart = if not spell.ObjectTarget and hit then hit.Instance else nil
					emit(
						d,
						"OnTick",
						spell.Caster,
						spell.Position,
						if spell.ObjectTarget then if targetHit then { spell.ObjectTarget } else {} else targetFrom(hit),
						spell.Direction,
						spell.Remote,
						spell.Player,
						nil,
						spell
					)
					if hit then
						emit(
							d,
							"OnImpact",
							spell.Caster,
							endpoint,
							if spell.ObjectTarget
								then if targetHit then { spell.ObjectTarget } else {}
								else targetFrom(hit),
							spell.Direction,
							spell.Remote,
							spell.Player,
							nil,
							spell
						)
					end
					spell.HitPart = nil
					spell.AllowObjectTarget = nil
				else
					ended = true
				end
			end
			if ended then
				finishBeamChannel(spell)
				if not spell.ResourceEnded then
					feedback(spell.Remote, spell.Player, "EXPIRED", d, {
						Reason = if not stats or stats.Mana <= 0
							then "Channel ended · mana depleted"
							else "Channel limit reached",
					})
				end
				table.remove(active, i)
			end
		elseif spell.Kind == "ProjectileChannel" then
			local ended = not stats or stats.Mana <= 0 or spell.RemainingLifetime <= 0
			if not ended and now >= spell.NextInterval then
				spell.NextInterval = now + (d.Projectile.ChannelInterval or 0.4)
				spawnChannelProjectile(spell)
			end
			if ended then
				finishBeamChannel(spell)
				if not spell.ResourceEnded then
					feedback(spell.Remote, spell.Player, "EXPIRED", d, {
						Reason = if not stats or stats.Mana <= 0
							then "Projectile channel ended · mana depleted"
							else "Projectile channel limit reached",
					})
				end
				table.remove(active, i)
			end
		elseif spell.Kind == "WaveChannel" then
			local ended = not stats or stats.Mana <= 0 or spell.RemainingLifetime <= 0
			if not ended and now >= spell.NextInterval then
				spell.NextInterval = now + (d.Wave.Interval or 0.4)
				local root = spell.Caster:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local wave = AreaGrowth.area(d.Wave, AreaGrowth.scale(d.Wave, spell.Age))
					local waveRange = math.min(wave.Range, d.TargetRules.Range)
					spell.Position = root.Position
					local frame = CFrame.lookAt(spell.Position, spell.Position + spell.Direction)
					local objectHit = objectTargetHit(
						spell.Caster,
						spell.Position + Vector3.new(0, 1.5, 0),
						spell.Direction,
						math.min(objectTargetRange(d), waveRange),
						spell.ObjectTarget,
						d
					)
					local targetRules = {
						OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
						RequireLineOfSight = d.TargetRules.RequiresLineOfSight,
						IncludeAttacker = d.TargetRules.IncludeCaster,
					}
					local targets = if spell.ObjectTarget
						then if objectHit then { spell.ObjectTarget } else {}
						elseif d.Geometry == "Sphere" then HitDetection.findSphere(
							spell.Caster,
							frame,
							waveRange,
							targetRules
						)
						else HitDetection.findCone(spell.Caster, frame, waveRange, d.Wave.Dot, targetRules)
					Presentation.wave(d, frame, waveRange, d.Wave.DebugDuration)
					spell.AllowObjectTarget = objectHit ~= nil
					emit(
						d,
						"OnTick",
						spell.Caster,
						spell.Position,
						targets,
						spell.Direction,
						spell.Remote,
						spell.Player,
						nil,
						spell
					)
					spell.AllowObjectTarget = nil
				else
					ended = true
				end
			end
			if ended then
				finishBeamChannel(spell)
				if not spell.ResourceEnded then
					feedback(spell.Remote, spell.Player, "EXPIRED", d, {
						Reason = if not stats or stats.Mana <= 0
							then "Wave channel ended · mana depleted"
							else "Wave channel limit reached",
					})
				end
				table.remove(active, i)
			end
		elseif spell.Kind == "Construct" then
			local attachment = spell.Attachment
			local gone = not spell.Visual:IsDescendantOf(workspace)
				or (attachment ~= nil and not attachment:IsDescendantOf(workspace))
			local dead = spell.AttachedHumanoid and spell.AttachedHumanoid.Health <= 0
			local hasConstructPart = false
			for part in spell.ComponentLifetimes or {} do
				if part.Parent == nil or not part:IsDescendantOf(spell.Visual) then
					spell.ComponentLifetimes[part] = nil
				end
			end
			for _, part in spell.Visual:GetChildren() do
				if part:IsA("BasePart") and string.sub(part.Name, 1, 13) == "ConstructPart" then
					local componentDuration = spell.ComponentLifetimes and spell.ComponentLifetimes[part]
					if componentDuration and spell.Age >= componentDuration then
						if spell.ComponentLifetimes then
							spell.ComponentLifetimes[part] = nil
						end
						part:Destroy()
					else
						hasConstructPart = true
					end
				end
			end
			if not hasConstructPart then
				spell.RemainingLifetime = 0
			end
			if spell.GrowthEnabled and not gone and not dead then
				spell.GrowthCheckAccumulator += step
				if attachment and spell.AttachmentPoint and spell.AttachmentNormal and spell.AttachmentRotation then
					local contactPoint = attachment.CFrame:PointToWorldSpace(spell.AttachmentPoint)
					local normal = attachment.CFrame:VectorToWorldSpace(spell.AttachmentNormal).Unit
					local rotation = attachment.CFrame.Rotation * spell.AttachmentRotation
					spell.GrowthAnchorPoint, spell.GrowthAnchorNormal, spell.GrowthAnchorRotation =
						contactPoint, normal, rotation
				end
				local anchorPoint = spell.GrowthAnchorPoint or spell.AnchorPoint
				local anchorNormal = spell.GrowthAnchorNormal or spell.AnchorNormal
				local anchorRotation = spell.GrowthAnchorRotation or spell.Visual:GetPivot().Rotation
				local function frameForScale(scale)
					local size = spell.BaseSize * scale
					if not anchorPoint or not anchorNormal then
						return CFrame.new(spell.Visual:GetPivot().Position) * anchorRotation, size
					end
					local orientation = CFrame.new(anchorPoint) * anchorRotation
					local offset = Geometry.surfaceOffset(
						anchorNormal,
						orientation.RightVector,
						orientation.UpVector,
						orientation.LookVector,
						size
					)
					local center = anchorPoint + anchorNormal * (offset + 0.03)
					return CFrame.new(center) * anchorRotation, size
				end
				if spell.GrowthCheckAccumulator >= 0.1 then
					spell.GrowthCheckAccumulator %= 0.1
					local growthScale = AreaGrowth.scale(d.Construct, spell.Age)
					local targetFrame, targetSize = frameForScale(growthScale)
					local overlap = OverlapParams.new()
					overlap.FilterType = Enum.RaycastFilterType.Exclude
					overlap.FilterDescendantsInstances = if spell.AttachedHumanoid
						then { spell.Visual, spell.AttachedHumanoid.Parent }
						elseif attachment then { spell.Visual, attachment }
						else { spell.Visual }
					local blocked = false
					for _, part in
						workspace:GetPartBoundsInBox(targetFrame, targetSize - Vector3.new(0.02, 0.02, 0.02), overlap)
					do
						local model = part:FindFirstAncestorOfClass("Model")
						if part.CanCollide or (model and model:FindFirstChildOfClass("Humanoid")) then
							blocked = true
							break
						end
					end
					if not blocked then
						local raycast = RaycastParams.new()
						raycast.FilterType = Enum.RaycastFilterType.Exclude
						raycast.FilterDescendantsInstances = overlap.FilterDescendantsInstances
						raycast.RespectCanCollide = true
						for _, axis in ipairs({
							{ targetFrame.RightVector, targetSize.X / 2 },
							{ targetFrame.UpVector, targetSize.Y / 2 },
							{ targetFrame.LookVector, targetSize.Z / 2 },
						}) do
							local distance = math.max(0, axis[2] - 0.05)
							for _, sign in ipairs({ -1, 1 }) do
								if
									distance > 0
									and workspace:Raycast(targetFrame.Position, axis[1] * distance * sign, raycast)
								then
									blocked = true
									break
								end
							end
							if blocked then
								break
							end
						end
					end
					if not blocked then
						if math.abs(growthScale - spell.CurrentScale) >= 0.001 then
							spell.Visual:ScaleTo(growthScale)
							spell.CurrentScale = growthScale
						end
					end
				end
				local followFrame = frameForScale(spell.CurrentScale)
				spell.Visual:PivotTo(followFrame)
			elseif attachment and not gone and not dead then
				spell.Visual:PivotTo(attachment.CFrame * spell.AttachmentOffset)
			end
			if not gone and not dead then
				spell.Position = spell.Visual:GetPivot().Position
				updateActiveProximity(spell, spell.Position, now)
			end
			if spell.RemainingLifetime <= 0 or gone or dead then
				expireConstruct(spell)
				if spell.IsChannel then
					spell.IsChannel = false
					if stats and stats.Channel == spell then
						stats.Channel = nil
					end
					setCastingMovement(spell.Player, spell.State, nil)
					Presentation.cancel(spell.Caster, d)
					if not spell.ResourceEnded then
						feedback(spell.Remote, spell.Player, "EXPIRED", d, {
							Reason = if gone or dead
								then "Sustained Construct ended · attachment or construct was removed"
								else "Sustained Construct reached its maximum duration",
						})
					end
				end
				Presentation.finish(spell.Visual)
				table.remove(active, i)
			end
			continue
		end
		if
			spell.Kind == "BeamChannel"
			or spell.Kind == "ProjectileChannel"
			or spell.Kind == "WaveChannel"
			or spell.Kind == "SelfEnhancementChannel"
		then
			continue
		end
		if spell.ReturnEnded then
			emitExpiry(spell, spell.Position, {})
			Presentation.finish(spell.Visual)
			table.remove(active, i)
			continue
		end
		if spell.Kind == "Field" or spell.Kind == "Aura" then
			if spell.Definition.Lifetime.Mode == "UntilDestroyed" and not spell.Visual:IsDescendantOf(workspace) then
				finishInterruptedArea(spell)
				table.remove(active, i)
				continue
			end
			local area = d.Field or d.Aura
			local areaScale = AreaGrowth.scale(area, spell.Age)
			local scaledArea = AreaGrowth.area(area, areaScale)
			local followsAnchor = spell.Kind == "Aura" or spell.FollowTarget == true
			if followsAnchor then
				if spell.FollowPart then
					local followPart = spell.FollowPart
					if
						not followPart:IsDescendantOf(workspace)
						or not followPart.CanCollide
						or hasHumanoidAncestor(followPart)
					then
						finishInterruptedArea(spell)
						table.remove(active, i)
						continue
					end
					spell.Position = followPart.CFrame:PointToWorldSpace(spell.FollowPartOffset)
				else
					local followTarget = spell.FollowTargetModel or spell.FollowTarget or spell.Caster
					local root = followTarget:FindFirstChild("HumanoidRootPart")
					local followHumanoid = followTarget:FindFirstChildOfClass("Humanoid")
					if
						not followTarget:IsDescendantOf(workspace)
						or not root
						or not root:IsA("BasePart")
						or not followHumanoid
						or followHumanoid.Health <= 0
					then
						finishInterruptedArea(spell)
						table.remove(active, i)
						continue
					end
					spell.Position = root.Position
				end
			end
			local visualPosition = spell.Position
			if spell.Kind == "Aura" and d.Geometry ~= "Cone" and d.Geometry ~= "Plane" and d.Geometry ~= "Line" then
				visualPosition -= Vector3.new(0, 2.7, 0)
			end
			local areaFrame = CFrame.new(visualPosition) * CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
			Presentation.resizeAreaMarker(
				spell.Visual,
				d.Geometry,
				areaFrame,
				Geometry.areaSize(d.Geometry, scaledArea),
				if spell.Kind == "Field" then d.Field.DebugHeight else nil
			)
			local targets = nil
			if spell.RemainingLifetime > 0 and now >= spell.NextInterval then
				spell.NextInterval = now + area.Interval
				targets = formAreaTargets(spell, spell.Position)
				updateAreaMembership(spell, targets)
				emit(
					d,
					"OnTick",
					spell.Caster,
					spell.Position,
					targets,
					spell.Direction,
					spell.Remote,
					spell.Player,
					nil,
					spell
				)
			end
			if spell.RemainingLifetime <= 0 then
				if not targets then
					targets = formAreaTargets(spell, spell.Position)
					updateAreaMembership(spell, targets)
				end
				local wasChannel = spell.IsChannel == true
				spell.IsChannel = false
				emitExpiry(spell, spell.Position, targets or formAreaCandidates(d, spell.Caster, spell.Position))
				closeAreaMembership(spell)
				if stats and stats.Channel == spell then
					stats.Channel = nil
				end
				if wasChannel then
					Presentation.cancel(spell.Caster, d)
				end
				Presentation.finish(spell.Visual)
				table.remove(active, i)
			end
		elseif spell.Kind == "ProjectileLinger" then
			if spell.AttachedPart then
				local attachedPart = spell.AttachedPart
				if attachedPart.Parent == nil or not attachedPart:IsDescendantOf(workspace) then
					spell.RemainingLifetime = 0
				else
					spell.Position = attachedPart.CFrame:PointToWorldSpace(spell.AttachedOffset)
					spell.Visual.Position = spell.Position
					if spell.LingerVisual then
						spell.LingerVisual.CFrame = attachedPart.CFrame * spell.AttachedVisualOffset
					end
				end
			end
			local targets = nil
			if spell.RemainingLifetime > 0 and now >= spell.NextInterval then
				spell.NextInterval = now + spell.LingerInterval
				targets = areaTargets(spell, spell.Position, spell.LingerRadius)
				emit(
					d,
					"OnTick",
					spell.Caster,
					spell.Position,
					targets,
					spell.Direction,
					spell.Remote,
					spell.Player,
					locusPotency(spell.Player) * (spell.PotencyMultiplier or 1),
					spell
				)
			end
			if spell.RemainingLifetime <= 0 then
				targets = targets or areaTargets(spell, spell.Position, spell.LingerRadius)
				emitExpiry(spell, spell.Position, targets, locusPotency(spell.Player) * (spell.PotencyMultiplier or 1))
				Presentation.finish(spell.Visual)
				if spell.LingerVisual then
					Presentation.finish(spell.LingerVisual)
				end
				table.remove(active, i)
			end
		else
			local maintainedTargetLost = spell.Kind == "Projectile"
				and LifetimeSpec.targetLost(d.Lifetime.Mode, isLiveHomingTarget(spell.HomingTarget))
			if spell.EndConditionEnded or maintainedTargetLost then
				emitExpiry(spell, spell.Position, {})
				Presentation.finish(spell.Visual)
				if spell.LingerVisual then
					Presentation.finish(spell.LingerVisual)
				end
				table.remove(active, i)
				continue
			end
			ProjectileBehaviors.update(spell, step, projectileBehaviorContext(spell))
			if spell.ReturnEnded then
				emitExpiry(spell, spell.Position, {})
				Presentation.finish(spell.Visual)
				table.remove(active, i)
				continue
			end
			local motionPhases = d.Projectile.MotionPhases or {}
			local previousPhase = spell.MotionPhaseIndex or 1
			local previousElapsed = spell.MotionPhaseElapsed or 0
			local phaseIndex, phaseElapsed, motionPhase =
				ProjectileMotion.advance(motionPhases, previousPhase, previousElapsed, step)
			local enteredPhase = phaseIndex ~= nil and phaseIndex ~= previousPhase
			local initializePhase = phaseIndex ~= nil
				and (enteredPhase or spell.MotionPhaseInitializedIndex ~= phaseIndex)
			if phaseIndex then
				spell.MotionPhaseIndex = phaseIndex
				spell.MotionPhaseElapsed = phaseElapsed
				if initializePhase then
					spell.MotionPhaseInitializedIndex = phaseIndex
					local velocityDirection = if spell.Velocity.Magnitude > 0.001
						then spell.Velocity.Unit
						else spell.Direction
					spell.Velocity = velocityDirection * spell.BaseSpeed * (motionPhase.SpeedMultiplier or 1)
					spell.Direction = velocityDirection
					spell.OrbitOrigin = nil
					spell.BezierOrigin = nil
					if motionPhase.Mode == "Orbiting" then
						local radial = spell.Direction:Cross(Vector3.yAxis)
						if radial.Magnitude < 0.05 then
							radial = spell.Direction:Cross(Vector3.xAxis)
						end
						spell.OrbitOrigin = spell.Position
						spell.OrbitRadial = radial.Unit
						spell.OrbitTangent = Vector3.yAxis:Cross(radial.Unit).Unit
					elseif motionPhase.Mode == "Bezier" then
						local sideAxis = spell.Direction:Cross(Vector3.yAxis)
						if sideAxis.Magnitude < 0.05 then
							sideAxis = spell.Direction:Cross(Vector3.xAxis)
						end
						spell.BezierOrigin = spell.Position
						spell.BezierDirection = spell.Direction
						spell.BezierSideAxis = sideAxis.Unit
						spell.BezierDistance = spell.Velocity.Magnitude * motionPhase.Duration
					end
				end
			end
			local mode = motionPhase and motionPhase.Mode or "Linear"
			spell.MotionPhaseMode = mode
			local phaseDuration = motionPhase and motionPhase.Duration or 1
			local phaseTimeBefore = if initializePhase then 0 else previousElapsed
			local previous = spell.Position
			local usesAcceleration = mode == "Linear" or mode == "Arcing" or mode == "Attached"
			local usesGravity = mode == "Linear" or mode == "Arcing" or mode == "Falling" or mode == "Attached"
			local acceleration = if mode == "Stationary"
				then Vector3.zero
				else spell.Direction * (if usesAcceleration and motionPhase
					then motionPhase.Acceleration or d.Projectile.Acceleration
					elseif usesAcceleration then d.Projectile.Acceleration
					else 0) - Vector3.new(
					0,
					if mode == "Falling"
						then motionPhase.Gravity
						elseif usesGravity and motionPhase then motionPhase.Gravity or d.Projectile.Gravity
						elseif usesGravity then d.Projectile.Gravity
						else 0,
					0
				)
			local movement = if mode == "Stationary"
				then Vector3.zero
				else spell.Velocity * step + acceleration * (step * step / 2)
			if mode == "Arcing" and motionPhase then
				local beforeArc = ProjectileMotion.arcOffset(motionPhase.ArcHeight, phaseDuration, phaseTimeBefore)
				local afterArc = ProjectileMotion.arcOffset(motionPhase.ArcHeight, phaseDuration, phaseElapsed)
				movement += Vector3.yAxis * (afterArc - beforeArc)
			elseif mode == "Orbiting" and motionPhase and spell.OrbitOrigin then
				local angularSpeed = motionPhase.OrbitAngularSpeed
				local radius = motionPhase.OrbitRadius
				local function orbitOffset(time)
					local angle = time * angularSpeed
					return spell.OrbitRadial * (radius * (math.cos(angle) - 1))
						+ spell.OrbitTangent * (radius * math.sin(angle))
				end
				movement += orbitOffset(phaseElapsed) - orbitOffset(phaseTimeBefore)
			elseif mode == "Bezier" and motionPhase and spell.BezierOrigin then
				local before = ProjectileMotion.bezierPosition(
					spell.BezierOrigin,
					spell.BezierDirection,
					spell.BezierSideAxis,
					spell.BezierDistance,
					motionPhase.BezierSide or 0,
					motionPhase.BezierHeight or 0,
					phaseTimeBefore / phaseDuration
				)
				local after = ProjectileMotion.bezierPosition(
					spell.BezierOrigin,
					spell.BezierDirection,
					spell.BezierSideAxis,
					spell.BezierDistance,
					motionPhase.BezierSide or 0,
					motionPhase.BezierHeight or 0,
					phaseElapsed / phaseDuration
				)
				movement = after - before
			end
			local collisionRadius = d.Projectile.Radius
			if mode == "Expanding" and motionPhase then
				collisionRadius *= ProjectileMotion.expansion(motionPhase.ExpandMultiplier, phaseDuration, phaseElapsed)
				if spell.InitialVisualSize then
					spell.Visual.Size = spell.InitialVisualSize * (collisionRadius / d.Projectile.Radius)
				end
			end
			if not spell.Returning then
				local remaining = d.Projectile.MaxDistance - spell.Distance
				if movement.Magnitude > remaining then
					movement = movement.Unit * math.max(0, remaining)
				end
			end
			if mode == "Bezier" and motionPhase then
				local tangent = ProjectileMotion.bezierTangent(
					spell.BezierDirection,
					spell.BezierSideAxis,
					spell.BezierDistance,
					motionPhase.BezierSide or 0,
					motionPhase.BezierHeight or 0,
					phaseElapsed / phaseDuration
				)
				if tangent.Magnitude > 0.001 then
					spell.Velocity = tangent.Unit * (tangent.Magnitude / phaseDuration)
					spell.Direction = tangent.Unit
				end
			else
				spell.Velocity += acceleration * step
			end
			if mode == "Stationary" then
				spell.Velocity = Vector3.zero
			end
			local hit = nil
			if not spell.CheckedSpawn then
				spell.CheckedSpawn = true
				local overlap = OverlapParams.new()
				overlap.FilterType = Enum.RaycastFilterType.Exclude
				local ignored = { spell.Caster, spell.Visual }
				for _, model in ipairs(spell.IgnoredTargetModels or {}) do
					table.insert(ignored, model)
				end
				overlap.FilterDescendantsInstances = ignored
				-- Query with the authored collision radius, never the independently scaled visual.
				for _, part in workspace:GetPartBoundsInRadius(previous, collisionRadius, overlap) do
					local model = part:FindFirstAncestorOfClass("Model")
					local isHumanoid = model and model:FindFirstChildOfClass("Humanoid")
					if
						(part.CanCollide or isHumanoid)
						and not isSpawnFloorClip(
							part,
							previous,
							spell.Direction,
							spell.Caster,
							spell.Visual,
							collisionRadius
						)
					then
						hit = { Instance = part, Position = previous, Distance = 0 }
						break
					end
				end
			end
			if mode == "Stationary" and now >= (spell.NextStationaryQuery or 0) then
				spell.NextStationaryQuery = now + Limits.ProjectileStationarySampleInterval
				local overlap = OverlapParams.new()
				overlap.FilterType = Enum.RaycastFilterType.Exclude
				local ignored = { spell.Caster, spell.Visual }
				for _, model in ipairs(spell.IgnoredTargetModels or {}) do
					table.insert(ignored, model)
				end
				overlap.FilterDescendantsInstances = ignored
				overlap.RespectCanCollide = false
				for _, part in workspace:GetPartBoundsInRadius(previous, collisionRadius, overlap) do
					local model = part:FindFirstAncestorOfClass("Model")
					local isHumanoid = model and model:FindFirstChildOfClass("Humanoid")
					if
						(part.CanCollide or isHumanoid)
						and not isSpawnFloorClip(
							part,
							previous,
							spell.Direction,
							spell.Caster,
							spell.Visual,
							collisionRadius
						)
					then
						hit = { Instance = part, Position = previous, Distance = 0 }
						break
					end
				end
			end
			hit = hit
				or sweep(previous, movement, spell.Caster, spell.Visual, collisionRadius, spell.IgnoredTargetModels)
			spell.Position = if hit
				then previous + (if movement.Magnitude > 0 then movement.Unit else Vector3.zero) * hit.Distance
				else previous + movement
			spell.Distance += if hit then hit.Distance else movement.Magnitude
			spell.Visual.CFrame = CFrame.lookAt(
				spell.Position,
				spell.Position + (if movement.Magnitude > 0.001 then movement.Unit else spell.Direction)
			)
			if hit then
				Presentation.impact(hit.Position, d.Visual.Color, d, hit)
				local hitObjectTarget = spell.ObjectTarget
					and hit.Instance == spell.ObjectTarget
					and spell.Distance <= objectTargetRange(d)
					and isValidObjectInteractionTarget(d, hit.Instance)
				local hitTargets = if spell.ObjectTarget
					then if hitObjectTarget then { spell.ObjectTarget } else {}
					else targetFrom(hit)
				local hitHumanoid = hitTargets[1]
				if hitHumanoid then
					spell.HitHumanoids = spell.HitHumanoids or {}
					spell.HitHumanoids[hitHumanoid] = true
					spell.TargetsHit[hitHumanoid] = true
					if projectileHasBehavior(spell, "Return") then
						local hitModel = hitHumanoid.Parent
						if hitModel then
							spell.IgnoredTargetModels = spell.IgnoredTargetModels or {}
							if not table.find(spell.IgnoredTargetModels, hitModel) then
								table.insert(spell.IgnoredTargetModels, hitModel)
							end
						end
					end
				end
				spell.CurrentPhase = "Impact"
				spell.AllowObjectTarget = hitObjectTarget == true
				spell.HitPart = hit.Instance
				emit(
					d,
					"OnImpact",
					spell.Caster,
					hit.Position,
					hitTargets,
					spell.Direction,
					spell.Remote,
					spell.Player,
					locusPotency(spell.Player) * (spell.PotencyMultiplier or 1),
					spell
				)
				spell.HitPart = nil
				spell.AllowObjectTarget = nil
				local continue = ProjectileBehaviors.impact(spell, hit, projectileBehaviorContext(spell))
				if projectileHasBehavior(spell, "Return") and hitHumanoid then
					continue = true
				end
				if continue then
					spell.Position = hit.Position + spell.Direction * (d.Projectile.Radius + 0.05)
					spell.Visual.CFrame = CFrame.lookAt(spell.Position, spell.Position + spell.Direction)
				elseif spell.Kind == "ProjectileLinger" then
					Presentation.stopLoop(spell.Visual, "TravelSoundId")
					Presentation.attachLoop(d, "AmbientLoopSoundId", spell.Visual)
					for _, behavior in ipairs(d.Projectile.Behaviors) do
						if behavior.Kind == "Linger" then
							spell.LingerVisual = Presentation.marker(
								"MagicLingerHazard",
								hit.Position,
								Vector3.new(0.15, behavior.Radius * 2, behavior.Radius * 2),
								d.Visual.Color
							)
							if spell.AttachedPart then
								spell.AttachedVisualOffset =
									spell.AttachedPart.CFrame:ToObjectSpace(spell.LingerVisual.CFrame)
							end
							break
						end
					end
				elseif spell.Kind ~= "ProjectileLinger" then
					Presentation.finish(spell.Visual)
					table.remove(active, i)
				end
			elseif spell.RemainingLifetime <= 0 or spell.Distance >= d.Projectile.MaxDistance - 0.001 then
				if
					spell.RemainingLifetime > 0
					and spell.Distance >= d.Projectile.MaxDistance - 0.001
					and not spell.Returning
				then
					spell.Returning = projectileHasBehavior(spell, "Return")
					if spell.Returning then
						spell.CurrentPhase = "Returning"
					end
				end
				if not spell.Returning or spell.RemainingLifetime <= 0 then
					emitExpiry(spell, spell.Position, {})
					Presentation.finish(spell.Visual)
					table.remove(active, i)
				end
			end
		end
	end
	for player, effects in enhancements do
		local fallback = nil
		for id, effect in effects do
			effect.Age += delta
			local manaRate = effect.Definition.Casting.ManaUpkeepPerSecond or 0
			local strainRate = effect.Definition.Casting.StrainPerSecond or 0
			if
				not effect.IsChannel
				and not effect.ResourceEnded
				and now < effect.ExpiresAt
				and (manaRate > 0 or strainRate > 0)
			then
				local stats = playerData[player]
				local paid = stats ~= nil and LocusModel.upkeep(stats, manaRate, strainRate, delta)
				if not paid or (stats and manaRate > 0 and stats.Mana <= 0) then
					effect.ResourceEnded = true
					effect.ExpiresAt = now
					feedback(effect.Remote, player, "EXPIRED", effect.Definition, {
						Reason = if stats and stats.Mana <= 0
							then "Enhancement ended · mana depleted"
							else "Enhancement ended · ongoing Locus resources depleted",
						Mana = stats and stats.Mana,
						Capacity = stats and stats.Capacity,
						Strain = stats and stats.Strain,
						StrainTolerance = stats and stats.StrainTolerance,
					})
				end
			end
			if not effect.EndConditionEnded and Conditions.endWhen(effect.Definition, effect, playerData[player]) then
				effect.EndConditionEnded = true
				effect.ExpiresAt = now
			end
			if
				now < effect.ExpiresAt
				and effect.State.Character == player.Character
				and effect.State.Humanoid.Health > 0
			then
				updateActiveProximity(effect, effect.State.Root.Position, now)
			end
			if
				now >= effect.ExpiresAt
				or effect.State.Character ~= player.Character
				or effect.State.Humanoid.Health <= 0
			then
				expireSelfEnhancement(player, effect)
				Presentation.stopSound(effect.AmbientSound)
				fallback = effect.State
				effects[id] = nil
			end
		end
		if fallback then
			updateEnhancement(player, fallback)
		end
	end
end)

task.spawn(function()
	local ready, reason = PersistentConstructStore.start(restorePersistentConstruct)
	if not ready then
		warn("Persistent Construct storage unavailable: " .. tostring(reason))
	end
end)

return Magic
