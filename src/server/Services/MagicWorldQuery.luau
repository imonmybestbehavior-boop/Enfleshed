--!strict
-- Stateless world queries for the magic runtime: sweeps, target and material
-- lookup, object-target rules, construct placement and channel end targets.
-- Extracted from MagicService (Phase 1.7); no runtime state lives here.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared.Configuration.Sandbox)
local HitDetection = require(script.Parent.HitDetectionService)
local Geometry = require(Shared.Modules.MagicGeometry)
local AreaGrowth = require(Shared.Modules.MagicAreaGrowth)
local Conditions = require(script.Parent.MagicConditions)
local Presentation = require(script.Parent.MagicPresentation)
local Manipulation = require(script.Parent.MagicManipulationExecutors)
local TargetingSpec = require(Shared.Modules.MagicTargetingSpec)
local ObjectTargetSpec = require(Shared.Modules.MagicObjectTargetSpec)
local MagicWorldQuery = {}

local function validVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
		and math.abs(value.X) < 1e7
		and math.abs(value.Y) < 1e7
		and math.abs(value.Z) < 1e7
end

local function hasHumanoidAncestor(instance: Instance): boolean
	local ancestor = instance.Parent
	while ancestor and ancestor ~= workspace do
		if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
			return true
		end
		ancestor = ancestor.Parent
	end
	return false
end

local function isValidObjectInteractionTarget(definition, target: BasePart): boolean
	local hasPhysics = false
	local hasManipulation = false
	for _, steps in definition.Triggers or {} do
		for _, step in steps do
			for _, payload in step.Payloads or {} do
				hasPhysics = hasPhysics or payload.Kind == "Force" or payload.Kind == "Control"
				hasManipulation = hasManipulation or payload.Kind == "Manipulation"
			end
		end
	end
	if
		not ObjectTargetSpec.isValidInteractionTarget({
			InWorkspace = target:IsDescendantOf(workspace),
			CanCollide = target.CanCollide,
			HasHumanoidAncestor = hasHumanoidAncestor(target),
			Tagged = CollectionService:HasTag(target, "MagicManipulable"),
			Anchored = target.Anchored,
			AssemblyMass = target.AssemblyMass,
			MaterialMatches = definition.Material ~= nil
				and target:GetAttribute("MagicMaterial") == definition.Material.Material,
			RaiseAuthorized = target:GetAttribute("MagicRaise") == true,
		}, hasPhysics, hasManipulation)
	then
		return false
	end
	return true
end

local function findMaterial(definition: any, point: Vector3): Instance?
	local requirement = definition.Material
	if not requirement then
		return nil
	end
	local closest: Instance? = nil
	local closestDistance = math.huge
	for _, source in CollectionService:GetTagged("MagicMaterialSource") do
		local position = if source:IsA("BasePart")
			then source.Position
			elseif source:IsA("Model") then source:GetPivot().Position
			else nil
		local available = source:GetAttribute("AvailableAmount")
		if
			position
			and source:IsDescendantOf(workspace)
			and source:GetAttribute("MagicMaterial") == requirement.Material
			and type(available) == "number"
			and available == available
			and available > -math.huge
			and available < math.huge
			and available >= requirement.Amount
			and (position - point).Magnitude <= requirement.SearchRadius
			and (position - point).Magnitude < closestDistance
		then
			closest, closestDistance = source, (position - point).Magnitude
		end
	end
	return closest
end

local function findManipulable(definition: any, point: Vector3): BasePart?
	local closest: BasePart? = nil
	local closestDistance = math.huge
	for _, source in CollectionService:GetTagged("MagicManipulable") do
		if
			source:IsA("BasePart")
			and source:GetAttribute("MagicMaterial") == definition.Material.Material
			and source:GetAttribute("MagicRaise") == true
			and (source.Position - point).Magnitude <= definition.Material.SearchRadius
			and (source.Position - point).Magnitude < closestDistance
		then
			closest, closestDistance = source, (source.Position - point).Magnitude
		end
	end
	return closest
end

