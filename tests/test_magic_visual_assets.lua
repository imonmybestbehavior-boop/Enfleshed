local specEnv = {}
setmetatable(specEnv, { __index = _G })
specEnv.Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255, _color = true }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b, _color = true }
	end,
}
specEnv.typeof = function(value)
	return type(value) == "table" and value._color and "Color3" or type(value)
end
local visualSpec = assert(loadfile("src/shared/Modules/MagicVisualSpec.luau", "t", specEnv))()
local assets = assert(loadfile("src/shared/Configuration/MagicVisualAssets.luau"))()
local function clone(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

assert(#assets.Groups >= 7 and #assets.Presets >= 5, "catalog should cover the modular presentation layers")
for _, preset in ipairs(assets.Presets) do
	local composed, reason = assets.apply(clone(visualSpec.Defaults), preset.Id)
	assert(composed, reason)
	assert(visualSpec.validate(composed), "preset " .. preset.Id .. " should produce valid visual settings")
	local customized = assets.set(composed, "ParticleStyle", "None")
	assert(customized and customized.ParticleStyle == "None", "individual components should remain replaceable")
	assert(customized.ImpactStyle == composed.ImpactStyle, "component replacement should preserve other layers")
end
local kept = clone(visualSpec.Defaults)
kept.CustomMarker = "preserved"
local applied = assert(assets.apply(kept, "bright-trail"))
assert(applied.CustomMarker == "preserved", "applying a starter should only replace its declared slots")
assert(not assets.apply(kept, "missing-preset"), "unknown starters should be rejected")
assert(not assets.set(kept, "ImpactStyle", "Damage"), "unsupported component values should be rejected")

print("Magic visual asset catalog checks passed")
