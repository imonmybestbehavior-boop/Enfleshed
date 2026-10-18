--!strict
-- Connects named attachments or a target attachment to a temporary point endpoint.
local RunService = game:GetService("RunService")
return {
	Run = function(session, config, target, context)
		if typeof(target) ~= "Instance" then
			return
		end
		local function getAttachment(name)
			local found = target:FindFirstChild(name or "", true)
			return if found and found:IsA("Attachment") then found else nil
		end
		local from = getAttachment(config.From or config.Attachment0)
		local to = getAttachment(config.To or config.Attachment1)
		if not from then
			return
		end
		local endpoint
		if not to and typeof(config.Point) == "Vector3" then
			local holder = Instance.new("Part")
			holder.Name = "VFXBeamEndpoint"
			holder.Anchored, holder.Transparency = true, 1
			holder.CanCollide, holder.CanTouch, holder.CanQuery = false, false, false
			holder.Size, holder.Position, holder.Parent = Vector3.one * 0.05, config.Point, session.Holder
			endpoint = Instance.new("Attachment")
			endpoint.Parent = holder
			to = endpoint
		end
		if not to then
			return
		end
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = from, to
		beam.Color = ColorSequence.new(config.Color or context.Color or Color3.new(1, 1, 1))
		beam.Width0, beam.Width1 = config.Width0 or 0.4, config.Width1 or 0.05
		beam.Texture, beam.TextureSpeed = config.Texture or "", config.TextureSpeed or 0
		beam.Parent = from.Parent
		session:AddCleanup(function()
			if beam.Parent then
				beam:Destroy()
			end
		end)
		if config.Duration then
			local started = os.clock()
			local connection = RunService.Heartbeat:Connect(function()
				if os.clock() - started >= math.clamp(config.Duration, 0.05, 30) and beam.Parent then
					beam:Destroy()
					connection:Disconnect()
				end
			end)
			session:AddConnection(connection)
		end
	end,
}
