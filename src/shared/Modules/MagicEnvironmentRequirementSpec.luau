-- Optional cast-time requirements based on server-resolved environment state.
local ZoneSpec = require(script.Parent.MagicEnvironmentZoneSpec)

local Spec = {}
local MAX_TAGS = ZoneSpec.MaxTags
Spec.MaxTags = MAX_TAGS
Spec.MaxTagLength = ZoneSpec.MaxTagLength

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validTagList(tags)
	if tags == nil then
		return true
	end
	if type(tags) ~= "table" then
		return false
	end
	local count = 0
	local seen = {}
	for key, tag in pairs(tags) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or type(tag) ~= "string" then
			return false
		end
		local canonical = string.lower(tag)
		if
			#canonical == 0
			or #canonical > ZoneSpec.MaxTagLength
			or string.find(canonical, "[^%w_%-]")
			or seen[canonical]
		then
			return false
		end
		seen[canonical] = true
		count = count + 1
		if count > MAX_TAGS then
			return false
		end
	end
	return count == #tags
end

function Spec.validate(requirements)
	if requirements == nil then
		return true
	end
	if type(requirements) ~= "table" then
		return false, "Environment requirements must be a table"
	end
	for key in pairs(requirements) do
		if key ~= "RequireGrounded" and key ~= "ClockTime" and key ~= "ZoneTags" then
			return false, "Unsupported environment requirement: " .. tostring(key)
		end
	end
	if requirements.RequireGrounded ~= nil and type(requirements.RequireGrounded) ~= "boolean" then
		return false, "Grounded requirement must be a boolean"
	end
	if requirements.ClockTime ~= nil then
		local window = requirements.ClockTime
		if type(window) ~= "table" then
			return false, "Clock-time requirement must be a window"
		end
		for key in pairs(window) do
			if key ~= "Start" and key ~= "End" then
				return false, "Unsupported clock-time window field"
			end
		end
		if
			not finite(window.Start)
			or not finite(window.End)
			or window.Start < 0
			or window.Start > 24
			or window.End < 0
			or window.End > 24
		then
			return false, "Clock-time window must be between 0 and 24"
		end
	end
	if requirements.ZoneTags ~= nil then
		local zoneTags = requirements.ZoneTags
		if type(zoneTags) ~= "table" then
			return false, "Zone-tag requirement must be a table"
		end
		for key in pairs(zoneTags) do
			if key ~= "Required" and key ~= "Forbidden" then
				return false, "Unsupported zone-tag requirement field"
			end
		end
		if not validTagList(zoneTags.Required) or not validTagList(zoneTags.Forbidden) then
			return false, "Zone tags must be unique canonical tags"
		end
		local required = {}
		for _, tag in ipairs(zoneTags.Required or {}) do
			required[string.lower(tag)] = true
		end
		for _, tag in ipairs(zoneTags.Forbidden or {}) do
			if required[string.lower(tag)] then
				return false, "A zone tag cannot be both required and forbidden"
			end
		end
	end
	return true
end

local function inWindow(time, window)
	local startTime = window.Start
	local endTime = window.End
	if startTime == endTime then
		return time == startTime
	elseif startTime < endTime then
		return time >= startTime and time <= endTime
	end
	return time >= startTime or time <= endTime
end

function Spec.check(requirements, environment)
	local valid, reason = Spec.validate(requirements)
	if not valid then
		return false, reason
	end
	if not requirements then
		return true
	end
	if type(environment) ~= "table" then
		return false, "Environment state unavailable"
	end
	if requirements.RequireGrounded and environment.OnGround ~= true then
		return false, "This spell requires solid ground beneath the caster"
	end
	if requirements.ClockTime then
		if not finite(environment.ClockTime) or not inWindow(environment.ClockTime, requirements.ClockTime) then
			return false,
				string.format(
					"This spell can only be cast between %g:00 and %g:00",
					requirements.ClockTime.Start,
					requirements.ClockTime.End
				)
		end
	end
	local zoneTags = requirements.ZoneTags
	if zoneTags then
		local encoded = environment.ZoneTags or "||"
		for _, tag in ipairs(zoneTags.Required or {}) do
			if not ZoneSpec.hasTag(encoded, tag) then
				return false, "This spell requires the " .. tag .. " environment"
			end
		end
		for _, tag in ipairs(zoneTags.Forbidden or {}) do
			if ZoneSpec.hasTag(encoded, tag) then
				return false, "This spell cannot be cast in the " .. tag .. " environment"
			end
		end
	end
	return true
end

return Spec
