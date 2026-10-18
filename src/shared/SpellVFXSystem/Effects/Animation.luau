--!strict
-- Plays an Animation asset on the target's Animator; caller owns animation permissions/assets.
local function animatorFor(target)
	if typeof(target) ~= "Instance" then
		return nil
	end
	local model = if target:IsA("Model") then target else target:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	end
	local controller = model:FindFirstChildOfClass("AnimationController")
	if controller then
		return controller:FindFirstChildOfClass("Animator") or Instance.new("Animator", controller)
	end
	return nil
end
return {
	Run = function(session, config, target)
		local animator = animatorFor(target)
		if not animator or type(config.AnimationId) ~= "string" then
			return
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = config.AnimationId
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not track then
			animation:Destroy()
			return
		end
		track:Play(config.FadeTime or 0.1, config.Weight or 1, config.Speed or 1)
		session:AddCleanup(function()
			pcall(function()
				track:Stop(config.FadeTime or 0.1)
				track:Destroy()
			end)
			animation:Destroy()
		end)
	end,
}
