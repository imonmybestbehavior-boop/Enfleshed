--!strict
-- Server timing for reusable procedural casting gestures. Timings are seconds.
local PoseSpec = require(script.Parent.Parent.Modules.MagicPoseSpec)
return {
	Profiles = PoseSpec.Profiles,
	Forms = {
		Projectile = "ProjectileCast",
		Beam = "BeamCast",
		Wave = "SelfCast",
		Field = "GroundCast",
		Aura = "SelfCast",
		Construct = "GroundCast",
		SelfEnhancement = "SelfCast",
		Manipulation = "GroundCast",
	},
	Timing = {
		ProjectileCast = { Gather = 0.16, Release = 0.12, Recovery = 0.20 },
		BeamCast = { Gather = 0.28, Release = 0.18, Recovery = 0.24 },
		GroundCast = { Gather = 0.20, Release = 0.12, Recovery = 0.22 },
		SelfCast = { Gather = 0.14, Release = 0.10, Recovery = 0.20 },
		OverheadCast = { Gather = 0.22, Release = 0.18, Recovery = 0.3 },
		WardCast = { Gather = 0.18, Release = 0.14, Recovery = 0.22 },
		SweepCast = { Gather = 0.20, Release = 0.17, Recovery = 0.25 },
	},
	ChargePoseDuration = 3,
	MaxPoseDuration = 3.5,
	ObserverDistance = 180,
	MaxObservedCasts = 32,
	LocalDistortion = {
		UpdateInterval = 0.1,
		FalloffDistance = 24,
		MaxBlur = 2.5,
		MaxContrast = 0.08,
		MaxDesaturation = 0.06,
	},
	ParticleTexture = "rbxasset://textures/particles/sparkles_main.dds",
	ParticleRate = 12,
	AreaNodes = 8,
	ParticleBudget = {
		MaxEmitters = 32,
		MaxContinuousRate = 180,
		MaxBurstPerSecond = 240,
		BurstCapacity = 300,
	},
}
