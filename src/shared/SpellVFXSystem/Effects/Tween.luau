--!strict
-- Tweens an explicitly named instance property map. Goals are data-only and validated by TweenService.
local TweenService = game:GetService("TweenService")
local function resolve(target, name)
	if typeof(target) ~= "Instance" then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		return target
	end
	return target:FindFirstChild(name, true)
end
return {
	Run = function(session, config, target)
		local instance = if type(config.InstanceName) == "string" and config.InstanceName ~= ""
			then session.Holder:FindFirstChild(config.InstanceName) or resolve(target, config.InstanceName)
			else resolve(target, config.InstanceName)
		if not instance or type(config.Goals) ~= "table" then
			return
		end
		local info = config.TweenInfo or {}
		local tweenInfo = TweenInfo.new(
			math.clamp(info.Duration or 0.35, 0, 30),
			info.EasingStyle or Enum.EasingStyle.Quad,
			info.EasingDirection or Enum.EasingDirection.Out,
			math.clamp(info.RepeatCount or 0, -1, 100),
			info.Reverses == true,
			math.clamp(info.DelayTime or 0, 0, 30)
		)
		local tween = TweenService:Create(instance, tweenInfo, config.Goals)
		session:AddTween(tween):Play()
	end,
}
