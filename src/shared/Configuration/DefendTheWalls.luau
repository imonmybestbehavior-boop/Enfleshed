--!strict
-- Provisional mission tuning. Studio acceleration never writes real progression.
return {
	Duration = 600,
	Preparation = 20,
	Results = 12,
	MaxParticipants = 4,
	-- Staging courtyard behind the inner bastion; the first defender line is wall 1.
	-- The live defender spawn follows the active wall (Workspace.DefendTheWalls.DefenderSpawn).
	Hub = Vector3.new(0, 6, 1362),
	Defender = Vector3.new(0, 6, 1140),
	Gateway = Vector3.new(0, 5, 1389), -- the final doors; their HP is still reported as Gateway
	GatewayIntegrity = 1000,
	-- Integrity of walls 1-3. All gates of one wall share its pool; only the doors lose the mission.
	Walls = { Integrity = { 650, 800, 950 }, Count = 3 },
	Map = {
		Seed = 1693,
		BranchChance = 0.3, -- chance an enemy targets another lane's gate via the crossroads
		Lighting = {
			ClockTime = 0.4,
			Brightness = 1.4,
			Exposure = 0.35, -- lifted for handheld screens; Steam Deck checked at this value
			Ambient = Color3.fromRGB(34, 38, 48),
			OutdoorAmbient = Color3.fromRGB(58, 66, 84),
			FogDensity = 0.38,
		},
	},
	-- Guard squads per wall. Spawned at preparation, never respawn within a round,
	-- fall back to the next wall when theirs is breached.
	Guards = {
		PerWall = {
			{ Spearman = 4, Crossbowman = 2 },
			{ Spearman = 3, Crossbowman = 3 },
			{ Spearman = 2, Crossbowman = 4 },
		},
		MaxTotal = 18,
		ThinkInterval = 0.3,
		RetreatTimeout = 14,
		Spearman = { Health = 240, Damage = 16, Range = 7, Cooldown = 1.3, Leash = 24, WalkSpeed = 15 },
		Crossbowman = { Health = 150, Damage = 20, Range = 85, Cooldown = 2.4, Leash = 0, WalkSpeed = 14 },
	},
	GatewayWarnings = { 0.75, 0.5, 0.25 },
	GatewayDamageScale = { Basic = 0.25, Swift = 0.2, Brute = 0.65, Elite = 1.1 },
	RepairCharges = 2,
	RepairAmount = 180,
	RepairDistance = 12,
	StuckTimeout = 32,
	Phases = {
		{ At = 0, Name = "INITIAL INCURSION", Interval = 7, Target = 3, Cap = 9, Budget = 65, Lanes = { 1 } },
		{ At = 120, Name = "MULTIPLE APPROACHES", Interval = 6, Target = 5, Cap = 10, Budget = 65, Lanes = { 1, 2 } },
		{
			At = 240,
			Name = "SUSTAINED ASSAULT",
			Interval = 5.5,
			Target = 6,
			Cap = 10,
			Budget = 65,
			Lanes = { 1, 2, 3 },
		},
		{ At = 360, Name = "BREACH THREAT", Interval = 5, Target = 7, Cap = 10, Budget = 80, Lanes = { 1, 2, 3 } },
		{ At = 510, Name = "LAST STAND", Interval = 4.5, Target = 8, Cap = 11, Budget = 55, Lanes = { 1, 2, 3 } },
	},
	Rewards = { VictoryXP = 120, VictoryMarks = 50, DefeatXP = 30, DefeatMarks = 10, BonusXP = 20, BonusMarks = 10 },
	Studio = { Accelerated = false, Duration = 120, MockProgression = true },
}
