-- Stat-driven spell appearance: pure feature extraction, fingerprinting and plan building.
-- Runs against real curated SpellSpec records and the real schema validator.
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
	elseif value == "schema" then
		return schema
	elseif value == "visualSpec" then
		return visualSpec
	end
	error(value)
end
env.warn = function(message)
	error("Curated recipe was skipped: " .. message)
end
local starters = load("src/shared/Modules/GrimoireStarters.luau")
local cost = load("src/shared/Modules/MagicLabCost.luau")
local modules = {}
env.require = function(value)
	return assert(modules[value], "Unexpected require " .. tostring(value))
end
env.script = { Parent = {} }
modules.curves = load("src/shared/SpellVFXSystem/Visual/VisualCurves.luau")
env.script = { Parent = { VisualCurves = "curves" } }
modules.extractor = load("src/shared/SpellVFXSystem/Visual/SpellVisualFeatureExtractor.luau")
modules.fingerprint = load("src/shared/SpellVFXSystem/Visual/SpellVisualFingerprint.luau")
modules.library = load("src/shared/SpellVFXSystem/Visual/SpellVisualAssetLibrary.luau")
env.script = {
	Parent = {
		VisualCurves = "curves",
		SpellVisualAssetLibrary = "library",
		SpellVisualFingerprint = "fingerprint",
		SpellVisualFeatureExtractor = "extractor",
	},
}
modules.builder = load("src/shared/SpellVFXSystem/Visual/SpellVisualPlanBuilder.luau")
env.script = {
	Parent = {
		Parent = {
			Visual = { SpellVisualFeatureExtractor = "extractor", SpellVisualFingerprint = "fingerprint" },
		},
	},
}
local analyzer = load("src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau")
local extractor, fingerprint, library, builder, curves =
	modules.extractor, modules.fingerprint, modules.library, modules.builder, modules.curves
local caps = library.Budget.PerSpell

local function serialize(value, seen)
	if type(value) ~= "table" then
		return type(value) .. ":" .. tostring(value)
	end
	if value._color then
		return string.format("color:%.4f,%.4f,%.4f", value.R, value.G, value.B)
	end
	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local out = {}
	for _, key in ipairs(keys) do
		table.insert(out, tostring(key) .. "=" .. serialize(value[key]))
	end
	return "{" .. table.concat(out, ";") .. "}"
end

local function render(spell, options)
	return builder.build(analyzer.resolve(spell), options)
end
local function param(plan, id, name)
	local entry = builder.find(plan, id)
	return entry and entry.Params[name]
end
local function withinBudget(plan, label)
	local t = plan.Totals
	assert(t.Layers <= caps.MaxLayers, label .. ": layers")
	assert(t.Accents <= caps.MaxAccents, label .. ": accents")
	assert(t.Parts <= caps.MaxParts, label .. ": parts " .. t.Parts)
	assert(t.Links <= caps.MaxLinks, label .. ": links")
	assert(t.Trails <= caps.MaxTrails, label .. ": trails")
	assert(t.Emitters <= caps.MaxEmitters, label .. ": emitters")
	assert(t.Rate <= caps.MaxSpellRate + 1e-9, label .. ": rate")
	assert(t.Fire <= caps.MaxFire, label .. ": fire")
	assert(t.Lights <= caps.MaxLights, label .. ": lights")
	local parts, links, rate = 0, 0, 0
	for _, entry in ipairs(plan.Layers) do
		local p = entry.Params
		if entry.Kind == "Nodes" then
			parts += p.Count
			links += p.LinkCount or 0
		elseif entry.Kind == "Emitter" then
			assert(p.Rate <= caps.MaxEmitterRate, label .. ": emitter rate")
			rate += p.Rate
		end
		for key, value in pairs(p) do
			assert(value == value and value > -math.huge and value < math.huge, label .. ": non-finite " .. key)
		end
		-- Quality tiers and part budgets may lower counts, never raise any value past its limit.
		for key, limit in pairs(entry.Limits or {}) do
			assert(p[key] <= limit[2] + 1e-9, label .. ": " .. entry.Id .. "." .. key)
			assert(
				key == "Count" or key == "Rate" or p[key] >= limit[1] - 1e-9,
				label .. ": " .. entry.Id .. "." .. key
			)
		end
	end
	assert(parts == t.Parts and links == t.Links, label .. ": totals must match layers")
	assert(math.abs(rate - t.Rate) < 1e-6, label .. ": rate total")
	local hasBoundary = false
	for _, entry in ipairs(plan.Layers) do
		hasBoundary = hasBoundary or entry.Priority == 1
	end
	assert(hasBoundary, label .. ": silhouette/boundary layer must survive")
