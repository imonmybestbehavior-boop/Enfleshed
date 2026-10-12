--!strict

-- Pure resource math shared by the server runtime and validation tests.
local Model = {}

local function clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

function Model.newState(profile, startingMana)
	return {
		Capacity = profile.Capacity,
		Efficiency = profile.Efficiency,
		Potency = profile.Potency,
		StrainTolerance = profile.StrainTolerance,
		ComplexityCapacity = profile.ComplexityCapacity,
		Mana = clamp(startingMana, 0, profile.Capacity),
		Strain = 0,
	}
end

function Model.cost(authored, charge, chargeScale, state)
	local chargeMultiplier = 1 + charge * chargeScale
	return authored.ManaDemand * chargeMultiplier / state.Efficiency,
		authored.Strain * chargeMultiplier * 30 / state.StrainTolerance,
		authored.Complexity
end

function Model.evaluate(state, manaDemand, strain, complexity, safety)
	if manaDemand > state.Mana then
		return "IMPOSSIBLE", "Insufficient mana", false
	end
	if complexity > state.ComplexityCapacity then
		return "IMPOSSIBLE", "Complexity exceeds capacity", false
	end
	local projectedStrain = state.Strain + strain
	local overextended = projectedStrain > state.StrainTolerance
	if manaDemand > safety.SafeManaDemand or strain > safety.SafeStrain or overextended then
		local reason = "Above safe Locus threshold"
		if overextended then
			reason = "Strain exceeds Locus tolerance; overextension risk"
		end
		return "UNSAFE", reason, overextended
	end
	return "VALID", nil, false
end

function Model.advance(state, delta, manaRecovery, strainRecovery)
	if delta <= 0 then
		return
	end
	state.Mana = math.min(state.Capacity, state.Mana + manaRecovery * delta)
	state.Strain = math.max(0, state.Strain - strainRecovery * delta)
end

function Model.spend(state, manaDemand, strain)
	state.Mana = math.max(0, state.Mana - manaDemand)
	state.Strain = state.Strain + strain
end

function Model.upkeep(state, manaPerSecond, strainPerSecond, delta)
	if delta <= 0 then
		return true
	end
	local manaDemand = manaPerSecond * delta / state.Efficiency
	local strain = strainPerSecond * delta * 30 / state.StrainTolerance
	if manaDemand > state.Mana then
		local fraction = 1
		if manaDemand > 0 then
			fraction = state.Mana / manaDemand
		end
		state.Mana = 0
		state.Strain = state.Strain + strain * fraction
		return false
	end
	Model.spend(state, manaDemand, strain)
	return true
end

return Model
