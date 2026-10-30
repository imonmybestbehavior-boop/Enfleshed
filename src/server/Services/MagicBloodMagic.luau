--!strict

-- Blood magic at runtime, kept free of Roblox services so the audit harness
-- can drive it with doubles. Rules live in MagicBloodCostSpec.
--
-- Paying health is not damage: `setHealth` writes the caster's health
-- directly, so OnDamageTaken, OnBeforeDamageTaken / Interception, soul links,
-- Shields, the DamageTaken stat, mitigation and damage-based breaks never see
-- it, and it is not healing or lifesteal either.
local Shared = game:GetService("ReplicatedStorage").Shared
local BloodSpec = require(Shared.Modules.MagicBloodCostSpec)
local Limits = require(Shared.Configuration.MagicLab)

local Blood = {}

Blood.FloorReason = "Not enough health · blood magic stops at "
	.. math.floor(Limits.BloodHealthFloor * 100 + 0.5)
	.. "%"
Blood.PlayersOnlyReason = "Blood magic is for players only"
Blood.UpkeepReason = "Blood upkeep ended · health floor reached"

-- HP this cast costs: sacrifice plus mana replacement, x the charge multiplier.
-- `percentCap` is the caster's PvP MaxHealthCostPercent (nil outside PvP).
function Blood.quote(cost: any, maxHealth: number, chargeMultiplier: number, percentCap: number?): number
	if not BloodSpec.uses(cost) then
		return 0
	end
	local _, fromMana = BloodSpec.split(cost.ManaDemand or 0, cost.HealthForMana, Limits.HealthPerMana)
	return BloodSpec.amount(cost, fromMana, maxHealth, chargeMultiplier, percentCap)
end

function Blood.canPay(humanoid: any, amount: number): boolean
	return BloodSpec.canPay(humanoid.Health, humanoid.MaxHealth, amount, Limits.BloodHealthFloor)
end

-- Pays `amount` HP. Returns what was paid, or nil (and pays nothing) when it
-- would cross the floor.
function Blood.pay(humanoid: any, amount: number, setHealth: (any, number) -> ()): number?
	if amount <= 0 then
		return 0
	end
	if not Blood.canPay(humanoid, amount) then
		return nil
	end
	setHealth(humanoid, humanoid.Health - amount)
	return amount
end

-- Health upkeep for `dt` seconds. False when the tick would cross the floor:
-- nothing is paid and the spell should end.
function Blood.upkeep(humanoid: any, perSecond: number, dt: number, setHealth: (any, number) -> ()): boolean
	if perSecond <= 0 or dt <= 0 then
		return true
	end
	local remaining = BloodSpec.tick(humanoid.Health, humanoid.MaxHealth, perSecond, dt, Limits.BloodHealthFloor)
	if not remaining then
		return false
	end
	setHealth(humanoid, remaining)
	return true
end

return Blood
