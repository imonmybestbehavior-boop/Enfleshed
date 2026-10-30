-- Runs against actual curated SpellSpec records, not a duplicate recipe list.
env.script = {
	Parent = {
		SpellSpec = "spec",
		MagicVisualSpec = "visualSpec",
		Parent = { Configuration = { MagicSchema = "schema" } },
	},
}
env.require = function(value)
	if value == "spec" then
		return spec
	end
	if value == "schema" then
		return schema
	end
	if value == "visualSpec" then
		return visualSpec
	end
	error(value)
end
env.warn = function(message)
	error("Curated recipe was skipped: " .. message)
end
local starters = load("src/shared/Modules/GrimoireStarters.luau")
local visualModules = {}
env.require = function(value)
	return assert(visualModules[value], "Unexpected require " .. tostring(value))
end
env.script = { Parent = {} }
visualModules.curves = load("src/shared/SpellVFXSystem/Visual/VisualCurves.luau")
env.script = { Parent = { VisualCurves = "curves" } }
visualModules.extractor = load("src/shared/SpellVFXSystem/Visual/SpellVisualFeatureExtractor.luau")
visualModules.fingerprint = load("src/shared/SpellVFXSystem/Visual/SpellVisualFingerprint.luau")
env.script = {
	Parent = {
		Parent = { Visual = { SpellVisualFeatureExtractor = "extractor", SpellVisualFingerprint = "fingerprint" } },
	},
}
local analyzer = load("src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau")
local cost = load("src/shared/Modules/MagicLabCost.luau")
local count, elements, forms, definitions = 0, {}, {}, {}
for _, build in ipairs({ starters.buildShowcase, starters.buildShowcaseExpansion, starters.buildFeatureShowcase }) do
	for _, record in ipairs(build()) do
		local d = record.Definition
		assert(not definitions[d.Name], "Duplicate curated spell " .. d.Name)
		definitions[d.Name] = d
		cost.refresh(d, spec.estimate, spec.copy)
		local valid, reason = spec.validate(d)
		assert(valid, d.Name .. ": " .. tostring(reason))
		local before = spec.copy(d)
		local plan = analyzer.resolve(d)
		assert(plan.Element == d.Element and plan.Form == d.Form, d.Name .. " lost its identity")
		assert(plan.Source == "Generated" and plan.Motif and plan.Volume and plan.Layout)
		assert(type(plan.FeatureVector) == "string" and type(plan.Seed) == "number")
		assert(d.Visual.VFXDefinition == before.Visual.VFXDefinition)
		assert(d.Casting.Cooldown == before.Casting.Cooldown)
		count += 1
		elements[plan.Element] = true
		forms[plan.Form] = true
		print(
			"COVERAGE|"
				.. d.Name
				.. "|"
				.. plan.Form
				.. "|"
				.. plan.Element
				.. "|"
				.. plan.Geometry
				.. "|"
				.. plan.Motif
				.. " + "
				.. plan.Volume
				.. "|"
				.. plan.Accents
		)
	end
end
assert(count == 76, "Expected all 76 recipes accepted, got " .. count)
for element in pairs(analyzer.Elements) do
	assert(elements[element], "Missing element " .. element)
end
for form in pairs(analyzer.Forms) do
	assert(forms[form], "Missing form " .. form)
end
-- Regression: keep one-shot waves one-shot and preserve their authored reach.
local waves = {
	["Crosswind Lane"] = { "Instant", 20 },
	["Faultline"] = { "Instant", 20 },
	["Hearthline"] = { "Instant", 13 },
	["Sundering Pulse"] = { "Charged", 9 },
	["Echoing Brand"] = { "Instant", 14 },
	["Seismic Crown"] = { "Charged", 16 },
	["Blue Hour"] = { "Instant", 11 },
}
local growth = load("src/shared/Modules/MagicAreaGrowth.luau")
for name, expected in pairs(waves) do
	local d = assert(definitions[name])
	assert(d.Targeting == "Self" and d.Casting.Mode == expected[1], name)
	assert(d.Wave.Range == expected[2] and growth.scale(d.Wave, 0) == 1, name .. " must cast at full authored range")
	assert(d.Wave.GrowthDuration == nil, name .. " must not imply unsupported gameplay growth")
