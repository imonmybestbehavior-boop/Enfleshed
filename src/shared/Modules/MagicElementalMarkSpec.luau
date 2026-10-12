--!strict

-- Pure helpers for bounded, timed elemental marks stored by the server status service.
local Spec = {}

local function isActive(mark, element, now)
	return mark.Kind == "ElementalMark"
		and mark.Element == element
		and type(mark.Stacks) == "number"
		and mark.Stacks > 0
		and type(mark.Remaining) == "number"
		and mark.Remaining > 0
		and type(mark.ExpiresAt) == "number"
		and mark.ExpiresAt > now
end

function Spec.stackCount(effects, element, now)
	local total = 0
	for _, effect in ipairs(effects) do
		if isActive(effect, element, now) then
			total = total + effect.Stacks
		end
	end
	return total
end

function Spec.apply(effects, candidate, maximumStacks, now, maximumEffects)
	local currentStacks = Spec.stackCount(effects, candidate.Element, now)
	local existing
	for _, effect in ipairs(effects) do
		if
			isActive(effect, candidate.Element, now)
			and effect.Caster == candidate.Caster
			and effect.SpellId == candidate.SpellId
		then
			existing = effect
			break
		end
	end
	if existing then
		existing.Stacks = existing.Stacks + math.min(candidate.Stacks, math.max(0, maximumStacks - currentStacks))
		existing.ExpiresAt = candidate.ExpiresAt
		existing.Remaining = candidate.Remaining
		existing.LastUpdateAt = candidate.LastUpdateAt
		return true
	end
	if currentStacks >= maximumStacks or #effects >= maximumEffects then
		return false
	end
	candidate.Stacks = math.min(candidate.Stacks, maximumStacks - currentStacks)
	table.insert(effects, candidate)
	return true
end

function Spec.encode(effects, now)
	local elements = {}
	for _, effect in ipairs(effects) do
		if isActive(effect, effect.Element, now) then
			elements[string.lower(effect.Element)] = true
		end
	end
	local sorted = {}
	for element in pairs(elements) do
		table.insert(sorted, element)
	end
	table.sort(sorted)
	if #sorted > 0 then
		return "|" .. table.concat(sorted, "|") .. "|"
	end
	return "||"
end

function Spec.hasEncoded(encoded, element)
	if type(encoded) ~= "string" or type(element) ~= "string" then
		return false
	end
	return string.find(encoded, "|" .. string.lower(element) .. "|", 1, true) ~= nil
end

function Spec.consume(effects, element, amount, now)
	local matching = {}
	for index, effect in ipairs(effects) do
		if isActive(effect, element, now) then
			table.insert(matching, { Index = index, Effect = effect })
		end
	end
	table.sort(matching, function(a, b)
		if a.Effect.ExpiresAt == b.Effect.ExpiresAt then
			return a.Index > b.Index
		end
		return a.Effect.ExpiresAt < b.Effect.ExpiresAt
	end)
	local remaining = amount
	for _, entry in ipairs(matching) do
		if remaining <= 0 then
			break
		end
		local take = math.min(entry.Effect.Stacks, remaining)
		entry.Effect.Stacks = entry.Effect.Stacks - take
		remaining = remaining - take
	end
	for index = #effects, 1, -1 do
		local effect = effects[index]
		if effect.Kind == "ElementalMark" and (effect.Stacks or 0) <= 0 then
			table.remove(effects, index)
		end
	end
	return amount - remaining
end

return Spec