local function acquireEntityTarget(state: any, direction: Vector3, definition: any): Model?
	local origin = state.Root.Position + Vector3.new(0, 1.5, 0)
	local range = math.min(TargetingSpec.entityRange(definition), Sandbox.Magic.LockOnAcquireRange)
	local candidates = HitDetection.findSphere(state.Character, CFrame.new(origin), range, {
		OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
		MaxDistance = range,
		RequireLineOfSight = definition.TargetRules.RequiresLineOfSight,
	})
	local selected: Model? = nil
	local bestDot = Sandbox.Magic.MinimumEntityAimDot
	local bestDistance = math.huge
	for _, humanoid in ipairs(candidates) do
		local model = humanoid.Parent
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if
			model
			and model:IsA("Model")
			and root
			and root:IsA("BasePart")
			and Conditions.relationshipMatches(state.Character, model, definition.TargetRules.Relationship)
			and Conditions.hasConsent(definition, model)
		then
			local delta = root.Position - origin
			if delta.Magnitude > 0.001 then
				local dot = direction:Dot(delta.Unit)
				if dot > bestDot or (dot == bestDot and delta.Magnitude < bestDistance) then
					selected = model
					bestDot = dot
					bestDistance = delta.Magnitude
				end
			end
		end
	end
	return selected
end

-- A single bounded sweep includes world solids and character limbs. Query-only
-- cosmetic parts are excluded through reassignment (FilterDescendantsInstances is a copy).
local function sweep(start, delta, caster, visualPart, radius, additionalIgnored)
	if delta.Magnitude < 0.0001 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = { caster }
	if visualPart then
		table.insert(ignored, visualPart)
	end
	for _, instance in ipairs(additionalIgnored or {}) do
		table.insert(ignored, instance)
	end
	params.RespectCanCollide = false
	for _ = 1, 16 do
		params.FilterDescendantsInstances = ignored
		local hit = if radius > 0
			then workspace:Spherecast(start, radius, delta, params)
			else workspace:Raycast(start, delta, params)
		if not hit then
			return nil
		end
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		if
			(model and model:FindFirstChildOfClass("Humanoid"))
			or hit.Instance:IsA("Terrain")
			or (hit.Instance:IsA("BasePart") and hit.Instance.CanCollide)
		then
			return hit
		end
		table.insert(ignored, hit.Instance)
	end
	-- Fail closed at the final obstruction, never tunnel through excessive decorations.
	params.RespectCanCollide = true
	return if radius > 0
		then workspace:Spherecast(start, radius, delta, params)
		else workspace:Raycast(start, delta, params)
end

local function targetFrom(hit)
	local model = hit and hit.Instance:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	return if humanoid then { humanoid } else {}
end

local function objectTargetHit(
	caster: Model,
	origin: Vector3,
	direction: Vector3,
	range: number,
	target: BasePart?,
	definition
)
	if not target or not isValidObjectInteractionTarget(definition, target) then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { caster }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(origin, direction * range, params)
	return if hit and hit.Instance == target then hit else nil
end

local function objectTargetRange(definition): number
	local formRange = if definition.Form == "Projectile"
		then definition.Projectile.MaxDistance
		elseif definition.Form == "Beam" then definition.Beam.Range * math.max(
			definition.Beam.GrowthStartScale or 1,
			definition.Beam.GrowthEndScale or 1
		)
		else definition.Wave.Range * math.max(
			definition.Wave.GrowthStartScale or 1,
			definition.Wave.GrowthEndScale or 1
		)
	return math.min(
		definition.TargetRules.Range,
		formRange,
		if definition.Material then definition.Material.SearchRadius else definition.TargetRules.Range
	)
end

local function constructPlacement(state, d, direction, intent)
	local origin = state.Root.Position + Vector3.new(0, 1.5, 0)
	local placementDistance = d.Construct.Distance
	-- Use a nearby camera aim point when available, but always preserve a valid
	-- direction-based free-air placement when the ray has no target.
	if validVector(intent.WorldPoint) then
		local delta = intent.WorldPoint - origin
		if
			delta.Magnitude > 0.001
			and delta.Magnitude <= placementDistance
			and direction:Dot(delta.Unit) >= Sandbox.Magic.MinimumWorldAimDot
		then
			direction = delta.Unit
			placementDistance = math.min(delta.Magnitude, placementDistance)
		end
	end
	local center = origin + direction * placementDistance
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.001 then
		flat = Vector3.new(0, 0, -1)
	end
	local frame = CFrame.lookAt(center, center + flat.Unit)
	local startScale = AreaGrowth.scale(d.Construct, 0)
	local size = Vector3.new(d.Construct.Width, d.Construct.Height, d.Construct.Depth) * startScale
	local hit = sweep(origin, direction * placementDistance, state.Character, nil, 0)
	local attachment, attachedHumanoid
	if hit then
		-- Project this upright box onto the surface normal, keeping its nearest face flush.
		local normal = hit.Normal
		local offset = Geometry.surfaceOffset(normal, frame.RightVector, frame.UpVector, frame.LookVector, size)
		frame = frame.Rotation + hit.Position + normal * (offset + 0.03)
		if hit.Instance:IsA("BasePart") then
			attachment = hit.Instance
			attachedHumanoid = targetFrom(hit)[1]
		end
	end
	-- Placement is intentionally not gated on free volume. A Construct can be
	-- formed in open air or intersect existing world geometry; a ray hit only
	-- improves placement by attaching it to the nearby surface/character.
	return frame, size, attachment, attachedHumanoid, if hit then hit.Position else nil, if hit then hit.Normal else nil
