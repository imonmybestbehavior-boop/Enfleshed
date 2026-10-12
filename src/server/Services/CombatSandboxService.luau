--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Configuration.DevelopmentSandbox)
local Arena = {}
function Arena.enabled()
	return game:GetService("RunService"):IsStudio() and Config.Enabled
end
function Arena.start()
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "CombatPracticeArena", workspace
	local function part(name, size, position, color)
		local p = Instance.new("Part")
		p.Name, p.Size, p.Position, p.Color = name, size, position, color
		p.Anchored, p.Material, p.Parent = true, Enum.Material.Concrete, folder
		return p
	end
	part("PracticeFloor", Vector3.new(200, 2, 220), Vector3.new(0, -1, -35), Color3.fromRGB(91, 89, 80))
	part("Backstop", Vector3.new(200, 14, 2), Vector3.new(0, 7, -144), Color3.fromRGB(66, 67, 61))
	for _, x in { -100, 100 } do
		part("SideWall", Vector3.new(2, 8, 220), Vector3.new(x, 4, -35), Color3.fromRGB(66, 67, 61))
	end
	local sign = part("PracticeGuide", Vector3.new(20, 7, 0.5), Vector3.new(-55, 6, 22), Color3.fromRGB(49, 56, 47))
	local surface = Instance.new("SurfaceGui")
	surface.Face, surface.CanvasSize, surface.Parent = Enum.NormalId.Back, Vector2.new(800, 280), sign
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.TextColor3 = UDim2.fromScale(1, 1), 1, Color3.fromRGB(244, 231, 200)
	text.Font, text.TextSize, text.TextWrapped = Enum.Font.Gotham, 28, true
	text.Text =
		"MAGIC PRACTICE\nP or the grimoire button: create & edit\nSave a slot · 1–9: cast · P: adjust\nReview & test: restore resources and targets"
	text.Parent = surface
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Position, spawn.Size =
		"CombatSandboxSpawn", Config.Spawn - Vector3.new(0, 4.5, 0), Vector3.new(8, 1, 8)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Parent = true, true, 0, folder
	for _, distance in { 10, 25, 50, 100, 150 } do
		local mark = part(
			"Range" .. distance,
			Vector3.new(80, 0.02, 0.15),
			Vector3.new(0, 0.03, 35 - distance),
			Color3.fromRGB(195, 175, 129)
		)
		local gui = Instance.new("BillboardGui")
		gui.Size, gui.StudsOffset, gui.MaxDistance, gui.Parent =
			UDim2.fromOffset(110, 24), Vector3.new(-38, 1, 0), 220, mark
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, distance .. " studs"
		label.TextColor3, label.TextSize, label.Parent = Color3.new(1, 1, 1), 16, gui
	end
	for i, material in { "Earth", "Water", "Metal", "Wood" } do
		local p = part(
			material .. "Source",
			Vector3.new(5, 3, 5),
			Vector3.new(35 + i * 7, 1.5, 10),
			Color3.fromRGB(124, 110, 87)
		)
		p:SetAttribute("MagicMaterial", material)
		p:SetAttribute("AvailableAmount", 50)
		p:SetAttribute("MagicRaise", true)
		game:GetService("CollectionService"):AddTag(p, "MagicMaterialSource")
		game:GetService("CollectionService"):AddTag(p, "MagicManipulable")
	end
	local crate =
		part("MovablePracticeObject", Vector3.new(4, 4, 4), Vector3.new(-20, 3, 0), Color3.fromRGB(125, 96, 60))
	crate.Anchored = false
	game:GetService("CollectionService"):AddTag(crate, "MagicManipulable")
	game:GetService("Lighting").ClockTime = 14
end
return Arena
