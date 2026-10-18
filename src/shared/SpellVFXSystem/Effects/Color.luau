--!strict
-- Tints supported visual descendants immediately or over time; never changes gameplay state.
local TweenService = game:GetService("TweenService")
return {
	Run = function(session, config, target, context)
		if typeof(target) ~= "Instance" then
			return
		end
		local color = config.Color or context.Color
		if typeof(color) ~= "Color3" then
			return
		end
		local duration = math.clamp(tonumber(config.Duration) or 0, 0, 10)
		local targets = {}
		if target:IsA("ParticleEmitter") or target:IsA("Beam") or target:IsA("Trail") or target:IsA("Light") then
			table.insert(targets, target)
		end
		for _, item in target:GetDescendants() do
			if item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Light") then
				table.insert(targets, item)
			end
		end
		for _, item in targets do
			local property = if item:IsA("Light") then "Color" else "Color"
			if duration == 0 then
				item[property] = color
			else
				local goal = if item:IsA("Beam")
						or item:IsA("Trail")
						or item:IsA("ParticleEmitter")
					then { Color = ColorSequence.new(color) }
					else { Color = color }
				local tween = TweenService:Create(item, TweenInfo.new(duration), goal)
				session:AddTween(tween):Play()
			end
		end
	end,
}
