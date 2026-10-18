--!strict
-- Creates a named attachment on a target BasePart or Model root.
return {
	Run = function(session, config, target)
		local parent = target
		if typeof(target) == "Instance" and target:IsA("Model") then
			parent = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		end
		if typeof(parent) ~= "Instance" or not parent:IsA("BasePart") then
			return
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = config.Name or "VFXAttachment"
		attachment.Position = config.Position or Vector3.zero
		attachment.Parent = parent
		session:AddCleanup(function()
			if attachment.Parent then
				attachment:Destroy()
			end
		end)
	end,
}
