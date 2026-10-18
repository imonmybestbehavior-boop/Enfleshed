--!strict
-- Reusable replicated presentation only; no hit tests or gameplay effects.
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicPresentation)
local BudgetSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicPresentationBudget)
local VisualSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicVisualSpec)
local TweenService = game:GetService("TweenService")
local Analyzer = require(game:GetService("ReplicatedStorage").Shared.SpellVFXSystem.Core.SpellVFXAnalyzer)
local SignaturePlanner = require(game:GetService("ReplicatedStorage").Shared.SpellVFXSystem.Signature.SignaturePlanner)
local Presentation = {}

-- Spells covered by a client signature (generated-asset VFX) skip the legacy primitive extras
-- below (hand motes, impact particles/rings, surface pulse). Anchors, sounds and cues still run.
local function signatureCovered(definition)
	if type(definition) ~= "table" then
		return false
	end
	local ok, covered = pcall(function()
		return SignaturePlanner.match(Analyzer.resolve(definition)) ~= nil
	end)
	return ok and covered
end
local castRemote
local particleBudget = BudgetSpec.new(Config.ParticleBudget, os.clock())
function Presentation.start(folder)
	local existing = folder:FindFirstChild("MagicPresentation")
	if existing and existing:IsA("RemoteEvent") then
		castRemote = existing
	else
		castRemote = Instance.new("RemoteEvent")
		castRemote.Name = "MagicPresentation"
		castRemote.Parent = folder
	end
end
local function visualSettings(definition)
	return (definition and definition.Visual) or {}
end

local function spellElement(definition)
	return (definition and definition.Element)
		or (definition and definition.Source and definition.Source.Expression)
		or "Neutral"
end

local function effectColors(definition, fallback)
	local settings = visualSettings(definition)
	return settings.Color or fallback,
		settings.SecondaryColor or settings.Color or fallback,
		settings.AccentColor or Color3.new(1, 1, 1)
end

