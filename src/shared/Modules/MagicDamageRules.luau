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

function Rules.mitigate(amount, resistance, armor)
	local safeAmount = 0
	if type(amount) == "number" and amount == amount then
		safeAmount = math.max(0, amount)
	end
	local safeResistance = 0
	if type(resistance) == "number" and resistance == resistance then
		safeResistance = math.max(0, math.min(1, resistance))
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
		return 0
	end
	return math.max(0, math.min(1, value))
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
		return 0
	end
	return math.max(0, math.min(100, value))
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
		return 0
	end
	return math.max(0, math.min(100, value))
end

function Rules.applyChannel(amount, target, channel, element)
	if channel == "Soul" then
		return Rules.mitigate(amount, Rules.soulResistance(target), Rules.soulArmor(target))
	elseif channel == "Physical" then
		return Rules.mitigate(amount, Rules.physicalResistance(target), Rules.physicalArmor(target))
	end
	return Rules.mitigate(amount, Rules.resistance(target, element), Rules.armor(target))
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
