--!strict
-- Server-validated discovery profile codec and dormant milestone rules.
-- The active unrestricted testbed bypasses these rules through MagicLab config.
local Spec = { Version = 3 }

Spec.PaletteOrder = { "Origin", "Ember", "Tide", "Verdant", "Soulfire", "Rift", "Chronal" }
Spec.Palettes = {
	Origin = {
		Label = "Origin",
		Colors = { Color3.fromRGB(180, 230, 255), Color3.fromRGB(100, 190, 255), Color3.new(1, 1, 1) },
		Requirement = "Available from the beginning",
	},
	Ember = {
		Label = "Ember",
		Colors = { Color3.fromRGB(255, 104, 45), Color3.fromRGB(205, 45, 23), Color3.fromRGB(255, 217, 105) },
		Requirement = "Cast 10 Energy spells",
		Principle = "Energy",
		Count = 10,
	},
	Tide = {
		Label = "Tide",
		Colors = { Color3.fromRGB(61, 183, 207), Color3.fromRGB(48, 103, 180), Color3.fromRGB(178, 239, 237) },
		Requirement = "Cast 10 Matter spells",
		Principle = "Matter",
		Count = 10,
	},
	Verdant = {
		Label = "Verdant",
		Colors = { Color3.fromRGB(119, 194, 105), Color3.fromRGB(49, 119, 75), Color3.fromRGB(218, 225, 129) },
		Requirement = "Cast 10 Body spells",
		Principle = "Body",
		Count = 10,
	},
	Soulfire = {
		Label = "Soulfire",
		Colors = { Color3.fromRGB(219, 114, 244), Color3.fromRGB(120, 70, 193), Color3.fromRGB(255, 190, 228) },
		Requirement = "Cast 10 Soul spells",
		Principle = "Soul",
		Count = 10,
	},
	Rift = {
		Label = "Rift",
		Colors = { Color3.fromRGB(237, 187, 100), Color3.fromRGB(173, 99, 58), Color3.fromRGB(255, 232, 174) },
		Requirement = "Cast 10 Space spells",
		Principle = "Space",
		Count = 10,
	},
	Chronal = {
		Label = "Chronal",
		Colors = { Color3.fromRGB(124, 225, 197), Color3.fromRGB(62, 140, 143), Color3.fromRGB(209, 255, 227) },
		Requirement = "Cast 10 Time spells",
		Principle = "Time",
		Count = 10,
	},
}

Spec.ShapeOrder = { "Sphere", "Block", "Crystal", "Wedge", "Cylinder" }
Spec.Shapes = {
	Sphere = { Requirement = "Available from the beginning" },
	Block = { Requirement = "Cast 3 Constructs", Form = "Construct", Count = 3 },
	Crystal = { Requirement = "Cast 5 Projectile spells", Form = "Projectile", Count = 5 },
	Wedge = { Requirement = "Cast 5 Beam or Wave spells", Forms = { Beam = true, Wave = true }, Count = 5 },
	Cylinder = { Requirement = "Cast 5 Field or Aura spells", Forms = { Field = true, Aura = true }, Count = 5 },
}

local principles = { "Energy", "Matter", "Body", "Soul", "Space", "Time" }
local forms = { "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Manipulation" }
Spec.ExpressionOrder = {
	"Earth",
	"Water",
	"Fire",
	"Lightning",
	"Force",
	"Unawakened",
	"BodyEnhancement",
	"Spirit",
	"SpatialFold",
	"TemporalShift",
}
Spec.Expressions = {
	Earth = { Principle = "Matter", Default = true, Requirement = "Available from the beginning" },
	Water = { Principle = "Matter", After = "Earth", Count = 5, Requirement = "Cast 5 Earth spells" },
	Fire = { Principle = "Energy", Default = true, Requirement = "Available from the beginning" },
	Lightning = { Principle = "Energy", After = "Fire", Count = 5, Requirement = "Cast 5 Fire spells" },
	Force = { Principle = "Energy", After = "Lightning", Count = 5, Requirement = "Cast 5 Lightning spells" },
	Unawakened = { Principle = "Energy", Legacy = true, Requirement = "Retained on existing saved spells" },
	BodyEnhancement = { Principle = "Body", Default = true, Requirement = "Available from the beginning" },
	Spirit = { Principle = "Soul", Default = true, Requirement = "Available from the beginning" },
	SpatialFold = { Principle = "Space", Default = true, Requirement = "Available from the beginning" },
	TemporalShift = { Principle = "Time", Default = true, Requirement = "Available from the beginning" },
}

