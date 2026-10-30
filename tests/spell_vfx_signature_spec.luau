-- Engine-independent checks for the signature VFX layer (planner, library, manifest references).
-- Run through tests/test_spell_vfx_signatures.py, which supplies `sources` and `load`.
-- Verifies data wiring only; it is not a rendered visual review.
local C3 = {}
C3.__index = C3
local function color(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, C3)
end
function C3:Lerp(o, a)
	return color(self.R + (o.R - self.R) * a, self.G + (o.G - self.G) * a, self.B + (o.B - self.B) * a)
end
env.Color3 = {
	new = color,
	fromRGB = function(r, g, b)
		return color(r / 255, g / 255, b / 255)
	end,
}
env.Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
env.Vector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}

local modules = {}
env.require = function(value)
	return assert(modules[value], "Unexpected require " .. tostring(value))
end
env.script = { Parent = {} }
modules.curves = load("src/shared/SpellVFXSystem/Visual/VisualCurves.luau")
env.script = { Parent = { VisualCurves = "curves" } }
modules.extractor = load("src/shared/SpellVFXSystem/Visual/SpellVisualFeatureExtractor.luau")
modules.fingerprint = load("src/shared/SpellVFXSystem/Visual/SpellVisualFingerprint.luau")
env.script = {
	Parent = {
		Parent = { Visual = { SpellVisualFeatureExtractor = "extractor", SpellVisualFingerprint = "fingerprint" } },
	},
}
local analyzer = load("src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau")
env.script = { Parent = {} }
modules.kits = load("src/shared/SpellVFXSystem/Signature/SignatureKits.luau")
env.script = { Parent = { SignatureKits = "kits" } }
modules.library = load("src/shared/SpellVFXSystem/Signature/SignatureLibrary.luau")
modules.styled = load("src/shared/SpellVFXSystem/Assets/StyledVFXManifest.luau")
env.script = { Parent = { SignatureLibrary = "library", Parent = { Assets = { StyledVFXManifest = "styled" } } } }
local planner = load("src/shared/SpellVFXSystem/Signature/SignaturePlanner.luau")
local manifest = load("src/shared/SpellVFXSystem/Assets/VFXAssetManifest.luau")
local library = modules.library

local function fireball()
	return {
		Form = "Projectile",
		Targeting = "AimDirection",
		Geometry = "Sphere",
		Motion = "Linear",
		Source = { Principle = "Energy", Expression = "Fire" },
		Casting = { Mode = "Instant", Cooldown = 0.45 },
		Lifetime = { Mode = "FixedDuration", Duration = 2.2 },
		Projectile = { Speed = 72, Radius = 1.1 },
		Visual = { Color = color(1, 105 / 255, 50 / 255) },
		Triggers = {
			OnImpact = {
				{ Payloads = { { Kind = "Damage", Amount = 10 } } },
				{ Behavior = "Explode", Radius = 7, Payloads = { { Kind = "Damage", Amount = 18 } } },
			},
		},
	}
end
local function bodyBurst()
	return {
		Form = "Wave",
		Targeting = "Self",
		Geometry = "Cone",
		Motion = "Stationary",
		Source = { Principle = "Body", Expression = "BodyEnhancement" },
		Casting = { Mode = "Instant", Cooldown = 1.2 },
		Lifetime = { Mode = "Instantaneous" },
		Wave = {
			Range = 10,
			Dot = 0.35,
			Payloads = { { Kind = "Damage", Amount = 16 }, { Kind = "Force", Magnitude = 54, Upward = 8 } },
		},
		Triggers = { OnCast = true },
	}
end

local function ids(render)
	local set = {}
	for _, layer in ipairs(render.Layers) do
		set[layer.Id] = layer
	end
	return set
end
local function param(render, id, name)
	return assert(ids(render)[id], "missing layer " .. id).Params[name]
end

