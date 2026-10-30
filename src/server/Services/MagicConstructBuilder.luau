--!strict
-- Builds Construct models and saves/restores world-persistent Constructs.
-- Extracted from MagicService (Phase 1.7); no runtime state lives here.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AreaGrowth = require(Shared.Modules.MagicAreaGrowth)
local Presentation = require(script.Parent.MagicPresentation)
local PersistentConstructStore = require(script.Parent.MagicPersistentConstructStore)
local ConstructHealth = require(script.Parent.MagicConstructHealth)
local MagicConstructBuilder = {}

local function watchPersistentConstruct(model: Model, id: string)
	local removed = false
	local function removeRecord()
		if removed then
			return
		end
		removed = true
		task.spawn(function()
			local reason
			for attempt = 1, 3 do
				local ok
				ok, reason = PersistentConstructStore.remove(id)
				if ok then
					return
				end
				task.wait(attempt)
			end
			warn("Persistent Construct removal was not saved: " .. tostring(reason))
		end)
	end
	model.Destroying:Connect(removeRecord)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			removeRecord()
		end
	end)
end

-- Health for a world-persistent Construct: damage queues a save; at zero the
-- model is destroyed, which removes its saved record (watchPersistentConstruct).
local function trackPersistentHealth(model: Model, id: string, ownerUserId: number, maxHealth: number?, health: number?)
	if not maxHealth then
		return
	end
	ConstructHealth.register({ Persistent = true, Id = id }, model, ownerUserId, maxHealth, health, {
		OnChanged = function(entry)
			PersistentConstructStore.updateHealth(id, entry.Health)
		end,
		OnDestroyed = function()
			model:Destroy()
		end,
	})
end

local function persistentConstructRecord(
	player: Player,
	frame: CFrame,
	components: { any },
	definition: any,
	maxHealth: number?
)
	local rx, ry, rz = frame:ToOrientation()
	local serializedComponents = {}
	for index, component in ipairs(components) do
		local rotation = component.RotationDegrees
		serializedComponents[index] = {
			Shape = component.Shape,
			Size = { component.Size[1], component.Size[2], component.Size[3] },
			Offset = { component.Offset[1], component.Offset[2], component.Offset[3] },
			RotationDegrees = { rotation[1], rotation[2], rotation[3] },
		}
	end
	local function colorArray(color)
		return { color.R, color.G, color.B }
	end
	local visual = definition.Visual
	return {
		OwnerUserId = player.UserId,
		MaxHealth = maxHealth,
		Health = maxHealth,
		Position = { frame.Position.X, frame.Position.Y, frame.Position.Z },
		RotationDegrees = { math.deg(rx), math.deg(ry), math.deg(rz) },
		Components = serializedComponents,
		Visual = {
			Color = colorArray(visual.Color),
			SecondaryColor = visual.SecondaryColor and colorArray(visual.SecondaryColor) or nil,
			AccentColor = visual.AccentColor and colorArray(visual.AccentColor) or nil,
			MaterialAppearance = visual.MaterialAppearance or "Auto",
			Opacity = visual.Opacity or 0.85,
			Emission = visual.Emission or 0,
			ParticleStyle = visual.ParticleStyle or "None",
		},
	}
end