local function empty()
	local profile = {
		Version = Spec.Version,
		TotalCasts = 0,
		Principles = {},
		Forms = {},
		Expressions = {},
		AwakeningProfileId = "RecruitGeneric",
	}
	for _, value in ipairs(principles) do
		profile.Principles[value] = 0
	end
	for _, value in ipairs(forms) do
		profile.Forms[value] = 0
	end
	for _, value in ipairs(Spec.ExpressionOrder) do
		profile.Expressions[value] = 0
	end
	return profile
end

local function finiteInteger(value)
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 0 and value <= 1000000
end

local function contains(values, value)
	for _, candidate in ipairs(values) do
		if candidate == value then
			return true
		end
	end
	return false
end

function Spec.decode(raw)
	local profile = empty()
	if raw == nil then
		return profile, true
	end
	if
		type(raw) ~= "table"
		or (raw.Version ~= 1 and raw.Version ~= 2 and raw.Version ~= Spec.Version)
		or not finiteInteger(raw.TotalCasts)
	then
		return profile, false, "Discovery profile has an unsupported or invalid format"
	end
	local legacyProfile = raw.Version == 1
	for key in pairs(raw) do
		if
			key ~= "Version"
			and key ~= "TotalCasts"
			and key ~= "Principles"
			and key ~= "Forms"
			and not (raw.Version >= 2 and key == "Expressions")
			and not (raw.Version >= 3 and key == "AwakeningProfileId")
		then
			return profile, false, "Discovery profile contains unknown data"
		end
	end
	local sections = { Principles = principles, Forms = forms }
	if raw.Version >= 2 then
		sections.Expressions = Spec.ExpressionOrder
	end
	for section, allowed in pairs(sections) do
		if type(raw[section]) ~= "table" then
			return profile, false, "Discovery profile is missing a counter section"
		end
		for key, value in pairs(raw[section]) do
			if not contains(allowed, key) or not finiteInteger(value) then
				return profile, false, "Discovery profile contains an invalid counter"
			end
		end
		for _, key in ipairs(allowed) do
			profile[section][key] = raw[section][key] or 0
		end
	end
	profile.TotalCasts = raw.TotalCasts
	if raw.Version >= 3 then
		if
			type(raw.AwakeningProfileId) ~= "string"
			or #raw.AwakeningProfileId < 1
			or #raw.AwakeningProfileId > 48
			or not string.match(raw.AwakeningProfileId, "^[%w_%-]+$")
		then
			return empty(), false, "Discovery profile has an invalid awakening selection"
		end
		profile.AwakeningProfileId = raw.AwakeningProfileId
	end
	if legacyProfile then
		-- V1 tracked only Principles and Forms. Its initial expression was the
		-- principle default, so migrate those known casts without inventing data
		-- for expressions that V1 could not distinguish.
		profile.Expressions.Fire = profile.Principles.Energy
		profile.Expressions.Earth = profile.Principles.Matter
		profile.Expressions.BodyEnhancement = profile.Principles.Body
		profile.Expressions.Spirit = profile.Principles.Soul
		profile.Expressions.SpatialFold = profile.Principles.Space
		profile.Expressions.TemporalShift = profile.Principles.Time
	end
	return profile, true
end

function Spec.recordCast(profile, principle, form, expression)
	local clean, ok = Spec.decode(profile)
	if not ok then
		clean = empty()
	end
	clean.TotalCasts = clean.TotalCasts + 1
	if clean.Principles[principle] ~= nil then
		clean.Principles[principle] = clean.Principles[principle] + 1
	end
	if clean.Forms[form] ~= nil then
		clean.Forms[form] = clean.Forms[form] + 1
	end
	local expressionDefinition = Spec.Expressions[expression]
	if expressionDefinition and expressionDefinition.Principle == principle then
		clean.Expressions[expression] = clean.Expressions[expression] + 1
	end
	return clean
end