local function addImpactLight(parent, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Name = "MagicImpactLight"
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	TweenService:Create(light, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()
end

local function playCustomVFX(definition, target, context)
	-- Authored presets are resolved into the same geometry-aware composition.
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		Analyzer.stamp(target, definition)
	end
	return
end
function Presentation.material(definition)
	local name = visualSettings(definition).MaterialAppearance
	if name == nil or name == "Auto" then
		name = VisualSpec.autoMaterial(
			definition and definition.Source and definition.Source.Principle,
			definition and definition.Source and definition.Source.Expression,
			definition and definition.Form
		)
	end
	local material = if type(name) == "string" then Enum.Material[name] else nil
	return material or Enum.Material.Neon
end
local function particles(parent, color, rate, style, emission)
	if not BudgetSpec.acquireEmitter(particleBudget, rate) then
		return nil
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = Config.ParticleTexture
	if style == "Smoke" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	elseif style == "Embers" then
		emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
		emitter.Lifetime = NumberRange.new(0.35, 0.8)
		emitter.Speed = NumberRange.new(1, 4)
	else
		emitter.Lifetime = NumberRange.new(0.2, 0.55)
		emitter.Speed = NumberRange.new(0.5, 2)
	end
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = emission or 0.8
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Rate = rate
	emitter.Parent = parent
	local released = false
	emitter.Destroying:Connect(function()
		if not released then
			released = true
			BudgetSpec.releaseEmitter(particleBudget, rate)
		end
	end)
	return emitter
end
local function emitParticles(emitter: ParticleEmitter?, count: number)
	if not emitter or not emitter.Parent then
		return
	end
	local allowed = BudgetSpec.takeBurst(particleBudget, count, os.clock())
	if allowed > 0 then
		emitter:Emit(allowed)
	end
end
function Presentation.profile(definition)
	local profile = definition.Visual.Profile
	if not profile or profile == "Auto" then
		profile = Config.Forms[definition.Form]
	end
	return profile
end
function Presentation.timing(definition)
	local profile = Presentation.profile(definition)
	return Config.Timing[profile] or Config.Timing.ProjectileCast
end
local function cue(character, profile, phase, duration, gather)
	if castRemote then
		castRemote:FireAllClients(character, profile, phase, duration, gather)
	end
end

function Presentation.vfx(definition, target, context)
	playCustomVFX(definition, target, context or {})
end
local function audioId(definition, key)
	local audio = definition and definition.Audio
	local id = audio and audio[key]
	return if type(id) == "string" and id ~= "" and string.match(id, "^%d+$") then id else nil
end
local function makeSound(definition, key, parent, looped)
	local id = audioId(definition, key)
	if not id or not parent or (definition.Audio.Volume or 0) <= 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "MagicAudio_" .. key
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = math.clamp(definition.Audio.Volume or 0.6, 0, 1)
	sound.RollOffMaxDistance = math.clamp(definition.Audio.RollOffMaxDistance or 80, 10, 250)
	sound.EmitterSize = 5
	sound.Looped = looped
	sound.Parent = parent
	sound:Play()
	if not looped then
		Debris:AddItem(sound, 20)
	end
	return sound
end
function Presentation.playSound(definition, key, position: Vector3, parent: Instance?)
	local emitter = parent
	if not emitter then
		local anchor = Instance.new("Part")
		anchor.Name = "MagicAudioEmitter"
		anchor.Size = Vector3.one * 0.1
		anchor.Position = position
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		anchor.Parent = workspace
		emitter = anchor
		local sound = makeSound(definition, key, emitter, false)
		if sound then
			Debris:AddItem(anchor, 20)
		else
			anchor:Destroy()
		end
		return sound
	end
	return makeSound(definition, key, emitter, false)
end
function Presentation.attachLoop(definition, key, parent: Instance)
	return makeSound(definition, key, parent, true)
end
function Presentation.stopLoop(parent: Instance, key: string)
	local sound = parent:FindFirstChild("MagicAudio_" .. key)
	if sound and sound:IsA("Sound") then
		Presentation.stopSound(sound)
	end
end
function Presentation.stopSound(sound: Sound?)
	if sound and sound.Parent then
		sound:Stop()
		sound:Destroy()
	end
end
local function stopAttachedAudio(parent: Instance)
	for _, child in parent:GetDescendants() do
		if child:IsA("Sound") and string.sub(child.Name, 1, 11) == "MagicAudio_" then
			Presentation.stopSound(child)
		end
	end
end
function Presentation.gather(character, definition, duration, gather, phase)
	local profile = Presentation.profile(definition)
	cue(character, profile, phase or "Gather", math.clamp(duration, 0.1, Config.MaxPoseDuration), gather)
	local settings = visualSettings(definition)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and settings.CastingStyle ~= "None" then
		local glow = Instance.new("Part")
		glow.Name = "SpellGatherComposition"
		glow.Transparency = 1
		glow.CanCollide, glow.CanTouch, glow.CanQuery = false, false, false
		glow.Massless = true
		glow.CFrame = root.CFrame
		glow.Parent = character
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, glow, glow
		Analyzer.stamp(glow, definition, Vector3.new(3, 4, 3), "Gather")
		Debris:AddItem(glow, duration + 0.1)
	end
	Presentation.playSound(
		definition,
		"ChargeSoundId",
		if root and root:IsA("BasePart") then root.Position else character:GetPivot().Position,
		root
	)
	if
		settings.CastingStyle == "GroundSigil"
		and root
		and root:IsA("BasePart")
		and not signatureCovered(definition)
	then
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { character }
		rayParams.RespectCanCollide = true
		local floor = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams)
		if floor then
			Presentation.marker(
				"MagicCastSigil",
				floor.Position + Vector3.new(0, 0.05, 0),
				Vector3.new(0.12, 5, 5),
				settings.AccentColor or definition.Visual.Color,
				duration
			)
		end
	end
	if settings.CastingStyle ~= "None" and settings.ParticleStyle ~= "None" and not signatureCovered(definition) then
		local element = spellElement(definition)
		local primary, secondary, accent = effectColors(definition, settings.Color)
		for _, name in { "RightHand", "LeftHand", "Right Arm", "Left Arm" } do
			local hand = character:FindFirstChild(name)
			if hand and hand:IsA("BasePart") then
				local attachment = Instance.new("Attachment")
				attachment.Name = "MagicCastGlow"
				attachment.Position = Vector3.new(0, -hand.Size.Y * 0.4, 0)
				attachment.Parent = hand
				local style = if element == "Fire"
					then "Embers"
					elseif element == "Poison" then "Smoke"
					else settings.ParticleStyle
				local emitter = particles(attachment, primary, 0, style, settings.Emission)
				if emitter then
					emitter.Name = "MagicGatherMotes"
					emitter.Lifetime = NumberRange.new(0.35, 0.75)
					emitter.Speed = NumberRange.new(1.2, 3.2)
					emitter.Size =
						NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
					emitter.Color = ColorSequence.new(secondary, accent)
				end
				emitParticles(emitter, 16)
				local light = Instance.new("PointLight")
				light.Name = "MagicGatherLight"
				light.Color = primary
				light.Range = if element == "Fire" then 8 else 5
				light.Brightness = 1.2
				light.Shadows = false
				light.Parent = attachment
				TweenService:Create(light, TweenInfo.new(math.max(0.2, duration)), { Brightness = 0 }):Play()
				Debris:AddItem(attachment, duration + 0.2)
			end
		end
	end
end
function Presentation.release(character, definition)
	for _, child in character:GetChildren() do
		if child.Name == "SpellGatherComposition" then
			child:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local anchor = Instance.new("Part")
		anchor.Name = "SpellReleaseComposition"
		anchor.Size = Vector3.one
		anchor.Transparency = 1
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		anchor.Massless = true
		anchor.CFrame = root.CFrame
		anchor.Parent = workspace
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, anchor, anchor
		Analyzer.stamp(anchor, definition, Vector3.new(5, 6, 5), "Release")
		Debris:AddItem(anchor, 0.6)
	end
	local timing = Presentation.timing(definition)
	cue(character, Presentation.profile(definition), "Release", timing.Release + timing.Recovery, timing.Release)
	local settings = visualSettings(definition)
	local root = character:FindFirstChild("HumanoidRootPart")
	Presentation.playSound(
		definition,
		"CastSoundId",
		if root and root:IsA("BasePart") then root.Position else character:GetPivot().Position,
		root
	)
	for _, name in { "RightHand", "Right Arm" } do
		local hand = character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") and settings.ParticleStyle ~= "None" and not signatureCovered(definition) then
			local element = spellElement(definition)
			local style = if element == "Fire"
				then "Embers"
				elseif element == "Poison" then "Smoke"
				else settings.ParticleStyle
			local attachment = Instance.new("Attachment")
			attachment.Name = "MagicReleaseFlash"
			attachment.Position = Vector3.new(0, -hand.Size.Y * 0.35, 0)
			attachment.Parent = hand
			local emitter =
				particles(attachment, settings.AccentColor or definition.Visual.Color, 0, style, settings.Emission)
			if emitter then
				emitter.Name = "MagicReleaseMotes"
				emitter.Speed = NumberRange.new(2.5, 6)
				emitter.Size =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
			end
			emitParticles(emitter, 22)
			local light = Instance.new("PointLight")
			light.Name = "MagicReleaseLight"
			light.Color = settings.Color
			light.Range = if element == "Fire" then 10 else 6
			light.Brightness = 1.8
			light.Shadows = false
			light.Parent = attachment
			TweenService:Create(light, TweenInfo.new(0.22), { Brightness = 0 }):Play()
			Debris:AddItem(attachment, 0.75)
			break
		end
	end
end
function Presentation.cancel(character, definition)
	for _, child in character:GetChildren() do
		if child.Name == "SpellGatherComposition" then
			child:Destroy()
		end
	end
	cue(character, Presentation.profile(definition), "Cancel", 0, 0)
end
function Presentation.sustain(character, definition)
	cue(character, Presentation.profile(definition), "Sustain", 0, 0)
end
function Presentation.handOrigin(character, fallback)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") and (hand.Position - fallback).Magnitude < 6 then
		return hand.Position - hand.CFrame.UpVector * hand.Size.Y * 0.35 + Vector3.yAxis * 0.9
	end
	return fallback
end

local function surfacePulse(hit, definition)
	local settings = visualSettings(definition)
	if settings.SurfaceBehavior ~= "Pulse" or not hit or not hit.Instance then
		return
	end
	local surface = hit.Instance
	if surface:IsA("BasePart") then
		if not surface.Anchored then
			return
		end
		local model = surface:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return
		end
	elseif not surface:IsA("Terrain") then
		return
	end
	-- Spend from the existing shared cosmetic burst budget; this effect never
	-- creates a gameplay part or participates in hit detection.
	if BudgetSpec.takeBurst(particleBudget, 1, os.clock()) == 0 then
		return
	end
	local normal = if typeof(hit.Normal) == "Vector3" and hit.Normal.Magnitude > 0.001
		then hit.Normal.Unit
		else Vector3.yAxis
	local seed = if math.abs(normal:Dot(Vector3.yAxis)) < 0.95 then Vector3.yAxis else Vector3.zAxis
	local yAxis = (seed - normal * seed:Dot(normal)).Unit
	local zAxis = normal:Cross(yAxis).Unit
	local pulse = Instance.new("Part")
	pulse.Name = "MagicSurfacePulse"
	pulse.Shape = Enum.PartType.Cylinder
	pulse.Size = Vector3.new(0.06, 0.35, 0.35)
	pulse.CFrame = CFrame.fromMatrix(hit.Position + normal * 0.04, normal, yAxis, zAxis)
	pulse.Anchored = true
	pulse.CanCollide, pulse.CanTouch, pulse.CanQuery = false, false, false
	pulse.Material = Presentation.material(definition)
	pulse.Color = settings.AccentColor or settings.SecondaryColor or settings.Color
	pulse.Transparency = 1 - (settings.Opacity or 0.85)
	pulse.Parent = workspace
	TweenService:Create(pulse, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.06, 3.5, 3.5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(pulse, 0.65)
end

function Presentation.impact(position, color, definition, hit)
	local settings = visualSettings(definition)
	playCustomVFX(
		definition,
		position,
		{ Caster = definition._VFXCaster, Element = definition.Element, Color = color, Power = 1 }
	)
	local covered = signatureCovered(definition)
	if not covered then
		surfacePulse(hit, definition)
	end
	local style = settings.ImpactStyle or "Burst"
	if style == "None" then
		return
	end
	local sparkAnchor = Instance.new("Part")
	sparkAnchor.Name = "MagicElementImpact"
	sparkAnchor.Anchored, sparkAnchor.CanCollide, sparkAnchor.CanTouch, sparkAnchor.CanQuery = true, false, false, false
	sparkAnchor.Transparency = 1
	sparkAnchor.Size = Vector3.one * 0.1
	sparkAnchor.Position = position
	sparkAnchor.Parent = workspace
	Analyzer.stamp(sparkAnchor, definition, Vector3.one * 5, "Impact")
	Debris:AddItem(sparkAnchor, 0.8)
	if covered then
		return
	end
	local element = spellElement(definition)
	local burstStyle = if element == "Fire"
		then "Embers"
		elseif element == "Poison" then "Smoke"
		else settings.ParticleStyle
	local burstColor = settings.AccentColor or settings.SecondaryColor or color
	local burst = if settings.ParticleStyle == "None"
		then nil
		else particles(sparkAnchor, burstColor, 0, burstStyle, settings.Emission)
	if burst then
		burst.Speed =
			NumberRange.new(if element == "Lightning" then 8 else 4, if element == "Lightning" then 18 else 11)
		burst.Lifetime = NumberRange.new(0.25, 0.65)
		burst.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if element == "Fire" then 1.15 else 0.7),
			NumberSequenceKeypoint.new(1, 0),
		})
		burst.LightEmission = 1
	end
	emitParticles(burst, if element == "Fire" then 28 else 20)
	addImpactLight(sparkAnchor, color, if element == "Fire" then 16 else 10, if element == "Fire" then 2.5 else 1.4)
	Debris:AddItem(sparkAnchor, 0.8)
	if style == "Ring" or style == "Pulse" then
		local part = Instance.new("Part")
		part.Name = if style == "Ring" then "MagicImpactRing" else "MagicImpactPulse"
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Material = Presentation.material(definition)
		part.Color = settings.AccentColor or settings.SecondaryColor or color
		part.Transparency = 1 - (settings.Opacity or 0.85)
		part.Position = position
		part.Parent = workspace
		if style == "Ring" then
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.08, 0.7, 0.7)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
			TweenService:Create(part, TweenInfo.new(0.35), { Size = Vector3.new(0.08, 5, 5), Transparency = 1 }):Play()
		else
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * 0.2
			TweenService:Create(part, TweenInfo.new(0.3), { Size = Vector3.one * 4, Transparency = 1 }):Play()
		end
		Debris:AddItem(part, 0.45)
		return
	end
	if style == "Cross" then
		for index, angle in { -45, 45 } do
			local bar = Instance.new("Part")
			bar.Name = "MagicImpactCross"
			bar.Anchored, bar.CanCollide, bar.CanTouch, bar.CanQuery = true, false, false, false
			bar.Material = Presentation.material(definition)
			bar.Color = settings.AccentColor or color
			bar.Transparency = 1 - (settings.Opacity or 0.85)
			bar.Size = Vector3.new(0.18, 0.18, 0.4)
			bar.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, math.rad(angle), 0)
			bar.Parent = workspace
			TweenService:Create(bar, TweenInfo.new(0.28), {
				Size = Vector3.new(0.18, 0.18, 3.5),
				Transparency = 1,
			}):Play()
			Debris:AddItem(bar, 0.35)
		end
		return
	end
	if settings.ParticleStyle == "None" then
		return
	end
