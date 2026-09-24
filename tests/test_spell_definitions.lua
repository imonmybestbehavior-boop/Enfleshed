-- Run from the repository root with: lua tests/test_spell_definitions.lua
-- This loads the registered data only; Roblox gameplay still requires Studio.
local dataTable = setmetatable({
	freeze = function(value)
		return value
	end,
}, { __index = table })
local sandbox = assert(loadfile("src/shared/Configuration/Sandbox.luau", "t", {
	math = math,
	Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	},
}))()
local spells = assert(loadfile("src/shared/Configuration/Spells.luau", "t", {
	table = dataTable,
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
	script = { Parent = { Sandbox = "sandbox" } },
	require = function(reference)
		assert(reference == "sandbox")
		return sandbox
	end,
}))()
local validator = assert(loadfile("src/shared/Modules/SpellDefinitionValidator.luau", "t", {
	typeof = type,
	table = table,
	ipairs = ipairs,
}))()

assert(spells.Fireball.Form == "Projectile" and spells.Fireball.Triggers.OnImpact[2].Behavior == "Explode")
assert(
	not spells.Fireball.Projectile.DirectDamage and spells.Fireball.Triggers.OnImpact[1].Payloads[1].Kind == "Damage"
)
assert(spells.BodyBurst.Form == "Wave" and #spells.BodyBurst.Wave.Payloads == 2)
assert(spells.StoneShot.Targeting == "MaterialTarget" and spells.StoneShot.Material.Material == "Earth")
assert(not spells.StoneShot.Projectile.DirectDamage and spells.StoneShot.Triggers.OnImpact[1].Payloads[1].Amount == 26)
assert(
	spells.RecruitMagicBolt.Form == "Projectile"
		and spells.RecruitMagicBolt.Triggers.OnImpact[1].Payloads[1].Amount == 18
)
assert(spells.RecruitMagicBolt.Casting.Cooldown >= 0.55 and spells.RecruitMagicBolt.Casting.Cooldown <= 0.65)
assert(spells.RecruitMagicDischarge.Form == "Wave" and spells.RecruitMagicDischarge.Wave.Dot == -1)
assert(spells.LightningLance.Form == "Beam" and spells.LightningLance.Triggers.OnCast[1].Kind == "Damage")
assert(spells.BurningGround.Form == "Field" and spells.BurningGround.Triggers.OnInterval[1].Kind == "Damage")
assert(spells.BodyReinforcement.Form == "SelfEnhancement" and spells.BodyReinforcement.Targeting == "Self")
assert(spells.StoneRaise.Form == "Manipulation" and spells.StoneRaise.Triggers.OnCast[1].Operation == "Raise")
for id, definition in pairs(spells) do
	assert(definition.SpellId == id and definition.Cost and definition.Casting and definition.Lifetime)
	assert(validator.validate(definition))
end
print("PASS: V1 and V2 registered spell data is valid")
