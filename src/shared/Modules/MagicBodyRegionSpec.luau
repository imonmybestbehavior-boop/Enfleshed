-- Classifies Roblox character body-part names for optional payload damage scaling.
-- Unknown/custom rig parts deliberately fall back to Other.
local Spec = {}

local function normalized(name)
	local result = string.lower(name):gsub("[^%a]", "")
	return result
end

function Spec.classify(partName)
	if type(partName) ~= "string" then
		return "Other"
	end

	local name = normalized(partName)
	if name == "head" then
		return "Head"
	elseif name == "torso" or name == "uppertorso" or name == "lowertorso" or name == "humanoidrootpart" then
		return "Torso"
	elseif string.find(name, "arm", 1, true) or string.find(name, "hand", 1, true) then
		return "Arm"
	elseif string.find(name, "leg", 1, true) or string.find(name, "foot", 1, true) then
		return "Leg"
	end
	return "Other"
end

function Spec.multiplier(payload, partName)
	local region = Spec.classify(partName)
	local value = payload[region .. "Multiplier"]
	if type(value) ~= "number" or value ~= value or value < 0 or value > 4 then
		value = 1
	end
	return region, value
end

return Spec
