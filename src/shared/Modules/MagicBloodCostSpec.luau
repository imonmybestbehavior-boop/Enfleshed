--!strict
-- Pure rules for blood magic: health as a spell cost.
--
--   Cost.Health = { Mode = "Flat" | "PercentMax", Amount }  a sacrifice on top of mana
--   Cost.HealthForMana = 0..100   percent of the mana price paid in health instead
--   Cost.HealthPerSecond          upkeep for channelled, held and toggled spells
--
-- Paying health is not damage: MagicService sets the caster's health directly
-- and none of the damage hooks run. The floor means blood magic never kills.
local Spec = {}

Spec.Modes = { "Flat", "PercentMax" }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Whether a Cost table uses health at all.
function Spec.uses(cost: any): boolean
	return type(cost) == "table"
		and (
			cost.Health ~= nil
			or (finite(cost.HealthForMana) and cost.HealthForMana > 0)
			or (finite(cost.HealthPerSecond) and cost.HealthPerSecond > 0)
		)
end

-- Splits a full mana price into the mana still paid and the health that
-- replaces the rest (`healthPerMana` HP per mana replaced).
function Spec.split(manaValue: number, share: number?, healthPerMana: number): (number, number)
	local fraction = if finite(share) then math.clamp((share :: number) / 100, 0, 1) else 0
	local mana = math.max(0, math.ceil(manaValue * (1 - fraction) - 1e-9))
	return mana, (manaValue - mana) * healthPerMana
end

-- The sacrifice in HP at `maxHealth`. `percentCap` (PvP) clamps PercentMax.
function Spec.sacrifice(health: any, maxHealth: number, percentCap: number?): number
	if type(health) ~= "table" or not finite(health.Amount) then
		return 0
	end
	if health.Mode == "PercentMax" then
		local percent = health.Amount
		if finite(percentCap) then
			percent = math.min(percent, percentCap :: number)
		end
		return math.max(0, maxHealth * percent / 100)
	end
	return math.max(0, health.Amount)
end

-- Total HP paid at cast: sacrifice plus mana replacement, both scaled by the
-- same charge multiplier as mana (Locus Efficiency does not apply to health).
function Spec.amount(
	cost: any,
	healthFromMana: number?,
	maxHealth: number,
	chargeMultiplier: number?,
	percentCap: number?
): number
	local base = Spec.sacrifice(cost and cost.Health, maxHealth, percentCap)
		+ (if finite(healthFromMana) then healthFromMana :: number else 0)
	return base * (if finite(chargeMultiplier) then chargeMultiplier :: number else 1)
end

-- A payment may not leave the caster below `floor` x max health.
function Spec.canPay(health: number, maxHealth: number, amount: number, floor: number): boolean
	if amount <= 0 then
		return true
	end
	return health - amount >= maxHealth * floor - 1e-9
end

-- Upkeep: the health left after paying `perSecond` for `dt`, or nil when that
-- tick would cross the floor (the spell ends instead and nothing is paid).
function Spec.tick(health: number, maxHealth: number, perSecond: number, dt: number, floor: number): number?
	local due = math.max(0, perSecond * dt)
	if not Spec.canPay(health, maxHealth, due, floor) then
		return nil
	end
	return health - due
end

-- PvP: the HealthPaid scaling bonus is at most `fraction` of the authored amount.
function Spec.capPaidBonus(base: number, scaled: number, fraction: number?): number
	if not finite(fraction) or scaled <= base then
		return scaled
	end
	return math.min(scaled, base + math.abs(base) * (fraction :: number))
end

local function number(value: number): string
	return if value % 1 == 0 then tostring(value) else string.format("%.1f", value)
end

-- One-line cost for editors and the HUD from `Spec.estimate`: "20 mana",
-- "20 mana + 30 HP", "0 mana + 15% HP + 40 HP".
function Spec.costLabel(estimate: any): string
	local parts = { number(estimate.ManaPaid or estimate.ManaDemand or 0) .. " mana" }
	local flat = estimate.HealthFromMana or 0
	local sacrifice = estimate.HealthCost
	if type(sacrifice) == "table" and finite(sacrifice.Amount) then
		if sacrifice.Mode == "PercentMax" then
			table.insert(parts, number(sacrifice.Amount) .. "% HP")
		else
			flat += sacrifice.Amount
		end
	end
	if flat > 0 then
		table.insert(parts, number(flat) .. " HP")
	end
	return table.concat(parts, " + ")
end

-- ScaleBy preset for "x (1 + HP paid / 100)": +1% of `amount` per HP paid,
-- at most +100% (and within the hard scaling limit `maxBonus`).
function Spec.paidScalePreset(amount: number, maxBonus: number): any
	local base = if finite(amount) then math.max(0, amount) else 0
	return {
		Source = "HealthPaid",
		PerUnit = math.min(maxBonus, base / 100),
		Max = math.min(maxBonus, base),
	}
end

-- Validation shared by SpellSpec (`limits` is Configuration.MagicLab).
function Spec.validate(cost: any, limits: any): (boolean, string?)
	local health = cost.Health
	if health ~= nil then
		if type(health) ~= "table" then
			return false, "Invalid health cost"
		end
		for key in pairs(health) do
			if key ~= "Mode" and key ~= "Amount" then
				return false, "Invalid health cost"
			end
		end
		local maximum = if health.Mode == "Flat"
			then limits.MaxFlatHealthCost
			elseif health.Mode == "PercentMax" then limits.MaxPercentHealthCost
			else nil
		if not maximum or not finite(health.Amount) or health.Amount < 1 or health.Amount > maximum then
			return false,
				"Health cost: Flat 1-"
					.. limits.MaxFlatHealthCost
					.. " HP or 1-"
					.. limits.MaxPercentHealthCost
					.. "% of max health"
		end
	end
	local share = cost.HealthForMana
	if share ~= nil and (not finite(share) or share < 0 or share > 100) then
		return false, "Health for mana must be 0-100%"
	end
	local perSecond = cost.HealthPerSecond
	if
		perSecond ~= nil
		and (not finite(perSecond) or perSecond < limits.MinHealthPerSecond or perSecond > limits.MaxHealthPerSecond)
	then
		return false, "Health per second must be " .. limits.MinHealthPerSecond .. "-" .. limits.MaxHealthPerSecond
	end
	return true, nil
end

return Spec
