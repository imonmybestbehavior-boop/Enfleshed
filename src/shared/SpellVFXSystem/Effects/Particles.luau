--!strict
-- Clones a named ParticleEmitter template and can follow a moving BasePart.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local function findTargetPart(target, name)
	if typeof(target) ~= "Instance" then
		return nil
	end
	if name and name ~= "" then
		local found = target:FindFirstChild(name, true)
		if found and found:IsA("Attachment") then
			return found
		end
	end
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end
return {
	Run = function(session, config, target, context)
		local assets = ReplicatedStorage:FindFirstChild(config.AssetsFolder or "SpellVFXAssets")
		local template = assets and assets:FindFirstChild(config.Template or "")
		local parent = findTargetPart(target, config.Attachment)
		if not parent then
			return
		end
		local emitter
		if template and template:IsA("ParticleEmitter") then
			emitter = template:Clone()
		else
			emitter = Instance.new("ParticleEmitter")
			local fireTemplate = string.find(config.Template or "", "Fire") ~= nil
			emitter.Texture = if fireTemplate
				then "rbxasset://textures/particles/fire_main.dds"
				else "rbxasset://textures/particles/sparkles_main.dds"
			emitter.Lifetime = if fireTemplate then NumberRange.new(0.3, 0.65) else NumberRange.new(0.35, 0.85)
			emitter.Speed = if fireTemplate then NumberRange.new(0.3, 1.8) else NumberRange.new(4, 12)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = if fireTemplate then NumberSequence.new(1.05, 0) else NumberSequence.new(0.28, 0)
			emitter.Transparency = NumberSequence.new(0.05, 1)
			emitter.LightEmission = 0.9
		end
		if typeof(config.Color or context.Color) == "Color3" then
			emitter.Color = ColorSequence.new(config.Color or context.Color)
		end
		if type(config.Rate) == "number" then
			emitter.Rate = math.clamp(config.Rate, 0, 100)
			emitter.Enabled = emitter.Rate > 0
		end
		if type(config.Count) == "number" then
			emitter:Emit(math.clamp(math.floor(config.Count), 0, 500))
		end
		if config.Speed then
			emitter.Speed = typeof(config.Speed) == "NumberRange" and config.Speed or NumberRange.new(config.Speed)
		end
		if config.Size then
			emitter.Size = typeof(config.Size) == "NumberSequence" and config.Size or NumberSequence.new(config.Size)
		end
		emitter.Parent = parent
		if config.Follow then
			emitter.Parent = parent
			session:AddCleanup(function()
				if emitter.Parent then
					local lifetime = math.clamp(config.Lifetime or 3, 0.1, 30)
					local attachment = Instance.new("Attachment")
					attachment.Name = "ExpiredVFXTrail"
					attachment.Parent = emitter.Parent
					emitter.Parent = attachment
					emitter.Enabled = false
					task.delay(math.clamp(config.Lifetime or 3, 0.1, 30), function()
						if attachment.Parent then
							attachment:Destroy()
						end
					end)
				end
			end)
		else
			Debris:AddItem(emitter, math.clamp(config.Lifetime or 3, 0.1, 30))
			session:AddCleanup(function()
				if emitter.Parent then
					emitter:Destroy()
				end
			end)
		end
	end,
}
