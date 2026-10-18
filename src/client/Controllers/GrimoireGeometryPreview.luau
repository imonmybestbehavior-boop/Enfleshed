--!strict
-- Debug geometry for the Grimoire: draws a spell's aim, range, area and construct
-- shapes in the world while "debug geometry" is on. Extracted from
-- MagicLabController (Phase 1.7); pure drawing, no Grimoire state.
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Geometry = require(Shared.Modules.MagicGeometry)
local ConstructGeometrySpec = require(Shared.Modules.MagicConstructGeometrySpec)
local GeometryPreview = {}

-- Draws into `drawFolder` (already cleared by the caller) for `draft` cast by `player`.
function GeometryPreview.draw(
	drawFolder: Folder,
	player: Player,
	draft: any,
	direction: Vector3,
	point: Vector3?,
	target: any
)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local function anchor(name, position)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.one * 0.05
		part.CFrame = CFrame.new(position)
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Transparency = 1
		part.Parent = drawFolder
		Debris:AddItem(part, 1.5)
		return part
	end
	local function sphere(name, center, radius, color, transparency)
		if radius <= 0 then
			return
		end
		local adornee = anchor(name .. "Anchor", center)
		local adornment = Instance.new("SphereHandleAdornment")
		adornment.Name = name
		adornment.Adornee = adornee
		adornment.Radius = radius
		adornment.Color3 = color
		adornment.Transparency = transparency
		adornment.AlwaysOnTop = false
		adornment.ZIndex = 1
		adornment.Parent = adornee
	end
	local function areaShape(name, center, shape, area, color)
		if shape == "Sphere" then
			sphere(name, center, area.Radius, color, 0.72)
			return
		end
		if shape == "Capsule" then
			local radius = area.Radius
			local stemHeight = math.max(area.Height - radius * 2, 0.05)
			local function capsulePart(partName, partShape, size, cframe)
				local part = Instance.new("Part")
				part.Name = partName
				part.Shape = partShape
				part.Size = size
				part.CFrame = cframe
				part.Anchored = true
				part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
				part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, 0.78
				part.Parent = drawFolder
				Debris:AddItem(part, 1.5)
			end
			local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
			capsulePart(
				name .. "CapsuleBody",
				Enum.PartType.Cylinder,
				Vector3.new(stemHeight, radius * 2, radius * 2),
				frame * CFrame.Angles(0, 0, math.rad(90))
			)
			for _, sign in { -1, 1 } do
				capsulePart(
					name .. "CapsuleCap",
					Enum.PartType.Ball,
					Vector3.one * radius * 2,
					frame * CFrame.new(0, sign * stemHeight / 2, 0)
				)
			end
			return
		end
		if shape == "Ring" then
			local anchor = Instance.new("Part")
			anchor.Name = name .. "RingAnchor"
			anchor.Size = Vector3.one * 0.1
			anchor.CFrame = CFrame.new(center)
			anchor.Anchored = true
			anchor.Transparency = 1
			anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
			anchor.Parent = drawFolder
			local function edge(first: Vector3, second: Vector3)
				local a, b = Instance.new("Attachment"), Instance.new("Attachment")
				a.Position, b.Position = first, second
				a.Parent, b.Parent = anchor, anchor
				local beam = Instance.new("Beam")
				beam.Name = name .. "RingBoundary"
				beam.Attachment0, beam.Attachment1 = a, b
				beam.Color = ColorSequence.new(color)
				beam.Transparency = NumberSequence.new(0.2)
				beam.Width0, beam.Width1 = 0.06, 0.06
				beam.FaceCamera = false
				beam.Parent = anchor
			end
			local function circle(radius: number, y: number)
				local segments = 24
				for index = 0, segments - 1 do
					local firstAngle = index / segments * math.pi * 2
					local secondAngle = (index + 1) / segments * math.pi * 2
					edge(
						Vector3.new(math.cos(firstAngle) * radius, y, math.sin(firstAngle) * radius),
						Vector3.new(math.cos(secondAngle) * radius, y, math.sin(secondAngle) * radius)
					)
				end
			end
			local halfHeight = area.Height / 2
			for _, y in { -halfHeight, halfHeight } do
				circle(area.InnerRadius, y)
				circle(area.OuterRadius, y)
			end
			for _, angle in { 0, math.pi / 2, math.pi, math.pi * 1.5 } do
				local x, z = math.cos(angle), math.sin(angle)
				for _, y in { -halfHeight, halfHeight } do
					edge(
						Vector3.new(x * area.InnerRadius, y, z * area.InnerRadius),
						Vector3.new(x * area.OuterRadius, y, z * area.OuterRadius)
					)
				end
				edge(
					Vector3.new(x * area.InnerRadius, -halfHeight, z * area.InnerRadius),
					Vector3.new(x * area.InnerRadius, halfHeight, z * area.InnerRadius)
				)
				edge(
					Vector3.new(x * area.OuterRadius, -halfHeight, z * area.OuterRadius),
					Vector3.new(x * area.OuterRadius, halfHeight, z * area.OuterRadius)
				)
			end
			Debris:AddItem(anchor, 1.5)
			return
		end
		if shape == "Cone" then
			local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
			local anchor = Instance.new("Part")
			anchor.Name = name .. "ConeAnchor"
			anchor.Size = Vector3.one * 0.1
			anchor.CFrame = frame
			anchor.Anchored = true
			anchor.Transparency = 1
			anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
			anchor.Parent = drawFolder
			local halfHeight = area.Height / 2
			local halfWidth = area.Range * math.tan(math.rad(area.Angle / 2))
			local function edge(first: Vector3, second: Vector3)
				local a, b = Instance.new("Attachment"), Instance.new("Attachment")
				a.Position, b.Position = first, second
				a.Parent, b.Parent = anchor, anchor
				local beam = Instance.new("Beam")
				beam.Name = name .. "ConeEdge"
				beam.Attachment0, beam.Attachment1 = a, b
				beam.Color = ColorSequence.new(color)
				beam.Transparency = NumberSequence.new(0.2)
				beam.Width0, beam.Width1 = 0.06, 0.06
				beam.FaceCamera = false
				beam.Parent = anchor
			end
			for _, y in { -halfHeight, halfHeight } do
				local apex = Vector3.new(0, y, 0)
				local left = Vector3.new(-halfWidth, y, -area.Range)
				local right = Vector3.new(halfWidth, y, -area.Range)
				edge(apex, left)
				edge(apex, right)
				edge(left, right)
			end
			edge(Vector3.new(0, -halfHeight, 0), Vector3.new(0, halfHeight, 0))
			edge(Vector3.new(-halfWidth, -halfHeight, -area.Range), Vector3.new(-halfWidth, halfHeight, -area.Range))
			edge(Vector3.new(halfWidth, -halfHeight, -area.Range), Vector3.new(halfWidth, halfHeight, -area.Range))
			Debris:AddItem(anchor, 1.5)
			return
		end
		local size = Geometry.areaSize(shape, area)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = if shape == "Cylinder" then Vector3.new(size.Y, size.X, size.Z) else size
		part.CFrame = CFrame.new(center)
			* CFrame.Angles(0, math.rad(area.Yaw or 0), 0)
			* (if shape == "Line" then CFrame.new(0, 0, -area.Range / 2) else CFrame.identity)
			* (if shape == "Cylinder" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
		part.Shape = if shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Material, part.Color, part.Transparency = Enum.Material.Neon, color, 0.82
		part.Parent = drawFolder
		Debris:AddItem(part, 1.5)
	end
	local function beamBetween(first, second, name)
		local a = Instance.new("Attachment")
		a.Parent = first
		local b = Instance.new("Attachment")
		b.Parent = second
		local beam = Instance.new("Beam")
		beam.Name = name
		beam.Attachment0, beam.Attachment1 = a, b
		beam.Width0, beam.Width1 = 0.08, 0.08
		beam.Color = ColorSequence.new(draft.Visual.Color)
		beam.Transparency = NumberSequence.new(0.2)
		beam.LightEmission = 0.55
		beam.FaceCamera = true
		beam.Parent = drawFolder
		Debris:AddItem(beam, 1.5)
	end
	local castOrigin = root.Position + Vector3.new(0, 1.5, 0)
	local targetRoot = if target and target:IsA("Model") then target:FindFirstChild("HumanoidRootPart") else nil
	local previewPoint = if targetRoot and targetRoot:IsA("BasePart") then targetRoot.Position else point
	local unitDirection = if direction.Magnitude > 0.001 then direction.Unit else root.CFrame.LookVector
	local aimFrame = CFrame.lookAt(castOrigin, castOrigin + unitDirection)
	if draft.Projectile then
		local position = castOrigin + unitDirection * 3
		-- The green sphere is the server hit radius; the colored core is appearance-only.
		sphere("ProjectileCollisionRadius", position, draft.Projectile.Radius, Color3.fromRGB(105, 230, 185), 0.45)
		local shape = draft.Visual.CoreShape or "Sphere"
		local appearanceScale = draft.Visual.ProjectileScale or 1
		local radius = draft.Projectile.Radius * appearanceScale
		local appearance = Instance.new(if shape == "Wedge" then "WedgePart" else "Part")
		appearance.Name = "ProjectileAppearance"
		if appearance:IsA("Part") then
			appearance.Shape =
				Enum.PartType[if shape == "Sphere" then "Ball" elseif shape == "Crystal" then "Block" else shape]
		end
		appearance.Size = Vector3.one * radius * 2
		appearance.CFrame = CFrame.new(position)
			* (if shape == "Crystal" then CFrame.Angles(math.rad(45), math.rad(45), math.rad(45)) else CFrame.identity)
		appearance.Anchored = true
		appearance.CanCollide, appearance.CanTouch, appearance.CanQuery = false, false, false
		appearance.Material = visualMaterial(draft)
		appearance.Color = draft.Visual.Color
		appearance.Transparency = 1 - (draft.Visual.Opacity or 0.85)
		appearance.Parent = drawFolder
		Debris:AddItem(appearance, 1.5)
	elseif draft.Beam then
		local maximumScale = math.max(draft.Beam.GrowthStartScale or 1, draft.Beam.GrowthEndScale or 1)
		local range = math.min(draft.Beam.Range * maximumScale, draft.TargetRules.Range)
		local width = math.max(0.12, draft.Beam.Width * maximumScale)
		local part = Instance.new("Part")
		part.Name = "BeamHitVolumePreview"
		part.Size = Vector3.new(width, width, range)
		part.CFrame = CFrame.lookAt(castOrigin + unitDirection * range / 2, castOrigin + unitDirection * range)
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Material = visualMaterial(draft)
		part.Color = draft.Visual.Color
		part.Transparency = 1 - (draft.Visual.Opacity or 0.85)
		part.Parent = drawFolder
		Debris:AddItem(part, 1.5)
	elseif draft.Field then
		areaShape("FieldHitVolume", previewPoint, draft.Geometry, draft.Field, draft.Visual.Color)
	elseif draft.Aura then
		local center = if draft.Targeting == "EntityTarget" or draft.Targeting == "ObjectTarget"
			then previewPoint
			else root.Position
		areaShape("AuraHitVolume", center, draft.Geometry, draft.Aura, draft.Visual.Color)
	elseif draft.Wave then
		local maximumScale = math.max(draft.Wave.GrowthStartScale or 1, draft.Wave.GrowthEndScale or 1)
		local previewRange = draft.Wave.Range * maximumScale
		if draft.Geometry == "Sphere" then
			sphere("WaveSphere", root.Position, previewRange, draft.Visual.Color, 0.82)
		else
			local count = 10
			local halfAngle = math.acos(math.clamp(draft.Wave.Dot, -1, 1))
			local ring = {}
			local originAnchor = anchor("WaveConeOrigin", castOrigin)
			local originAttachment = Instance.new("Attachment")
			originAttachment.Parent = originAnchor
			for index = 1, count do
				local angle = (index - 1) / count * math.pi * 2
				local radial = aimFrame.RightVector * math.cos(angle) + aimFrame.UpVector * math.sin(angle)
				local edgeDirection = unitDirection * math.cos(halfAngle) + radial * math.sin(halfAngle)
				local edgeAnchor = anchor("WaveConeEdge", castOrigin + edgeDirection * previewRange)
				local edgeAttachment = Instance.new("Attachment")
				edgeAttachment.Parent = edgeAnchor
				local spoke = Instance.new("Beam")
				spoke.Name = "WaveConeBoundary"
				spoke.Attachment0, spoke.Attachment1 = originAttachment, edgeAttachment
				spoke.Width0, spoke.Width1 = 0.08, 0.08
				spoke.Color = ColorSequence.new(draft.Visual.Color)
				spoke.Transparency = NumberSequence.new(0.2)
				spoke.FaceCamera = true
				spoke.Parent = drawFolder
				Debris:AddItem(spoke, 1.5)
				ring[index] = edgeAnchor
			end
			for index = 1, count do
				beamBetween(ring[index], ring[index % count + 1], "WaveConeRim")
			end
		end
	elseif draft.Construct then
		local center = if draft.Targeting == "WorldPoint"
			then point
			else castOrigin + unitDirection * draft.Construct.Distance
		local flatDirection = Vector3.new(unitDirection.X, 0, unitDirection.Z)
		if flatDirection.Magnitude < 0.001 then
			flatDirection = Vector3.new(0, 0, -1)
		end
		local frame = CFrame.lookAt(center, center + flatDirection.Unit)
		local components = ConstructGeometrySpec.components(
			draft.Geometry,
			draft.Construct.Width,
			draft.Construct.Height,
			draft.Construct.Depth,
			draft.Construct.Components
		)
		local previewScale = if draft.Construct.GrowthDuration and draft.Construct.GrowthDuration > 0
			then draft.Construct.GrowthStartScale or 1
			else 1
		for index, component in ipairs(components or {}) do
			local part = Instance.new(if component.Shape == "Wedge" then "WedgePart" else "Part")
			part.Name = string.format("ConstructGeometryPreview%02d", index)
			part.Size = Vector3.new(component.Size[1], component.Size[2], component.Size[3]) * previewScale
			if part:IsA("Part") then
				part.Shape = Enum.PartType[component.Shape]
			end
			local rotation = component.RotationDegrees
			part.CFrame = frame
				* CFrame.new(
					component.Offset[1] * previewScale,
					component.Offset[2] * previewScale,
					component.Offset[3] * previewScale
				)
				* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
			part.Anchored = true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.Material, part.Color, part.Transparency = Enum.Material.Neon, draft.Visual.Color, 0.84
			part.Parent = drawFolder
			Debris:AddItem(part, 1.5)
		end
	end
	for triggerEvent, steps in pairs(draft.Triggers or {}) do
		for _, step in ipairs(steps or {}) do
			if step.Behavior == "Explode" then
				local explosionCenter = if triggerEvent == "OnCast" and draft.Form == "Wave"
					then root.Position
					else previewPoint
				sphere(
					"ExplosionRadiusAt" .. triggerEvent,
					explosionCenter,
					step.Radius,
					Color3.fromRGB(255, 167, 89),
					0.78
				)
			end
		end
	end
	if draft.TargetRules then
		sphere("TargetingRange", root.Position, draft.TargetRules.Range, Color3.fromRGB(255, 221, 105), 0.94)
	end
end

return GeometryPreview
