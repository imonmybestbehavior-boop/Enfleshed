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
	elseif kind == "Slow" and number(out.Multiplier) and profile.MinSlowMultiplier then
		-- executor: effective = 1 - (1 - Multiplier) * potency  ≥  MinSlowMultiplier
		out.Multiplier = math.max(out.Multiplier, 1 - (1 - profile.MinSlowMultiplier) / p)
	elseif kind == "DamageOverTime" and number(out.Amount) then
		out.Amount = capScaled(out.Amount, profile.MaxDotPerTick, p)
	elseif kind == "Heal" and number(out.Amount) then
		out.Amount = capScaled(out.Amount, profile.MaxHealPerHit, p)
	elseif kind == "Shield" and number(out.Amount) then
		out.Amount = capScaled(out.Amount, profile.MaxShield, p)
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
	elseif kind == "ModifyAttribute" and number(out.Amount) and profile.MaxAttributeChange then
		local limit = profile.MaxAttributeChange / p
		out.Amount = math.clamp(out.Amount, -limit, limit)
	end
	return out
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
