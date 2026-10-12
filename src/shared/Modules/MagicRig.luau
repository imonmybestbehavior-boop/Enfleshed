--!strict
-- Recognize both legacy and upgraded avatar joints; never modify rig attachments.
local Rig = {}
local bodies = {
	RightUpperArm = "RightArm",
	LeftUpperArm = "LeftArm",
	["Right Arm"] = "RightArm",
	["Left Arm"] = "LeftArm",
	RightLowerArm = "RightElbow",
	LeftLowerArm = "LeftElbow",
	UpperTorso = "Torso",
	Torso = "Torso",
	Head = "Neck",
}
function Rig.describe(joint)
	local modern = joint:IsA("AnimationConstraint")
	if not modern and not joint:IsA("Motor6D") then
		return nil
	end
	local part, frame
	if modern then
		if not joint.Attachment0 or not joint.Attachment1 then
			return nil
		end
		part = joint.Attachment1.Parent
		frame = joint.Attachment0.CFrame
	else
		if not joint.Part0 or not joint.Part1 then
			return nil
		end
		part = joint.Part1
		frame = joint.C0
	end
	local role = part and bodies[part.Name]
	if not role then
		return nil
	end
	return { Joint = joint, Frame = frame, Role = role }
end
function Rig.strength(t)
	if t < 0 or t >= 1 then
		return 0
	end
	local x = math.min(t / 0.22, 1) * math.min((1 - t) / 0.3, 1)
	return x * x * (3 - 2 * x)
end
return Rig