end

local function finalChannelTargets(channel)
	local definition = channel.Definition
	channel.HitPart = nil
	local humanoid = channel.Caster:FindFirstChildOfClass("Humanoid")
	local root = channel.Caster:FindFirstChild("HumanoidRootPart")
	if
		not humanoid
		or humanoid.Health <= 0
		or not root
		or not root:IsA("BasePart")
		or not root:IsDescendantOf(workspace)
	then
		return channel.Position, {}
	end
	channel.AllowObjectTarget = false
	if channel.Kind == "BeamChannel" then
		local beam = AreaGrowth.area(definition.Beam, AreaGrowth.scale(definition.Beam, channel.Age))
		local range = math.min(beam.Range, definition.TargetRules.Range)
		local origin = Presentation.handOrigin(channel.Caster, root.Position + Vector3.new(0, 1.5, 0))
		local hit = sweep(origin, channel.Direction * range, channel.Caster, nil, beam.Width / 2)
		local objectHit = if hit and hit.Instance == channel.ObjectTarget
			then objectTargetHit(
				channel.Caster,
				origin,
				channel.Direction,
				math.min(objectTargetRange(definition), range),
				channel.ObjectTarget,
				definition
			)
			else nil
		channel.AllowObjectTarget = objectHit ~= nil
		channel.HitPart = if not channel.ObjectTarget and hit then hit.Instance else nil
		channel.Position = origin
		return origin,
			if channel.ObjectTarget then if objectHit then { channel.ObjectTarget } else {} else targetFrom(hit)
	elseif channel.Kind == "WaveChannel" then
		local wave = AreaGrowth.area(definition.Wave, AreaGrowth.scale(definition.Wave, channel.Age))
		local range = math.min(wave.Range, definition.TargetRules.Range)
		local position = root.Position
		local objectHit = objectTargetHit(
			channel.Caster,
			position + Vector3.new(0, 1.5, 0),
			channel.Direction,
			math.min(objectTargetRange(definition), range),
			channel.ObjectTarget,
			definition
		)
		if channel.ObjectTarget then
			channel.AllowObjectTarget = objectHit ~= nil
			channel.Position = position
			return position, if objectHit then { channel.ObjectTarget } else {}
		end
		local frame = CFrame.lookAt(position, position + channel.Direction)
		local targetRules = {
			OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
			RequireLineOfSight = definition.TargetRules.RequiresLineOfSight,
			IncludeAttacker = definition.TargetRules.IncludeCaster,
		}
		local targets = if definition.Geometry == "Sphere"
			then HitDetection.findSphere(channel.Caster, frame, range, targetRules)
			else HitDetection.findCone(channel.Caster, frame, range, wave.Dot, targetRules)
		channel.Position = position
		return position, targets
	end
	return channel.Position, {}
end

MagicWorldQuery.validVector = validVector
MagicWorldQuery.hasHumanoidAncestor = hasHumanoidAncestor
MagicWorldQuery.isValidObjectInteractionTarget = isValidObjectInteractionTarget
MagicWorldQuery.findMaterial = findMaterial
MagicWorldQuery.findManipulable = findManipulable
MagicWorldQuery.acquireEntityTarget = acquireEntityTarget
MagicWorldQuery.sweep = sweep
MagicWorldQuery.targetFrom = targetFrom
MagicWorldQuery.objectTargetHit = objectTargetHit
MagicWorldQuery.objectTargetRange = objectTargetRange
MagicWorldQuery.constructPlacement = constructPlacement
MagicWorldQuery.finalChannelTargets = finalChannelTargets

return MagicWorldQuery
