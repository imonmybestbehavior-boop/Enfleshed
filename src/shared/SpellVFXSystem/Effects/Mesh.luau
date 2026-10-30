--!strict
-- Spawns a configurable decorative MeshPart/SpecialMesh and animates its transform.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local function positionOf(target)
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		end
		if target:IsA("Attachment") then
			return target.WorldPosition
		end
		if target:IsA("Model") then
			return target:GetPivot().Position
		end
	end
	return nil
end
return {
	Run = function(session, config, target, context)
		local assets = ReplicatedStorage:FindFirstChild(config.AssetsFolder or "SpellVFXAssets")
		local source = assets and assets:FindFirstChild(config.Template or "")
		local part
		if source and source:IsA("BasePart") then
			part = source:Clone()
		else
			part = Instance.new("Part")
			part.Shape = Enum.PartType.Ball
			part.Material = Enum.Material.Neon
			part.Color = config.Color or context.Color or Color3.new(1, 1, 1)
			part.Size = Vector3.one
			if config.InstanceName then
				part.Name = config.InstanceName
			end
		end
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		local position = positionOf(target)
		if not position then
			part:Destroy()
			return
		end
		part.CFrame = CFrame.new(position)
			* CFrame.Angles(
				math.rad(config.RotationX or 0),
				math.rad(config.RotationY or 0),
				math.rad(config.RotationZ or 0)
			)
		part.Parent = session.Holder
		session:AddCleanup(function()
			if part.Parent then
				part:Destroy()
			end
		end)
		if config.Scale then
			part.Size = config.Scale
		end
		if config.Transparency ~= nil then
			part.Transparency = config.Transparency
		end
		local mesh = part:FindFirstChildWhichIsA("SpecialMesh")
		if mesh and config.MeshScale then
			mesh.Scale = config.MeshScale
		end
		if config.SpinRate and config.SpinRate ~= 0 and part.Parent == session.Holder then
			local connection = RunService.Heartbeat:Connect(function(dt)
				if session.Active and part.Parent then
					part.CFrame *= CFrame.Angles(0, (config.SpinRate :: number) * dt, 0)
				end
			end)
			session:AddConnection(connection)
		end
		if config.Lifetime then
			local lifetime = math.clamp(config.Lifetime, 0.05, 30)
			local thread = task.delay(lifetime, function()
				if part.Parent then
					part:Destroy()
				end
			end)
			table.insert(session.Tasks, thread)
		end
	end,
}
