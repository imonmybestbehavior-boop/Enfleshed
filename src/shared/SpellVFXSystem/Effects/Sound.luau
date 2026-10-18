--!strict
-- Plays a positional sound asset and releases it when the session ends.
local Debris = game:GetService("Debris")
return {
	Run = function(session, config, target)
		local parent
		if typeof(target) == "Instance" then
			parent = target
			if target:IsA("Model") then
				parent = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
			end
		elseif typeof(target) == "Vector3" then
			local part = Instance.new("Part")
			part.Name, part.Anchored, part.Transparency = "VFXSoundPoint", true, 1
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.Size, part.Position, part.Parent = Vector3.one * 0.1, target, session.Holder
			parent = part
		end
		if not parent then
			return
		end
		local sound = Instance.new("Sound")
		sound.SoundId = config.SoundId or ""
		sound.Volume = math.clamp(config.Volume or 0.5, 0, 10)
		sound.PlaybackSpeed = math.clamp(config.Pitch or 1, 0.25, 4)
		sound.RollOffMaxDistance = math.clamp(config.Range or 80, 1, 500)
		sound.Parent = parent
		sound:Play()
		Debris:AddItem(sound, math.clamp(config.Lifetime or 10, 0.1, 30))
		session:AddCleanup(function()
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end)
	end,
}
