--!strict
-- Local-only bounded camera impulse. Remote delivery is handled by the server bridge.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
return {
	Run = function(session, config, target)
		if not RunService:IsClient() then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local origin = if typeof(target) == "Vector3"
			then target
			elseif typeof(target) == "Instance" and target:IsA("BasePart") then target.Position
			else nil
		local distance = if origin
				and Players.LocalPlayer.Character
				and Players.LocalPlayer.Character.PrimaryPart
			then (Players.LocalPlayer.Character.PrimaryPart.Position - origin).Magnitude
			else 0
		local maxDistance = math.max(1, config.Falloff or 100)
		local strength = math.clamp(config.Magnitude or 0.3, 0, 5) * math.clamp(1 - distance / maxDistance, 0, 1)
		local duration = math.clamp(config.Duration or 0.25, 0.02, 5)
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - started
			if elapsed >= duration or not camera.Parent then
				connection:Disconnect()
				return
			end
			local fade = 1 - elapsed / duration
			local offset = Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, 0) * strength * fade * 0.08
			camera.CFrame *= CFrame.new(offset)
		end)
		session:AddConnection(connection)
	end,
}
