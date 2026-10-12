--!strict

return table.freeze({
	Compass = { UpdateRate = 0.05, ObjectiveVerticalThreshold = 12 },
	Map = {
		ToggleKey = "M",
		SurfaceColor = Color3.fromRGB(120, 135, 150),
		UndergroundColor = Color3.fromRGB(95, 135, 120),
	},
	Ambient = {
		Enabled = true,
		Debug = false,
		Cap = 6,
		SpawnInterval = 15,
		MinimumPlayerDistance = 55,
		MaximumPlayerDistance = 280,
		SafeZoneRadius = 70,
		DespawnDistance = 420,
		MinimumCandidateReuseSeconds = 90,
	},
})
