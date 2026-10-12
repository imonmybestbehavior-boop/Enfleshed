--!strict
-- Reusable replicated presentation only; no hit tests or gameplay effects.
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicPresentation)
local BudgetSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicPresentationBudget)
local VisualSpec = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicVisualSpec)
local TweenService = game:GetService("TweenService")
local Presentation = {}
local castRemote
local particleBudget = BudgetSpec.new(Config.ParticleBudget, os.clock())
function Presentation.start(folder)
	castRemote = Instance.new("RemoteEvent")
	castRemote.Name = "MagicPresentation"
	castRemote.Parent = folder
end
local function visualSettings(definition)
	return (definition and definition.Visual) or {}
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
local function environmentalLayer(parent: BasePart, definition: any?)
	local settings = visualSettings(definition)
	local style = settings.EnvironmentalVisual or "None"
	if style == "None" then
		return
	end
	local color = settings.SecondaryColor or settings.Color or Color3.new(1, 1, 1)
	local particleStyle = if style == "GroundMist" then "Smoke" else "Sparks"
	local emitter = particles(parent, color, 2, particleStyle, settings.Emission)
	if not emitter then
		return
	end
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(35, 35)
	if style == "GroundMist" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Lifetime = NumberRange.new(1.2, 2.2)
		emitter.Speed = NumberRange.new(0.1, 0.7)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.2) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	else
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Speed = NumberRange.new(0.3, 1.2)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.35) })
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
	Presentation.playSound(
		definition,
		"ChargeSoundId",
		if root and root:IsA("BasePart") then root.Position else character:GetPivot().Position,
		root
	)
	if settings.CastingStyle == "GroundSigil" and root and root:IsA("BasePart") then
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
	if settings.CastingStyle ~= "None" and settings.ParticleStyle ~= "None" then
		for _, name in { "RightHand", "LeftHand", "Right Arm", "Left Arm" } do
			local hand = character:FindFirstChild(name)
			if hand and hand:IsA("BasePart") then
				local attachment = Instance.new("Attachment")
				attachment.Name = "MagicCastGlow"
				attachment.Position = Vector3.new(0, -hand.Size.Y * 0.4, 0)
				attachment.Parent = hand
				emitParticles(
					particles(attachment, definition.Visual.Color, 0, settings.ParticleStyle, settings.Emission),
					10
				)
				Debris:AddItem(attachment, duration + 0.2)
			end
		end
	end
end
function Presentation.release(character, definition)
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
		if hand and hand:IsA("BasePart") and settings.ParticleStyle ~= "None" then
			emitParticles(
				particles(
					hand,
					settings.AccentColor or definition.Visual.Color,
					0,
					settings.ParticleStyle,
					settings.Emission
				),
				12
			)
			break
		end
	end
end
function Presentation.cancel(character, definition)
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
	surfacePulse(hit, definition)
	local style = settings.ImpactStyle or "Burst"
	if style == "None" then
		return
	end
	if style == "Ring" or style == "Pulse" then
		local part = Instance.new("Part")
		part.Name = if style == "Ring" then "MagicImpactRing" else "MagicImpactPulse"
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.Material = Presentation.material(definition)
		part.Color = settings.AccentColor or settings.SecondaryColor or color
		part.Transparency = 1 - (settings.Opacity or 0.85)
		part.Position = position
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
		part.Parent = workspace
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
	local anchor = Instance.new("Part")
	anchor.Name = "MagicImpact"
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Position = position
	anchor.Parent = workspace
	local emitterColor = settings.AccentColor or settings.SecondaryColor or color
	local emitter = particles(anchor, emitterColor, 0, settings.ParticleStyle, settings.Emission)
	if emitter then
		emitter.Speed = NumberRange.new(3, 8)
	end
	emitParticles(emitter, 18)
	Debris:AddItem(anchor, 0.7)
end
function Presentation.construct(part: BasePart, particleCount: number?, definition: any?)
	local settings = visualSettings(definition)
	local finalTransparency = 1 - (settings.Opacity or 0.85)
	part.Transparency = 0.85
	TweenService:Create(part, TweenInfo.new(0.25), { Transparency = finalTransparency }):Play()
	if settings.ParticleStyle ~= "None" then
		emitParticles(
			particles(part, settings.SecondaryColor or part.Color, 0, settings.ParticleStyle, settings.Emission),
			particleCount or 20
		)
	end
