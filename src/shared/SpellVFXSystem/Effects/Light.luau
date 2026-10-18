--!strict
-- Creates a short-lived point/spot light and fades its brightness and range.
local TweenService = game:GetService("TweenService")
return {
	Run = function(session, config, target, context)
		local parent = if typeof(target) == "Instance" then target else nil
		if parent and parent:IsA("Model") then
			parent = parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
		end
		if not parent or not parent:IsA("BasePart") then
			if typeof(target) ~= "Vector3" then
				return
			end
			local part = Instance.new("Part")
			part.Anchored, part.Transparency, part.CanCollide = true, 1, false
			part.Size, part.Position, part.Parent = Vector3.one * 0.1, target, session.Holder
			parent = part
		end
		local light = if config.Spot then Instance.new("SpotLight") else Instance.new("PointLight")
		light.Color = config.Color or context.Color or Color3.new(1, 1, 1)
		light.Range, light.Brightness = math.clamp(config.Range or 12, 0, 60), math.clamp(config.Brightness or 2, 0, 10)
		light.Parent = parent
		local duration = math.clamp(config.Duration or 0.4, 0.05, 10)
		local tween = TweenService:Create(light, TweenInfo.new(duration), { Brightness = 0, Range = 0 })
		session:AddTween(tween):Play()
		task.delay(duration, function()
			if light.Parent then
				light:Destroy()
			end
		end)
		session:AddCleanup(function()
			if light.Parent then
				light:Destroy()
			end
		end)
	end,
}