end

-- Reference constants track the real safety limits.
for key, limitKey in pairs({
	Duration = "MaxDuration",
	Bind = "MaxBindDuration",
	Force = "MaxForce",
	Speed = "MaxSpeed",
	Range = "MaxRange",
	Radius = "MaxRadius",
	TurnRate = "MaxHomingTurnRate",
	Aerial = "MaxAerialSpeed",
	MarkStacks = "MaxElementalMarkStacks",
	Shield = "MaxShieldPerTarget",
}) do
	assert(extractor.Reference[key] == limits[limitKey], "Reference " .. key .. " drifted from MagicLab." .. limitKey)
end
assert(math.abs(extractor.Reference.TickRate - 1 / limits.MinInterval) < 1e-9)
assert(math.abs(extractor.Reference.MaxSlow - (1 - limits.MinSlowMultiplier)) < 1e-9)

-- Curves are bounded, monotonic and safe for hostile input.
for _, x in ipairs({ -5, 0, 0.5, 3, 1e6, math.huge, -math.huge, 0 / 0 }) do
	for _, f in ipairs({ curves.log, curves.sqrt, curves.linear, curves.saturate }) do
		local y = f(x, 10)
		assert(y >= 0 and y <= 1, "curve escaped [0,1]")
	end
end
assert(curves.log(1, 10) < curves.log(5, 10) and curves.log(5, 10) < curves.log(10, 10))

-- Curated spells: every recipe validates and yields a bounded, deterministic plan.
local definitions = {}
local curatedCount = 0
for _, build in ipairs({ starters.buildShowcase, starters.buildShowcaseExpansion }) do
	for _, record in ipairs(build()) do
		local d = record.Definition
		cost.refresh(d, spec.estimate, spec.copy)
		assert(spec.validate(d))
		definitions[d.Name] = d
		local before = serialize(d)
		local resolved = analyzer.resolve(d)
		local plan = builder.build(resolved)
		assert(serialize(d) == before, d.Name .. ": analysis must not mutate the spell")
		withinBudget(plan, d.Name)
		local particles = 0
		for _, entry in ipairs(plan.Layers) do
			particles += if entry.Kind == "Emitter" then 1 else 0
		end
		assert(particles > 0, d.Name .. ": layer cap must leave room for elemental particles")
		for _, quality in ipairs({ "Medium", "Low" }) do
			local reduced = builder.build(resolved, { Quality = quality })
			withinBudget(reduced, d.Name .. " " .. quality)
			assert(reduced.Totals.Parts <= plan.Totals.Parts and reduced.Totals.Emitters <= plan.Totals.Emitters)
		end
		curatedCount += 1
	end
end
assert(curatedCount == 65, "Expected 65 curated spells, got " .. curatedCount)

local function variant(baseName, mutate)
	local d = spec.copy(definitions[baseName])
	mutate(d)
	cost.refresh(d, spec.estimate, spec.copy)
	local ok, reason = spec.validate(d)
	assert(ok, baseName .. " variant invalid: " .. tostring(reason))
	return d
end
local function fireDot(amount, interval, duration, direct)
	return variant("Cinder Comet", function(d)
		local payloads = { { Kind = "DamageOverTime", Amount = amount, Interval = interval, Duration = duration } }
		if direct then
			table.insert(payloads, 1, { Kind = "Damage", Amount = direct })
		end
		d.Triggers = { OnImpact = { { Payloads = payloads } } }
		d.Projectile.Behaviors = {}
	end)
end

