--!strict
-- Intent hints use existing Form/effect capabilities. Required runtime defaults stay internal.
local Guide = {}

Guide.Intents = {
	{
		Id = "Attack",
		Label = "Attack",
		Description = "Hurt a target or pressure an area with damaging effects.",
		Payloads = { "Damage", "DamageOverTime", "Force", "DrainResource" },
		RecommendedForms = { "Projectile", "Beam", "Wave", "Field" },
	},
	{
		Id = "Defense",
		Label = "Defense",
		Description = "Protect yourself or an ally with shields or defensive enhancements.",
		Payloads = { "Shield", "ModifyAttribute", "Enhancement" },
		RecommendedForms = { "Aura", "Field", "SelfEnhancement", "Construct" },
	},
	{
		Id = "Healing",
		Label = "Healing & support",
		Description = "Restore health or help an ally survive and recover.",
		Payloads = { "Heal", "Restoration", "Shield", "ModifyAttribute", "Cleanse", "Stealth", "RestoreResource" },
		RecommendedForms = { "Aura", "Field", "Beam", "Projectile" },
	},
	{
		Id = "Movement",
		Label = "Movement",
		Description = "Dash or blink yourself, fly, improve movement, or move a target through space.",
		Payloads = { "Enhancement", "AerialMovement", "Displacement", "Control" },
		RecommendedForms = { "Rush", "SelfEnhancement", "Wave", "Aura", "Projectile" },
	},
	{
		Id = "Control",
		Label = "Control",
		Description = "Slow, bind, pull, push, or otherwise limit a target.",
		Payloads = { "Slow", "Bind", "Stun", "Silence", "Taunt", "Fear", "Control", "TimeDilation", "Displacement" },
		RecommendedForms = { "Field", "Wave", "Projectile", "Beam", "Aura" },
	},
	{
		Id = "Summoning",
		Label = "Summoning",
		Description = "Create a companion that can follow, protect, or use an assigned spell.",
		Payloads = { "Summon" },
		RecommendedForms = { "Aura", "Field", "Projectile", "Beam" },
	},
	{
		Id = "Utility",
		Label = "Utility",
		Description = "Reveal, alter, or interact with a target or the surrounding world.",
		Payloads = { "Reveal", "Manipulation", "Transformation" },
		RecommendedForms = { "Manipulation", "Construct", "Field", "Projectile" },
	},
	{
		Id = "Area",
		Label = "Area effects",
		Description = "Affect a zone, pulse, or nearby group instead of one direct target.",
		Payloads = {
			"Damage",
			"DamageOverTime",
			"Heal",
			"Restoration",
			"Shield",
			"Slow",
			"Bind",
			"Control",
			"Reveal",
			"Summon",
		},
		RecommendedForms = { "Field", "Aura", "Wave" },
	},
}

local function included(values, value)
	return table.find(values, value) ~= nil
end

local function intentDefinition(intentId)
	for _, intent in ipairs(Guide.Intents) do
		if intent.Id == intentId then
			return intent
		end
	end
	return nil
end

local function internalDefault(kind, formName, schema)
	local definition = schema.Payloads[kind]
	if definition and definition.Principle then
		return definition.Principle
	end
	-- Matches the Lab's creation step (MagicLabController): material
	-- Manipulation always uses the Matter Principle.
	if kind == "Manipulation" then
		return "Matter"
	end
	-- The runtime still requires a valid Source contract. Pick its default privately;
	-- this value never becomes a creation choice or a description of the spell.
	if schema.supportsPrincipleForm("Energy", formName) then
		return "Energy"
	end
	for _, principle in ipairs(schema.Principles) do
		if schema.supportsPrincipleForm(principle, formName) then
			return principle
		end
	end
	return nil
end

local function candidate(intent, formName, kind, event, schema, spec)
	local definition = schema.Payloads[kind]
	local principle = internalDefault(kind, formName, schema)
	if not definition or not principle or not schema.supportsPrincipleForm(principle, formName) then
		return nil
	end
	if not schema.supportsPayloadCapability(kind, formName, event) then
		return nil
	end
	local draft = spec.createDraft(formName, principle)
	if not draft then
		return nil
	end
	local payload = spec.copy(definition.Defaults or {})
	payload.Kind = kind
	draft.Triggers[event] = { { Payloads = { payload } } }
	-- Only offer starters the server will accept as created (for example,
	-- Manipulation on a Beam needs ObjectTarget and a material the guided
	-- path does not configure).
	if not spec.validate(draft) then
		return nil
	end
	return {
		Form = formName,
		-- Internal compatibility default required by the current spell contract.
		Payload = kind,
		Event = event,
		PayloadLabel = definition.Label or kind,
		Description = definition.Description or "",
		Category = definition.Category or "Utility",
		Intent = intent.Id,
	}
end

function Guide.forShape(intentId, formName, schema, spec)
	local intent = intentDefinition(intentId)
	local form = schema.Forms[formName]
	if not intent or not form then
		return {}
	end
	local results = {}
	for _, kind in ipairs(intent.Payloads) do
		local definition = schema.Payloads[kind]
		if definition then
			for _, event in ipairs(schema.eventsForEffects(formName, "Instant", form.Draft.Targeting)) do
				local result = candidate(intent, formName, kind, event, schema, spec)
				if result then
					table.insert(results, result)
					break
				end
			end
		end
	end
	return results
end

function Guide.shapes(intentId, schema, spec)
	local intent = intentDefinition(intentId)
	if not intent then
		return {}
	end
	local results = {}
	for _, formName in ipairs(schema.FormOrder) do
		if #Guide.forShape(intentId, formName, schema, spec) > 0 then
			table.insert(results, formName)
		end
	end
	local order = {}
	for index, formName in ipairs(intent.RecommendedForms or {}) do
		order[formName] = index
	end
	table.sort(results, function(left, right)
		local leftRank, rightRank = order[left], order[right]
		if leftRank and rightRank then
			return leftRank < rightRank
		elseif leftRank then
			return true
		elseif rightRank then
			return false
		end
		return table.find(schema.FormOrder, left) < table.find(schema.FormOrder, right)
	end)
	return results
end

function Guide.isRecommended(intentId, formName)
	local intent = intentDefinition(intentId)
	return intent ~= nil and included(intent.RecommendedForms or {}, formName)
end

function Guide.intents()
	return Guide.Intents
end

function Guide.definition(intentId)
	return intentDefinition(intentId)
end

return Guide
