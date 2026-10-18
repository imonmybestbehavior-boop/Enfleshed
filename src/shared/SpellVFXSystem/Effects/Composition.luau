-- Existing preset playback routes through the same composer; no missing template assets.
local Analyzer = require(script.Parent.Parent.Core.SpellVFXAnalyzer)
local Composer = require(script.Parent.Parent.Core.SpellVFXComposer)
return {
	Run = function(session, config, target, context)
		local anchor = target
		if typeof(target) == "Vector3" then
			anchor = Instance.new("Part")
			anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
			anchor.Transparency = 1
			anchor.Position = target
			anchor.Parent = session.Holder
		elseif target:IsA("Model") then
			anchor = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		end
		if not anchor or not anchor:IsA("BasePart") then
			return
		end
		local plan = Analyzer.resolve({
			Form = config.Form,
			Element = config.Element,
			Visual = { Color = context.Color, VFXDefinition = config.Preset },
		})
		plan.Phase = config.Phase
		local effect = Composer.attach(
			anchor,
			plan,
			{ Parent = session.Holder, Duration = config.Duration or 3, Size = Vector3.one * 3 }
		)
		if effect then
			session:AddCleanup(function()
				effect:Stop()
			end)
		end
	end,
}
