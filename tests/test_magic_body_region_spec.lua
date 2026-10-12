local Spec = assert(loadfile("src/shared/Modules/MagicBodyRegionSpec.luau"))()

local cases = {
	{ "Head", "Head" },
	{ "Torso", "Torso" },
	{ "UpperTorso", "Torso" },
	{ "LowerTorso", "Torso" },
	{ "HumanoidRootPart", "Torso" },
	{ "Left Arm", "Arm" },
	{ "RightUpperArm", "Arm" },
	{ "LeftHand", "Arm" },
	{ "Right Leg", "Leg" },
	{ "LeftLowerLeg", "Leg" },
	{ "RightFoot", "Leg" },
	{ "Tail", "Other" },
	{ nil, "Other" },
}

for _, case in ipairs(cases) do
	assert(Spec.classify(case[1]) == case[2], tostring(case[1]) .. " should map to " .. case[2])
end

local payload = { HeadMultiplier = 2.5, ArmMultiplier = 0, LegMultiplier = 0.75 }
local region, multiplier = Spec.multiplier(payload, "Head")
assert(region == "Head" and multiplier == 2.5)
region, multiplier = Spec.multiplier(payload, "LeftHand")
assert(region == "Arm" and multiplier == 0, "A zero multiplier should disable damage for that region")
region, multiplier = Spec.multiplier(payload, "RightFoot")
assert(region == "Leg" and multiplier == 0.75)
region, multiplier = Spec.multiplier(payload, "UpperTorso")
assert(region == "Torso" and multiplier == 1, "Omitted multipliers should preserve existing damage")
region, multiplier = Spec.multiplier({ TorsoMultiplier = 9 }, "Torso")
assert(region == "Torso" and multiplier == 1, "Out-of-range values should safely use the default")

print("PASS: body-region classification, optional scaling, and compatibility defaults")