-- 1. Determinism: identical definitions -> identical plans and fingerprints.
local a, b = fireDot(6, 0.5, 4), fireDot(6, 0.5, 4)
assert(serialize(render(a)) == serialize(render(b)), "Identical spells must produce identical plans")
assert(analyzer.resolve(a).Seed == analyzer.resolve(b).Seed)
assert(analyzer.resolve(a).FeatureVector == analyzer.resolve(b).FeatureVector)
-- 2. Identity never matters: renaming and re-identifying changes nothing visual.
local renamed = spec.copy(a)
renamed.Name, renamed.SpellId = "Completely Different Name", "SomeOtherId"
assert(serialize(render(renamed)) == serialize(render(a)), "Spell name/ID must not affect appearance")
assert(analyzer.resolve(fireDot(7, 0.5, 4)).Seed ~= analyzer.resolve(a).Seed, "Mechanics should change the seed")
-- Encoding round-trips exactly (server stamp -> client read).
local features = analyzer.resolve(a).Features
local decoded = extractor.decode(extractor.encode(features))
for _, key in ipairs(extractor.Order) do
	assert(math.abs(decoded[key] - features[key]) < 1e-9, "Feature encoding lost " .. key)
end
assert(serialize(builder.build({
	Element = "Fire",
	Form = "Projectile",
	Geometry = "Sphere",
	FeatureVector = extractor.encode(features),
})) == serialize(render(a)))

-- 3 + 5. Monotonic, bounded response: more total DoT -> fuller flames, never past caps.
local previousScale, previousCount, previousSize = -1, -1, -1
for _, amount in ipairs({ 0.5, 1, 2, 4, 8, 16, 32, 41 }) do -- 41 x 12 ticks stays under the 500 total limit
	local plan = render(fireDot(amount, 0.5, 6))
	local scale, count = param(plan, "Fire.Flames", "Scale"), param(plan, "Fire.Flames", "Count")
	local size = param(plan, "Fire.Native", "Size")
	assert(
		scale >= previousScale and count >= previousCount and size >= previousSize,
		"Flame response must be monotonic"
	)
	assert(scale <= 1.5 and count <= 10 and size <= 12, "Flame response must stay capped")
	previousScale, previousCount, previousSize = scale, count, size
	withinBudget(plan, "dot " .. amount)
end
local weak, strong = render(fireDot(1, 0.25, 2)), render(fireDot(14, 1, 6))
assert(param(strong, "Fire.Flames", "Scale") > param(weak, "Fire.Flames", "Scale"), "Stronger DoT -> larger flames")
assert(param(strong, "Fire.Flames", "Count") > param(weak, "Fire.Flames", "Count"), "Stronger DoT -> fuller flames")
assert(param(strong, "Fire.Native", "Size") > param(weak, "Fire.Native", "Size"))

-- 4. Orthogonality: amount, interval and duration move different channels.
local base = render(fireDot(4, 1, 4))
local moreAmount = render(fireDot(12, 1, 4))
local fasterTicks = render(fireDot(4, 0.25, 4))
local longer = render(fireDot(4, 1, 12))
local function delta(plan, id, name)
	return param(plan, id, name) - param(base, id, name)
end
-- Higher per-tick damage -> stronger surges, but tick rate (flicker) is unchanged.
assert(delta(moreAmount, "Fire.Flames", "PulseAmplitude") > 0)
assert(delta(moreAmount, "Fire.Flames", "PulseFrequency") == 0)
-- Faster ticks -> faster flicker; individual surge strength is unchanged.
assert(delta(fasterTicks, "Fire.Flames", "PulseFrequency") > 0)
assert(delta(fasterTicks, "Fire.Flames", "PulseAmplitude") == 0)
-- Longer duration -> persistent embers/smoke; neither flicker nor surge strength changes.
assert(delta(longer, "Fire.Embers", "Lifetime") > 0)
assert(delta(longer, "Fire.Flames", "PulseFrequency") == 0 and delta(longer, "Fire.Flames", "PulseAmplitude") == 0)
assert(delta(longer, "Fire.Smoke", "Rate") > 0, "Longer burns add persistent smoke")
assert(not builder.find(render(fireDot(4, 1, 1)), "Fire.Smoke"), "Short burns carry no smoke layer")
assert(delta(moreAmount, "Fire.Embers", "Lifetime") == 0, "Per-tick damage must not read as long duration")
assert(serialize(moreAmount) ~= serialize(longer), "High damage and long duration must look different")

