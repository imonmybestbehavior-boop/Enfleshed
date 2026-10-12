local configuration = {
	MagicLab = {
		MaxArmorModifier = 100,
		MinMagicStrengthModifier = -75,
		MaxMagicStrengthModifier = 100,
	},
}
local environment = setmetatable({
	script = { Parent = { Parent = { Configuration = configuration } } },
}, { __index = _G })
environment.require = function(_)
	return configuration.MagicLab
end
local spec = assert(loadfile("src/shared/Modules/MagicAttributeSpec.luau", "t", environment))()
assert(spec.supports("MagicArmor"))
assert(spec.supports("MagicStrength"))
assert(not spec.supports("WalkSpeed"), "unregistered engine attributes must stay inaccessible")
assert(spec.clamp("MagicArmor", 130) == 100)
assert(spec.clamp("MagicArmor", -130) == -100)
assert(spec.clamp("MagicStrength", -130) == -75)
assert(spec.clamp("MagicStrength", 130) == 100)
assert(spec.clamp("MagicArmor", math.huge) == nil)
assert(spec.clamp("WalkSpeed", 3) == nil)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicStrength", Amount = -25 },
	{ Kind = "ModifyAttribute", Attribute = "MagicStrength", Amount = -80 },
}, "MagicStrength") == -75)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 45 },
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 70 },
	{ Kind = "Slow", Attribute = "MagicArmor", Amount = 50 },
}, "MagicArmor") == 100)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = -20 },
}, "MagicArmor") == -20)
assert(spec.aggregate({
	{ Kind = "ModifyAttribute", Attribute = "MagicArmor", Amount = 50, ExpiresAt = 4 },
}, "MagicArmor", 5) == 0, "expired modifiers must not contribute")
print("Magic attribute spec: allowlist, finite bounds and aggregate caps passed")
