--!strict
-- Read-only summaries; all calculations come from the existing validator/estimator.
local Summary = {}
local function human(value)
	return tostring(value):gsub("(%l)(%u)", "%1 %2")
end
local function properties(value, depth)
	if type(value) ~= "table" then
		return human(value)
	end
	if depth > 4 then
		return "nested rules"
	end
	local items, keys = {}, {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, key in ipairs(keys) do
		local v = value[key]
		if v ~= nil then
			table.insert(items, human(key) .. ": " .. properties(v, depth + 1))
		end
	end
	return table.concat(items, ", ")
end
local function creatorIssue(reason)
	local issue = tostring(reason)
	local lowered = string.lower(issue)
	if
		string.find(lowered, "principle", 1, true)
		or string.find(lowered, "expression", 1, true)
		or string.find(lowered, "source", 1, true)
	then
		return "One or more selected effects or settings conflict with this combination. Remove or adjust an effect, then review again."
	end
	return issue
end
function Summary.describe(d, schema, spec)
	local ok, reason = spec.validate(d)
	local estimated, cost = pcall(spec.estimate, d)
	if not estimated then
		cost = { ManaDemand = 0, Strain = 0, Complexity = 0 }
	end
	local lines = {
		d.Name .. " · " .. (schema.Forms[d.Form] and schema.Forms[d.Form].Label or d.Form),
		"Element: " .. d.Element,
		"Activation: " .. human(d.Casting.Mode) .. " · cooldown " .. d.Casting.Cooldown .. "s",
		"Preparation: " .. (d.Casting.CastTime or 0) .. "s · recovery " .. (d.Casting.RecoveryTime or 0) .. "s",
		"Aim: "
			.. (schema.TargetingModes[d.Targeting] and schema.TargetingModes[d.Targeting].Label or human(d.Targeting)),
		"Lifetime: "
			.. human(d.Lifetime.Mode)
			.. (d.Lifetime.Duration and (" · " .. d.Lifetime.Duration .. "s") or ""),
		"Targets: "
			.. (d.TargetRules.Relationship or "Any")
			.. " · reach "
			.. d.TargetRules.Range
			.. " studs · maximum "
			.. d.TargetRules.MaxTargets,
	}
	if d.Lifetime.Duration then
		table.insert(lines, "Active for " .. tostring(d.Lifetime.Duration) .. " seconds.")
	end
	if d.TargetRules.RequiresLineOfSight then
		table.insert(lines, "Walls can block targets (line of sight required).")
	end
	if d.TargetRules.RequiresConsent then
		table.insert(lines, "Players must allow consent-gated spells to affect them.")
	end
	if d.TargetRules.IncludeCaster then
		table.insert(lines, "Includes you: damage/control effects may also affect you.")
	end
	local effects = 0
	local events = {}
	for event in pairs(d.Triggers or {}) do
		table.insert(events, event)
	end
	table.sort(events)
	for _, event in ipairs(events) do
		for _, step in ipairs(d.Triggers[event]) do
			for _, payload in ipairs(step.Payloads or {}) do
				effects = effects + 1
				local definition = schema.Payloads[payload.Kind]
				local details = {}
				for _, field in ipairs(definition and definition.Fields or {}) do
					if payload[field.Key] ~= nil then
						table.insert(details, field.Label .. " " .. human(payload[field.Key]))
					end
				end
				table.insert(
					lines,
					(schema.EventLabels[event] or human(event))
						.. ": "
						.. (definition and definition.Label or payload.Kind)
						.. (step.Behavior and (" / " .. human(step.Behavior)) or "")
						.. (#details > 0 and (" — " .. table.concat(details, "; ")) or "")
				)
			end
		end
	end
	if effects == 0 then
		table.insert(lines, "No effects yet. Choose one or more effects to decide what the spell does.")
	end
	table.insert(
		lines,
		string.format(
			"Estimated demand %g mana · strain %g · complexity %g",
			cost.ManaDemand,
			cost.Strain,
			cost.Complexity
		)
	)
	table.insert(
		lines,
		string.format(
			"While active: %g mana/s · %g strain/s",
			cost.ManaUpkeepPerSecond or 0,
			cost.StrainPerSecond or 0
		)
	)
	table.insert(
		lines,
		"More effects, larger areas, more targets and added behaviors can increase estimates. Actual costs and damage also depend on the caster, charge and target defenses."
	)
	for _, pair in ipairs({
		{ "Special costs", d.Cost.SpecialResources },
		{ "Caster requirements", d.LocusRequirements },
		{ "Environment", d.EnvironmentRequirements },
		{ "Cast conditions", d.Conditions },
		{ "End conditions", d.Lifetime.EndWhen },
	}) do
		if type(pair[2]) == "table" and next(pair[2]) then
			table.insert(lines, pair[1] .. ": " .. properties(pair[2], 0))
		end
	end
	if not estimated then
		table.insert(
			lines,
			"Cost estimate unavailable until the invalid settings are corrected; zeros above are not a free cast."
		)
	end
	table.insert(lines, ok and "Ready to save and test." or "Needs attention: " .. creatorIssue(reason))
	return table.concat(lines, "\n"), ok, reason
end
return Summary
