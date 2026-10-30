-- Cosmetic composition grammar. No spell identity branches or gameplay mutation.
local Extractor = require(script.Parent.Parent.Visual.SpellVisualFeatureExtractor)
local Fingerprint = require(script.Parent.Parent.Visual.SpellVisualFingerprint)
local Analyzer = {}
Analyzer.Elements = {
	Fire = { Motif = "Flame", Volume = "Fire", Speed = 2.4 },
	Ice = { Motif = "Crystal", Volume = "Mist", Speed = 0.6 },
	Lightning = { Motif = "Fork", Volume = "Charge", Speed = 8 },
	Water = { Motif = "Ripple", Volume = "Spray", Speed = 1.2 },
	Wind = { Motif = "Ribbon", Volume = "Mist", Speed = 2.8 },
	Earth = { Motif = "Stone", Volume = "Dust", Speed = 0.45 },
	Poison = { Motif = "Bubble", Volume = "Vapor", Speed = 0.7 },
	Neutral = { Motif = "Rune", Volume = "Arcane", Speed = 1.4 },
}
Analyzer.Forms = {
	Projectile = "Comet",
	Beam = "Helix",
	Wave = "Crest",
	Field = "Volume",
	Aura = "Orbit",
	Construct = "Lattice",
	SelfEnhancement = "Mantle",
	Manipulation = "Lattice",
	-- The caster is the moving body of a Rush; a Tether is a live link between two ends.
	Rush = "Comet",
	Tether = "Helix",
}
Analyzer.Behaviors = {
	Homing = "Seeker",
	Chain = "Forks",
	Bounce = "Echo",
	Split = "Satellites",
	Pierce = "Lance",
	Orbit = "Satellites",
	Return = "Echo",
	Boomerang = "Echo",
	Cascade = "Forks",
	Linger = "Pulse",
	Damage = "Fracture",
	Force = "Wings",
	Displacement = "Wings",
	TimeDilation = "Bands",
	Reveal = "Seeker",
	Enhancement = "Crown",
	Shield = "Ward",
	Heal = "Rise",
	Restoration = "Rise",
	Summon = "Crown",
	Slow = "Bands",
	Bind = "Bands",
	Stun = "Bands",
	Silence = "Bands",
	Taunt = "Seeker",
	Fear = "Wings",
	Stealth = "Ward",
	DrainResource = "Pulse",
	RestoreResource = "Rise",
	Cleanse = "Rise",
	Dispel = "Fracture",
	Control = "Bands",
	Manipulation = "Lattice",
	DamageOverTime = "Pulse",
	ElementalMark = "Rune",
	AerialMovement = "Wings",
}
-- Authored presets only supply an element when the caller gave none (allowlisted remote
-- preset playback). On a saved spell they are retained legacy data and never override it.
local authored = {
	FireBurst = { Element = "Fire", Accent = "Pulse" },
	FireProjectile = { Element = "Fire" },
	FrostCharge = { Element = "Ice", Accent = "Rise" },
	FrostProjectile = { Element = "Ice" },
	ArcaneTrail = { Element = "Neutral", Accent = "Echo" },
	ArcaneProjectile = { Element = "Neutral" },
}
-- Saved manual visual fields stay valid and loadable but no longer drive composition.
-- Palette and colors remain the player's high-level cosmetic choice.
Analyzer.LegacyFields = {
	"CoreShape",
	"MaterialAppearance",
	"ParticleStyle",
	"TrailStyle",
	"ImpactStyle",
	"CastingStyle",
	"SurfaceBehavior",
	"EnvironmentalVisual",
	"Opacity",
	"Emission",
	"ProjectileScale",
	"VFXDefinition",
}
local legacyDefaults = {
	CoreShape = "Sphere",
	MaterialAppearance = "Auto",
	ParticleStyle = "Sparks",
	TrailStyle = "Ribbon",
	ImpactStyle = "Burst",
	CastingStyle = "HandGlow",
	SurfaceBehavior = "None",
	EnvironmentalVisual = "None",
	Opacity = 0.85,
	Emission = 0.8,
	ProjectileScale = 1,
	VFXDefinition = "None",
}
-- Largest Explode radius on impact: sizes impact visuals to the real area, read-only.
local function impactRadius(spell)
	local largest = 0
	local triggers = spell.Triggers
	local steps = type(triggers) == "table" and triggers.OnImpact
	if type(steps) == "table" then
		for _, step in ipairs(steps) do
			if type(step) == "table" and step.Behavior == "Explode" and type(step.Radius) == "number" then
				largest = math.max(largest, step.Radius)
			end
		end
	end
	return largest