end
function Presentation.construct(part: BasePart, particleCount: number?, definition: any?)
	Analyzer.stamp(part, definition, part.Size)
	local settings = visualSettings(definition)
	local finalTransparency = 1 - (settings.Opacity or 0.85)
	local element = spellElement(definition)
	local primary, secondary, accent = effectColors(definition, part.Color)
	part.Transparency = 0.85
	TweenService:Create(part, TweenInfo.new(0.25), { Transparency = finalTransparency }):Play()
	local outline = Instance.new("Highlight")
	outline.Name = "MagicConstructHighlight"
	outline.Adornee = part
	outline.FillColor = primary
	outline.FillTransparency = 0.88
	outline.OutlineColor = accent
	outline.OutlineTransparency = 0.18
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = part
	local light = Instance.new("PointLight")
	light.Name = "MagicConstructLight"
	light.Color = secondary
	light.Range = math.clamp(part.Size.Magnitude * 0.45, 6, 18)
	light.Brightness = 0.75
	light.Shadows = false
	light.Parent = part
	local top = Instance.new("Attachment")
	top.Name = "MagicConstructCrest"
	top.Position = Vector3.new(0, part.Size.Y * 0.5, 0)
	top.Parent = part
	local crest = if settings.ParticleStyle == "None"
		then nil
		else particles(
			top,
			accent,
			0,
			if element == "Fire" then "Embers" else settings.ParticleStyle,
			settings.Emission
		)
	if crest then
		crest.Name = "MagicConstructCrestMotes"
		crest.EmissionDirection = Enum.NormalId.Top
		crest.SpreadAngle = Vector2.new(22, 22)
		crest.Lifetime = NumberRange.new(0.5, 1.1)
		crest.Speed = NumberRange.new(0.25, 1.2)
		crest.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, math.clamp(part.Size.Magnitude * 0.04, 0.25, 0.9)),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	if settings.ParticleStyle ~= "None" then
		emitParticles(particles(part, secondary, 0, settings.ParticleStyle, settings.Emission), particleCount or 20)
	end
