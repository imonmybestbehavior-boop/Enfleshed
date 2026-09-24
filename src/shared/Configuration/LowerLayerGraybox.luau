--!strict

return {
	Enabled = true,
	SpawnDebug = false,
	Colors = {
		Ancient = Color3.fromRGB(50, 55, 65),
		AncientDark = Color3.fromRGB(27, 31, 40),
		Human = Color3.fromRGB(97, 78, 62),
		HumanDark = Color3.fromRGB(59, 51, 47),
		Military = Color3.fromRGB(112, 56, 52),
		Contamination = Color3.fromRGB(122, 55, 77),
		Light = Color3.fromRGB(255, 189, 110),
	},
	PhaseA = {
		Minimum = Vector3.new(-700, -70, 350),
		Maximum = Vector3.new(700, 160, 1750),
		RecruitSpawn = Vector3.new(0, 3, 1550),
		CivilianDistrict = Vector3.new(-250, 3, 1080),
		MilitaryStaging = Vector3.new(0, 3, 380), -- Phase-B connector marker.
		MarketCombatYard = Vector3.new(460, 3, 650),
	},
	Metrics = {
		PrimaryAvenueWidth = 52,
		MarketCrossAvenueWidth = 42,
		LocalStreetWidth = 26,
		AlleyWidth = 16,
		CatchSurfaceY = -80,
		UpperRouteHeight = 72,
	},
	-- Distant visual enclosure, outside Phase A routes and beneath the catch.
	Enclosure = {
		Minimum = Vector3.new(-1000, -140, 200),
		Maximum = Vector3.new(1000, 1000, 1900),
		Thickness = 24,
	},
	Boundary = { HalfWidth = 1550, NorthZ = 2250, SouthZ = -2250, Height = 900, BottomY = -80 },
}