-- 6. Direct damage drives impact/core intensity, not sustained flame volume.
local lowDirect, highDirect = render(fireDot(4, 1, 4, 5)), render(fireDot(4, 1, 4, 90))
assert(param(highDirect, "Projectile.Core", "Scale") > param(lowDirect, "Projectile.Core", "Scale"))
assert(param(highDirect, "Fire.HotCore", "Brightness") > param(lowDirect, "Fire.HotCore", "Brightness"))
assert(param(highDirect, "Mechanic.Impact", "BurstSize") > param(lowDirect, "Mechanic.Impact", "BurstSize"))
assert(
	param(highDirect, "Fire.Flames", "Scale") == param(lowDirect, "Fire.Flames", "Scale"),
	"Direct damage must not inflate sustained flames"
)
assert(param(highDirect, "Fire.Native", "Size") == param(lowDirect, "Fire.Native", "Size"))
assert(param(highDirect, "Projectile.Core", "Scale") <= 0.6, "Core never exceeds 0.6x the hit diameter")

-- 7. Shield amount -> ward layers / thickness / opacity.
local function shieldAura(amount)
	return variant("Verdant Sanctuary", function(d)
		d.Triggers = { OnEnter = { { Payloads = { { Kind = "Shield", Amount = amount, Duration = 6 } } } } }
	end)
end
local lowWard, highWard = render(shieldAura(8)), render(shieldAura(100))
assert(param(highWard, "Mechanic.Ward", "Count") > param(lowWard, "Mechanic.Ward", "Count"))
assert(param(highWard, "Mechanic.Ward", "Thickness") > param(lowWard, "Mechanic.Ward", "Thickness"))
assert(param(highWard, "Mechanic.Ward", "Opacity") > param(lowWard, "Mechanic.Ward", "Opacity"))
assert(param(highWard, "Mechanic.Ward", "Count") <= 4)

-- 8. Projectile speed -> trail length and streamlining.
local function speed(value)
	return variant("Cinder Comet", function(d)
		d.Projectile.Speed = value
	end)
end
local slow, fast = render(speed(20)), render(speed(190))
assert(param(fast, "Projectile.Trail", "Lifetime") > param(slow, "Projectile.Trail", "Lifetime"))
assert(param(fast, "Projectile.Core", "Stretch") > param(slow, "Projectile.Core", "Stretch"))
assert(param(fast, "Projectile.Shell", "RotationSpeed") > param(slow, "Projectile.Shell", "RotationSpeed"))
assert(fast.MotionRate > slow.MotionRate)

-- 9. Chain/split/pierce/bounce counts -> bounded mechanical accents.
local function behaviors(list)
	return variant("Cinder Comet", function(d)
		d.Projectile.Behaviors = list
		d.Triggers.OnTick = nil -- Cinder Comet's tick trigger needs its Linger behavior
	end)
end
local chained = render(behaviors({ { Kind = "Chain", Radius = 10, MaxJumps = 6, DamageFalloff = 0.7 } }))
assert(param(chained, "Mechanic.Forks", "Count") == 6, "Chain jumps map to fork branches")
local fewer = render(behaviors({ { Kind = "Chain", Radius = 10, MaxJumps = 2, DamageFalloff = 0.7 } }))
assert(param(fewer, "Mechanic.Forks", "Count") == 2)
local split = render(behaviors({ { Kind = "Split", ChildCount = 5, SpreadAngle = 24, DamageFalloff = 0.65 } }))
assert(param(split, "Mechanic.Satellites", "Count") == 5)
local pierce = render(behaviors({ { Kind = "Pierce", MaxPierces = 5 } }))
local pierceOne = render(behaviors({ { Kind = "Pierce", MaxPierces = 1 } }))
assert(param(pierce, "Mechanic.Lance", "Length") > param(pierceOne, "Mechanic.Lance", "Length"))
local bounce = render(behaviors({ { Kind = "Bounce", MaxBounces = 5, Restitution = 0.8 } }))
assert(param(bounce, "Mechanic.Echo", "Count") <= 4 and param(bounce, "Mechanic.Echo", "Count") >= 1)
for _, plan in ipairs({ chained, split, pierce, bounce }) do
	withinBudget(plan, "behavior accents")
