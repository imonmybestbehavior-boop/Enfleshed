--!strict

return {
	Player = { MaxHealth = 400 }, -- Temporary stress-test health, not progression.
	Movement = {
		WalkSpeed = 16,
		SprintSpeed = 28,
		DashDistance = 14,
		DashDuration = 0.18,
		DashCooldown = 0.8,
		DashCollisionSize = Vector3.new(2, 3, 2),
		WallPadding = 0.25,
		DirectionEpsilon = 0.01,
		ValidationInterval = 0.25,
		PositionTolerance = 5,
		DashReplicationGrace = 0.25,
		CorrectionOwnershipTime = 0.2,
		SpawnValidationGrace = 1, -- Movement anchoring only; not damage immunity.
		CharacterReadyTimeout = 10,
	},
	Combat = {
		ComboReset = 0.85,
		InputBuffer = 0.18,
		MinimumFacingDot = 0,
		OverlapCollisionGroup = "SandboxCombatQuery",
		Attacks = {
			{
				Startup = 0.05,
				Active = 0.08,
				Recovery = 0.12,
				Damage = 24,
				Size = Vector3.new(5, 5, 5),
				Offset = 3,
				Reach = 6,
			},
			{
				Startup = 0.06,
				Active = 0.08,
				Recovery = 0.12,
				Damage = 26,
				Size = Vector3.new(5, 5, 5),
				Offset = 3,
				Reach = 6,
			},
			{
				Startup = 0.09,
				Active = 0.10,
				Recovery = 0.19,
				Damage = 30,
				Size = Vector3.new(6, 5, 5),
				Offset = 3,
				Reach = 6.5,
			},
		},
	},
	Networking = { RequestsPerSecond = 20, Burst = 30, MaxSequence = 2147483647 },
	Magic = {
		MaxAimDistance = 90,
		MinimumWorldAimDot = 0.35,
		ChargeCostScale = 0.35,
		Player = {
			Mana = 120,
			Capacity = 120, -- Future Locus capacity modifier seam.
			Efficiency = 1, -- Future mana-demand modifier seam.
			Potency = 1, -- Future payload modifier seam.
			StrainTolerance = 30,
			SafeManaDemand = 35,
			SafeStrain = 18,
			ComplexityCapacity = 8,
		},
	},
	Enemy = {
		Health = 80,
		LightHitFlinch = 0.16,
		VisualCollisionGroup = "SandboxEnemyVisuals",
		CollisionHull = { Height = 9, Diameter = 2.8, CenterOffsetY = 1.5, Friction = 0 },
		WalkSpeed = 12,
		DetectionRange = 28,
		DisengageRange = 45,
		AttackRange = 4.5,
		ThinkInterval = 0.1,
		Telegraph = 0.7,
		Active = 0.12,
		Recovery = 0.8,
		Damage = 12,
		HitboxSize = Vector3.new(5, 5, 5),
		HitboxOffset = 3,
		DebugTelegraph = true, -- Temporary replicated parts/highlight, not a VFX system.
		Navigation = {
			AgentRadius = 2,
			AgentHeight = 9,
			AgentCanJump = true,
			WaypointSpacing = 3,
			RepathInterval = 0.75,
			TargetMoveThreshold = 5,
			WaypointTolerance = 2,
			StuckTime = 1.25,
			ProgressDistance = 0.75,
			SweepSize = Vector3.new(2.8, 8.5, 2.8),
		},
	},
	StressTest = { -- Temporary test harness, not a production spawn system.
		WaveSizes = { 1, 5, 10, 20 },
		EnemyCollisions = true, -- Keep bodies separate; toggle only for crowd comparisons.
		InterWaveDelay = 3,
		CorpseLifetime = 2,
		SpawnCenter = Vector3.new(35, 3, -35),
		SpawnRadius = 24,
		MinSpawnSpacing = 8,
		SpawnClearance = 10,
		SpawnAttempts = 16,
		SpawnRadiusStep = 8,
		HitQueryRate = 30,
		PathStartsPerSecond = 4, -- Test defaults: change to evaluate queue hesitation.
		MaxPathsInFlight = 2,
	},
	Dummy = { Health = 100, Position = Vector3.new(0, 3, -18), ResetDelay = 2 },
	Debug = { HitDuration = 0.65, TargetFlashDuration = 0.25, SwingTransparency = 0.8 },
}
