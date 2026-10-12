--!strict
-- Post-Animator procedural overlays for Motor6D and AnimationConstraint rigs.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.MagicPresentation)
local Protocol = require(Shared.Networking.Protocol)
local Controller = {}
local started = false
local Rig = require(Shared.Modules.MagicRig)
local PoseSpec = require(Shared.Modules.MagicPoseSpec)
function Controller.start()
	if started then
		return
	end
	started = true
	local casts = {}
	local applied = {}
	local warned = setmetatable({}, { __mode = "k" })
	local function restoreTransforms()
		for joint, previous in applied do
			if joint.Parent and joint.Transform == previous.Output then
				joint.Transform = previous.Base
			end
		end
		table.clear(applied)
	end
	RunService.PreAnimation:Connect(restoreTransforms)
	local function restore(character)
		local cast = casts[character]
		if cast then
			for _, entry in cast.Joints do
				local previous = applied[entry.Joint]
				if previous and entry.Joint.Parent and entry.Joint.Transform == previous.Output then
					entry.Joint.Transform = previous.Base
				end
				applied[entry.Joint] = nil
			end
		end
		casts[character] = nil
	end
	Shared:WaitForChild(Protocol.Folder)
		:WaitForChild("MagicPresentation").OnClientEvent
		:Connect(function(character, profile, phase, duration, gather)
			if typeof(character) ~= "Instance" or not character:IsA("Model") then
				return
			end
			if phase == "Cancel" then
				restore(character)
				return
			end
			if phase == "Release" then
				local existing = casts[character]
				if existing then
					existing.Phase = "Release"
					existing.Start = os.clock()
					existing.Duration = math.max(0.25, duration)
					existing.Gather = 0
				end
				return
			end
			if phase == "Sustain" then
				local existing = casts[character]
				if existing then
					existing.Phase = "Sustain"
					existing.Start = os.clock()
					existing.Duration = math.huge
					existing.Gather = 0
					return
				end
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local camera = workspace.CurrentCamera
			if
				not root
				or not humanoid
				or humanoid.Health <= 0
				or not camera
				or (root.Position - camera.CFrame.Position).Magnitude > Config.ObserverDistance
			then
				return
			end
			local count = 0
			for _ in casts do
				count += 1
			end
			if not casts[character] and count >= Config.MaxObservedCasts then
				return
			end
			restore(character)
			local joints = {}
			for _, joint in character:GetDescendants() do
				local entry = Rig.describe(joint)
				if entry then
					table.insert(joints, entry)
				end
			end
			character:SetAttribute("MagicPoseJointCount", #joints)
			character:SetAttribute("MagicPoseProfile", profile)
			if #joints == 0 and not warned[character] then
				warned[character] = true
				warn("Magic casting: no supported body joints found in " .. character.Name)
			end
			casts[character] = {
				Profile = profile,
				Phase = phase,
				Start = os.clock(),
				Duration = if phase == "Sustain" then math.huge else math.clamp(duration, 0.1, Config.MaxPoseDuration),
				Gather = math.clamp(gather or 0.1, 0.05, Config.MaxPoseDuration),
				Joints = joints,
			}
		end)
	local distortionCamera: Camera? = nil
	local distortionBlur: BlurEffect? = nil
	local distortionColor: ColorCorrectionEffect? = nil
	local function bindDistortionEffects(camera: Camera?)
		if distortionCamera == camera then
			return
		end
		if distortionBlur then
			distortionBlur:Destroy()
			distortionBlur = nil
		end
		if distortionColor then
			distortionColor:Destroy()
			distortionColor = nil
		end
		distortionCamera = camera
		if not camera then
			return
		end
		distortionBlur = Instance.new("BlurEffect")
		distortionBlur.Name = "MagicLocalDistortionBlur"
		distortionBlur.Size = 0
		distortionBlur.Enabled = false
		distortionBlur.Parent = camera
		distortionColor = Instance.new("ColorCorrectionEffect")
		distortionColor.Name = "MagicLocalDistortionColor"
		distortionColor.Contrast = 0
		distortionColor.Saturation = 0
		distortionColor.Enabled = false
		distortionColor.Parent = camera
	end
	local distortionAccumulator = 0
	local distortionConfig = Config.LocalDistortion
	RunService.Heartbeat:Connect(function(deltaTime)
		distortionAccumulator += deltaTime
		if distortionAccumulator < distortionConfig.UpdateInterval then
			return
		end
		distortionAccumulator %= distortionConfig.UpdateInterval
		local camera = workspace.CurrentCamera
		bindDistortionEffects(camera)
		if not camera or not distortionBlur or not distortionColor then
			return
		end
		local strongest = 0
		local cameraPosition = camera.CFrame.Position
		for _, marker in CollectionService:GetTagged("MagicDistortionArea") do
			if not marker:IsA("BasePart") or not marker:IsDescendantOf(workspace) then
				continue
			end
			local authored = marker:GetAttribute("MagicVisualDistortion")
			local radius = marker:GetAttribute("MagicDistortionRadius")
			if type(authored) ~= "number" or type(radius) ~= "number" then
				continue
			end
			local distance = (cameraPosition - marker.Position).Magnitude
			local falloff = if distance <= radius
				then 1
				else math.clamp(1 - (distance - radius) / distortionConfig.FalloffDistance, 0, 1)
			strongest = math.max(strongest, math.clamp(authored, 0, 1) * falloff)
		end
		distortionBlur.Size = strongest * distortionConfig.MaxBlur
		distortionBlur.Enabled = strongest > 0.01
		distortionColor.Contrast = strongest * distortionConfig.MaxContrast
		distortionColor.Saturation = -strongest * distortionConfig.MaxDesaturation
		distortionColor.Enabled = strongest > 0.01
	end)
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		for character, cast in casts do
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local elapsed = now - cast.Start
			local t = elapsed / cast.Duration
			local strength
			local releasing = cast.Phase == "Release"
			if cast.Phase == "Charge" then
				strength = 0.88
			elseif cast.Phase == "Sustain" then
				strength = 0.76 + math.sin(elapsed * 1.8) * 0.035
			elseif releasing then
				strength = math.min(elapsed / 0.12, 1) * math.min((cast.Duration - elapsed) / 0.2, 1)
				strength = strength * strength * (3 - 2 * strength)
			elseif elapsed < cast.Gather then
				local rise = math.min(elapsed / 0.22, 1)
				strength = 0.82 * rise * rise * (3 - 2 * rise)
			else
				strength = 0.82 * math.min((cast.Duration - elapsed) / 0.2, 1)
			end
			if
				not character:IsDescendantOf(workspace)
				or not humanoid
				or humanoid.Health <= 0
				or (cast.Phase ~= "Charge" and cast.Phase ~= "Sustain" and t >= 1)
			then
				restore(character)
				continue
			end
			strength = math.clamp(strength, 0, 1)
			for _, entry in cast.Joints do
				if not entry.Joint.Parent then
					continue
				end
				local x, y, z = PoseSpec.angles(cast.Profile, entry.Role, cast.Phase)
				-- Rotate in the parent body's axes, not the differently oriented R6/R15 joint axes.
				local offset = CFrame.Angles(math.rad(x) * strength, math.rad(y) * strength, math.rad(z) * strength)
				local frame = entry.Frame.Rotation
				local localOffset = frame:Inverse() * offset * frame
				local base = entry.Joint.Transform
				local output = localOffset * base
				applied[entry.Joint] = { Base = base, Output = output }
				entry.Joint.Transform = output
			end
		end
	end)
end
return Controller
