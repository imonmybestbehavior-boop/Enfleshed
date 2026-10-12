--!strict
-- Session prototype. Names, clothing colors and scrip are gameplay placeholders.
return {
	DevelopmentSpells = false, -- Studio opt-in; normal aptitude uses equipment only.
	Opening = { Node = "B1", Offset = Vector3.new(0, 3, -20) },
	Presets = {
		{ Name = "Ash cloth", Skin = Color3.fromRGB(179, 135, 104), Cloth = Color3.fromRGB(76, 79, 70) },
		{ Name = "Worker ochre", Skin = Color3.fromRGB(105, 70, 50), Cloth = Color3.fromRGB(115, 91, 60) },
		{ Name = "Dust linen", Skin = Color3.fromRGB(223, 187, 156), Cloth = Color3.fromRGB(124, 115, 98) },
	},
	NPCs = {
		Enabled = true,
		Scale = 1,
		MaxPopulation = 80,
		AmbientTarget = 72,
		EventReserve = 8,
		UpdatesPerTick = 24,
		SpawnAttemptsPerTick = 2,
		Tick = 0.1,
		Health = 100,
		Speed = 10,
		FleeSpeed = 15,
		DangerRadius = 32,
		GuardDamage = 12,
		GuardRange = 5,
		GuardCooldown = 1.2,
		RepathSeconds = 4,
		PathStartsPerSecond = 2,
		RespawnSeconds = 90,
		Roster = {
			{ Name = "Iven", Role = "Resident", Nodes = { "B3", "B3" } },
			{ Name = "Sela", Role = "Resident", Nodes = { "B4", "B4" } },
			{ Name = "Mara", Role = "Shopkeeper", Nodes = { "B6", "B6" } },
			{ Name = "Oren", Role = "Worker", Nodes = { "B7", "B7" } },
			{ Name = "Tess", Role = "Worker", Nodes = { "B6", "B6" } },
			{ Name = "Guard", Role = "Guard", Nodes = { "S4", "S4" } },
			{ Name = "Military", Role = "Guard", Nodes = { "S6", "S6" } },
			{ Name = "Watch patrol", Role = "Patrol", Nodes = { "S4", "S5", "S4" } },
			{ Name = "Courier", Role = "Civilian", Nodes = { "S3", "S4", "S3" } },
		},
	},
}
