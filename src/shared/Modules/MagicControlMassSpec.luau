-- Pure mass gate shared by the server executor and validation tests.
local Spec = {}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Spec.allows(controlledMass, authoredMaximum)
	return finite(controlledMass)
		and controlledMass > 0
		and finite(authoredMaximum)
		and authoredMaximum > 0
		and controlledMass <= authoredMaximum
end

function Spec.adjust(totals, caster, spellId, delta)
	if type(totals) ~= "table" or caster == nil or type(spellId) ~= "string" or not finite(delta) then
		return 0
	end
	local bySpell = totals[caster]
	if not bySpell then
		bySpell = {}
		totals[caster] = bySpell
	end
	local total = math.max(0, (bySpell[spellId] or 0) + delta)
	if total <= 1e-6 then
		bySpell[spellId] = nil
		if next(bySpell) == nil then
			totals[caster] = nil
		end
		return 0
	end
	bySpell[spellId] = total
	return total
end

function Spec.total(totals, caster, spellId)
	local total = totals[caster] and totals[caster][spellId]
	if finite(total) and total > 0 then
		return total
	end
	return 0
end

return Spec
