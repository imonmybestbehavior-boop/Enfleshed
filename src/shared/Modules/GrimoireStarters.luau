--!strict
-- Curated, generic SpellSpecs. The server validates each one before adding it to a library.
local Schema = require(script.Parent.Parent.Configuration.MagicSchema)
local Spec = require(script.Parent.SpellSpec)
local VisualSpec = require(script.Parent.MagicVisualSpec)
local Starters = {}
Starters.Collection = "Starter templates"
Starters.Tag = "starter-template"

local recipes = {
	{ "Ember Bolt", "A direct fire projectile. Fire is an element; the impact deals damage.", "Projectile", "Energy", "Fire", "OnImpact", { "Damage" } },
	{ "Frost Needle", "A precise cold hit that slows its target.", "Projectile", "Energy", "Ice", "OnImpact", { "Damage", "Slow" } },
	{ "Storm Brand", "Marks a target for a later elemental combination.", "Projectile", "Energy", "Lightning", "OnImpact", { "ElementalMark" } },
	{ "Cinder Brand", "A fire mark setup; the mark itself does not burn.", "Projectile", "Energy", "Fire", "OnImpact", { "ElementalMark" } },
	{ "Ash Burst", "A fire projectile that deals damage in a bounded blast on impact.", "Projectile", "Energy", "Fire", "OnImpact", { "Damage" }, "Explode" },
	{ "Burning Brand", "Applies explicit damage over time on impact.", "Projectile", "Energy", "Fire", "OnImpact", { "DamageOverTime" } },
	{ "Markbreaker", "Consumes a fire mark and deals direct impact damage.", "Projectile", "Energy", "Fire", "OnImpact", { "ConsumeElementalMark", "Damage" } },
	{ "Arc Lance", "A direct beam of energy damage.", "Beam", "Energy", "Lightning", "OnCast", { "Damage" } },
	{ "Mercy Ray", "A beam that restores health on contact.", "Beam", "Body", "Neutral", "OnCast", { "Heal" } },
	{ "Binding Wave", "A short control wave that binds affected targets.", "Wave", "Energy", "Neutral", "OnCast", { "Bind" } },
	{ "Revealing Wave", "A wave that exposes affected targets.", "Wave", "Energy", "Neutral", "OnCast", { "Reveal" } },
	{ "Stillwater Field", "A placed field that slows targets entering it.", "Field", "Energy", "Water", "OnEnter", { "Slow" } },
	{ "Watcher's Field", "A placed field that reveals entrants.", "Field", "Energy", "Neutral", "OnEnter", { "Reveal" } },
	{ "Healing Circle", "A placed field that heals entrants.", "Field", "Body", "Neutral", "OnEnter", { "Heal" } },
	{ "Ward Circle", "A placed field that grants a shield on entry.", "Field", "Energy", "Neutral", "OnEnter", { "Shield" } },
	{ "Mending Aura", "A personal aura that restores allies who enter it.", "Aura", "Body", "Neutral", "OnEnter", { "Restoration" } },
	{ "Iron Ward", "A self spell that grants a shield when cast.", "SelfEnhancement", "Body", "Neutral", "OnCast", { "Shield" } },
	{ "Fleet Step", "A self spell that enhances movement speed.", "SelfEnhancement", "Body", "Neutral", "OnCast", { "Enhancement" } },
	{ "Sky Step", "A self spell that grants aerial movement.", "SelfEnhancement", "Body", "Neutral", "OnCast", { "AerialMovement" } },
	{ "Sentinel Sigil", "A placed construct that binds targets nearby.", "Construct", "Energy", "Neutral", "OnProximity", { "Bind" } },
	{ "Beacon Sigil", "A placed construct that reveals targets nearby.", "Construct", "Energy", "Neutral", "OnProximity", { "Reveal" } },
	{ "Wisp Companion", "Calls a bounded companion beside the caster.", "Projectile", "Soul", "Neutral", "OnCast", { "Summon" } },
	{ "Gravity Nudge", "A safe displacement effect on beam contact.", "Beam", "Space", "Neutral", "OnCast", { "Displacement" } },
	{ "Slow Time", "An aura that changes the rate of affected targets.", "Aura", "Time", "Neutral", "OnEnter", { "TimeDilation" } },
	{ "Earthen Lift", "Raises nearby eligible server-tagged Earth material.", "Manipulation", "Matter", "Earth", "OnCast", { "Manipulation" } },
}

function Starters.build()
	local result = {}
	for _, recipe in ipairs(recipes) do
		local name, description, form, principle, element, event, kinds = table.unpack(recipe)
		local definition = assert(Spec.createDraft(form, principle), "Unsupported starter form: " .. name)
		definition.Name = name
		definition.Element = element
		local paletteName = if principle == "Soul" then "Soulfire"
			elseif principle == "Space" then "Rift"
			elseif principle == "Time" then "Chronal"
			elseif principle == "Body" then "Verdant"
			elseif element == "Fire" then "Ember"
			elseif element == "Water" or element == "Ice" then "Tide"
			elseif element == "Earth" then "Rift"
			else "Origin"
		local colors = VisualSpec.PaletteDefinitions[paletteName].Colors
		definition.Visual.Palette = paletteName
		definition.Visual.Color = colors[1]
		definition.Visual.SecondaryColor = colors[2]
		definition.Visual.AccentColor = colors[3]
		local payloads = {}
		for _, kind in ipairs(kinds) do
			assert(Schema.supportsPayload(kind, form, event, principle), "Unsupported starter effect: " .. name .. " / " .. kind)
			local payload = Spec.copy(Schema.Payloads[kind].Defaults)
			payload.Kind = kind
			table.insert(payloads, payload)
		end
		definition.Triggers[event] = { { Payloads = payloads } }
		if recipe[8] == "Explode" then
			definition.Triggers[event][1].Behavior = "Explode"
			definition.Triggers[event][1].Radius = Schema.Behaviors.Explode.Defaults.Radius
		end
		local valid, reason = Spec.validate(definition)
		assert(valid, "Invalid starter " .. name .. ": " .. tostring(reason))
		table.insert(result, { Definition = definition, Description = description })
	end
	return result
end

return Starters