end

-- 10. Adversarial values (unvalidated, hostile) never exceed rendering budgets.
local huge = 1e12
local hostile = {
	Form = "Projectile",
	Element = "Fire",
	Projectile = {
		Speed = huge,
		Radius = math.huge,
		MaxDistance = 0 / 0,
		Behaviors = {
			{ Kind = "Chain", MaxJumps = huge },
			{ Kind = "Split", ChildCount = huge },
			{ Kind = "Pierce", MaxPierces = huge },
			{ Kind = "Bounce", MaxBounces = huge },
			{ Kind = "Linger", Duration = huge, Interval = 0 },
			{ Kind = "Homing", TurnRate = huge },
		},
	},
	Triggers = {},
}
local payloads = {}
for _, kind in ipairs({
	"Damage",
	"DamageOverTime",
	"Heal",
	"Shield",
	"Slow",
	"Bind",
	"Force",
	"Summon",
	"ElementalMark",
}) do
	table.insert(payloads, {
		Kind = kind,
		Amount = huge,
		Duration = huge,
		Interval = 1e-9,
		Multiplier = -huge,
		Magnitude = huge,
		Count = huge,
		Stacks = huge,
	})
end
for _, event in ipairs({ "OnImpact", "OnTick", "OnExpire", "OnCast", "OnEnter" }) do
	hostile.Triggers[event] = { { Payloads = payloads }, { Payloads = payloads } }
end
for _, form in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura", "Construct", "SelfEnhancement", "Manipulation" }) do
	for element in pairs(library.Elements) do
		hostile.Form, hostile.Element = form, element
		hostile.Beam = { Range = huge, Width = huge, Pattern = "Cascade", StrikeCount = huge, StrikeInterval = 0 }
		hostile.Field = { Radius = huge, GrowthDuration = huge, Interval = 0 }
		hostile.Construct = { Width = huge, Height = huge, Depth = huge }
		for _, quality in ipairs({ "High", "Medium", "Low" }) do
			withinBudget(render(hostile, { Quality = quality }), "hostile " .. form .. "/" .. element)
		end
	end
end
for _, key in ipairs(extractor.Order) do
	local value = extractor.extract(hostile)[key]
	assert(
		value >= 0 and value <= (extractor.Counts[key] and extractor.Reference.MaxCount or 1),
		"Feature " .. key .. " escaped bounds"
	)
end
assert(serialize(render({})) == serialize(render({})), "Empty data still renders deterministically")
withinBudget(render({}), "empty")

-- 12. Legacy visual data still loads; generation ignores manual composition choices.
local legacy = spec.copy(definitions["Cinder Comet"])
legacy.Visual.VFXDefinition = "FrostProjectile"
legacy.Visual.CoreShape = "Wedge"
legacy.Visual.ParticleStyle = "None"
legacy.Visual.TrailStyle = "None"
legacy.Visual.Opacity = 0.4
legacy.Visual.ProjectileScale = 4
assert(spec.validate(legacy), "Legacy visual fields must remain valid")
assert(visualSpec.validate(legacy.Visual))
local legacyPlan = analyzer.resolve(legacy)
assert(legacyPlan.Element == "Fire", "Legacy VFXDefinition must not replace the spell's element")
assert(
	string.find(legacyPlan.Legacy, "VFXDefinition", 1, true)
		and string.find(legacyPlan.Legacy, "ProjectileScale", 1, true)
)
assert(
	serialize(builder.build(legacyPlan)) == serialize(render(definitions["Cinder Comet"])),
	"Manual shape/particle/trail/scale choices must not change the generated composition"
)
assert(legacy.Visual.CoreShape == "Wedge", "Resolving must keep saved legacy data untouched")
-- Remote preset playback (no spell element) still uses the preset's element.
assert(analyzer.resolve({ Form = "Projectile", Visual = { VFXDefinition = "FrostProjectile" } }).Element == "Ice")

