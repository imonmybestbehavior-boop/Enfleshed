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
local principleSpec = assert(loadfile("src/shared/Modules/MagicPrincipleSpec.luau"))()
local validator = assert(loadfile("src/shared/Modules/SpellDefinitionValidator.luau", "t", {
	typeof = type,
	table = table,
	ipairs = ipairs,
	script = { Parent = { MagicPrincipleSpec = "principles" } },
	require = function(reference)
		assert(reference == "principles")
		return principleSpec
	end,
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
local matterWater = {}
for key, value in pairs(spells.Fireball) do
	matterWater[key] = value
end
matterWater.Source = { Principle = "Matter", Expression = "Water" }
assert(
	validator.validate(matterWater),
	"Water should be a valid represented Matter expression for generic Projectile spells"
)
local spaceSpell = {}
for key, value in pairs(spells.LightningLance) do
	spaceSpell[key] = value
end
spaceSpell.Source = { Principle = "Space", Expression = "SpatialFold" }
assert(validator.validate(spaceSpell), "Space/SpatialFold should be valid on its supported Beam Form")
local soulSpell = {}
for key, value in pairs(spells.LightningLance) do
	soulSpell[key] = value
end
soulSpell.Source = { Principle = "Soul", Expression = "Spirit" }
assert(validator.validate(soulSpell), "Soul/Spirit should be valid on its supported Beam Form")
local timeSpell = {}
for key, value in pairs(spells.LightningLance) do
	timeSpell[key] = value
end
timeSpell.Source = { Principle = "Time", Expression = "TemporalShift" }
assert(validator.validate(timeSpell), "Time/TemporalShift should be valid on its supported Beam Form")
local forceSpell = {}
for key, value in pairs(spells.Fireball) do
	forceSpell[key] = value
end
forceSpell.Source = { Principle = "Energy", Expression = "Force" }
assert(validator.validate(forceSpell), "Force should be a valid Energy expression on generic Forms")
local invalidCrossPrinciple = {}
for key, value in pairs(spells.Fireball) do
	invalidCrossPrinciple[key] = value
end
invalidCrossPrinciple.Source = { Principle = "Matter", Expression = "Fire" }
assert(not validator.validate(invalidCrossPrinciple), "Expressions cannot be assigned to a different Principle")
local unsupportedPrinciple = {}
for key, value in pairs(spells.Fireball) do
	unsupportedPrinciple[key] = value
end
unsupportedPrinciple.Source = { Principle = "Time", Expression = "" }
assert(
	not validator.validate(unsupportedPrinciple),
	"A Time spell with an unsupported expression must not silently execute"
)
print("PASS: V1 and V2 registered spell data is valid")
