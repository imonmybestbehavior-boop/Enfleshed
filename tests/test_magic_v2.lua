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
local channeledBeam = copy(spells.LightningLance)
channeledBeam.Casting = copy(spells.LightningLance.Casting)
channeledBeam.Casting.Mode = "Channeled"
channeledBeam.Casting.ManaUpkeepPerSecond = 2
channeledBeam.Lifetime = { Mode = "FixedDuration", Duration = 5 }
channeledBeam.Triggers = { OnTick = { { Kind = "Damage", Amount = 4 } } }
local channelValid, channelReason = validator.validate(channeledBeam)
assert(channelValid, "A bounded mana-fed Beam channel should validate: " .. tostring(channelReason))
local channelWithoutDuration = copy(channeledBeam)
channelWithoutDuration.Lifetime = { Mode = "Instantaneous" }
assert(not validator.validate(channelWithoutDuration), "A channel must have a fixed maximum duration")
local channelWithoutUpkeep = copy(channeledBeam)
channelWithoutUpkeep.Casting = copy(channeledBeam.Casting)
channelWithoutUpkeep.Casting.ManaUpkeepPerSecond = nil
assert(not validator.validate(channelWithoutUpkeep), "A channel must define mana upkeep")
local holdBeam = copy(spells.LightningLance)
holdBeam.Casting = copy(spells.LightningLance.Casting)
holdBeam.Casting.Mode = "HoldAndRelease"
holdBeam.Casting.MinimumCharge = 0.2
holdBeam.Casting.MaximumCharge = 1.2
local holdBeamValid, holdBeamReason = validator.validate(holdBeam)
assert(holdBeamValid, "A HoldAndRelease Beam should pass registered-data validation: " .. tostring(holdBeamReason))
local commandBeam = copy(spells.LightningLance)
commandBeam.Casting = copy(spells.LightningLance.Casting)
commandBeam.Casting.Mode = "CommandCast"
local commandBeamValid, commandBeamReason = validator.validate(commandBeam)
assert(commandBeamValid, "A CommandCast Beam should pass registered-data validation: " .. tostring(commandBeamReason))
local commandManipulation = copy(spells.StoneRaise)
commandManipulation.Casting = copy(spells.StoneRaise.Casting)
commandManipulation.Casting.Mode = "CommandCast"
assert(not validator.validate(commandManipulation), "CommandCast must reject world Manipulation Forms")
local channeledProjectile = copy(channeledBeam)
channeledProjectile.Form = "Projectile"
channeledProjectile.Targeting = "AimDirection"
channeledProjectile.Geometry = "Sphere"
channeledProjectile.Motion = "Linear"
channeledProjectile.Projectile = { Speed = 70, Radius = 0.5 }
channeledProjectile.Visual = { Color = { R = 1, G = 1, B = 1 } }
channeledProjectile.Triggers = { OnImpact = { { Kind = "Damage", Amount = 4 } } }
local projectileChannelValid, projectileChannelReason = validator.validate(channeledProjectile)
assert(
	projectileChannelValid,
	"A bounded mana-fed Projectile channel should validate: " .. tostring(projectileChannelReason)
)
local channeledWave = copy(channeledBeam)
channeledWave.Form = "Wave"
channeledWave.Targeting = "Self"
channeledWave.Geometry = "Cone"
channeledWave.Motion = "Stationary"
channeledWave.Wave = { Range = 12, Dot = 0.3, Payloads = { { Kind = "Damage", Amount = 4 } } }
channeledWave.Triggers = {
	OnCast = { { Kind = "Damage", Amount = 4 } },
	OnTick = { { Kind = "Damage", Amount = 4 } },
}
local waveChannelValid, waveChannelReason = validator.validate(channeledWave)
assert(waveChannelValid, "A bounded mana-fed Wave channel should validate: " .. tostring(waveChannelReason))
local invalidField = copy(spells.BurningGround)
invalidField.Triggers = { OnInterval = { { Kind = "Damage", Amount = 0 } } }
assert(not validator.validate(invalidField), "Invalid interval payload must fail")
local intervalField = copy(spells.BurningGround)
intervalField.Triggers = { OnInterval = { { Kind = "Damage", Amount = 3 } } }
assert(validator.validate(intervalField), "OnInterval should normalize to the existing Field pulse runtime")
local growingField = copy(spells.BurningGround)
growingField.Field = copy(spells.BurningGround.Field)
growingField.Field.GrowthStartScale = 0.25
growingField.Field.GrowthEndScale = 1.5
growingField.Field.GrowthDuration = 3
assert(validator.validate(growingField), "A bounded expanding Field should validate")
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
invalidManipulation.Triggers = { OnCast = { { Kind = "Manipulation", Operation = "Teleport", Distance = 2 } } }
assert(not validator.validate(invalidManipulation), "Unsupported manipulation must fail")
print("PASS: V2 Beam/Wave channels, Field, SelfEnhancement, and Manipulation validation")
