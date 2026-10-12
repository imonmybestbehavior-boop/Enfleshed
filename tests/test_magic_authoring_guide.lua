local originalFind = table.find
table.find = table.find
	or function(values, value)
		for index, candidate in ipairs(values) do
			if candidate == value then
				return index
			end
		end
		return nil
	end

local Guide = dofile("src/shared/Modules/MagicAuthoringGuide.luau")
local formOrder = { "Projectile", "Beam", "Wave", "Field", "Aura", "SelfEnhancement", "Construct", "Manipulation" }
local forms, payloads = {}, {}
for _, intent in ipairs(Guide.intents()) do
	for _, kind in ipairs(intent.Payloads) do
		payloads[kind] = { Label = kind, Description = "test payload", Defaults = {} }
	end
end
payloads.Displacement.Principle = "Space"
payloads.TimeDilation.Principle = "Time"
for _, form in ipairs(formOrder) do
	forms[form] = { Draft = { Targeting = "AimDirection" } }
end

local schema = {
	Forms = forms,
	FormOrder = formOrder,
	Principles = { "Energy", "Matter", "Body", "Space", "Time" },
	Payloads = payloads,
	supportsPrincipleForm = function(principle, form)
		return form ~= "Manipulation" or principle == "Matter"
	end,
	supportsPayload = function()
		error("authoring choices must not be filtered by the hidden source default")
	end,
	supportsPayloadCapability = function(kind, form)
		return kind == "Manipulation" and form == "Manipulation" or kind ~= "Manipulation"
	end,
	eventsForEffects = function()
		return { "OnCast" }
	end,
}
local spec = {
	createDraft = function(form, principle)
		return { Form = form, Principle = principle, Triggers = {} }
	end,
	copy = function(value)
		local copy = {}
		for key, child in pairs(value) do
			copy[key] = child
		end
		return copy
	end,
	validate = function()
		error("authoring choices must not be filtered by hidden runtime validation")
	end,
}

local areaForms = Guide.shapes("Area", schema, spec)
assert(areaForms[1] == "Field" and areaForms[2] == "Aura" and areaForms[3] == "Wave")
assert(Guide.isRecommended("Area", "Aura"))
assert(not Guide.isRecommended("Area", "Projectile"))
assert(table.find(areaForms, "Projectile"), "A compatible alternative remains selectable")

local healingForms = Guide.shapes("Healing", schema, spec)
assert(healingForms[1] == "Aura", "Healing's suggested delivery should appear first")
assert(table.find(healingForms, "Projectile"), "Healing does not inherit a fixed Form")

local utilityForms = Guide.shapes("Utility", schema, spec)
assert(table.find(utilityForms, "Manipulation"), "The compatible Manipulation Form remains selectable")
assert(not table.find(Guide.shapes("Area", schema, spec), "UnknownForm"))
local movementChoices = Guide.forShape("Movement", "Wave", schema, spec)
local hasDisplacement = false
for _, choice in ipairs(movementChoices) do
	if choice.Payload == "Displacement" then
		hasDisplacement = true
	end
end
assert(hasDisplacement, "Hidden source requirements must not filter capability-compatible choices")

table.find = originalFind
print("Magic authoring guide Form recommendations passed")
