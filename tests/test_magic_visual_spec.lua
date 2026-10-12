local env = {}
setmetatable(env, { __index = _G })
env.Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255, _color = true }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b, _color = true }
	end,
}
env.typeof = function(value)
	return type(value) == "table" and value._color and "Color3" or type(value)
end
local spec = assert(loadfile("src/shared/Modules/MagicVisualSpec.luau", "t", env))()
local function clone(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local valid, reason = spec.validate(spec.Defaults)
assert(valid, reason)
local distortion = clone(spec.Defaults)
distortion.Distortion = 1
assert(spec.validate(distortion), "maximum cosmetic distortion should validate")

local expectedAutoMaterials = {
	{ "Matter", "Earth", "Projectile", "Slate" },
	{ "Matter", "Water", "Projectile", "Glass" },
	{ "Energy", "Fire", "Projectile", "Neon" },
	{ "Energy", "Lightning", "Beam", "ForceField" },
	{ "Energy", "Force", "Wave", "SmoothPlastic" },
	{ "Body", "BodyEnhancement", "Aura", "ForceField" },
	{ "Soul", "Spirit", "Field", "Glass" },
	{ "Space", "SpatialFold", "Projectile", "ForceField" },
	{ "Time", "TemporalShift", "Beam", "Glass" },
}
for _, case in ipairs(expectedAutoMaterials) do
	assert(spec.autoMaterial(case[1], case[2], case[3]) == case[4])
end
assert(spec.autoMaterial("Matter", "Water", "Construct") == "Slate", "Constructs keep their legacy material")
assert(spec.autoMaterial("Unknown", "Unknown", "Projectile") == "Neon", "Unknown metadata keeps a safe fallback")

local ember = assert(spec.PaletteDefinitions.Ember)
assert(
	ember.Label == "Ember" and #ember.Colors == 3,
	"palette presentation metadata is available without discovery rules"
)
assert(ember.Principle == nil and ember.Requirement == nil, "palette metadata stays independent of deferred discovery")

local legacy = { Color = env.Color3.fromRGB(255, 80, 30), ProjectileScale = 1 }
assert(spec.validate(legacy), "legacy visual settings should retain automatic presentation defaults")

for _, group in ipairs({
	{ "CoreShape", spec.CoreShapes },
	{ "Palette", spec.Palettes },
	{ "MaterialAppearance", spec.Materials },
	{ "ParticleStyle", spec.ParticleStyles },
	{ "TrailStyle", spec.TrailStyles },
	{ "ImpactStyle", spec.ImpactStyles },
	{ "CastingStyle", spec.CastingStyles },
	{ "SurfaceBehavior", spec.SurfaceBehaviors },
	{ "EnvironmentalVisual", spec.EnvironmentalVisuals },
}) do
	local key, options = group[1], group[2]
	for _, option in ipairs(options) do
		local visual = clone(spec.Defaults)
		visual[key] = option
		assert(spec.validate(visual), key .. " should accept " .. option)
	end
end

for _, invalid in ipairs({
	{ Opacity = 0.19 },
	{ Opacity = 1.01 },
	{ Emission = -0.01 },
	{ Distortion = -0.01 },
	{ Distortion = 1.01 },
	{ ProjectileScale = 4.01 },
	{ MaterialAppearance = "Unknown" },
	{ SurfaceBehavior = "DamageTerrain" },
	{ EnvironmentalVisual = "HeatVision" },
	{ CastingStyle = "Orbiting" },
	{ Unexpected = true },
	{ SecondaryColor = "blue" },
}) do
	local visual = clone(spec.Defaults)
	for key, value in pairs(invalid) do
		visual[key] = value
	end
	assert(not spec.validate(visual), "invalid visual configuration should be rejected")
end

print("Magic visual spec checks passed")
