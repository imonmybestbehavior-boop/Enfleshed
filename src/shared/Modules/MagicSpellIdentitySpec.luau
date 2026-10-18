-- Shared validation and normalization for editable spell identity: names and tags.
local Spec = { MaxTags = 16, MaxTagLength = 48, MaxNameLength = 32, DefaultName = "Untitled Spell" }

local function clean(value)
	return string.lower(string.gsub(value, "^%s*(.-)%s*$", "%1"))
end

-- Canonical form of a player-typed name: control characters removed, whitespace
-- collapsed and trimmed, cut to MaxNameLength characters (UTF-8 aware).
-- Returns nil when nothing usable remains or the text is not valid UTF-8.
function Spec.normalizeName(value: any, maxLength: number?): string?
	if type(value) ~= "string" or utf8.len(value) == nil then
		return nil
	end
	local name = string.gsub(value, "%c", " ")
	name = string.gsub(name, "%s+", " ")
	name = string.match(name, "^%s*(.-)%s*$") :: string
	local limit = maxLength or Spec.MaxNameLength
	if (utf8.len(name) :: number) > limit then
		name = string.sub(name, 1, (utf8.offset(name, limit + 1) :: number) - 1)
		name = string.gsub(name, " $", "")
	end
	return if name == "" then nil else name
end

-- A stored or submitted name must already be in canonical form.
function Spec.validateName(value: any): (boolean, string?)
	if type(value) ~= "string" then
		return false, "Missing spell identity"
	end
	if Spec.normalizeName(value) ~= value then
		return false, "Use a spell name of 1–" .. Spec.MaxNameLength .. " characters without control characters"
	end
	return true, nil
end

-- Repairs names saved before the length rule existed.
function Spec.repairName(value: any): string
	return Spec.normalizeName(value) or Spec.DefaultName
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
