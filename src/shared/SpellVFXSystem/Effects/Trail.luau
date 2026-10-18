--!strict
-- Adds a Trail between named attachments on a BasePart/Model.
return {
	Run = function(session, config, target, context)
		if typeof(target) ~= "Instance" then
			return
		end
		local function attachment(name)
			local item = target:FindFirstChild(name or "", true)
			return if item and item:IsA("Attachment") then item else nil
		end
		local a0, a1 = attachment(config.Attachment0), attachment(config.Attachment1)
		if not a0 or not a1 then
			return
		end
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(config.Color or context.Color or Color3.new(1, 1, 1))
		trail.Lifetime = math.clamp(config.Lifetime or 0.35, 0.05, 10)
		trail.Transparency = config.Transparency or NumberSequence.new(0, 1)
		trail.Parent = a0.Parent
		session:AddCleanup(function()
			if trail.Parent then
				trail:Destroy()
			end
		end)
	end,
}