end
function Presentation.finish(part: Instance)
	part:SetAttribute("VFXPhase", "End")
	for _, child in part:GetDescendants() do
		if child:IsA("BasePart") then
			child:SetAttribute("VFXPhase", "End")
		end
	end
	stopAttachedAudio(part)
	if part:IsA("Model") then
		for _, object in part:GetDescendants() do
			if object:IsA("BasePart") then
				object.CanCollide, object.CanTouch, object.CanQuery = false, false, false
				TweenService:Create(object, TweenInfo.new(0.35), { Transparency = 1 }):Play()
			elseif object:IsA("ParticleEmitter") then
				object.Enabled = false
			end
		end
		Debris:AddItem(part, 0.6)
		return
	end
	if not part:IsA("BasePart") then
		part:Destroy()
		return
	end
	if part.Name == "MagicTemporaryConstruct" then
		local ghost = Instance.new("Part")
		ghost.Name = "MagicConstructDissolve"
		ghost.Size, ghost.CFrame, ghost.Color, ghost.Material = part.Size, part.CFrame, part.Color, part.Material
		ghost.Anchored, ghost.CanCollide, ghost.CanTouch, ghost.CanQuery = true, false, false, false
		ghost.Transparency = 0.4
		ghost.Parent = workspace
		TweenService:Create(ghost, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		emitParticles(particles(ghost, ghost.Color, 0), 12)
		Debris:AddItem(ghost, 0.6)
	end
	if part.Name ~= "MagicTemporaryConstruct" then
		for _, object in part:GetDescendants() do
			if object:IsA("ParticleEmitter") then
				object.Enabled = false
			end
		end
		part.Transparency = 1
		Debris:AddItem(part, 0.6)
	else
		part:Destroy()
	end
end
function Presentation.projectile(definition: any, position: Vector3): BasePart
	local settings = visualSettings(definition)
	local shape = settings.CoreShape or "Sphere"
	local part: BasePart = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
	part.Name = "MagicProjectile"
	if part:IsA("Part") then
		part.Shape = Enum.PartType[if shape == "Sphere" then "Ball" elseif shape == "Crystal" then "Block" else shape]
	end
	local appearanceScale = math.clamp(definition.Visual.ProjectileScale or 1, 1, 4)
	local visualRadius = definition.Projectile.Radius * appearanceScale
	part.Size = Vector3.new(visualRadius * 2, visualRadius * 2, visualRadius * 2)
	part.CFrame = CFrame.new(position)
		* (if shape == "Crystal" then CFrame.Angles(math.rad(45), math.rad(45), math.rad(45)) else CFrame.identity)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Presentation.material(definition)
	part.Color = definition.Visual.Color
	part.Parent = workspace
	part.Transparency = 1 - (settings.Opacity or 0.85)
	Analyzer.stamp(part, definition)
	Presentation.attachLoop(definition, "TravelSoundId", part)
	return part
end

function Presentation.marker(
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	duration: number?,
	shape: Enum.PartType?,
	composed: boolean?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape or Enum.PartType.Cylinder
	part.Size = size
	part.CFrame = CFrame.new(position)
		* if part.Shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Transparency, part.Material, part.Color = 0.55, Enum.Material.Neon, color
	part.Parent = workspace
	part.Transparency = 0.85
	for i = 1, if composed then 0 else Config.AreaNodes do
		local angle = i / Config.AreaNodes * math.pi * 2
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(0, math.cos(angle) * size.Y * 0.5, math.sin(angle) * size.Z * 0.5)
		attachment.Parent = part
		local emitter = particles(attachment, color, if duration then 0 else 2)
		emitParticles(emitter, 2)
	end
	if duration then
		TweenService:Create(part, TweenInfo.new(duration), { Transparency = 1 }):Play()
		Debris:AddItem(part, math.max(duration, 0.6))
	end
	return part
end

local function finishAreaMarker(marker: BasePart, definition: any?, size: Vector3, shape: string)
	marker.Transparency = 1
	for _, child in marker:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 1
		end
	end
	marker:SetAttribute("MagicAreaShape", shape)
	marker:SetAttribute("VFXRotated", shape == "Cylinder" or shape == "Capsule" or shape == "Sphere")
	Analyzer.stamp(marker, definition, size)
	local distortion = visualSettings(definition).Distortion or 0
	if distortion > 0 then
		marker:SetAttribute("MagicVisualDistortion", distortion)
		marker:SetAttribute("MagicDistortionRadius", math.max(size.X, size.Y, size.Z) / 2)
		CollectionService:AddTag(marker, "MagicDistortionArea")
	end
	return marker
end

function Presentation.areaMarker(
	name: string,
	frame: CFrame,
	shape: string,
	size: Vector3,
	color: Color3,
	flatHeight: number?,
	definition: any?
): BasePart
	if shape == "Sphere" then
		return finishAreaMarker(
			Presentation.marker(
				name,
				frame.Position,
				Vector3.new(flatHeight or 0.15, size.X, size.Z),
				color,
				nil,
				nil,
				true
			),
			definition,
			size,
			shape
		)
	end
	if shape == "Capsule" then
		local radius = size.X / 2
		local stemHeight = math.max(size.Y - radius * 2, 0.05)
		local marker = Instance.new("Part")
		marker.Name = name
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(stemHeight, size.X, size.Z)
		marker.CFrame = frame * CFrame.Angles(0, 0, math.rad(90))
		marker.Anchored = true
		marker.CanCollide, marker.CanTouch, marker.CanQuery = false, false, false
		marker.Transparency, marker.Material, marker.Color = 0.9, Enum.Material.Neon, color
		marker.Parent = workspace
		for _, sign in { -1, 1 } do
			local cap = Instance.new("Part")
			cap.Name = if sign < 0 then "CapsuleLowerCap" else "CapsuleUpperCap"
			cap.Shape = Enum.PartType.Ball
			cap.Size = Vector3.one * radius * 2
			cap.CFrame = frame * CFrame.new(0, sign * stemHeight / 2, 0)
			cap.Anchored = false
			cap.Massless = true
			cap.CanCollide, cap.CanTouch, cap.CanQuery = false, false, false
			cap.Transparency, cap.Material, cap.Color = 0.88, Enum.Material.Neon, color
			cap.Parent = marker
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = marker, cap
			weld.Parent = marker
		end
		return finishAreaMarker(marker, definition, size, shape)
	end
	if shape == "Cone" then
		local anchor = Instance.new("Part")
		anchor.Name = name
		anchor.Size = Vector3.one * 0.1
		anchor.CFrame = frame
		anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
		anchor.Transparency = 1
		anchor.Parent = workspace
		anchor:SetAttribute("MagicAreaWidth", size.X)
		anchor:SetAttribute("MagicAreaHeight", size.Y)
		anchor:SetAttribute("MagicAreaDepth", size.Z)
		local range = size.Z
		local angle = 2 * math.deg(math.atan(size.X / (2 * range)))
		local halfWidth = range * math.tan(math.rad(angle / 2))
		local halfHeight = size.Y / 2
		local function edge(first: Vector3, second: Vector3)
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Position, b.Position = first, second
			a.Parent, b.Parent = anchor, anchor
			local beam = Instance.new("Beam")
			beam.Name = "MagicConeEdge"
			beam.Attachment0, beam.Attachment1 = a, b
			beam.Color = ColorSequence.new(color)
			beam.Transparency = NumberSequence.new(0.35)
			beam.Width0, beam.Width1 = 0.08, 0.08
			beam.FaceCamera = false
			beam.Parent = anchor
		end
		for _, y in { -halfHeight, halfHeight } do
			local apex = Vector3.new(0, y, 0)
			local left = Vector3.new(-halfWidth, y, -range)
			local right = Vector3.new(halfWidth, y, -range)
			edge(apex, left)
			edge(apex, right)
			edge(left, right)
		end
		edge(Vector3.new(0, -halfHeight, 0), Vector3.new(0, halfHeight, 0))
		edge(Vector3.new(-halfWidth, -halfHeight, -range), Vector3.new(-halfWidth, halfHeight, -range))
		edge(Vector3.new(halfWidth, -halfHeight, -range), Vector3.new(halfWidth, halfHeight, -range))
		return finishAreaMarker(anchor, definition, size, shape)
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
	part.Size = if shape == "Cylinder" then Vector3.new(size.Y, size.X, size.Z) else size
	local lineOffset = if shape == "Line" then CFrame.new(0, 0, -size.Z / 2) else CFrame.identity
	part.CFrame = frame
		* lineOffset
		* (if shape == "Cylinder" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
	part.Transparency, part.Material, part.Color = 0.88, Enum.Material.Neon, color
	part.Parent = workspace
	return finishAreaMarker(part, definition, size, shape)
end

function Presentation.resizeAreaMarker(
	marker: BasePart,
	shape: string,
	frame: CFrame,
	size: Vector3,
	flatHeight: number?
)
	marker:SetAttribute("VFXSize", size)
	if shape == "Capsule" then
		local radius = size.X / 2
		local stemHeight = math.max(size.Y - radius * 2, 0.05)
		marker.Size = Vector3.new(stemHeight, size.X, size.Z)
		marker.CFrame = frame * CFrame.Angles(0, 0, math.rad(90))
		for _, child in marker:GetChildren() do
			if child:IsA("BasePart") and string.find(child.Name, "Capsule", 1, true) == 1 then
				local sign = if child.Name == "CapsuleLowerCap" then -1 else 1
				child.Size = Vector3.one * radius * 2
				child.CFrame = frame * CFrame.new(0, sign * stemHeight / 2, 0)
			end
		end
		return
	end
	local lineOffset = if shape == "Line" then CFrame.new(0, 0, -size.Z / 2) else CFrame.identity
	marker.CFrame = frame
		* lineOffset
		* (if shape == "Cylinder" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
	if shape == "Sphere" then
		marker.Size = Vector3.new(flatHeight or 0.15, size.X, size.Z)
	elseif shape == "Cone" then
		local previous = Vector3.new(
			marker:GetAttribute("MagicAreaWidth") or size.X,
			marker:GetAttribute("MagicAreaHeight") or size.Y,
			marker:GetAttribute("MagicAreaDepth") or size.Z
		)
		local ratios = Vector3.new(
			if previous.X > 0 then size.X / previous.X else 1,
			if previous.Y > 0 then size.Y / previous.Y else 1,
			if previous.Z > 0 then size.Z / previous.Z else 1
		)
		for _, child in marker:GetChildren() do
			if child:IsA("Attachment") then
				child.Position =
					Vector3.new(child.Position.X * ratios.X, child.Position.Y * ratios.Y, child.Position.Z * ratios.Z)
			end
		end
		marker:SetAttribute("MagicAreaWidth", size.X)
		marker:SetAttribute("MagicAreaHeight", size.Y)
		marker:SetAttribute("MagicAreaDepth", size.Z)
	else
		marker.Size = if shape == "Cylinder" then Vector3.new(size.Y, size.X, size.Z) else size
	end
end

function Presentation.follow(definition, target: BasePart, size: Vector3, duration: number?)
	local anchor = Instance.new("Part")
	anchor.Name = "SpellSustainedComposition"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Massless = true
	anchor.CFrame = target.CFrame
	anchor.Parent = target
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = target, anchor, anchor
	Analyzer.stamp(anchor, definition, size)
	if duration then
		Debris:AddItem(anchor, duration)
	end
	return anchor
end

function Presentation.wave(definition, frame, range, duration)
	local anchor = Instance.new("Part")
	anchor.Name = "MagicWaveComposition"
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Transparency = 1
	anchor.CFrame = frame
	anchor.Parent = workspace
	local size = if definition.Geometry == "Sphere" then Vector3.one * range * 2 else Vector3.new(range * 2, 5, range)
	Analyzer.stamp(anchor, definition, size, "Release")
	Debris:AddItem(anchor, math.max(0.65, duration))
end

function Presentation.beam(
	origin: Vector3,
	endpoint: Vector3,
	width: number,
	color: Color3,
	duration: number,
	definition: any?,
	previous: BasePart?,
	sustained: boolean?
): BasePart?
	local length = (endpoint - origin).Magnitude
	if length < 0.01 then
		if previous then
			Presentation.finish(previous)
		end
		return nil
	end
	local anchor = previous
	if not anchor or not anchor.Parent then
		anchor = Instance.new("Part")
		anchor.Name = "MagicBeamPath"
		anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.1
		anchor.CFrame = CFrame.lookAt(origin, endpoint)
		anchor.Parent = workspace
		local beamDefinition = table.clone(definition or {})
		beamDefinition.Form = "Beam"
		Analyzer.stamp(anchor, beamDefinition, Vector3.new(width, width, length), "Sustain")
		if not sustained then
			Debris:AddItem(anchor, math.max(0.15, duration))
		end
	else
		anchor.CFrame = CFrame.lookAt(origin, endpoint)
		anchor:SetAttribute("VFXSize", Vector3.new(width, width, length))
	end
	return anchor
end
return Presentation
