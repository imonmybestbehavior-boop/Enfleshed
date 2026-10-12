local spec = assert(loadfile("src/shared/Modules/MagicPoseSpec.luau"))()
local env = setmetatable({ script = { Parent = { Parent = { Modules = { MagicPoseSpec = "pose" } } } } }, {
	__index = _G,
})
env.require = function(name)
	assert(name == "pose")
	return spec
end
local presentation = assert(loadfile("src/shared/Configuration/MagicPresentation.luau", "t", env))()

assert(spec.isKnown("Auto"))
assert(spec.isKnown("WardCast"))
assert(not spec.isKnown("UnvalidatedPose"))
for _, profile in ipairs(spec.Profiles) do
	if profile ~= "Auto" then
		assert(presentation.Timing[profile], profile .. " should have cast timing")
	end
end

for _, profile in ipairs(spec.Profiles) do
	if profile ~= "Auto" then
		for _, phase in ipairs({ false, true, "Sustain" }) do
			for _, role in ipairs({ "Torso", "Neck", "RightArm", "LeftArm", "RightElbow", "LowerBody" }) do
				local x, y, z = spec.angles(profile, role, phase)
				assert(type(x) == "number" and type(y) == "number" and type(z) == "number")
			end
		end
	end
end

local overheadX = spec.angles("OverheadCast", "RightArm", false)
local groundX = spec.angles("GroundCast", "RightArm", false)
assert(overheadX > groundX, "OverheadCast should use a distinct raised gesture")
local beamGatherX = spec.angles("BeamCast", "RightArm", false)
local beamSustainX = spec.angles("BeamCast", "RightArm", "Sustain")
assert(beamGatherX ~= beamSustainX, "held casts should use a distinct sustain pose")

print("Magic pose profiles: allowlist and gather/release/sustain joint poses passed")
