-- Shared outgoing strength and incoming Elemental, Physical, and Soul damage
-- math. Combat attributes remain server-owned.
local Rules = {}

Rules.Elements = { "Neutral", "Fire", "Ice", "Lightning", "Earth", "Water", "Wind", "Poison" }
Rules.KnownElements = {}
for _, element in ipairs(Rules.Elements) do
	Rules.KnownElements[element] = true
end
Rules.ExpressionElements = { Fire = "Fire", Earth = "Earth", Water = "Water", Lightning = "Lightning" }

function Rules.defaultElementForExpression(expression)
	return Rules.ExpressionElements[expression] or "Neutral"
end

-- Spell-driven bonuses written by ModifyAttribute (see MagicAttributeSpec, which
-- owns these ranges; kept literal here because that module requires this one).
Rules.ArmorBonusRange = { -100, 100 }
Rules.ResistanceBonusRange = { -1, 1 }
Rules.DamageTakenRange = { -50, 50 }

local function bonus(target, attribute, range)
	if not target then
		return 0
	end
	local value = target:GetAttribute(attribute)
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(range[1], math.min(range[2], value))
end

function Rules.mitigate(amount, resistance, armor)
	local safeAmount = 0
	if type(amount) == "number" and amount == amount then
		safeAmount = math.max(0, amount)
	end
	local safeResistance = 0
	if type(resistance) == "number" and resistance == resistance then
		safeResistance = math.max(-1, math.min(1, resistance))
	end
	local afterResistance = safeAmount * (1 - safeResistance)
	local safeArmor = 0
	if type(armor) == "number" and armor == armor then
		safeArmor = math.max(0, math.min(100, armor))
	end
	return math.max(0, afterResistance - safeArmor)
end

function Rules.resistance(target, element)
	if not target or not Rules.KnownElements[element] or element == "Neutral" then
		return 0
	end
	local value = target:GetAttribute("MagicResistance" .. element)
	if type(value) ~= "number" or value ~= value then
		value = 0
	end
	local base = math.max(0, math.min(1, value))
	local modifier = bonus(target, "MagicResistance" .. element .. "Bonus", Rules.ResistanceBonusRange)
	-- A negative total is a vulnerability: mitigate() turns -0.5 into x1.5 damage.
	return math.max(-1, math.min(1, base + modifier))
end

function Rules.armor(target)
	if not target then
		return 0
	end
	local base = target:GetAttribute("MagicArmor")
	local modifier = target:GetAttribute("MagicArmorBonus")
	if type(base) ~= "number" or base ~= base then
		base = 0
	end
	if type(modifier) ~= "number" or modifier ~= modifier then
		modifier = 0
	end
	return math.max(0, math.min(100, base + modifier))
end

function Rules.soulResistance(target)
	if not target then
		return 0
	end
	local value = target:GetAttribute("SoulResistance")
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.min(1, value))
end

function Rules.soulArmor(target)
	if not target then
		return 0
	end
	local value = target:GetAttribute("SoulArmor")
	if type(value) ~= "number" or value ~= value then
		value = 0
	end
	return math.max(0, math.min(100, value + bonus(target, "SoulArmorBonus", Rules.ArmorBonusRange)))
end

function Rules.physicalResistance(target)
	if not target then
		return 0
	end
	local value = target:GetAttribute("PhysicalResistance")
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.max(0, math.min(1, value))
end

function Rules.physicalArmor(target)
	if not target then
		return 0
	end
	local value = target:GetAttribute("PhysicalArmor")
	if type(value) ~= "number" or value ~= value then
		value = 0
	end
	return math.max(0, math.min(100, value + bonus(target, "PhysicalArmorBonus", Rules.ArmorBonusRange)))
end

-- DamageTakenBonus scales damage after mitigation: +20 means x1.2.
function Rules.applyDamageTaken(amount, target)
	local safeAmount = 0
	if type(amount) == "number" and amount == amount then
		safeAmount = math.max(0, amount)
	end
	return safeAmount * (1 + bonus(target, "DamageTakenBonus", Rules.DamageTakenRange) / 100)
end

function Rules.applyChannel(amount, target, channel, element)
	local mitigated
	if channel == "Soul" then
		mitigated = Rules.mitigate(amount, Rules.soulResistance(target), Rules.soulArmor(target))
	elseif channel == "Physical" then
		mitigated = Rules.mitigate(amount, Rules.physicalResistance(target), Rules.physicalArmor(target))
	else
		mitigated = Rules.mitigate(amount, Rules.resistance(target, element), Rules.armor(target))
	end
	return Rules.applyDamageTaken(mitigated, target)
end

function Rules.applyOutgoingStrength(amount, strengthBonus)
	local safeAmount = 0
	if type(amount) == "number" and amount == amount then
		safeAmount = math.max(0, amount)
	end
	local safeBonus = 0
	if type(strengthBonus) == "number" and strengthBonus == strengthBonus then
		safeBonus = math.max(-75, math.min(100, strengthBonus))
	end
	local multiplier = 1 + safeBonus / 100
	return safeAmount * math.max(0.25, math.min(2, multiplier))
end

return Rules