end
function Analyzer.resolve(spell)
	spell = spell or {}
	local visual = spell.Visual or {}
	local preset = authored[visual.VFXDefinition]
	local declared = spell.Element or (spell.Source and spell.Source.Expression)
	local element = declared or (preset and preset.Element) or "Neutral"
	if not Analyzer.Elements[element] then
		element = "Neutral"
	end
	local form = Analyzer.Forms[spell.Form] and spell.Form or "Projectile"
	local rule = Analyzer.Elements[element]
	local accents, seen = {}, {}
	local function scan(value, depth)
		if depth > 7 then
			return
		end
		if type(value) == "string" and Analyzer.Behaviors[value] then
			local accent = Analyzer.Behaviors[value]
			if not seen[accent] then
				seen[accent] = true
				table.insert(accents, accent)
			end
		elseif type(value) == "table" then
			for key, child in pairs(value) do
				if child ~= false then
					scan(key, depth + 1)
					scan(child, depth + 1)
				end
			end
		end
	end
	scan(spell.Projectile, 0)
	scan(spell.Beam, 0)
	scan(spell.Construct, 0)
	scan(spell.Triggers, 0)
	if not declared and preset and preset.Accent and not seen[preset.Accent] then
		table.insert(accents, preset.Accent)
	end
	table.sort(accents)
	local color, secondary, accent = visual.Color, visual.SecondaryColor, visual.AccentColor
	-- Untouched editor defaults mean elemental colors, matching spell-book icons.
	if
		visual.Palette == "Origin"
		and color
		and math.abs(color.R - 180 / 255) < 0.0001
		and math.abs(color.G - 230 / 255) < 0.0001
		and math.abs(color.B - 1) < 0.0001
	then
		color, secondary, accent = nil, nil, nil
	end
	local legacy = {}
	for _, key in ipairs(Analyzer.LegacyFields) do
		if visual[key] ~= nil and visual[key] ~= legacyDefaults[key] then
			table.insert(legacy, key)
		end
	end
	local geometry = spell.Geometry or "Sphere"
	local features = Extractor.extract(spell)
	local vector = Extractor.encode(features)
	local plan = {
		Element = element,
		Form = form,
		Layout = Analyzer.Forms[form],
		Motif = rule.Motif,
		Volume = rule.Volume,
		Speed = rule.Speed,
		Geometry = geometry,
		Targeting = spell.Targeting or "AimDirection",
		Accents = table.concat(accents, ","),
		Color = color,
		SecondaryColor = secondary,
		AccentColor = accent,
		RingInner = ((spell[form] or {}).InnerRadius or 0) / math.max((spell[form] or {}).OuterRadius or 1, 0.01),
		Follow = (spell[form] or {}).FollowTarget == true,
		Source = "Generated",
		-- Magical principle (Body, Energy, ...) lets signatures cover schools without an element.
		Principle = spell.Source and spell.Source.Principle or nil,
		Expression = spell.Source and spell.Source.Expression or nil,
		ImpactRadius = impactRadius(spell),
		-- Retained-but-unapplied manual visual choices, for editor display only.
		Legacy = table.concat(legacy, ","),
		-- Stat-driven appearance: normalized features (replicated as one string) and a stable seed.
		Features = features,
		FeatureVector = vector,
		Seed = Fingerprint.seed(element, form, geometry, vector),
	}
	plan.Label = element .. " / " .. form .. " / " .. plan.Geometry .. " · " .. rule.Motif .. " + " .. rule.Volume
	return plan
end
-- Cast cues surround the source; only an active beam owns an axial path.
function Analyzer.forPhase(plan, phase, anchorName)
	local resolved = table.clone(plan)
	resolved.CastingCue = phase == "Gather" or (phase == "Release" and anchorName == "SpellReleaseComposition")
	if resolved.CastingCue then
		resolved.Layout = "Comet"
	end
	return resolved
end

function Analyzer.stamp(part, spell, size, phase)
	local plan = Analyzer.resolve(spell)
	for key, value in pairs(plan) do
		-- Tables (Features) replicate through the scalar FeatureVector attribute instead.
		if type(value) ~= "table" then
			part:SetAttribute("VFX" .. key, value)
		end
	end
	if size then
		part:SetAttribute("VFXSize", size)
	end
	part:SetAttribute("VFXPhase", phase or "Sustain")
	game:GetService("CollectionService"):AddTag(part, "ComposedSpellVFX")
end
function Analyzer.read(part)
	local plan = {}
	for key, value in pairs(part:GetAttributes()) do
		if string.sub(key, 1, 3) == "VFX" then
			plan[string.sub(key, 4)] = value
		end
	end
	plan.Features = Extractor.decode(plan.FeatureVector)
	return plan
end
return Analyzer
