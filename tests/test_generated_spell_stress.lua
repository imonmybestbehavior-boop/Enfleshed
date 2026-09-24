-- Run from the repository root with: lua tests/test_generated_spell_stress.lua
-- Exercises trusted generation and structural validation without Roblox execution.
local function vector(x, y, z)
	return { X = x, Y = y, Z = z }
end
local sandbox =
	assert(loadfile("src/shared/Configuration/Sandbox.luau", "t", { Vector3 = { new = vector }, math = math }))()
local validator = assert(loadfile("src/shared/Modules/SpellDefinitionValidator.luau", "t", {
	typeof = type,
	table = table,
	ipairs = ipairs,
}))()
local generated = assert(loadfile("src/shared/Configuration/GeneratedSpellStress.luau", "t", {
	math = math,
	table = table,
	string = string,
	assert = assert,
	tostring = tostring,
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
	script = { Parent = { Sandbox = "sandbox", Parent = { Modules = { SpellDefinitionValidator = "validator" } } } },
	require = function(reference)
		if reference == "sandbox" then
			return sandbox
		end
		if reference == "validator" then
			return validator
		end
		error("Unexpected module reference")
	end,
}))()

local first =
	generated.Generate(sandbox.DevelopmentSpellStress.SpellTestSeed, sandbox.DevelopmentSpellStress.GeneratedSpellCount)
local second =
	generated.Generate(sandbox.DevelopmentSpellStress.SpellTestSeed, sandbox.DevelopmentSpellStress.GeneratedSpellCount)
assert(#first.Order == 10 and #second.Order == 10)
for index, id in ipairs(first.Order) do
	local definition = first.Definitions[id]
	local valid, reason = validator.validate(definition)
	assert(valid, reason)
	assert(
		second.Order[index] == id and second.Descriptions[id] == first.Descriptions[id],
		"Generation must be deterministic"
	)
	local casting = definition.Casting
	local charge = ""
	if casting.Mode == "Charged" then
		charge = string.format(" | charge %.2f-%.2f", casting.MinimumCharge, casting.MaximumCharge)
	end
	local extras = ""
	if definition.Form == "Projectile" then
		for _, trigger in ipairs(definition.Triggers.OnImpact) do
			if trigger.Behavior == "Explode" then
				extras = extras .. string.format(" | explode %.0f", trigger.Radius)
			end
		end
	elseif #definition.Wave.Payloads == 2 then
		local force = definition.Wave.Payloads[2]
		extras = string.format(" | force %.0f up %.0f", force.Magnitude, force.Upward)
	end
	print(id .. " | " .. first.Descriptions[id] .. charge .. extras)
end
local invalid = {
	SpellId = "Invalid",
	Name = "Invalid",
	Source = { Principle = "Energy", Expression = "Fire" },
	Form = "Beam",
	Casting = { Mode = "Instant", Cooldown = 1 },
	Cost = { ManaDemand = 1, Strain = 1, Complexity = 1 },
}
assert(not validator.validate(invalid), "Unsupported definitions must fail safely")
local invalidPayload = {
	SpellId = "InvalidPayload",
	Name = "InvalidPayload",
	Source = { Principle = "Energy", Expression = "Fire" },
	Form = "Projectile",
	Targeting = "AimDirection",
	Geometry = "Sphere",
	Motion = "Linear",
	Casting = { Mode = "Instant", Cooldown = 1 },
	Lifetime = { Mode = "FixedDuration", Duration = 1 },
	Cost = { ManaDemand = 1, Strain = 1, Complexity = 1 },
	Projectile = { Speed = 1, Radius = 1 },
	Visual = {},
	Triggers = { OnImpact = { { Payloads = { { Kind = "Unsupported" } } } } },
}
assert(not validator.validate(invalidPayload), "Unsupported payloads must fail safely")
local invalidMaterial = {
	SpellId = "InvalidMaterial",
	Name = "InvalidMaterial",
	Source = { Principle = "Energy", Expression = "Fire" },
	Form = "Projectile",
	Targeting = "MaterialTarget",
	Geometry = "Sphere",
	Motion = "Linear",
	Casting = { Mode = "Instant", Cooldown = 1 },
	Lifetime = { Mode = "FixedDuration", Duration = 1 },
	Cost = { ManaDemand = 1, Strain = 1, Complexity = 1 },
	Projectile = { Speed = 1, Radius = 1 },
	Visual = {},
	Material = { Material = "Earth", Amount = 1, SearchRadius = 1 },
	Triggers = { OnImpact = {} },
}
assert(not validator.validate(invalidMaterial), "Incompatible material requirements must fail safely")
print("PASS: deterministic generated definitions and invalid-definition rejection")
