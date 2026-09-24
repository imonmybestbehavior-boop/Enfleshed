--!strict

local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.Sandbox)
local World = require(Shared.Configuration.LowerLayerGraybox)
local Graybox = require(script.Parent.Parent.Development.LowerLayerGraybox)
local Sandbox = {}

function Sandbox.start()
	Graybox.start()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RecruitSpawnLocation"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = World.PhaseA.RecruitSpawn
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = workspace

	local function createDummy()
		local model = Instance.new("Model")
		model.Name = "TargetDummy"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.CanCollide = false
		root.Anchored = true
		root.Position = Config.Dummy.Position
		root.Parent = model
		local body = Instance.new("Part")
		body.Name = "Torso"
		body.Size = Vector3.new(3, 4, 2)
		body.Position = Config.Dummy.Position
		body.Anchored = true
		body.Color = Color3.fromRGB(175, 95, 85)
		body.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 2, 2)
		head.Position = Config.Dummy.Position + Vector3.new(0, 3, 0)
		head.Anchored = true
		head.Parent = model
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
		humanoid.MaxHealth = Config.Dummy.Health
		humanoid.Health = Config.Dummy.Health
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.Parent = model
		model.PrimaryPart = root
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(180, 40)
		gui.StudsOffset = Vector3.new(0, 2, 0)
		gui.AlwaysOnTop = true
		gui.Parent = head
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0
		label.TextSize = 18
		label.Parent = gui
		local function update()
			label.Text = string.format("Dummy  %d / %d", humanoid.Health, humanoid.MaxHealth)
		end
		update()
		humanoid.HealthChanged:Connect(update)
		humanoid.Died:Once(function()
			task.delay(Config.Dummy.ResetDelay, function()
				model:Destroy()
				createDummy()
			end)
		end)
		model.Parent = workspace
	end
	createDummy()
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
end

return Sandbox
