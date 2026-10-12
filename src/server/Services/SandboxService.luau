--!strict

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Configuration.LowerLayerGraybox)
local Locations = require(Shared.Configuration.AssignmentLocations)
local Graybox = require(script.Parent.Parent.Development.LowerLayerGraybox)
local Sandbox = {}

function Sandbox.start()
	Graybox.start()
	local signs = Instance.new("Folder")
	signs.Name = "DistrictSigns"
	signs.Parent = workspace
	for id, location in Locations do
		if id ~= "Underground_Junction" then
			local sign = Instance.new("Part")
			sign.Name = "Sign_" .. id
			sign.Size = Vector3.new(8, 3, 0.25)
			sign.CFrame = CFrame.new(location.Position + Vector3.new(0, 7, -4))
			sign.Anchored, sign.CanCollide, sign.Material = true, false, Enum.Material.Metal
			sign.Color = Color3.fromRGB(45, 48, 52)
			sign.Parent = signs
			local surface = Instance.new("SurfaceGui")
			surface.Face, surface.CanvasSize = Enum.NormalId.Front, Vector2.new(400, 150)
			surface.Parent = sign
			local text = Instance.new("TextLabel")
			text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
			text.Text, text.TextColor3, text.Font, text.TextScaled =
				location.Name:upper(), Color3.new(1, 1, 1), Enum.Font.GothamBold, true
			text.Parent = surface
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RecruitSpawnLocation"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = World.PhaseA.RecruitSpawn
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	local earth = Instance.new("Part")
	earth.Name = "EarthMagicMaterial"
	earth.Size = Vector3.new(6, 3, 6)
	earth.Position = Vector3.new(-70, 1.5, 1460)
	earth.Anchored = true
	earth.Material = Enum.Material.Slate
	earth.Color = Color3.fromRGB(100, 75, 55)
	earth:SetAttribute("MagicMaterial", "Earth")
	earth:SetAttribute("AvailableAmount", 50)
	earth.Parent = workspace
	CollectionService:AddTag(earth, "MagicMaterialSource")
	local water = Instance.new("Part")
	water.Name = "WaterMagicMaterial"
	water.Size = Vector3.new(6, 3, 6)
	water.Position = Vector3.new(-60, 1.5, 1460)
	water.Anchored = true
	water.Material = Enum.Material.Glass
	water.Color = Color3.fromRGB(65, 150, 185)
	water.Transparency = 0.28
	water:SetAttribute("MagicMaterial", "Water")
	water:SetAttribute("AvailableAmount", 50)
	water.Parent = workspace
	CollectionService:AddTag(water, "MagicMaterialSource")
	local metal = Instance.new("Part")
	metal.Name = "MetalMagicMaterial"
	metal.Size = Vector3.new(6, 3, 6)
	metal.Position = Vector3.new(-50, 1.5, 1460)
	metal.Anchored = true
	metal.Material = Enum.Material.Metal
	metal.Color = Color3.fromRGB(105, 115, 124)
	metal:SetAttribute("MagicMaterial", "Metal")
	metal:SetAttribute("AvailableAmount", 50)
	metal:SetAttribute("MagicRaise", true)
	metal.Parent = workspace
	CollectionService:AddTag(metal, "MagicMaterialSource")
	CollectionService:AddTag(metal, "MagicManipulable")
	local wood = Instance.new("Part")
	wood.Name = "WoodMagicMaterial"
	wood.Size = Vector3.new(6, 3, 6)
	wood.Position = Vector3.new(-40, 1.5, 1460)
	wood.Anchored = true
	wood.Material = Enum.Material.WoodPlanks
	wood.Color = Color3.fromRGB(112, 77, 48)
	wood:SetAttribute("MagicMaterial", "Wood")
	wood:SetAttribute("AvailableAmount", 50)
	wood:SetAttribute("MagicRaise", true)
	wood.Parent = workspace
	CollectionService:AddTag(wood, "MagicMaterialSource")
	CollectionService:AddTag(wood, "MagicManipulable")
	local manipulable = Instance.new("Part")
	manipulable.Name = "EarthRaiseStone"
	manipulable.Size = Vector3.new(5, 2, 5)
	manipulable.Position = Vector3.new(75, 1, 1460)
	manipulable.Anchored = true
	manipulable.Material = Enum.Material.Slate
	manipulable.Color = Color3.fromRGB(90, 105, 80)
	manipulable:SetAttribute("MagicMaterial", "Earth")
	manipulable:SetAttribute("MagicRaise", true)
	manipulable.Parent = workspace
	CollectionService:AddTag(manipulable, "MagicManipulable")
	local movableTarget = Instance.new("Part")
	movableTarget.Name = "MagicMovableObjectTarget"
	movableTarget.Size = Vector3.new(4, 3, 4)
	movableTarget.Position = Vector3.new(86, 1.5, 1460)
	movableTarget.Anchored = false
	movableTarget.Material = Enum.Material.WoodPlanks
	movableTarget.Color = Color3.fromRGB(91, 62, 39)
	movableTarget.Parent = workspace
	CollectionService:AddTag(movableTarget, "MagicManipulable")
	local movableLabel = Instance.new("BillboardGui")
	movableLabel.Size = UDim2.fromOffset(210, 30)
	movableLabel.StudsOffset = Vector3.new(0, 3, 0)
	movableLabel.AlwaysOnTop = true
	movableLabel.Parent = movableTarget
	local movableText = Instance.new("TextLabel")
	movableText.Size = UDim2.fromScale(1, 1)
	movableText.BackgroundTransparency = 1
	movableText.TextColor3 = Color3.new(1, 1, 1)
	movableText.TextStrokeTransparency = 0
	movableText.Text = "Movable object (Force / Control)"
	movableText.Parent = movableLabel
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(180, 30)
	label.StudsOffset = Vector3.new(0, 3, 0)
	label.AlwaysOnTop = true
	label.Parent = earth
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.Text = "Earth source (Stone Shot)"
	text.Parent = label
	local waterLabel = Instance.new("BillboardGui")
	waterLabel.Size = UDim2.fromOffset(180, 30)
	waterLabel.StudsOffset = Vector3.new(0, 3, 0)
	waterLabel.AlwaysOnTop = true
	waterLabel.Parent = water
	local waterText = Instance.new("TextLabel")
	waterText.Size = UDim2.fromScale(1, 1)
	waterText.BackgroundTransparency = 1
	waterText.TextColor3 = Color3.new(1, 1, 1)
	waterText.TextStrokeTransparency = 0
	waterText.Text = "Water source (Matter Projectile)"
	waterText.Parent = waterLabel
	for _, source in { { metal, "Metal source (Earth affinity)" }, { wood, "Wood source (Earth affinity)" } } do
		local sourceLabel = Instance.new("BillboardGui")
		sourceLabel.Size = UDim2.fromOffset(190, 30)
		sourceLabel.StudsOffset = Vector3.new(0, 3, 0)
		sourceLabel.AlwaysOnTop = true
		sourceLabel.Parent = source[1]
		local sourceText = Instance.new("TextLabel")
		sourceText.Size = UDim2.fromScale(1, 1)
		sourceText.BackgroundTransparency = 1
		sourceText.TextColor3 = Color3.new(1, 1, 1)
		sourceText.TextStrokeTransparency = 0
		sourceText.Text = source[2]
		sourceText.Parent = sourceLabel
	end
end

return Sandbox
