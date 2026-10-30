--!strict
-- Spell Lab limits. The Lab is enabled on live servers; Forge features are gated by SpellProgression.
return {
	Enabled = true,
	StudioOnly = false,
	AllowLive = true,
	LibraryDataStoreName = "EnfleshedMagicLabLibraryV1",
	LibrarySaveDebounce = 2,
	PersistentConstructDataStoreName = "EnfleshedPersistentConstructsV1",
	MaxDamage = 100,
	MaxHeal = 100,
	MaxShield = 100,
	MaxShieldPerTarget = 150,
	-- Largest ScaleBy bonus per unit and in total (MagicScaleSpec).
	MaxScaleBonus = 100,
	MaxArmorModifier = 100,
	MinMagicStrengthModifier = -75,
	MaxMagicStrengthModifier = 100,
	MinTransformScale = 0.7,
	MaxTransformScale = 1.35,
	MaxCombinedTransformScale = 1.75,
	-- Transformation modes Polymorph and Shapeshift (provisional).
	MinPolymorphDuration = 1,
	MaxPolymorphDuration = 8,
	PolymorphSpeedMultiplier = 0.7,
	MinShapeshiftDuration = 5,
	MaxShapeshiftDuration = 60,
	MaxBindDuration = 4,
	-- Stun binds and blocks attacks/casts; PvP caps it lower (SpellStatCaps).
	MaxStunDuration = 1.5,
	-- Silence blocks spell casts and channels (players only).
	MaxSilenceDuration = 4,
	MaxCleanseCount = 10,
	-- Taunt / Fear (creatures only). Provisional.
	MaxTauntDuration = 6,
	MaxFearDuration = 4,
	MaxStealthDuration = 8, -- provisional
	MaxResourceTransfer = 50, -- DrainResource / RestoreResource per target, provisional
	HealOverflowShieldDuration = 5, -- Heal Overflow = "Shield", provisional
	-- Rush Form (Dash / Blink), provisional. Path checks mirror displaceTarget.
	MaxRushDistance = 30,
	MaxRushSpeed = 120,
	MaxRushRadius = 6,
	RushSampleStep = 2,
	RushWallPadding = 1.5,
	RushMaxStepHeight = 4,
	RushMinGroundNormalY = 0.55,
	RushMinDistance = 1,
	-- Constructs and traps (Phase 10), provisional.
	MaxConstructInterval = 10,
	MaxConstructHealth = 500,
	MaxTrapArmDelay = 10,
	PersistentHealthSaveInterval = 30,
	-- Spell vs Spell (Dispel, Force on spells, Field lenses), provisional.
	MaxDispelSeconds = 30,
	MaxSpellForceDistance = 10,
	TetherDispelWidth = 2,
	-- Blood magic (health as a spell cost), provisional. MagicBloodCostSpec.
	BloodHealthFloor = 0.1, -- a cast or upkeep tick never leaves the caster below this fraction of max health
	HealthPerMana = 2, -- HP paid per mana replaced (health is always the worse rate)
	MaxFlatHealthCost = 100,
	MaxPercentHealthCost = 40,
	MinHealthPerSecond = 0.5,
	MaxHealthPerSecond = 10,
	-- Environment reactions (MagicEnvironmentSpec), provisional. Tags read by the
	-- server: "Flammable" and "Water" (CollectionService) plus Terrain water.
	WetChainRadius = 8, -- studs from the last character struck
	WetChainFraction = 0.5, -- of the original hit, per hop
	WetChainJumps = 3,
	EnvironmentFireRadius = 4,
	EnvironmentFireDuration = 5,
	EnvironmentFireInterval = 0.5,
	EnvironmentFireBurn = 2, -- DamageOverTime per second for 2 s, refreshed each tick inside
	IgniteCooldown = 3, -- a part ignites at most once every this many seconds
	MaxEnvironmentFires = 6, -- per caster; the oldest goes out first
	FlammableMaterials = {}, -- Enum.Material names that burn without a tag (none by default)
	IcePlatformSize = 6,
	IcePlatformThickness = 1,
	IcePlatformDuration = 8,
	IcePlatformHealth = 50,
	MaxIcePlatforms = 4, -- per caster; the oldest melts first
	-- Tether Form, provisional.
	MinTetherLength = 10,
	MaxTetherLength = 60,
	MaxTetherInterval = 10,
	TetherLineOfSightGrace = 0.5,
	TetherPullStart = 0.8,
	TetherPullSpeed = 12,
	MaxTethersPerCaster = 2,
	MaxTethersPerCharacter = 3,
	-- Interception (OnBeforeDamageTaken), provisional.
	MaxInterceptionCharges = 5,
	MinInterceptionInterval = 0.25,
	-- Recast (OnRecast), provisional.
	MaxRecasts = 3,
	MinRecastInterval = 0.2,
	MaxRevealDuration = 15,
	MaxEffectsPerTarget = 8,
	-- The same Enchantment (same spell) stacks at most this many times on one
	-- character, from different casters; a recast by the same caster refreshes
	-- it. Different Enchantments have no cap.
	MaxSameEnchantmentPerHolder = 3,
	MaxEffectTargets = 256,
	MaxElementalMarkStacks = 5,
	-- Elemental interactions, one list (MagicElementalInteractionSpec):
	--   Starter effects: { Incoming = X, Effects } apply whenever a mark of X lands.
	--   Reactions: { Name, Existing, Incoming, ConsumeStacks, Effects } fire once when
	--   Incoming lands on a target that already has Existing (an element mark, or
	--   "Frozen" from Freeze). First match wins; reactions never trigger reactions.
	--   Every effect is credited to the incoming caster, spends from the cascade
	--   budget and goes through SpellStatCaps.
	ElementalInteractions = {
		{
			Incoming = "Fire",
			Effects = {
				{
					Kind = "DamageOverTime",
					Amount = 2,
					Interval = 1,
					Duration = "Mark",
					RequiresElementalMark = "Fire",
				},
				{
					Kind = "Slow",
					Multiplier = 0.9,
					Duration = "Mark",
					RequiresElementalMark = "Fire",
				},
				{
					Kind = "ModifyAttribute",
					Attribute = "MagicStrength",
					Amount = -20,
					Duration = "Mark",
					RequiresElementalMark = "Fire",
				},
			},
		},
		{
			Incoming = "Water",
			Effects = {
				{
					Kind = "ConsumeElementalMark",
					Element = "Fire",
					Stacks = 5,
				},
				{
					Kind = "Slow",
					Multiplier = 0.95,
					Duration = "Mark",
					RequiresElementalMark = "Water",
				},
			},
		},
		{
			Incoming = "Ice",
			Effects = {
				{ Kind = "Slow", Multiplier = 0.8, Duration = "Mark", RequiresElementalMark = "Ice" },
			},
		},
		{
			Incoming = "Lightning",
			Effects = {
				{
					Kind = "DamageOverTime",
					Amount = 1,
					Interval = 0.5,
					Duration = "Mark",
					RequiresElementalMark = "Lightning",
				},
				{ Kind = "Slow", Multiplier = 0.9, Duration = "Mark", RequiresElementalMark = "Lightning" },
			},
		},
		{
			Incoming = "Earth",
			Effects = {
				{ Kind = "Slow", Multiplier = 0.85, Duration = "Mark", RequiresElementalMark = "Earth" },
			},
		},
		{
			Incoming = "Wind",
			Effects = {
				{ Kind = "Force", Magnitude = 8, Upward = 0 },
			},
		},
		{
			Incoming = "Poison",
			Effects = {
				{
					Kind = "DamageOverTime",
					Amount = 1.5,
					Interval = 1,
					Duration = "Mark",
					RequiresElementalMark = "Poison",
				},
				{ Kind = "Slow", Multiplier = 0.95, Duration = "Mark", RequiresElementalMark = "Poison" },
			},
		},
		{
			Name = "Conduct", -- Wet + Lightning: the hit chains to Wet targets nearby
			Existing = "Water",
			Incoming = "Lightning",
			ConsumeStacks = 1,
			-- The chain itself is the Wet chain (MagicEnvironmentSpec): Lightning damage on a
			-- Wet character hops to other Wet characters. Conduct still names the reaction.
			Effects = {},
		},
		{
			Name = "Firestorm", -- Burning + Wind: a small burning Field
			Existing = "Fire",
			Incoming = "Wind",
			ConsumeStacks = 1,
			Effects = {
				{ Kind = "SpawnField", Radius = 6, Duration = 3, Interval = 0.5, TickDamage = 3, Element = "Fire" },
			},
		},
		{
			Name = "Freeze", -- Wet + Ice: a 1 s Stun (Phase 6 diminishing returns and PvP cap)
			Existing = "Water",
			Incoming = "Ice",
			ConsumeStacks = 1,
			Effects = { { Kind = "Stun", Duration = 1 } },
		},
		{
			Name = "Shatter", -- Frozen + Earth or Force: bonus Physical damage, ends the Freeze
			Existing = "Frozen",
			Incoming = { "Earth", "Force" },
			Effects = { { Kind = "Damage", Amount = 15, DamageChannel = "Physical" } },
		},
		{
			Name = "ToxicSmoke", -- Burning + Poison: a Field that blocks Reveal
			Existing = "Fire",
			Incoming = "Poison",
			ConsumeStacks = 1,
			Effects = { { Kind = "Smoke", Radius = 8, Duration = 5 } },
		},
		{
			Name = "Mire", -- Earth + Water: a strong Slow
			Existing = "Earth",
			Incoming = "Water",
			ConsumeStacks = 1,
			Effects = { { Kind = "Slow", Multiplier = 0.4, Duration = 3 } },
		},
	},
	-- How long a target's last reaction stays visible to conditions (Status.Reaction).
	ReactionMemory = 5,
	MaxPeriodicEffectsGlobal = 256,
	MaxPeriodicEffectsPerCaster = 32,
	MinSlowMultiplier = 0.25,
	MaxForce = 100,
	MaxControlledMass = 10000,
	MaxSpecialResourceCost = 10000,
	MaxSpecialResourceCostTypes = 4,
	MaxDisplacementDistance = 24,
	MinTimeRate = 0.25,
	MaxTimeRate = 2,
	MaxRadius = 20,
	MaxRange = 200,
	MaxDuration = 15,
	MaxManaUpkeepPerSecond = 100,
	MaxStrainPerSecond = 100,
	MaxCastingMovementPenalty = 0.9,
	MaxChargeReadyHoldSeconds = 8,
	MaxSpeed = 200,
	MaxAcceleration = 100,
	MaxGravity = 100,
	MinCooldown = 0.15,
	MinInterval = 0.1,
	AimUpdateInterval = 0.1,
	MaxTargets = 16,
	MaxMultiplier = 4,
	MaxJumpBonus = 30,
	MaxAerialSpeed = 48,
	MaxPayloads = 4,
	MaxSteps = 4,
	MaxProjectileBehaviors = 3,
	MaxProjectileMotionPhases = 4,
	ProjectileMotionModes = {
		"Linear",
		"Arcing",
		"Bezier",
		"Falling",
		"Orbiting",
		"Stationary",
		"Expanding",
		"Attached",
	},
	MaxProjectileArcHeight = 40,
	MaxProjectileBezierOffset = 30,
	MaxProjectileOrbitRadius = 20,
	MaxProjectileOrbitSpeed = 8,
	MaxProjectileExpansion = 8,
	MaxProjectileExpansionSpeed = 12,
	ProjectileStationarySampleInterval = 0.1,
	MaxHomingSearchRadius = 60,
	MaxHomingTurnRate = 540,
	MaxPierces = 5,
	MaxChainJumps = 6,
	MaxPropagationTargets = 8,
	MaxBounces = 5,
	MaxSplitChildren = 5,
	MaxSplitAngle = 60,
	MaxSpreadPairs = 2,
	MaxSpreadAngle = 45,
	MaxAbsorbedProjectiles = 8,
	MaxAbsorbPowerGain = 1,
	MaxAbsorbPotencyMultiplier = 4,
	MaxProjectileReflections = 8,
	MaxProjectileReflectionHops = 3,
	MaxActivePerPlayer = 8,
	MaxActiveGlobal = 64,
	MaxMagicEventDepth = 8,
	-- Cost units one root event may cascade into: each dispatched event or area
	-- query costs 1 plus its target count. See MagicOperationBudget.
	MaxOperationsPerCascade = 256,
	-- SpawnEffect: a trigger step that starts another Form at the event.
	MaxSpawnNesting = 2, -- spawned effects may themselves spawn, this many levels deep
	MaxSpawnCount = 3, -- Projectiles started by one SpawnEffect step
	MaxSpawnSpreadAngle = 90, -- total fan angle for spawned Projectiles
}
