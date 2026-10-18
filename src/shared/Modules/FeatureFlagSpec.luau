--!strict
-- Pure rules for feature flags and spell kill switches; shared by server and client.
local Spec = {}

Spec.EarlyAccessAttribute = "EarlyAccess" -- server-owned Player attribute (granted by purchases later)

export type Feature = { Enabled: boolean, PublicReleaseAt: number? }
export type Flags = {
	RefreshSeconds: number,
	Features: { [string]: Feature },
	DisabledForms: { string },
	DisabledPayloads: { string },
	DisabledBehaviors: { string },
}

local LIST_KEYS = { "DisabledForms", "DisabledPayloads", "DisabledBehaviors" }
local MAX_FEATURES, MAX_LIST, MAX_NAME = 128, 64, 48

local function name(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_NAME and not value:find("[^%w_]")
end

-- Merges a stored override document over defaults. Invalid entries are ignored
-- (never trusted), so a bad override can only fail closed to the defaults.
function Spec.merge(defaults: Flags, override: any): Flags
	local result: Flags = {
		RefreshSeconds = defaults.RefreshSeconds,
		Features = {},
		DisabledForms = table.clone(defaults.DisabledForms),
		DisabledPayloads = table.clone(defaults.DisabledPayloads),
		DisabledBehaviors = table.clone(defaults.DisabledBehaviors),
	}
	for key, feature in defaults.Features do
		result.Features[key] = table.clone(feature)
	end
	if type(override) ~= "table" then
		return result
	end
	if type(override.Features) == "table" then
		local count = 0
		for key, feature in override.Features do
			count += 1
			if count > MAX_FEATURES then
				break
			end
			if name(key) and type(feature) == "table" and type(feature.Enabled) == "boolean" then
				local release = feature.PublicReleaseAt
				result.Features[key] = {
					Enabled = feature.Enabled,
					PublicReleaseAt = if type(release) == "number"
							and release == release
							and release > 0
						then release
						else nil,
				}
			end
		end
	end
	for _, listKey in LIST_KEYS do
		local list = override[listKey]
		if type(list) == "table" then
			local clean = {}
			for _, entry in list do
				if name(entry) and #clean < MAX_LIST and not table.find(clean, entry) then
					table.insert(clean, entry)
				end
			end
			(result :: any)[listKey] = clean
		end
	end
	return result
end

-- Unknown features are off: a typo can never enable something.
function Spec.enabled(flags: Flags, feature: string, now: number, earlyAccess: boolean?): boolean
	local entry = flags.Features[feature]
	if not entry or entry.Enabled ~= true then
		return false
	end
	if entry.PublicReleaseAt and now < entry.PublicReleaseAt then
		return earlyAccess == true
	end
	return true
end

-- Returns (allowed, reason). Walks Form, trigger payloads/behaviors and projectile behaviors.
function Spec.spellAllowed(flags: Flags, definition: any): (boolean, string?)
	if type(definition) ~= "table" then
		return false, "Invalid spell"
	end
	if table.find(flags.DisabledForms, definition.Form) then
		return false, tostring(definition.Form) .. " spells are temporarily disabled"
	end
	local function behavior(kind: any): (boolean, string?)
		if kind ~= nil and table.find(flags.DisabledBehaviors, kind) then
			return false, tostring(kind) .. " is temporarily disabled"
		end
		return true, nil
	end
	local projectile = definition.Projectile
	if type(projectile) == "table" and type(projectile.Behaviors) == "table" then
		for _, entry in projectile.Behaviors do
			local ok, reason = behavior(type(entry) == "table" and entry.Kind or nil)
			if not ok then
				return false, reason
			end
		end
	end
	if type(definition.Triggers) == "table" then
		for _, steps in definition.Triggers do
			for _, step in (if type(steps) == "table" then steps else {}) do
				if type(step) == "table" then
					local kind = if type(step.Behavior) == "table" then step.Behavior.Kind else step.Behavior
					local ok, reason = behavior(kind)
					if not ok then
						return false, reason
					end
					for _, payload in (if type(step.Payloads) == "table" then step.Payloads else {}) do
						if type(payload) == "table" and table.find(flags.DisabledPayloads, payload.Kind) then
							return false, tostring(payload.Kind) .. " effects are temporarily disabled"
						end
					end
				end
			end
		end
	end
	return true, nil
end

return Spec