-- Selection is by data: Fire element, Body principle; other schools keep the composer only.
local fire = analyzer.resolve(fireball())
assert(fire.Element == "Fire" and fire.ImpactRadius == 7, "analyzer exposes element and explode radius")
local body = analyzer.resolve(bodyBurst())
assert(body.Element == "Neutral" and body.Principle == "Body", "Body Burst resolves through its principle")
assert(planner.match(fire).Name == "Fire" and planner.match(body).Name == "Body")
-- Every school resolves to a kit: element first, then expression/principle, Arcane otherwise.
local schools = {
	{ "Ice", { Element = "Ice", Source = { Principle = "Matter", Expression = "Water" } } },
	{ "Lightning", { Source = { Principle = "Energy", Expression = "Lightning" } } },
	{ "Water", { Source = { Principle = "Matter", Expression = "Water" } } },
	{ "Earth", { Source = { Principle = "Matter", Expression = "Earth" } } },
	{ "Wind", { Element = "Wind", Source = { Principle = "Energy", Expression = "Force" } } },
	{ "Poison", { Element = "Poison", Source = { Principle = "Body", Expression = "BodyEnhancement" } } },
	{ "Force", { Source = { Principle = "Energy", Expression = "Force" } } },
	{ "Spirit", { Source = { Principle = "Soul", Expression = "Spirit" } } },
	{ "Space", { Source = { Principle = "Space", Expression = "SpatialFold" } } },
	{ "Time", { Source = { Principle = "Time", Expression = "TemporalShift" } } },
	{ "Arcane", { Source = { Principle = "Energy", Expression = "Unawakened" } } },
}
local forms = {
	Projectile = { Projectile = { Speed = 60, Radius = 1 } },
	Beam = { Beam = { Width = 1.5, Range = 24 } },
	Wave = { Wave = { Range = 10, Dot = 0.4, Payloads = { { Kind = "Damage", Amount = 10 } } } },
	Field = { Field = { Radius = 6 }, Geometry = "Cylinder" },
	Aura = { Aura = { Radius = 5 } },
	SelfEnhancement = {},
	Construct = { Construct = { Width = 8, Height = 6, Depth = 2 } },
	Manipulation = {},
}
local roleCount = 0
for _, school in ipairs(schools) do
	local name, base = school[1], school[2]
	for form, extra in pairs(forms) do
		local spell = {
			Form = form,
			Geometry = extra.Geometry or "Sphere",
			Targeting = "AimDirection",
			Element = base.Element,
			Source = base.Source,
			Triggers = {},
		}
		for key, value in pairs(extra) do
			spell[key] = value
		end
		local plan = analyzer.resolve(spell)
		assert(planner.match(plan).Name == name, name .. " " .. form .. " matched " .. planner.match(plan).Name)
		for _,quality in {"High","Low"} do
			for _,layer in planner.plan(plan,"End",{Quality=quality}).Layers do
				assert(layer.Kind~="Burst",name.." "..form.." ending must not spawn a hit cloud")
			end
		end
		for _, phase in ipairs({ "Sustain", "Impact" }) do
			local render = planner.plan(plan, phase)
			assert(render and #render.Layers > 0, name .. " " .. form .. " " .. phase .. " has layers")
			assert(render.Replaces.Form and render.Replaces.Mechanic, name .. " fully replaces the composer")
			for _, layer in ipairs(render.Layers) do
				assert(
					string.sub(layer.Id, 1, #name + 1) == name .. ".",
					name .. " uses only its own layers: " .. layer.Id
				)
			end
			roleCount += 1
		end
		local gather = planner.plan(analyzer.forPhase(plan, "Gather", "x"), "Gather", { CastingCue = true })
		assert(#gather.Layers > 0, name .. " charges")
		for _,q in {"High","Low"} do
			local release=planner.plan(analyzer.forPhase(plan,"Release","SpellReleaseComposition"),"Release",{CastingCue=true,Quality=q})
			assert(#release.Layers>0 and release.Replaces.Form,"Release must not fall back to source explosions")
			for _,l in release.Layers do assert(l.Kind=="Light",name.." "..form.." source release contains an explosion or moving motif") end
		end
	end
end

-- Fireball phases map to distinct components.
local flight = planner.plan(fire, "Sustain")
local f = ids(flight)
assert(flight.Role == "Projectile")
for _, id in ipairs({
	"Fire.Core.Heart",
	"Fire.Core.Body",
	"Fire.Shell.Tongues",
	"Fire.Trail.Wake",
	"Fire.Ambient.Embers",
}) do
	assert(f[id], "projectile flight layer " .. id)
end
assert(not f["Fire.Impact.Fireball"], "no impact layers in flight")
assert(flight.Replaces.Form and flight.Replaces.Element, "fire projectile replaces stock composer bodies")
local impact = planner.plan(fire, "Impact")
local i = ids(impact)
assert(impact.Role == "Impact")
for _, id in ipairs({ "Fire.Impact.Flash", "Fire.Impact.Fireball", "Fire.Impact.Shockwave", "Fire.Dissipate.Smoke" }) do
	assert(i[id], "impact layer " .. id)
end
assert(not i["Fire.Core.Heart"], "impact does not respawn the core")
local ending = planner.plan(fire, "End")
assert(not ids(ending)["Fire.Dissipate.Smoke"] and not ids(ending)["Fire.Core.Heart"], "projectile end cannot spawn another hit cloud")
local cast =
	planner.plan(analyzer.forPhase(fire, "Release", "SpellReleaseComposition"), "Release", { CastingCue = true })
assert(cast.Role == "Cast" and ids(cast)["Fire.Cast.ReleaseCue"], "release is a small light, not a second explosion")
local gather =
	planner.plan(analyzer.forPhase(fire, "Gather", "SpellGatherComposition"), "Gather", { CastingCue = true })
assert(ids(gather)["Fire.Charge.Point"] and ids(gather)["Fire.Charge.Converge"], "gather accumulates energy")

-- Variables drive visuals without touching gameplay values.
local small, big = fireball(), fireball()
big.Projectile.Radius = 3
local smallPlan, bigPlan = analyzer.resolve(small), analyzer.resolve(big)
assert(small.Projectile.Radius == 1.1 and big.Projectile.Radius == 3, "analysis never mutates gameplay data")
local sFlight, bFlight = planner.plan(smallPlan, "Sustain"), planner.plan(bigPlan, "Sustain")
assert(bFlight.Scalars.Size > sFlight.Scalars.Size, "size scalar follows hit radius")
assert(bFlight.Scalars.Potency == sFlight.Scalars.Potency, "size does not imply potency")
assert(
	param(bFlight, "Fire.Shell.Tongues", "Rate") > param(sFlight, "Fire.Shell.Tongues", "Rate"),
	"bigger body emits more"
)

local strong = fireball()
strong.Triggers.OnImpact[1].Payloads[1].Amount = 90
local strongPlan = analyzer.resolve(strong)
local stFlight = planner.plan(strongPlan, "Sustain")
assert(stFlight.Scalars.Potency > sFlight.Scalars.Potency, "potency follows damage")
assert(stFlight.Scalars.Size == sFlight.Scalars.Size, "potency does not change body size")
assert(
	param(stFlight, "Fire.Core.Heart", "Framerate") > param(sFlight, "Fire.Core.Heart", "Framerate"),
	"potency animates the core faster"
)
assert(
	param(stFlight, "Fire.Core.Body", "Wobble") > param(sFlight, "Fire.Core.Body", "Wobble"),
	"potency adds instability"
)
assert(
	param(planner.plan(strongPlan, "Impact"), "Fire.Impact.Embers", "Count")
		> param(planner.plan(smallPlan, "Impact"), "Fire.Impact.Embers", "Count"),
	"potency adds impact detail"
)

local wide = fireball()
wide.Triggers.OnImpact[2].Radius = 16
assert(
	param(planner.plan(analyzer.resolve(wide), "Impact"), "Fire.Impact.Shockwave", "SizeEnd")
		> param(impact, "Fire.Impact.Shockwave", "SizeEnd"),
	"impact shockwave follows the real explode radius"
)

local homing = fireball()
homing.Projectile.Behaviors = { { Kind = "Homing", SearchRadius = 20, TurnRate = 360 } }
assert(
	param(planner.plan(analyzer.resolve(homing), "Sustain"), "Fire.Trail.Wake", "Lifetime")
		> param(flight, "Fire.Trail.Wake", "Lifetime"),
	"homing keeps a longer trail so curves read"
)

local fast = fireball()
fast.Projectile.Speed = 180
assert(
	param(planner.plan(analyzer.resolve(fast), "Sustain"), "Fire.Shell.Mesh", "Stretch")
		> param(flight, "Fire.Shell.Mesh", "Stretch"),
	"speed stretches the flame shell"
)

local charged = fireball()
charged.Casting = { Mode = "Charged", MinimumCharge = 0.2, MaximumCharge = 2.5, Cooldown = 0.5 }
local chargedPlan = analyzer.resolve(charged)
assert(planner.scalars(chargedPlan).Charge > planner.scalars(fire).Charge, "charge time is visible")
local chargedGather = planner.plan(analyzer.forPhase(chargedPlan, "Gather", "x"), "Gather", { CastingCue = true })
assert(param(chargedGather, "Fire.Charge.Converge", "Rate") > param(gather, "Fire.Charge.Converge", "Rate"))

-- Body Burst: its own identity, direction and force response.
local wave = planner.plan(body, "Release")
local w = ids(wave)
assert(wave.Role == "Wave" and wave.Signature == "Body")
for _, id in ipairs({
	"Body.Core.Cone",
	"Body.Shell.Fronts",
	"Body.Secondary.Streaks",
	"Body.Impact.Front",
	"Body.Ambient.Dust",
}) do
	assert(w[id], "body wave layer " .. id)
end
for id in pairs(w) do
	assert(string.sub(id, 1, 5) == "Body.", "Body Burst uses no Fire layers: " .. id)
end
local heavy = bodyBurst()
heavy.Wave.Payloads[2].Magnitude = 100
local heavyWave = planner.plan(analyzer.resolve(heavy), "Release")
assert(
	param(heavyWave, "Body.Shell.Fronts", "Size") > param(wave, "Body.Shell.Fronts", "Size"),
	"force enlarges fronts"
)
assert(param(heavyWave, "Body.Secondary.Streaks", "Count") > param(wave, "Body.Secondary.Streaks", "Count"))
assert(heavy.Wave.Range == 10, "force does not change range")
local bodyCast =
	planner.plan(analyzer.forPhase(body, "Release", "SpellReleaseComposition"), "Release", { CastingCue = true })
assert(
	ids(bodyCast)["Body.Cast.ReleaseCue"] and not ids(bodyCast)["Body.Core.Cone"],
	"caster cue is separate from the wave"
)

-- Quality: every priority-1 layer survives Low; lights and decorative meshes drop.
for _, phase in ipairs({ "Sustain", "Impact" }) do
	local high, low = planner.plan(fire, phase, { Quality = "High" }), planner.plan(fire, phase, { Quality = "Low" })
	local lowIds = ids(low)
	for _, layer in ipairs(high.Layers) do
		if layer.Priority == 1 then
			assert(lowIds[layer.Id], "Low keeps critical " .. layer.Id)
		end
	end
	for _, layer in ipairs(low.Layers) do
		assert(layer.Kind ~= "Light", "Low has no lights")
		assert(layer.Priority == 1, "Low keeps only critical layers")
		if layer.Params.Rate then
			assert(layer.Params.Rate <= param(high, layer.Id, "Rate"), "Low lowers rates")
		end
	end
	assert(#low.Layers < #high.Layers)
end
assert(ids(planner.plan(body, "Release", { Quality = "Low" }))["Body.Core.Cone"], "Body cone stays on Low")

-- Beams distinguish continuous fluids from motifs opening at fixed path stations.
for _,identity in {"Fire","Water","Arcane","Space"} do
	local plan=table.clone(fire);plan.Element=identity;plan.Expression=identity;plan.Form="Beam"
	for _,quality in {"High","Low"} do
		local resolved=planner.plan(plan,"Sustain",{Quality=quality})
		local found=false
		for _,layer in resolved.Layers do
			assert(not string.find(layer.Id,"Beam.Flow",1,true),identity.." has travelling glyphs")
			assert(not string.find(layer.Id,"Beam.Motes",1,true),identity.." has spinning path particles")
			if identity=="Fire" or identity=="Water" then
				assert(layer.Kind~="Sprite" and layer.Kind~="Emitter",identity.." still has a spinning sprite body")
				if layer.Kind=="Beam" then assert(layer.Params.ContinuousStream);found=true end
			elseif layer.Kind=="PathGlyphs" then
				found=true
				if identity=="Arcane" then assert(layer.FrameTexture=="rune_circle","Runes need geometric enclosures") end
			end
		end
		assert(found,identity.." beam body missing at "..quality)
	end
end

-- Every asset a recipe names exists in the generated manifest; budgets are bounded.
local count = 0
for _, signature in pairs(library.Signatures) do
	for _, layer in ipairs(signature.Layers) do
		count += 1
		assert(layer.Priority >= 1 and layer.Priority <= 3, layer.Id .. " priority")
		if layer.Texture then
			assert(manifest.Textures[layer.Texture], layer.Id .. " texture " .. layer.Texture)
		end
		if layer.FrameTexture then assert(manifest.Textures[layer.FrameTexture],layer.Id.." enclosure asset") end
		for _, mesh in ipairs(layer.Meshes or { layer.Mesh }) do
			assert(manifest.Meshes[mesh], layer.Id .. " mesh " .. tostring(mesh))
		end
		local tokens = if type(layer.Colors) == "table" then layer.Colors else { layer.Colors }
		for _, token in ipairs(tokens) do
			assert(signature.Palette[token], layer.Id .. " palette token " .. tostring(token))
		end
		assert((layer.Params.Rate or 0) <= library.Budget.MaxEmitterRate, layer.Id .. " base rate within budget")
	end
end
for _, entry in pairs(manifest.Textures) do
	assert(entry.Id == nil or string.match(entry.Id, "^rbxassetid://%d+$"), "manifest ids are real asset ids or nil")
end
-- Worst-case driven rates stay inside the per-emitter cap.
local maxed = {}
for key in pairs(planner.scalars(fire)) do
	maxed[key] = 1
end
for _, signature in pairs(library.Signatures) do
	for _, layer in ipairs(signature.Layers) do
		local rate = layer.Params.Rate or 0
		for _, driver in ipairs(layer.Drivers) do
			if driver[1] == "Rate" then
				rate += driver[3]
			end
		end
		if layer.Limits.Rate then
			rate = math.min(rate, layer.Limits.Rate[2])
		end
		assert(rate <= library.Budget.MaxEmitterRate, layer.Id .. " max rate " .. rate)
	end
end
print(
	"Signature VFX: "
		.. roleCount
		.. " school/form/phase plans and "
		.. count
		.. " layers checked; selection, phases, variable mapping, quality tiers and manifest references passed"
)
