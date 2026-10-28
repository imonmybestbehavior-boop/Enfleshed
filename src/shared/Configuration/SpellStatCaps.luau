--!strict
-- Stat-cap profiles applied when a spell resolves against a target. The profile
-- depends on who is hit (see Modules/SpellStatCaps): NPCs/world → PvE, players in
-- an open zone or duel → PvPOpen, players in a ranked zone → PvPRanked.
-- Caps limit the *final* value after potency. Omitted caps are unlimited.
-- Starting values; tune from PvP playtests and SpellUsage analytics.
return {
	PvE = {}, -- identity: PvE balance is governed by rank budgets and MagicLab limits
	PvPOpen = {
		DamageMultiplier = 0.6, -- every damage source (spells, DoT, melee, summons) vs players
		MaxDamagePerHit = 35,
		MaxDotPerTick = 4,
		MaxHealPerHit = 30,
		MaxShield = 40,
		MinSlowMultiplier = 0.5, -- at most a 50% slow
		MaxEffectDuration = 4, -- slow, bind, control, reveal, time dilation, transformation, marks, stat changes
		MaxBindDuration = 1,
		MaxControlAcceleration = 16,
		MaxDisplacement = 8,
		MaxForce = 40,
		MinTimeRate = 0.6,
		MaxTransformScale = 1.2,
		MinTransformScale = 0.85,
		MaxAttributeChange = 25, -- armor/strength points and the percent attributes
		MaxDamageTakenChange = 15, -- DamageTaken percentage points (vulnerability or protection)
		MaxResistanceChange = 0.25, -- Resistance fraction per element (-1..1 scale)
		MaxStunDuration = 0.5, -- stuns on players (diminishing returns apply too)
		MaxSilenceDuration = 1.5,
		-- Stealth hides only from monsters for now. Turning this on hides stealthed
		-- players from opponents (MagicStealthSpec / MagicStealthController).
		StealthHidesFromPlayers = false,
		MaxResourceDrainPerHit = 15, -- DrainResource against players (Mana or a special resource)
		MaxRushDistance = 24, -- Rush (Dash/Blink) while the caster can fight players
		MaxConstructHealth = 150, -- Construct.Health cast while the caster can fight players
		MinHiddenTrapArmDelay = 1, -- a Hidden Field trap arms no sooner than this in PvP
		-- Interception (OnBeforeDamageTaken) against hits from players.
		MaxInterceptReducePercent = 50,
		MaxInterceptNegateChargesVsPlayer = 1, -- per spell
		MaxInterceptRedirectToAttackerPercent = 50,
		-- Tether: length while the caster can fight players, soul-link share onto
		-- a player, and whether Pull may move players.
		MaxTetherLength = 40,
		MaxTetherShareDamagePercent = 50,
		TetherPullOnPlayers = true,
		-- Polymorph on a player (always breaks on damage).
		MaxPolymorphDurationVsPlayer = 1.5,
	},
	PvPRanked = {
		DamageMultiplier = 0.5,
		MaxDamagePerHit = 30,
		MaxDotPerTick = 3,
		MaxHealPerHit = 25,
		MaxShield = 30,
		MinSlowMultiplier = 0.6,
		MaxEffectDuration = 3,
		MaxBindDuration = 0.75,
		MaxControlAcceleration = 12,
		MaxDisplacement = 6,
		MaxForce = 30,
		MinTimeRate = 0.7,
		MaxTransformScale = 1.15,
		MinTransformScale = 0.9,
		MaxAttributeChange = 20,
		MaxDamageTakenChange = 10,
		MaxResistanceChange = 0.2,
		MaxStunDuration = 0.5,
		MaxSilenceDuration = 1,
		StealthHidesFromPlayers = false,
		MaxResourceDrainPerHit = 10,
		MaxRushDistance = 18,
		MaxConstructHealth = 100,
		MinHiddenTrapArmDelay = 1.5,
		MaxInterceptReducePercent = 35,
		MaxInterceptNegateChargesVsPlayer = 1,
		MaxInterceptRedirectToAttackerPercent = 30,
		MaxTetherLength = 30,
		MaxTetherShareDamagePercent = 35,
		TetherPullOnPlayers = false,
		MaxPolymorphDurationVsPlayer = 1.0,
	},
}
