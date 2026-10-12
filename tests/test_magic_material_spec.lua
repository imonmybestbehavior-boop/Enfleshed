local spec = assert(loadfile("src/shared/Modules/MagicMaterialSpec.luau"))()
local matterForms = { "Projectile", "Beam", "Wave", "Field", "Aura" }

for _, form in ipairs(matterForms) do
	for _, material in ipairs({ "Earth", "Metal", "Wood" }) do
		assert(spec.supports("Matter", "Earth", form, "MaterialTarget", material), material .. " " .. form)
	end
	assert(spec.supports("Matter", "Water", form, "MaterialTarget", "Water"), "Water " .. form)
end
for _, material in ipairs({ "Earth", "Metal", "Wood", "Water" }) do
	local expression = "Earth"
	if material == "Water" then
		expression = "Water"
	end
	assert(
		not spec.supports("Matter", expression, "Construct", "MaterialTarget", material),
		"Construct placement should not require a material source"
	)
end
assert(#spec.options("Matter", "Earth", "Construct", "MaterialTarget") == 0)
assert(spec.supports("Matter", "Earth", "Manipulation", "MaterialTarget", "Earth"))
assert(spec.supports("Matter", "Earth", "Manipulation", "ObjectTarget", "Earth"))
for _, form in ipairs({ "Projectile", "Beam", "Wave" }) do
	for _, material in ipairs({ "Earth", "Metal", "Wood" }) do
		assert(spec.supports("Matter", "Earth", form, "ObjectTarget", material), material .. " ObjectTarget " .. form)
	end
end
assert(spec.supports("Matter", "Earth", "Manipulation", "MaterialTarget", "Metal"))
assert(spec.supports("Matter", "Earth", "Manipulation", "ObjectTarget", "Wood"))
assert(not spec.supports("Matter", "Water", "Manipulation", "MaterialTarget", "Water"))
assert(not spec.supports("Energy", "Fire", "Projectile", "MaterialTarget", "Fire"))
assert(not spec.supports("Matter", "Earth", "Beam", "MaterialTarget", "Water"))
assert(not spec.supports("Matter", "Earth", "SelfEnhancement", "MaterialTarget", "Earth"))
assert(table.concat(spec.options("Matter", "Earth", "Projectile", "MaterialTarget"), ",") == "Earth,Metal,Wood")
assert(table.concat(spec.options("Matter", "Water", "Field", "MaterialTarget"), ",") == "Water")
assert(spec.label("Metal") == "Metal")
print("Magic material spec: Matter source profiles and Form compatibility passed")
