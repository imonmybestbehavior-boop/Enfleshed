--!strict
-- Pure stat-cap rules. Profiles live in Configuration/SpellStatCaps. Payload
-- caps are expressed on the authored value so that `value * potency` (as the
-- executors compute it) never exceeds the cap; the input payload is never mutated.
local Policy = require(script.Parent.CombatPolicy)
local Caps = {}

Caps.RankedZone = Policy.RankedZone
local DURATION_KINDS = {
	Slow = true,
	Bind = true,
	Control = true,
	Reveal = true,
	TimeDilation = true,
	Transformation = true,
	ElementalMark = true,
	ModifyAttribute = true,
	DamageOverTime = true,
	Stun = true,
	Silence = true,
}

-- Payload kinds Caps.payload leaves unchanged, and why. Listed so every
-- Schema.Payloads kind is accounted for here (test_magic_registry_parity).
Caps.UncappedKinds = {
	Damage = "Capped on the final hit by Caps.damage (every damage source)",
	ConsumeElementalMark = "Removes mark stacks; no numeric effect on the target",
	Restoration = "Support over time; PvP profiles apply only between opponents",
	Enhancement = "Affects only the caster",
	AerialMovement = "Affects only the caster",
	Manipulation = "Moves world objects, not players",
	Summon = "Summon damage is capped by Caps.damage",
	Cleanse = "Removes effects; it has no number to cap",
	Dispel = "Acts on spells, not players; its End rule compares spell complexity",
	Taunt = "Creatures only; never applies to players, so no PvP cap",
	Fear = "Creatures only; never applies to players, so no PvP cap",
	Stealth = "Hides from monsters only while StealthHidesFromPlayers is off; nothing to cap",
	RestoreResource = "Support; PvP profiles apply only between opponents",
}

-- ModifyAttribute caps by attribute; anything not listed uses MaxAttributeChange.
local ATTRIBUTE_CAP_KEYS = {
	DamageTaken = "MaxDamageTakenChange",
	Resistance = "MaxResistanceChange",
}

-- Profile name for a hit. `attacker`/`target` are CombatPolicy owners (nil = not player-owned).
-- PvP profiles apply only between players who may fight each other (same PvP
-- zone or a mutual duel); co-op support between teammates stays PvE.
function Caps.profileName(attacker: Policy.Owner?, target: Policy.Owner?): string
	if target == nil or attacker == nil or attacker.UserId == target.UserId or not Policy.allows(attacker, target) then
		return "PvE"
	end
	if attacker.Zone == Caps.RankedZone and target.Zone == Caps.RankedZone then
		return "PvPRanked"
	end
	return "PvPOpen"
end

-- Profile for effects on the caster's own movement (Rush), which have no
-- target: PvP rules apply while the caster could be fighting players (inside a
-- PvP zone or in a duel).
function Caps.selfProfileName(owner: Policy.Owner?): string
	if owner == nil then
		return "PvE"
	elseif owner.Zone == Caps.RankedZone then
		return "PvPRanked"
	elseif owner.Zone == Policy.OpenZone or owner.DuelOpponent ~= nil then
		return "PvPOpen"
	end
	return "PvE"
end

local function number(value: any): boolean
	return type(value) == "number" and value == value
end

local function capScaled(value: number, cap: number?, potency: number): number
	if not cap or potency <= 0 then
		return value
	end
	return math.min(value, cap / potency)
end

-- Returns the payload unchanged for PvE/empty profiles, otherwise a capped copy.
function Caps.payload(payload: any, profile: { [string]: number }?, potency: number?): any
	if not profile or next(profile) == nil or type(payload) ~= "table" then
		return payload
	end
	local p = if number(potency) and (potency :: number) > 0 then potency :: number else 1
	local out = table.clone(payload)
	local kind = out.Kind
	if DURATION_KINDS[kind] and number(out.Duration) and profile.MaxEffectDuration then
		out.Duration = math.min(out.Duration, profile.MaxEffectDuration)
	end
	if kind == "Bind" and number(out.Duration) and profile.MaxBindDuration then
		out.Duration = math.min(out.Duration, profile.MaxBindDuration)
	elseif kind == "Stun" and number(out.Duration) and profile.MaxStunDuration then
		out.Duration = math.min(out.Duration, profile.MaxStunDuration)
	elseif kind == "Silence" and number(out.Duration) and profile.MaxSilenceDuration then
		out.Duration = math.min(out.Duration, profile.MaxSilenceDuration)
	elseif kind == "DrainResource" and number(out.Amount) then
		out.Amount = capScaled(out.Amount, profile.MaxResourceDrainPerHit, p)
	elseif kind == "Slow" and number(out.Multiplier) and profile.MinSlowMultiplier then
		-- executor: effective = 1 - (1 - Multiplier) * potency  ≥  MinSlowMultiplier
		out.Multiplier = math.max(out.Multiplier, 1 - (1 - profile.MinSlowMultiplier) / p)
	elseif kind == "Control" and number(out.Acceleration) then
		out.Acceleration = capScaled(out.Acceleration, profile.MaxControlAcceleration, p)
	elseif kind == "Displacement" and number(out.Distance) then
		out.Distance = capScaled(out.Distance, profile.MaxDisplacement, p)
	elseif kind == "Force" and number(out.Magnitude) and profile.MaxForce then
		out.Magnitude = math.min(out.Magnitude, profile.MaxForce)
		if number(out.Upward) then
			out.Upward = math.min(out.Upward, profile.MaxForce)
		end
	elseif kind == "TimeDilation" and number(out.Rate) and profile.MinTimeRate and out.Rate < 1 then
		out.Rate = math.max(out.Rate, profile.MinTimeRate)
	elseif kind == "Transformation" and number(out.Multiplier) then
		-- executor: effective = 1 + (Multiplier - 1) * potency
		if profile.MaxTransformScale and out.Multiplier > 1 then
			out.Multiplier = math.min(out.Multiplier, 1 + (profile.MaxTransformScale - 1) / p)
		elseif profile.MinTransformScale and out.Multiplier < 1 then
			out.Multiplier = math.max(out.Multiplier, 1 - (1 - profile.MinTransformScale) / p)
		end
	elseif kind == "ModifyAttribute" and number(out.Amount) then
		local cap = profile[ATTRIBUTE_CAP_KEYS[out.Attribute] or "MaxAttributeChange"]
		if cap then
			local limit = cap / p
			out.Amount = math.clamp(out.Amount, -limit, limit)
		end
	end
	return out
end

-- DamageOverTime, Heal and Shield amounts are capped once, on the final value
-- (after ScaleBy and potency): MaxDotPerTick in DamageService, MaxHealPerHit in
-- Status.heal, MaxShield in the Shield executor. See Caps.finalAmount.
function Caps.finalAmount(kind: string, amount: number, profile: { [string]: number }?): number
	if not profile or not number(amount) then
		return amount
	end
	local cap = if kind == "DamageOverTime"
		then profile.MaxDotPerTick
		elseif kind == "Heal" then profile.MaxHealPerHit
		elseif kind == "Shield" then profile.MaxShield
		else nil
	return if cap then math.min(amount, cap) else amount
end

-- Final damage against a target under a profile (applies to every damage source).
function Caps.damage(amount: number, profile: { [string]: number }?): number
	if not profile or not number(amount) then
		return amount
	end
	local result = amount * (profile.DamageMultiplier or 1)
	if profile.MaxDamagePerHit then
		result = math.min(result, profile.MaxDamagePerHit)
	end
	return result
end

return Caps
