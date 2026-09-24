--!strict

local HitDetection = {}

export type Rules = {
	MaxDistance: number?,
	MinimumFacingDot: number?,
	RequireLineOfSight: boolean?,
	CanTarget: ((Model, Humanoid) -> boolean)?,
}

-- Geometry and target policy come from the caller, never from attacker identity.
function HitDetection.find(attacker: Model, origin: CFrame, hitbox: CFrame, size: Vector3, rules: Rules): { Humanoid }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker }
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
			or model == attacker
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
		if rules.RequireLineOfSight then
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

return HitDetection
