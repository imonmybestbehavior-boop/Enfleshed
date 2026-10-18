--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local MapConfig = require(Shared.Configuration.CombatBattleMap)
local MapGenerator = require(script.Parent.MapGenerator)
local SpawnConfig = require(Shared.Configuration.Sandbox)
local Arena = {}
function Arena.enabled()
	return true
end
function Arena.start()
	MapGenerator.Generate(MapConfig.Seed)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.Position =
		"SandboxSpawn", Vector3.new(8, 1, 8), MapConfig.Spawn - Vector3.new(0, 4, 0)
	spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
	spawn.Parent = workspace.Map:FindFirstChild("Props")
	local defaultSpawn = Instance.new("Part")
	defaultSpawn.Name, defaultSpawn.Size, defaultSpawn.CFrame =
		"SandboxDefaultSpawn", Vector3.new(1, 1, 1), CFrame.new(MapConfig.Spawn)
	defaultSpawn.Anchored, defaultSpawn.Transparency, defaultSpawn.CanCollide = true, 1, false
	defaultSpawn.Parent = workspace.Map:FindFirstChild("Props")
	local Physics = game:GetService("PhysicsService")
	local enemyGroup = SpawnConfig.Enemy.VisualCollisionGroup
	if not Physics:IsCollisionGroupRegistered(enemyGroup) then
		Physics:RegisterCollisionGroup(enemyGroup)
	end
	Physics:CollisionGroupSetCollidable(enemyGroup, "Default", false)
	Physics:CollisionGroupSetCollidable(enemyGroup, enemyGroup, false)
	local dummies = workspace:FindFirstChild("TrainingDummies")
	if not dummies then
		dummies = Instance.new("Folder")
		dummies.Name, dummies.Parent = "TrainingDummies", workspace
	end
	local function addPracticeDummy(position: Vector3, index: number): Model
		local model = Instance.new("Model")
		model.Name = string.format("Enfleshed_%02d", index)
		model:SetAttribute("SandboxLabel", string.format("Enfleshed %02d", index))
		local root = Instance.new("Part")
		root.Name, root.Size, root.Position = "HumanoidRootPart", Vector3.new(2, 2, 1), position + Vector3.new(0, 3, 0)
		root.Anchored, root.Transparency, root.CanCollide = false, 1, false
		root.Parent = model
		local body = Instance.new("Part")
		body.Name, body.Size, body.Position = "Torso", Vector3.new(3, 4, 1.5), position + Vector3.new(0, 4, 0)
		body.Anchored, body.CanCollide, body.Color, body.Material =
			false, false, Color3.fromRGB(119, 74, 70), Enum.Material.Slate
		body.Parent = model
		local head = Instance.new("Part")
		head.Name, head.Shape, head.Size, head.Position =
			"Head", Enum.PartType.Ball, Vector3.new(2, 2, 2), position + Vector3.new(0, 7, 0)
		head.Anchored, head.CanCollide, head.Color, head.Material =
			false, false, Color3.fromRGB(160, 132, 111), Enum.Material.Slate
		head.Parent = model
		local torsoWeld = Instance.new("WeldConstraint")
		torsoWeld.Part0, torsoWeld.Part1, torsoWeld.Parent = root, body, body
		local headWeld = Instance.new("WeldConstraint")
		headWeld.Part0, headWeld.Part1, headWeld.Parent = body, head, head
		local humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth, humanoid.Health, humanoid.RequiresNeck =
			SpawnConfig.TrainingDummies.Health, SpawnConfig.TrainingDummies.Health, false
		humanoid.Parent = model
		model.PrimaryPart = root
		game:GetService("CollectionService"):AddTag(model, "MagicHostileTarget")
		model.Parent = dummies
		return model
	end
	local enemies = Instance.new("Folder")
	enemies.Name, enemies.Parent = "BattleEnemies", workspace
	for index = 1, 12 do
		local angle = math.pi * 2 * (index - 1) / 12
		local radius = if index % 2 == 0 then 175 else 205
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local handle = require(script.Parent.EnemyService).create(
			position,
			enemies,
			enemyGroup,
			(index - 1) * SpawnConfig.Enemy.ThinkInterval / 12,
			1 / SpawnConfig.StressTest.HitQueryRate
		)
		handle.Model:SetAttribute("SandboxLabel", string.format("Enfleshed %02d", index))
	end
	local function addMaterial(name: string, material: string, position: Vector3)
		local source = Instance.new("Part")
		source.Name, source.Size, source.Position = name, Vector3.new(6, 4, 6), position
		source.Anchored, source.Material, source.Color = true, Enum.Material.Rock, Color3.fromRGB(124, 110, 87)
		source:SetAttribute("MagicMaterial", material)
		source:SetAttribute("AvailableAmount", 50)
		source:SetAttribute("MagicRaise", true)
		source.Parent = workspace.Map:FindFirstChild("Props")
		game:GetService("CollectionService"):AddTag(source, "MagicMaterialSource")
		game:GetService("CollectionService"):AddTag(source, "MagicManipulable")
	end
	for index, material in { "Earth", "Water", "Metal", "Wood" } do
		addMaterial(material .. "Source", material, Vector3.new(28 + index * 8, 2, 360))
	end
	local targetOrigin = MapConfig.PracticeTargets or Vector3.new(0, 0, 0)
	for index = 1, 8 do
		local angle = math.pi * 2 * (index - 1) / 8
		local position = targetOrigin + Vector3.new(math.cos(angle) * 54, 0, math.sin(angle) * 54)
		local enemy = addPracticeDummy(position, index)
		local plate = Instance.new("BillboardGui")
		plate.Name, plate.Size, plate.StudsOffset, plate.AlwaysOnTop =
			"PracticeTargetLabel", UDim2.fromOffset(140, 28), Vector3.new(0, 9, 0), true
		plate.Parent = enemy:FindFirstChild("Head")
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextColor3, label.TextStrokeTransparency =
			"PRACTICE TARGET", Color3.fromRGB(245, 224, 188), 0.25
		label.TextScaled, label.Font = true, Enum.Font.GothamBold
		label.Parent = plate
	end
	local crate = Instance.new("Part")
	crate.Name, crate.Size, crate.Position = "MovablePracticeObject", Vector3.new(4, 4, 4), Vector3.new(-20, 3, 365)
	crate.Anchored, crate.Material, crate.Color = false, Enum.Material.WoodPlanks, Color3.fromRGB(125, 96, 60)
	crate.Parent = workspace.Map:FindFirstChild("Props")
	game:GetService("CollectionService"):AddTag(crate, "MagicManipulable")
end
return Arena