function Spec.progress(profile, progressionEnabled)
	local clean, ok = Spec.decode(profile)
	if not ok then
		clean = empty()
	end
	local palettes, shapes, expressions = {}, {}, {}
	for id, definition in pairs(Spec.Palettes) do
		palettes[id] = progressionEnabled == false
			or definition.Principle == nil
			or clean.Principles[definition.Principle] >= definition.Count
	end
	for id, definition in pairs(Spec.Shapes) do
		local count = 0
		if definition.Form then
			count = clean.Forms[definition.Form] or 0
		elseif definition.Forms then
			for form in pairs(definition.Forms) do
				count = count + (clean.Forms[form] or 0)
			end
		end
		shapes[id] = progressionEnabled == false or definition.Count == nil or count >= definition.Count
	end
	for id, definition in pairs(Spec.Expressions) do
		expressions[id] = progressionEnabled == false
			or definition.Default == true
			or (definition.After ~= nil and clean.Expressions[definition.After] >= definition.Count)
	end
	local visibleCasts = clean.TotalCasts
	local visiblePrinciples = clean.Principles
	local visibleForms = clean.Forms
	if progressionEnabled == false then
		local blank = empty()
		visibleCasts, visiblePrinciples, visibleForms = 0, blank.Principles, blank.Forms
	end
	return {
		TotalCasts = visibleCasts,
		Principles = visiblePrinciples,
		Forms = visibleForms,
		Palettes = palettes,
		Shapes = shapes,
		Expressions = expressions,
	}
end

function Spec.encode(profile)
	local clean, ok = Spec.decode(profile)
	if not ok then
		return nil, "Cannot encode invalid discovery progress"
	end
	return clean
end

local function unlockCounter(profile, requirement)
	if type(requirement) ~= "table" or type(requirement.Count) ~= "number" then
		return nil
	end
	local count = requirement.Count
	if count ~= count or count % 1 ~= 0 or count < 1 or count > 1000000 then
		return nil
	end
	if requirement.Counter == "TotalCasts" then
		return profile.TotalCasts
	end
	if type(requirement.Key) ~= "string" then
		return nil
	end
	local section
	if requirement.Counter == "Principle" then
		section = "Principles"
	elseif requirement.Counter == "Form" then
		section = "Forms"
	elseif requirement.Counter == "Expression" then
		section = "Expressions"
	end
	local values = section and profile[section]
	return values and values[requirement.Key] or nil
end

function Spec.awakeningProfileUnlockStatus(profile, profileId, profileDefinitions, progressionEnabled)
	local definition = profileDefinitions[profileId]
	if not definition then
		return false, "Unknown Magic Profile"
	end
	if progressionEnabled == false then
		return true, nil
	end
	local unlock = definition.Unlock
	if unlock == nil then
		return true, nil
	end
	local requirements = unlock.Requirements
	if requirements == nil and type(unlock.Expression) == "string" then
		-- Accept the original single-expression contract for saved/configured profiles.
		requirements = {
			{
				Counter = "Expression",
				Key = unlock.Expression,
				Count = unlock.Count,
				Description = "Cast " .. tostring(unlock.Count) .. " " .. unlock.Expression .. " spells",
			},
		}
	end
	if type(requirements) ~= "table" or #requirements < 1 or #requirements > 8 then
		return false, "Profile unlock requirements are invalid"
	end
	local unmet = {}
	for _, requirement in ipairs(requirements) do
		local count = unlockCounter(profile, requirement)
		if count == nil then
			return false, "Profile unlock requirements are invalid"
		end
		if count < requirement.Count then
			table.insert(
				unmet,
				type(requirement.Description) == "string" and requirement.Description
					or "Cast "
						.. tostring(requirement.Count)
						.. " "
						.. tostring(requirement.Key or "total")
						.. " spells"
			)
		end
	end
	if #unmet == 0 then
		return true, nil
	end
	return false, "Locked · " .. table.concat(unmet, " and ")
end

function Spec.awakeningProfileUnlocked(profile, profileId, profileDefinitions, progressionEnabled)
	local unlocked = Spec.awakeningProfileUnlockStatus(profile, profileId, profileDefinitions, progressionEnabled)
	return unlocked
end

function Spec.selectAwakeningProfile(profile, profileId, profileDefinitions, progressionEnabled)
	local clean, valid = Spec.decode(profile)
	if not valid then
		return nil, false, "Magic discovery is unavailable"
	end
	if type(profileId) ~= "string" then
		return clean, false, "Choose a valid Magic Profile"
	end
	local definition = profileDefinitions[profileId]
	if not definition then
		return clean, false, "Unknown Magic Profile"
	end
	local unlocked, reason = Spec.awakeningProfileUnlockStatus(clean, profileId, profileDefinitions, progressionEnabled)
	if not unlocked then
		return clean, false, reason
	end
	clean.AwakeningProfileId = profileId
	return clean, true, nil
end

return Spec
