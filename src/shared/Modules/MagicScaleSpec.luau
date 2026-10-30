--!strict
-- Pure rules for scaling a spell's numbers.
--
--   Casting.ChargeScaling = { MinPotency, MaxPotency }   (Charged / HoldAndRelease)
--     How long the cast was held maps linearly onto a potency multiplier:
--     MinimumCharge -> MinPotency, MaximumCharge -> MaxPotency.
--
--   payload.ScaleBy = { Source, PerUnit, Max, Element? }  (Damage, DamageOverTime, Heal, Shield)
--     amount = authored Amount + min(PerUnit * units, Max), per target.
--
-- Order of operations (each clamp happens once, at its own step):
--   authored amount -> ScaleBy -> charge potency -> outgoing strength
--   -> mitigation -> final caps (MaxDamage / MaxHeal and PvP SpellStatCaps).
local Spec = {}

Spec.MinPotency = 0.25
Spec.MaxPotency = 5

Spec.ScalableKinds = { Damage = true, DamageOverTime = true, Heal = true, Shield = true }

-- Units per source; `read(source, element)` returns the raw value MagicService
-- resolves through the condition value adapters (and the status service for
-- mark stacks).
Spec.Sources = {
	TargetMissingHealthPercent = {
		Label = "Target's missing health (%)",
		Units = function(raw: number): number
			return math.clamp((1 - raw) * 100, 0, 100) -- raw: Target.HealthPercent (0..1)
		end,
	},
	ElementalMarkStacks = {
		Label = "Elemental mark stacks on the target",
		NeedsElement = true,
		Units = function(raw: number): number
			return math.max(0, raw)
		end,
	},
	DistanceFromCaster = {
		Label = "Distance from the caster (studs)",
		Units = function(raw: number): number
			return math.max(0, raw)
		end,
	},
	AreaOccupants = {
		Label = "Targets inside the area",
		Units = function(raw: number): number
			return math.max(0, raw)
		end,
	},
	TriggerCount = {
		Label = "Times this event has fired",
		Units = function(raw: number): number
			return math.max(0, raw)
		end,
	},
	ChargePercent = {
		Label = "Charge (%)",
		Units = function(raw: number): number
			return math.clamp(raw * 100, 0, 100) -- raw: charge fraction (0..1)
		end,
	},
	HealthPaid = {
		Label = "Health paid (HP)",
		Units = function(raw: number): number
			return math.max(0, raw) -- raw: HP paid at cast (blood magic)
		end,
	},
}
Spec.SourceOrder = {
	"TargetMissingHealthPercent",
	"ElementalMarkStacks",
	"DistanceFromCaster",
	"AreaOccupants",
	"TriggerCount",
	"ChargePercent",
	"HealthPaid",
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- 0..1 position of `held` between MinimumCharge and MaximumCharge.
function Spec.chargeFraction(held: number?, minimum: number?, maximum: number?): number
	if not finite(held) or not finite(minimum) or not finite(maximum) then
		return 0
	end
	local span = (maximum :: number) - (minimum :: number)
	if span <= 0 then
		return if (held :: number) >= (minimum :: number) then 1 else 0
	end
	return math.clamp(((held :: number) - (minimum :: number)) / span, 0, 1)
end

-- Potency multiplier from ChargeScaling; 1 when the spell has none.
function Spec.chargePotency(scaling: any, held: number?, minimum: number?, maximum: number?): number
	if type(scaling) ~= "table" or not finite(scaling.MinPotency) or not finite(scaling.MaxPotency) then
		return 1
	end
	local low = math.clamp(scaling.MinPotency, Spec.MinPotency, Spec.MaxPotency)
	local high = math.clamp(scaling.MaxPotency, Spec.MinPotency, Spec.MaxPotency)
	return low + (high - low) * Spec.chargeFraction(held, minimum, maximum)
end

function Spec.units(scaleBy: any, read: (string, string?) -> any): number
	local source = type(scaleBy) == "table" and Spec.Sources[scaleBy.Source]
	if not source then
		return 0
	end
	local raw = read(scaleBy.Source, scaleBy.Element)
	if not finite(raw) then
		return 0
	end
	return source.Units(raw)
end

-- Authored amount plus the ScaleBy bonus (capped by Max), never negative.
function Spec.amount(base: number, scaleBy: any, units: number): number
	local amount = if finite(base) then base else 0
	if type(scaleBy) ~= "table" or not finite(scaleBy.PerUnit) or not finite(units) then
		return math.max(0, amount)
	end
	local bonus = scaleBy.PerUnit * units
	if finite(scaleBy.Max) then
		bonus = math.min(bonus, scaleBy.Max)
	end
	return math.max(0, amount + bonus)
end

-- Validation shared by SpellSpec. Returns ok, reason.
function Spec.validateScaleBy(
	scaleBy: any,
	kind: string,
	maxBonus: number,
	validElement: (any) -> boolean
): (boolean, string?)
	if scaleBy == nil then
		return true, nil
	end
	if not Spec.ScalableKinds[kind] then
		return false, "Scaling is only available on damage, damage over time, healing and shields"
	end
	if type(scaleBy) ~= "table" then
		return false, "Invalid scaling"
	end
	for key in pairs(scaleBy) do
		if key ~= "Source" and key ~= "PerUnit" and key ~= "Max" and key ~= "Element" then
			return false, "Unsupported scaling field"
		end
	end
	local source = Spec.Sources[scaleBy.Source]
	if not source then
		return false, "Unsupported scaling source"
	end
	if not finite(scaleBy.PerUnit) or scaleBy.PerUnit < 0 or scaleBy.PerUnit > maxBonus then
		return false, "Scaling per unit must be between 0 and " .. maxBonus
	end
	if not finite(scaleBy.Max) or scaleBy.Max < 0 or scaleBy.Max > maxBonus then
		return false, "Scaling maximum must be between 0 and " .. maxBonus
	end
	if source.NeedsElement then
		if not validElement(scaleBy.Element) then
			return false, "Mark-stack scaling needs a non-neutral element"
		end
	elseif scaleBy.Element ~= nil then
		return false, "Only mark-stack scaling uses an element"
	end
	return true, nil
end

-- Extra projectiles a charged Projectile fires on release:
-- floor(charge fraction x MaxExtraProjectiles).
function Spec.extraProjectiles(scaling: any, fraction: number): number
	local maximum = type(scaling) == "table" and scaling.MaxExtraProjectiles
	if not finite(maximum) or not finite(fraction) then
		return 0
	end
	return math.max(0, math.floor(math.clamp(fraction, 0, 1) * maximum + 1e-9))
end

-- Yaw offsets (degrees) for `count` extra projectiles, fanned out in pairs
-- like the Spread behavior: +a, -a, +2a, -2a, ... `skipPairs` starts the fan
-- outside a Spread behavior's own side pairs so they never overlap.
function Spec.extraOffsets(count: number, angleDegrees: number, skipPairs: number?): { number }
	local offsets = {}
	for index = 1, count do
		local step = math.ceil(index / 2) + (skipPairs or 0)
		local side = if index % 2 == 1 then 1 else -1
		table.insert(offsets, side * step * angleDegrees)
	end
	return offsets
end

-- maxExtra: the projectile count limit (Limits.MaxSpawnCount); form: the spell's Form.
function Spec.validateChargeScaling(
	scaling: any,
	chargeMode: boolean,
	form: string?,
	maxExtra: number?
): (boolean, string?)
	if scaling == nil then
		return true, nil
	end
	if not chargeMode then
		return false, "Charge scaling needs a Charged or Hold-and-release cast"
	end
	if type(scaling) ~= "table" then
		return false, "Invalid charge scaling"
	end
	for key in pairs(scaling) do
		if key ~= "MinPotency" and key ~= "MaxPotency" and key ~= "MaxExtraProjectiles" then
			return false, "Unsupported charge scaling field"
		end
	end
	for _, key in { "MinPotency", "MaxPotency" } do
		local value = scaling[key]
		if not finite(value) or value < Spec.MinPotency or value > Spec.MaxPotency then
			return false, "Charge potency must be between " .. Spec.MinPotency .. " and " .. Spec.MaxPotency
		end
	end
	if scaling.MinPotency > scaling.MaxPotency then
		return false, "Charge scaling minimum cannot exceed its maximum"
	end
	local extra = scaling.MaxExtraProjectiles
	if extra ~= nil then
		if form ~= "Projectile" then
			return false, "Extra projectiles from charge need a Projectile"
		end
		local limit = maxExtra or 0
		if not finite(extra) or extra % 1 ~= 0 or extra < 0 or extra > limit then
			return false, "Extra projectiles must be a whole number from 0 to " .. limit
		end
	end
	return true, nil
end

return Spec
