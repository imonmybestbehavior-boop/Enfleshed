-- Whitelisted metadata helpers for author-authored magic environment volumes.
local Spec = {}

Spec.MaxTags = 8
Spec.MaxTagLength = 24

function Spec.encodeTags(value)
	if type(value) ~= "string" then
		return "||"
	end
	local tags = {}
	local seen = {}
	for token in string.gmatch(value, "[^,;|%s]+") do
		local tag = string.lower(token)
		if #tag <= Spec.MaxTagLength and not seen[tag] and not string.find(tag, "[^%w_%-]") then
			seen[tag] = true
			table.insert(tags, tag)
			if #tags >= Spec.MaxTags then
				break
			end
		end
	end
	if #tags == 0 then
		return "||"
	end
	return "|" .. table.concat(tags, "|") .. "|"
end

function Spec.hasTag(encoded, expected)
	if type(encoded) ~= "string" or type(expected) ~= "string" then
		return false
	end
	local tag = string.lower(expected)
	if #tag == 0 or #tag > Spec.MaxTagLength or string.find(tag, "[^%w_%-]") then
		return false
	end
	return string.find(encoded, "|" .. tag .. "|", 1, true) ~= nil
end

return Spec
