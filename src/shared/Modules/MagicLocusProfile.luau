-- Versioned persistent runtime values for the canonical Locus profile.
local Profile = { Version = 2 }
local SpecialResources = require(script.Parent.MagicSpecialResourceSpec)

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Profile.decode(raw, fallbackMana, capacity, maxStrain, specialDefinitions)
	local fallback = {
		Mana = fallbackMana,
		Strain = 0,
		SpecialResources = SpecialResources.defaults(specialDefinitions or {}),
	}
	if raw == nil then
		return fallback, true, nil
	end
	if type(raw) ~= "table" or (raw.Version ~= 1 and raw.Version ~= Profile.Version) then
		return fallback, false, "Locus profile has an unsupported or invalid version"
	end
	for key in pairs(raw) do
		if
			key ~= "Version"
			and key ~= "Mana"
			and key ~= "Strain"
			and (raw.Version == 1 or key ~= "SpecialResources")
		then
			return fallback, false, "Locus profile contains unknown data and was left untouched"
		end
	end
	if raw.Version == Profile.Version and type(raw.SpecialResources) ~= "table" then
		return fallback, false, "Locus profile is missing its special resource data and was left untouched"
	end
	if
		not finite(raw.Mana)
		or raw.Mana < 0
		or raw.Mana > capacity
		or not finite(raw.Strain)
		or raw.Strain < 0
		or raw.Strain > maxStrain
	then
		return fallback, false, "Locus profile contains invalid resource values and was left untouched"
	end
	local special
	if raw.Version == 1 then
		special = fallback.SpecialResources
	else
		special = SpecialResources.mergeCurrent(raw.SpecialResources, specialDefinitions or {})
	end
	if raw.Version == Profile.Version and not SpecialResources.validateCurrent(special, specialDefinitions or {}) then
		return fallback, false, "Locus profile contains invalid special resource values and was left untouched"
	end
	if raw.Version == Profile.Version then
		for id in pairs(raw.SpecialResources or {}) do
			if not specialDefinitions or not specialDefinitions[id] then
				return fallback, false, "Locus profile contains an unknown special resource and was left untouched"
			end
		end
	end
	return { Mana = raw.Mana, Strain = raw.Strain, SpecialResources = special }, true, nil
end

function Profile.encode(state, maxStrain, specialDefinitions)
	if
		type(state) ~= "table"
		or not finite(state.Mana)
		or state.Mana < 0
		or state.Mana > state.Capacity
		or not finite(state.Strain)
		or state.Strain < 0
		or state.Strain > maxStrain
		or not SpecialResources.validateCurrent(state.SpecialResources or {}, specialDefinitions or {})
	then
		return nil, "Locus state is outside persistence limits"
	end
	local specialSnapshot = {}
	for key, value in pairs(state.SpecialResources) do
		specialSnapshot[key] = value
	end
	return {
		Version = Profile.Version,
		Mana = state.Mana,
		Strain = state.Strain,
		SpecialResources = specialSnapshot,
	},
		nil
end

return Profile
