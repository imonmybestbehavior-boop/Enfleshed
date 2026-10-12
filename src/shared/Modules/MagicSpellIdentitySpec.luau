-- Shared validation and normalization for editable spell identity tags.
local Spec = { MaxTags = 16, MaxTagLength = 48 }

local function clean(value)
	return string.lower(string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

function Spec.validateTags(tags)
	if type(tags) ~= "table" or #tags > Spec.MaxTags then
		return false, "Use at most " .. Spec.MaxTags .. " spell tags"
	end
	local seen = {}
	for _, value in ipairs(tags) do
		if type(value) ~= "string" then
			return false, "Spell tags must be text"
		end
		local tag = clean(value)
		if tag == "" or #tag > Spec.MaxTagLength or string.find(tag, "[^%w_%-]") then
			return false,
				"Each spell tag must use letters, numbers, _ or - (1–" .. Spec.MaxTagLength .. " characters)"
		end
		if seen[tag] then
			return false, "Spell tags must be unique"
		end
		seen[tag] = true
	end
	return true
end

function Spec.parse(text)
	if type(text) ~= "string" then
		return nil, "Spell tags must be text"
	end
	local tags = {}
	local seen = {}
	for token in string.gmatch(text, "[^,;]+") do
		local tag = clean(token)
		if tag ~= "" and not seen[tag] then
			table.insert(tags, tag)
			seen[tag] = true
		end
	end
	local valid, reason = Spec.validateTags(tags)
	if not valid then
		return nil, reason
	end
	return tags
end

function Spec.encode(tags)
	local valid = Spec.validateTags(tags or {})
	if not valid then
		return "||"
	end
	local canonical = {}
	for _, tag in ipairs(tags) do
		table.insert(canonical, clean(tag))
	end
	return "|" .. table.concat(canonical, "|") .. "|"
end

return Spec
