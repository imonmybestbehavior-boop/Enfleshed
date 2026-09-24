-- Run from the repository root with: lua tests/test_magic_v2.lua
-- Data validation only: Roblox runtime execution remains a Studio test.
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

for _, id in ipairs({ "LightningLance", "BurningGround", "BodyReinforcement", "StoneRaise" }) do
	assert(validator.validate(spells[id]), id .. " must be executable V2 data")
end

local function copy(value)
	local result = {}
	for key, entry in pairs(value) do
		result[key] = entry
	end
	return result
end

local invalidBeam = copy(spells.LightningLance)
invalidBeam.Geometry = "Sphere"
assert(not validator.validate(invalidBeam), "Invalid beam geometry must fail")
local invalidField = copy(spells.BurningGround)
invalidField.Triggers = { OnInterval = { { Kind = "Damage", Amount = 0 } } }
assert(not validator.validate(invalidField), "Invalid interval payload must fail")
local invalidEnhancement = copy(spells.BodyReinforcement)
invalidEnhancement.Triggers = { OnCast = { { Kind = "Enhancement" } } }
assert(not validator.validate(invalidEnhancement), "Empty enhancement must fail")
assert(spells.BodyReinforcement.Lifetime.Mode == "UntilToggledOff")
assert(spells.BodyReinforcement.Triggers.OnCast[1].SpeedMultiplier == 3)
local invalidLifetime = copy(spells.BodyReinforcement)
invalidLifetime.Lifetime = { Mode = "Unsupported" }
assert(not validator.validate(invalidLifetime))
local speed = assert(loadfile("src/shared/Modules/MovementSpeed.luau"))()
local walk, sprint = sandbox.Movement.WalkSpeed, sandbox.Movement.SprintSpeed
assert(speed.calculate(walk, sprint, false, 0, 3) == 48)
assert(speed.calculate(walk, sprint, true, 0, 3) == 84)
assert(speed.calculate(walk, sprint, false, 0, 1) == 16)
assert(speed.calculate(walk, sprint, true, 0, 1) == 28)
local invalidManipulation = copy(spells.StoneRaise)
invalidManipulation.Triggers = { OnCast = { { Kind = "Manipulation", Operation = "Move", Distance = 2 } } }
assert(not validator.validate(invalidManipulation), "Unsupported manipulation must fail")
print("PASS: V2 Beam, Field, SelfEnhancement, and Manipulation validation")