-- 13. Purity: neither stage mutates its inputs.
local probe = fireDot(5, 0.5, 5, 20)
local snapshot = serialize(probe)
local resolved = analyzer.resolve(probe)
local resolvedSnapshot = serialize(resolved)
builder.build(resolved)
builder.build(resolved, { Quality = "Low" })
assert(serialize(probe) == snapshot and serialize(resolved) == resolvedSnapshot, "Analyzer/builder must be pure")

-- Distinct mechanics usually look distinct.
local seeds, distinctPlans = {}, 0
for name, d in pairs(definitions) do
	local key = serialize(render(d).Layers)
	if not seeds[key] then
		seeds[key] = name
		distinctPlans += 1
	end
end
assert(distinctPlans >= 60, "Curated spells should produce mostly distinct plans, got " .. distinctPlans)

-- Representative example plans (also recorded in docs/spell-vfx-coverage.md).
local function summary(label, spell)
	local plan = render(spell)
	local layers = {}
	for _, entry in ipairs(plan.Layers) do
		local p, fields = entry.Params, {}
		for _, key in ipairs({
			"Count",
			"Scale",
			"PulseAmplitude",
			"PulseFrequency",
			"Rate",
			"Lifetime",
			"Size",
			"Thickness",
			"Length",
			"Opacity",
			"Brightness",
		}) do
			if p[key] then
				table.insert(fields, string.format("%s=%g", key, math.floor(p[key] * 100 + 0.5) / 100))
			end
		end
		table.insert(layers, entry.Id .. "(" .. table.concat(fields, " ") .. ")")
	end
	local t = plan.Totals
	print(
		string.format(
			"EXAMPLE|%s|seed=%d|time=%.2f|parts=%d links=%d emitters=%d rate=%g fire=%d|%s",
			label,
			plan.Seed,
			plan.TimeScale,
			t.Parts,
			t.Links,
			t.Emitters,
			t.Rate,
			t.Fire,
			table.concat(layers, "; ")
		)
	)
	withinBudget(plan, label)
	return plan
end
local weakFast = summary("Weak fast-ticking fire DoT projectile", fireDot(1.5, 0.15, 2))
local strongSlow = summary("Strong slow-ticking fire DoT projectile", fireDot(16, 1.5, 9))
local highDirectPlan = summary("High direct-damage fire projectile", fireDot(0.5, 1, 1, 95))
assert(param(weakFast, "Fire.Flames", "PulseFrequency") > param(strongSlow, "Fire.Flames", "PulseFrequency"))
assert(param(strongSlow, "Fire.Flames", "Scale") > param(weakFast, "Fire.Flames", "Scale"))
assert(param(highDirectPlan, "Projectile.Core", "Scale") > param(strongSlow, "Projectile.Core", "Scale"))
local poison = summary(
	"Low-damage long-duration poison field",
	variant("Gravemire", function(d)
		d.Triggers =
			{ OnEnter = { { Payloads = { { Kind = "DamageOverTime", Amount = 1, Interval = 1, Duration = 14 } } } } }
	end)
)
assert(param(poison, "Poison.Vapor", "Lifetime") > 2, "Long-duration poison lingers")
summary("High-value shield aura", shieldAura(100))
local lightning = summary(
	"Fast chaining lightning beam",
	variant("Thunderhead", function(d)
		d.Beam.StrikeCount = 6
		d.Beam.StrikeInterval = 0.1
	end)
)
assert(param(lightning, "Mechanic.Forks", "Count") == 6)
assert(param(lightning, "Lightning.Forks", "PulseFrequency") > 10, "Fast cascades flicker quickly")
print(
	"Visual plans: determinism, identity independence, monotonic bounded response, DoT orthogonality, direct/shield/speed/behavior channels, adversarial budgets, legacy compatibility, purity and 65 curated plans passed"
)