-- Builds a temporary Construct model from validated components at `frame`
-- and parents it to workspace. Shared by the cast path and spawned effects.
local function buildConstructModel(d, components, frame: CFrame, collidable: boolean)
	local componentLifetimes = {}
	local model = Instance.new("Model")
	model.Name = "MagicTemporaryConstruct"
	local pivot = Instance.new("Part")
	pivot.Name = "ConstructPivot"
	pivot.Size = Vector3.one * 0.1
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide, pivot.CanTouch, pivot.CanQuery = false, false, false
	pivot.CFrame = frame
	pivot.Parent = model
	model.PrimaryPart = pivot
	-- The bounded registry is shared with the preview; only server-authored
	-- components become collidable, and character attachments remain harmless.
	for index, component in ipairs(components) do
		local part: BasePart = Instance.new(if component.Shape == "Wedge" then "WedgePart" else "Part")
		part.Name = string.format("ConstructPart%02d", index)
		part.Size = Vector3.new(component.Size[1], component.Size[2], component.Size[3])
		if part:IsA("Part") then
			part.Shape = Enum.PartType[component.Shape]
		end
		local rotation = component.RotationDegrees
		part.CFrame = frame
			* CFrame.new(component.Offset[1], component.Offset[2], component.Offset[3])
			* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
		-- Anchored pieces are moved together with the Model and cannot tunnel.
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = collidable, false, true
		part.Material, part.Color, part.Transparency =
			Presentation.material(d), d.Visual.Color, 1 - (d.Visual.Opacity or 0.85)
		part.Parent = model
		if component.Duration then
			componentLifetimes[part] = component.Duration
		end
		Presentation.construct(part, if index == 1 then 20 else 4, d)
	end
	local constructStartScale = AreaGrowth.scale(d.Construct, 0)
	if constructStartScale ~= 1 then
		model:ScaleTo(constructStartScale)
	end
	model.Parent = workspace
	return model, pivot, componentLifetimes, constructStartScale
end

local function restorePersistentConstruct(record)
	local savedVisual = record.Visual
	local visual = {
		Color = Color3.new(savedVisual.Color[1], savedVisual.Color[2], savedVisual.Color[3]),
		MaterialAppearance = savedVisual.MaterialAppearance,
		Opacity = savedVisual.Opacity,
		Emission = savedVisual.Emission,
		ParticleStyle = savedVisual.ParticleStyle,
	}
	if savedVisual.SecondaryColor then
		visual.SecondaryColor =
			Color3.new(savedVisual.SecondaryColor[1], savedVisual.SecondaryColor[2], savedVisual.SecondaryColor[3])
	end
	local frame = CFrame.new(record.Position[1], record.Position[2], record.Position[3])
		* CFrame.Angles(
			math.rad(record.RotationDegrees[1]),
			math.rad(record.RotationDegrees[2]),
			math.rad(record.RotationDegrees[3])
		)
	local definition = { Form = "Construct", Visual = visual }
	local model = Instance.new("Model")
	model.Name = "MagicPersistentConstruct"
	local pivot = Instance.new("Part")
	pivot.Name = "ConstructPivot"
	pivot.Size = Vector3.one * 0.1
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide, pivot.CanTouch, pivot.CanQuery = false, false, false
	pivot.CFrame = frame
	pivot.Parent = model
	model.PrimaryPart = pivot
	for index, component in ipairs(record.Components) do
		local part: BasePart = Instance.new(if component.Shape == "Wedge" then "WedgePart" else "Part")
		part.Name = string.format("ConstructPart%02d", index)
		part.Size = Vector3.new(component.Size[1], component.Size[2], component.Size[3])
		if part:IsA("Part") then
			part.Shape = Enum.PartType[component.Shape]
		end
		local rotation = component.RotationDegrees
		part.CFrame = frame
			* CFrame.new(component.Offset[1], component.Offset[2], component.Offset[3])
			* CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3]))
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = true, false, true
		part.Material = Presentation.material(definition)
		part.Color = definition.Visual.Color
		part.Transparency = 1 - (definition.Visual.Opacity or 0.85)
		part.Parent = model
	end
	model:SetAttribute("MagicPersistentConstruct", true)
	model:SetAttribute("MagicPersistentConstructId", record.Id)
	model:SetAttribute("MagicPersistentConstructOwner", record.OwnerUserId)
	model.Parent = workspace
	watchPersistentConstruct(model, record.Id)
	trackPersistentHealth(model, record.Id, record.OwnerUserId, record.MaxHealth, record.Health)
end

MagicConstructBuilder.buildConstructModel = buildConstructModel
MagicConstructBuilder.watchPersistentConstruct = watchPersistentConstruct
MagicConstructBuilder.persistentConstructRecord = persistentConstructRecord
MagicConstructBuilder.restorePersistentConstruct = restorePersistentConstruct
MagicConstructBuilder.trackPersistentHealth = trackPersistentHealth

return MagicConstructBuilder