end
function Presentation.finish(part: Instance)
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
	local emitter = if settings.ParticleStyle == "None"
		then nil
		else particles(
			part,
			settings.SecondaryColor or part.Color,
			Config.ParticleRate,
			settings.ParticleStyle,
			settings.Emission
		)
	if emitter then
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35 * appearanceScale),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position, b.Position = Vector3.new(0, 0.25 * appearanceScale, 0), Vector3.new(0, -0.25 * appearanceScale, 0)
	a.Parent, b.Parent = part, part
	if (settings.TrailStyle or "Ribbon") == "Ribbon" then
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a, b
		trail.Color = ColorSequence.new(part.Color, settings.AccentColor or settings.SecondaryColor or part.Color)
		trail.LightEmission = settings.Emission or 1
		trail.Lifetime = 0.25
		trail.FaceCamera = true
		trail.WidthScale = NumberSequence.new(appearanceScale, 0)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Parent = part
	elseif settings.TrailStyle == "Particles" and settings.ParticleStyle ~= "None" then
		local trailParticles = particles(
			a,
			settings.SecondaryColor or part.Color,
			Config.ParticleRate,
			settings.ParticleStyle,
			settings.Emission
		)
		if trailParticles then
			trailParticles.Lifetime = NumberRange.new(0.18, 0.32)
			trailParticles.Speed = NumberRange.new(0.1, 0.8)
		end
	end
	Presentation.attachLoop(definition, "TravelSoundId", part)
	return part
end

function Presentation.marker(
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	duration: number?,
	shape: Enum.PartType?
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
	for i = 1, Config.AreaNodes do
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

local function finishAreaMarker(marker: BasePart, definition: any?, size: Vector3)
	environmentalLayer(marker, definition)
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
			Presentation.marker(name, frame.Position, Vector3.new(flatHeight or 0.15, size.X, size.Z), color),
			definition,
			size
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
		return finishAreaMarker(marker, definition, size)
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
		return finishAreaMarker(anchor, definition, size)
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
	particles(part, color, 2)
	return finishAreaMarker(part, definition, size)
end

function Presentation.resizeAreaMarker(
	marker: BasePart,
	shape: string,
	frame: CFrame,
	size: Vector3,
	flatHeight: number?
)
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

function Presentation.beam(
	origin: Vector3,
	endpoint: Vector3,
	width: number,
	color: Color3,
	duration: number,
	definition: any?
)
	if (endpoint - origin).Magnitude < 0.01 then
		return
	end
	local settings = visualSettings(definition)
	local secondary = settings.SecondaryColor or color
	local lifetime = math.max(0.45, duration)
	local model = Instance.new("Model")
	model.Name = "MagicBeamFlash"
	model.Parent = workspace
	local function endpointPart(position)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Shape, p.Material, p.Color = Enum.PartType.Ball, Presentation.material(definition), color
		p.Size = Vector3.one * math.max(1.8, width)
		p.Position = position
		p.Parent = model
		local attachment = Instance.new("Attachment")
		attachment.Parent = p
		game:GetService("TweenService")
			:Create(p, TweenInfo.new(lifetime), { Transparency = 1, Size = p.Size * 1.7 })
			:Play()
		return attachment
	end
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = endpointPart(origin), endpointPart(endpoint)
	beam.FaceCamera = true
	beam.Width0, beam.Width1 = math.max(1.4, width), math.max(1.4, width)
	beam.Color = ColorSequence.new(color, secondary)
	beam.LightEmission = settings.Emission or 1
	beam.Texture = Config.ParticleTexture
	beam.TextureSpeed = 3
	beam.TextureLength = 2
	beam.Parent = model
	local core = beam:Clone()
	core.Name = "BeamCore"
	core.Texture = ""
	core.Width0, core.Width1 = math.max(0.3, width * 0.3), math.max(0.3, width * 0.3)
	core.Color = ColorSequence.new(settings.AccentColor or Color3.new(1, 1, 1))
	core.Parent = model
	TweenService:Create(core, TweenInfo.new(lifetime), { Width0 = 0, Width1 = 0 }):Play()
	game:GetService("TweenService"):Create(beam, TweenInfo.new(lifetime), { Width0 = 0, Width1 = 0 }):Play()
	Debris:AddItem(model, lifetime)
end
return Presentation
