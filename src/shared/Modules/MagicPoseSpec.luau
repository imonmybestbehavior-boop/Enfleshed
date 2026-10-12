-- Shared procedural cast poses. Angles use the body-space convention from MagicRig.
local Spec = {}

Spec.Profiles = {
	"Auto",
	"ProjectileCast",
	"BeamCast",
	"GroundCast",
	"SelfCast",
	"OverheadCast",
	"WardCast",
	"SweepCast",
}

local poses = {
	ProjectileCast = {
		Gather = {
			Torso = { -6, 0, 0 },
			Neck = { 3, 0, 0 },
			RightArm = { 38, 0, 10 },
			LeftArm = { 28, 0, -10 },
			LowerBody = { 42, 0, 0 },
		},
		Release = {
			Torso = { -8, -14, 0 },
			Neck = { 5, 0, 0 },
			RightArm = { 115, 0, 8 },
			LeftArm = { 35, 0, -12 },
			LowerBody = { 30, 0, 0 },
		},
		Sustain = {
			Torso = { -3, -2, 0 },
			Neck = { 2, 0, 0 },
			RightArm = { 64, 0, 8 },
			LeftArm = { 22, 0, -8 },
			LowerBody = { 38, 0, 0 },
		},
	},
	BeamCast = {
		Gather = {
			Torso = { -6, 0, 0 },
			Neck = { 3, 0, 0 },
			RightArm = { 58, 0, 10 },
			LeftArm = { 58, 0, -10 },
			LowerBody = { 42, 0, 0 },
		},
		Release = {
			Torso = { -8, 0, 0 },
			Neck = { 5, 0, 0 },
			RightArm = { 105, 0, 8 },
			LeftArm = { 105, 0, -12 },
			LowerBody = { 30, 0, 0 },
		},
		Sustain = {
			Torso = { -4, 0, 0 },
			Neck = { 2, 0, 0 },
			RightArm = { 72, 0, 8 },
			LeftArm = { 72, 0, -8 },
			LowerBody = { 36, 0, 0 },
		},
	},
	GroundCast = {
		Gather = {
			Torso = { -12, 0, 0 },
			Neck = { 8, 0, 0 },
			RightArm = { 18, 0, 10 },
			LeftArm = { 18, 0, -10 },
			LowerBody = { 58, 0, 0 },
		},
		Release = {
			Torso = { -30, 0, 0 },
			Neck = { 12, 0, 0 },
			RightArm = { -35, 0, 8 },
			LeftArm = { -25, 0, -12 },
			LowerBody = { 20, 0, 0 },
		},
		Sustain = {
			Torso = { -10, 0, 0 },
			Neck = { 6, 0, 0 },
			RightArm = { -6, 0, 5 },
			LeftArm = { 8, 0, -5 },
			LowerBody = { 46, 0, 0 },
		},
	},
	SelfCast = {
		Gather = {
			Torso = { -6, 4, 0 },
			Neck = { 3, 0, 0 },
			RightArm = { 52, 0, 10 },
			LeftArm = { 52, 0, -10 },
			LowerBody = { 42, 0, 0 },
		},
		Release = {
			Torso = { 5, 0, 0 },
			Neck = { 5, 0, 0 },
			RightArm = { 82, 0, 30 },
			LeftArm = { 82, 0, -30 },
			LowerBody = { 55, 0, 0 },
		},
		Sustain = {
			Torso = { -2, 2, 0 },
			Neck = { 1, 0, 0 },
			RightArm = { 44, 0, 18 },
			LeftArm = { 44, 0, -18 },
			LowerBody = { 34, 0, 0 },
		},
	},
	OverheadCast = {
		Gather = {
			Torso = { -14, 0, 0 },
			Neck = { -4, 0, 0 },
			RightArm = { 105, 0, 18 },
			LeftArm = { 105, 0, -18 },
			LowerBody = { 48, 0, 0 },
		},
		Release = {
			Torso = { 8, 0, 0 },
			Neck = { 8, 0, 0 },
			RightArm = { 145, 0, 8 },
			LeftArm = { 145, 0, -8 },
			LowerBody = { 38, 0, 0 },
		},
		Sustain = {
			Torso = { -8, 0, 0 },
			Neck = { -2, 0, 0 },
			RightArm = { 96, 0, 12 },
			LeftArm = { 96, 0, -12 },
			LowerBody = { 40, 0, 0 },
		},
	},
	WardCast = {
		Gather = {
			Torso = { -8, 0, 0 },
			Neck = { 2, 0, 0 },
			RightArm = { 30, 0, 16 },
			LeftArm = { 66, 0, -24 },
			LowerBody = { 35, 0, 0 },
		},
		Release = {
			Torso = { -4, 0, 0 },
			Neck = { 5, 0, 0 },
			RightArm = { 58, 0, 26 },
			LeftArm = { 108, 0, -32 },
			LowerBody = { 26, 0, 0 },
		},
		Sustain = {
			Torso = { -4, 0, 0 },
			Neck = { 2, 0, 0 },
			RightArm = { 38, 0, 14 },
			LeftArm = { 76, 0, -22 },
			LowerBody = { 34, 0, 0 },
		},
	},
	SweepCast = {
		Gather = {
			Torso = { -6, -12, 0 },
			Neck = { 2, 0, 0 },
			RightArm = { 48, 0, 34 },
			LeftArm = { 20, 0, -34 },
			LowerBody = { 44, 0, 0 },
		},
		Release = {
			Torso = { -12, 22, 0 },
			Neck = { 6, 0, 0 },
			RightArm = { 105, 0, -24 },
			LeftArm = { 72, 0, 24 },
			LowerBody = { 32, 0, 0 },
		},
		Sustain = {
			Torso = { -3, -7, 0 },
			Neck = { 1, 0, 0 },
			RightArm = { 52, 0, 20 },
			LeftArm = { 22, 0, -20 },
			LowerBody = { 38, 0, 0 },
		},
	},
}

function Spec.isKnown(profile)
	for _, candidate in ipairs(Spec.Profiles) do
		if candidate == profile then
			return true
		end
	end
	return false
end

function Spec.angles(profile, role, phase)
	local selected = poses[profile] or poses.ProjectileCast
	local pose
	if phase == true or phase == "Release" then
		pose = selected.Release
	elseif phase == "Sustain" then
		pose = selected.Sustain
	else
		pose = selected.Gather
	end
	local angle = pose[role] or pose.LowerBody
	return angle[1], angle[2], angle[3]
end

return Spec
