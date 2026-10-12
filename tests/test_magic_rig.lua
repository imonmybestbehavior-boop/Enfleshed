local rig = assert(loadfile("src/shared/Modules/MagicRig.luau"))()
local function joint(class, body)
	local j = {
		Part0 = {},
		Part1 = { Name = body },
		C0 = "frame",
		Attachment0 = { CFrame = "frame" },
		Attachment1 = {
			Parent = { Name = body },
		},
	}
	function j:IsA(name)
		return name == class
	end
	return j
end
for _, class in ipairs({ "Motor6D", "AnimationConstraint" }) do
	for body, role in pairs({
		RightUpperArm = "RightArm",
		LeftUpperArm = "LeftArm",
		UpperTorso = "Torso",
		Torso = "Torso",
		Head = "Neck",
		["Right Arm"] = "RightArm",
		RightLowerArm = "RightElbow",
	}) do
		local entry = assert(rig.describe(joint(class, body)))
		assert(entry.Role == role and entry.Frame == "frame")
	end
	assert(not rig.describe(joint(class, "LowerTorso")), "Do not pose R15 root/legs")
end
assert(not rig.describe(joint("WeldConstraint", "RightUpperArm")))
local missing = joint("AnimationConstraint", "Head")
missing.Attachment0 = nil
assert(not rig.describe(missing))
assert(rig.strength(0) == 0 and rig.strength(1) == 0)
assert(rig.strength(0.3) == 1 and rig.strength(0.65) == 1, "Gesture needs a sustained readable hold")
assert(rig.strength(0.1) > 0 and rig.strength(0.9) > 0)
print("PASS: legacy/upgraded joint recognition, missing attachments, excluded roots and sustained gesture envelope")
