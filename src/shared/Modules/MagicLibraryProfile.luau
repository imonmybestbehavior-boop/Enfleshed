--!strict
-- Small versioned codec for the development Magic Lab slot library.
local Profile = { Version = 1 }

local function copy(value, clone)
	return clone(value)
end

function Profile.decode(raw, slotCount, slotId, validate, clone, hydrate)
	local definitions = {}
	if raw == nil then
		return definitions, true, nil
	end
	if type(raw) ~= "table" or raw.Version ~= Profile.Version or type(raw.Slots) ~= "table" then
		return definitions, false, "Saved spell library has an unsupported or invalid format"
	end
	for key in pairs(raw) do
		if key ~= "Version" and key ~= "Slots" then
			return definitions, false, "Saved spell library contains unknown data; it was left untouched"
		end
	end
	for key, value in pairs(raw.Slots) do
		local slot = tonumber(key)
		if not slot or slot % 1 ~= 0 or slot < 1 or slot > slotCount or tostring(slot) ~= tostring(key) then
			return definitions, false, "Saved spell library contains an invalid slot; it was left untouched"
		end
		if type(value) ~= "table" then
			return definitions, false, "Saved spell library contains an invalid spell; it was left untouched"
		end
		local definition = copy(value, clone)
		if hydrate then
			definition = hydrate(definition, slot, slotId(slot))
		end
		local ok = validate(definition)
		if not ok then
			return {}, false, "A saved spell no longer passes validation; the profile was left untouched"
		end
		definitions[slot] = definition
	end
	return definitions, true, nil
end

function Profile.encode(definitions, slotCount, slotId, validate, clone, dehydrate)
	local slots = {}
	for slot = 1, slotCount do
		local value = definitions[slot]
		if value ~= nil then
			if type(value) ~= "table" then
				return nil, "Cannot save an invalid spell slot"
			end
			local definition = copy(value, clone)
			if dehydrate then
				definition = dehydrate(definition, slot, slotId(slot))
			end
			local ok = validate(definition)
			if not ok then
				return nil, "Cannot save a spell that no longer passes validation"
			end
			slots[tostring(slot)] = definition
		end
	end
	return { Version = Profile.Version, Slots = slots }, nil
end

return Profile
