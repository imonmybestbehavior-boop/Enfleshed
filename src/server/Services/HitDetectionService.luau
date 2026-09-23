--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local HitDetection = {}

function HitDetection.find(state: Types.PlayerState, attack: Types.Attack): { Humanoid }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { state.Character }
	local frame = state.Root.CFrame
	local parts = workspace:GetPartBoundsInBox(frame * CFrame.new(0, 0, -attack.Offset), attack.Size, overlap)
	local found: { [Humanoid]: boolean } = {}
	local targets = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
		local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
		if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 and not found[humanoid] then
			found[humanoid] = true
			local delta = root.Position - frame.Position
			local horizontal = Vector3.new(delta.X, 0, delta.Z)
			if delta.Magnitude > attack.Reach then
				continue
			end
			if
				horizontal.Magnitude > 0.01
				and frame.LookVector:Dot(horizontal.Unit) < Config.Combat.MinimumFacingDot
			then
				continue
			end
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = { state.Character, model :: Model }
			ray.RespectCanCollide = true
			if not workspace:Raycast(frame.Position, delta, ray) then
				table.insert(targets, humanoid)
			end
		end
	end
	return targets
end

return HitDetection
