--!strict
-- Mesh placement and joint pivots from assets/enemies manifests.
return {
	Basic = {
		Parts = {
			["Torso"] = { Center = Vector3.new(-0.2627, 0.3128, 0.3773), Size = Vector3.new(4.113, 4.832, 3.032) },
			["Head"] = { Center = Vector3.new(0.0442, 2.7511, -0.0468), Size = Vector3.new(1.808, 2.153, 1.923) },
			["Left Arm"] = { Center = Vector3.new(-2.038, -0.0883, 0.0642), Size = Vector3.new(1.085, 4.112, 0.984) },
			["Right Arm"] = { Center = Vector3.new(2.2024, -0.297, 0.0566), Size = Vector3.new(1.924, 4.725, 2.149) },
			["Left Leg"] = { Center = Vector3.new(-0.71, -2.6294, -0.161), Size = Vector3.new(0.992, 3.634, 1.376) },
			["Right Leg"] = { Center = Vector3.new(0.7186, -2.5951, -0.2345), Size = Vector3.new(1.06, 3.64, 1.258) },
		},
		Pivots = {
			["Neck"] = Vector3.new(0, 2.1, -0.15),
			["Left Shoulder"] = Vector3.new(-1.85, 1.55, 0),
			["Right Shoulder"] = Vector3.new(1.85, 1.55, 0),
			["Left Hip"] = Vector3.new(-0.65, -1.2, 0),
			["Right Hip"] = Vector3.new(0.65, -1.2, 0),
		},
	},
	Swift = {
		Parts = {
			["Torso"] = { Center = Vector3.new(-0.0086, 0.2129, -0.1972), Size = Vector3.new(2.887, 3.776, 2.454) },
			["Head"] = { Center = Vector3.new(0.0386, 1.9975, -1.4631), Size = Vector3.new(0.94, 1.101, 1.72) },
			["Left Arm"] = { Center = Vector3.new(-1.3322, -1.0414, -0.9689), Size = Vector3.new(1.132, 4.83, 2.156) },
			["Right Arm"] = { Center = Vector3.new(1.3135, -1.033, -0.9689), Size = Vector3.new(1.158, 4.847, 2.156) },
			["Left Leg"] = { Center = Vector3.new(-0.6065, -2.6149, -0.1148), Size = Vector3.new(0.883, 3.662, 1.747) },
			["Right Leg"] = { Center = Vector3.new(0.5743, -2.5686, -0.1322), Size = Vector3.new(0.826, 3.677, 1.782) },
		},
		Pivots = {
			["Neck"] = Vector3.new(0, 1.8, -1),
			["Left Shoulder"] = Vector3.new(-1, 1.12, -0.45),
			["Right Shoulder"] = Vector3.new(1, 1.12, -0.45),
			["Left Hip"] = Vector3.new(-0.5, -1.1, 0),
			["Right Hip"] = Vector3.new(0.5, -1.1, 0),
		},
	},
	Brute = {
		Parts = {
			["Torso"] = { Center = Vector3.new(0.1289, 0.461, 0.1824), Size = Vector3.new(5.303, 4.897, 4.163) },
			["Head"] = { Center = Vector3.new(0.0025, 1.8245, -0.779), Size = Vector3.new(1.302, 1.205, 1.673) },
			["Left Arm"] = { Center = Vector3.new(-2.2436, -0.4359, -0.2796), Size = Vector3.new(2.081, 4.844, 1.85) },
			["Right Arm"] = { Center = Vector3.new(2.4334, -0.5263, -0.5551), Size = Vector3.new(2.589, 5.364, 2.536) },
			["Left Leg"] = { Center = Vector3.new(-0.9645, -2.5451, -0.2237), Size = Vector3.new(1.604, 4.038, 1.815) },
			["Right Leg"] = { Center = Vector3.new(0.9515, -2.557, -0.2157), Size = Vector3.new(1.554, 4.06, 1.831) },
		},
		Pivots = {
			["Neck"] = Vector3.new(0, 1.7, -0.5),
			["Left Shoulder"] = Vector3.new(-1.9, 1.4, 0),
			["Right Shoulder"] = Vector3.new(1.9, 1.4, 0),
			["Left Hip"] = Vector3.new(-0.85, -1.2, 0),
			["Right Hip"] = Vector3.new(0.85, -1.2, 0),
		},
	},
	Elite = {
		Parts = {
			["Torso"] = { Center = Vector3.new(0.2542, 1.2026, -0.018), Size = Vector3.new(5.036, 5.741, 2.814) },
			["Head"] = { Center = Vector3.new(0.0007, 2.9331, -0.1227), Size = Vector3.new(1.281, 2.204, 2.369) },
			["Left Arm"] = { Center = Vector3.new(-1.9987, -0.1043, -0.4341), Size = Vector3.new(1.326, 4.201, 1.681) },
			["Right Arm"] = { Center = Vector3.new(2.0253, -0.4401, -0.6012), Size = Vector3.new(1.44, 5.008, 2.821) },
			["Left Leg"] = { Center = Vector3.new(-0.6904, -2.5818, -0.2811), Size = Vector3.new(1.203, 3.781, 1.614) },
			["Right Leg"] = { Center = Vector3.new(0.6658, -2.5565, -0.2841), Size = Vector3.new(1.139, 3.8, 1.608) },
		},
		Pivots = {
			["Neck"] = Vector3.new(0, 2.1, -0.15),
			["Left Shoulder"] = Vector3.new(-1.85, 1.55, 0),
			["Right Shoulder"] = Vector3.new(1.85, 1.55, 0),
			["Left Hip"] = Vector3.new(-0.65, -1.2, 0),
			["Right Hip"] = Vector3.new(0.65, -1.2, 0),
		},
	},
}
