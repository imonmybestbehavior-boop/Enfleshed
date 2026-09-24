-- Run from the repository root with: lua tests/test_spell_definitions.lua
-- This loads the registered data only; Roblox gameplay still requires Studio.
local dataTable = setmetatable({
	freeze = function(value)
		return value
	end,
}, { __index = table })
local spells = assert(loadfile("src/shared/Configuration/Spells.luau", "t", {
	table = dataTable,
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
}))()

assert(spells.Fireball.Form == "Projectile" and spells.Fireball.Triggers.OnImpact[1].Behavior == "Explode")
assert(spells.BodyBurst.Form == "Wave" and #spells.BodyBurst.Wave.Payloads == 2)
assert(spells.StoneShot.Targeting == "MaterialTarget" and spells.StoneShot.Material.Material == "Earth")
for id, definition in pairs(spells) do
	assert(definition.SpellId == id and definition.Cost and definition.Casting and definition.Lifetime)
end
print("PASS: Fireball, Body Burst, and Stone Shot have valid V1 component data")
