--!strict

local HitDetection = {}
local Geometry = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicGeometry)

export type Rules = {
	OverlapCollisionGroup: string?,
	MaxDistance: number?,
	MinimumFacingDot: number?,
	RequireLineOfSight: boolean?,
	IncludeAttacker: boolean?,
	CanTarget: ((Model, Humanoid) -> boolean)?,
}

-- Geometry and target policy come from the caller, never from attacker identity.
function HitDetection.find(attacker: Model, origin: CFrame, hitbox: CFrame, size: Vector3, rules: Rules): { Humanoid }
	local overlap = OverlapParams.new()
	overlap.CollisionGroup = rules.OverlapCollisionGroup or "Default"
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if rules.IncludeAttacker then {} else { attacker }
	local found: { [Humanoid]: boolean } = {}
	local targets: { Humanoid } = {}
	for _, part in workspace:GetPartBoundsInBox(hitbox, size, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not model:FindFirstChildOfClass("Humanoid") do
			model = model:FindFirstAncestorOfClass("Model")
		end
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if
			not model
			or (model == attacker and not rules.IncludeAttacker)
			or not humanoid
			or humanoid.Health <= 0
			or not root
			or not root:IsA("BasePart")
			or found[humanoid]
		then
			continue
		end
		found[humanoid] = true
		if rules.CanTarget and not rules.CanTarget(model, humanoid) then
			continue
		end
		local delta = root.Position - origin.Position
		if rules.MaxDistance and delta.Magnitude > rules.MaxDistance then
			continue
		end
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		if
			rules.MinimumFacingDot
			and horizontal.Magnitude > 0
			and origin.LookVector:Dot(horizontal.Unit) < rules.MinimumFacingDot
		then
			continue
		end
		if rules.RequireLineOfSight and delta.Magnitude > 0.001 then
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { attacker, model }
			ray.RespectCanCollide = true
			if workspace:Raycast(origin.Position, delta, ray) then
				continue
			end
		end
		table.insert(targets, humanoid)
	end
	return targets
end

function HitDetection.findArea(attacker: Model, origin: CFrame, shape: string, area: any, rules: Rules): { Humanoid }
	local size = Geometry.areaSize(shape, area)
	local queryFrame = Geometry.areaQueryFrame(shape, origin, area)
	local queryRules = table.clone(rules)
	local previousCanTarget = rules.CanTarget
	queryRules.CanTarget = function(model, humanoid)
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or not Geometry.containsArea(shape, origin, root.Position, area) then
			return false
		end
		return not previousCanTarget or previousCanTarget(model, humanoid)
	end
	return HitDetection.find(attacker, origin, queryFrame, size, queryRules)
end

-- Sphere and cone use the same target/LOS policy as melee. They remain neutral
-- queries: callers provide geometry and target policy rather than attacker roles.
function HitDetection.findSphere(attacker: Model, origin: CFrame, radius: number, rules: Rules): { Humanoid }
	local overlap = OverlapParams.new()
	overlap.CollisionGroup = rules.OverlapCollisionGroup or "Default"
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = if rules.IncludeAttacker then {} else { attacker }
	local found: { [Humanoid]: boolean } = {}
	local targets: { Humanoid } = {}
	for _, part in workspace:GetPartBoundsInRadius(origin.Position, radius, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if
			not model
			or not humanoid
			or not root
			or not root:IsA("BasePart")
			or (model == attacker and not rules.IncludeAttacker)
			or humanoid.Health <= 0
			or found[humanoid]
		then
			continue
		end
		found[humanoid] = true
		local delta = root.Position - origin.Position
		if
			(rules.MaxDistance and delta.Magnitude > rules.MaxDistance)
			or (rules.CanTarget and not rules.CanTarget(model, humanoid))
		then
			continue
		end
		if rules.RequireLineOfSight and delta.Magnitude > 0.001 then
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { attacker, model }
			ray.RespectCanCollide = true
			if workspace:Raycast(origin.Position, delta, ray) then
				continue
			end
		end
		table.insert(targets, humanoid)
	end
	return targets
end

function HitDetection.findCone(
	attacker: Model,
	origin: CFrame,
	range: number,
	minimumDot: number,
	rules: Rules
): { Humanoid }
	local result: { Humanoid } = {}
	for _, humanoid in HitDetection.findSphere(attacker, origin, range, rules) do
		local root = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local delta = root.Position - origin.Position
			if Geometry.withinCone(origin.LookVector, delta, minimumDot) then
				table.insert(result, humanoid)
			end
		end
	end
	return result
end

return HitDetection