end
for name, radius in pairs({ ["Static Orchard"] = 8, ["Gravitas Well"] = 9, ["Pollen Veil"] = 7 }) do
	local d = assert(definitions[name])
	assert(d.Geometry == "Sphere" and d.Field.Radius == radius and d.Field.Height == nil, name)
end
for name, expected in pairs({ ["Gale Mantle"] = { 8, 6 }, ["Mirror Step"] = { 5, 2 }, ["Redshift Lunge"] = { 7, 4 } }) do
	local d = assert(definitions[name])
	assert(d.Lifetime.Duration == expected[2], name .. " must retain its lifetime")
	local found = false
	for _, step in ipairs(d.Triggers.OnCast) do
		for _, payload in ipairs(step.Payloads) do
			if payload.Kind == "Enhancement" then
				found = true
				assert(payload.WalkSpeedBonus == expected[1] and payload.Duration == nil, name)
			end
		end
	end
	assert(found, name .. " must retain its movement enhancement")
end
-- Beam charge/release must not create an axial beam around the caster.
local lariat = analyzer.resolve(definitions["Astral Lariat"])
assert(lariat.Layout == "Helix")
assert(analyzer.forPhase(lariat, "Gather", "SpellGatherComposition").Layout == "Comet")
assert(analyzer.forPhase(lariat, "Release", "SpellReleaseComposition").CastingCue)
assert(analyzer.forPhase(lariat, "Sustain", "MagicBeamPath").Layout == "Helix")
assert(lariat.Layout == "Helix", "Phase resolution must not mutate the shared composition")
local wavePlan = analyzer.resolve(definitions["Gale Reversal"])
assert(
	analyzer.forPhase(wavePlan, "Release", "MagicWaveComposition").Layout == "Crest",
	"Wave release must retain its actual geometry"
)
-- A newly authored spell requires data only, including combined behaviors.
local fresh = {
	Form = "Beam",
	Element = "Ice",
	Geometry = "Line",
	Targeting = "AimDirection",
	Projectile = { Behaviors = { { Kind = "Split" }, { Kind = "Chain" } } },
}
local resolved = analyzer.resolve(fresh)
assert(resolved.Layout == "Helix" and resolved.Motif == "Crystal" and resolved.Volume == "Mist")
assert(string.find(resolved.Accents, "Satellites") and string.find(resolved.Accents, "Forks"))
assert(fresh.Visual == nil, "Resolver must not mutate input")
-- Legacy manual choices are retained but no longer override generated appearance.
fresh.Visual = { VFXDefinition = "FireProjectile", Opacity = 0.72, CoreShape = "Wedge" }
resolved = analyzer.resolve(fresh)
assert(resolved.Element == "Ice", "A saved preset must not replace the spell's element")
assert(resolved.Form == "Beam", "Generation must retain gameplay form")
assert(string.find(resolved.Legacy, "VFXDefinition", 1, true) and string.find(resolved.Legacy, "CoreShape", 1, true))
assert(resolved.Seed == analyzer.resolve({
	Form = "Beam",
	Element = "Ice",
	Geometry = "Line",
	Targeting = "AimDirection",
	Projectile = fresh.Projectile,
}).Seed)
fresh.Visual.VFXDefinition = "None"
assert(analyzer.resolve(fresh).Element == "Ice")
-- Allowlisted remote preset playback has no spell element, so the preset supplies it.
assert(analyzer.resolve({ Form = "Projectile", Visual = { VFXDefinition = "FireProjectile" } }).Element == "Fire")
assert(analyzer.resolve({}).Element == "Neutral" and analyzer.resolve({}).Layout == "Comet")
-- Every Element + Form combination is a supported deliberate fallback.
for element in pairs(analyzer.Elements) do
	for form in pairs(analyzer.Forms) do
		local p = analyzer.resolve({ Element = element, Form = form })
		assert(p.Element == element and p.Form == form and p.Motif and p.Volume)
	end
end
print(
	"VFX: all 65 curated spells validate after server cost refresh; 13 recipe regressions, 64 Element/Form combinations and composition tests passed"
)
