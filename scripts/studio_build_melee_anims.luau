-- Builds the starter melee KeyframeSequences for the Sword archetype into
-- ServerStorage.RBX_ANIMSAVES.<rig> so the Animation Editor can load them.
-- Source: "Enfleshed Melee Impact Package" keyframe tables (60 fps, degrees,
-- relative to rest). Run in Studio's Edit DataModel; re-running replaces them.
--
-- Easing: KeyframeSequences only support Linear/Constant/Cubic/Elastic/Bounce,
-- so the doc's Quad/Quart/Expo Out map to CubicV2 Out, Cubic/Quad In to
-- CubicV2 In and Sine InOut to CubicV2 InOut. The doc name is kept on each
-- Keyframe as the "DocEasing" attribute. Knees: this rig bends the knee with negative X,
-- so the doc's positive knee values are applied negated.
--
-- Rest grip: the weapon's Grip attachment carries a 60 degree wrist tilt (blade
-- angled down the forearm line), which is what the doc's arm angles assume.
local RIG_NAME = "MeleeAnimDummy_Sword"
local PREFIX = "Sword_"
local FPS = 60

local JOINT = {
	W = "UpperTorso", N = "Head",
	RS = "RightUpperArm", RE = "RightLowerArm",
	LS = "LeftUpperArm", LE = "LeftLowerArm",
	RH = "RightUpperLeg", LH = "LeftUpperLeg",
	RK = "RightLowerLeg", LK = "LeftLowerLeg",
	LT = "LowerTorso",
	H = "Handle", -- WeaponGrip Motor6D (RightHand -> weapon Handle): wrist/grip correction.
}
local PARENT = {
	LowerTorso = "HumanoidRootPart", UpperTorso = "LowerTorso", Head = "UpperTorso",
	RightUpperArm = "UpperTorso", RightLowerArm = "RightUpperArm",
	LeftUpperArm = "UpperTorso", LeftLowerArm = "LeftUpperArm",
	RightUpperLeg = "LowerTorso", RightLowerLeg = "RightUpperLeg",
	LeftUpperLeg = "LowerTorso", LeftLowerLeg = "LeftUpperLeg",
	RightHand = "RightLowerArm", Handle = "RightHand",
}
local LEGS = { RH = true, LH = true, RK = true, LK = true }

local EASE = {
	Linear = { Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In },
	QuadOut = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out },
	QuartOut = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out },
	ExpoOut = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.Out },
	CubicIn = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.In },
	QuadIn = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.In },
	SineInOut = { Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection.InOut },
}

-- r = rotation in degrees {x, y, z}; LTp = LowerTorso position, LTr = LowerTorso rotation.
local function r(x, y, z) return { x or 0, y or 0, z or 0 } end

local GUARD = {
	W = r(0, -10), RS = r(30, 0, 10), RE = r(45), LS = r(20, 0, -10), LE = r(10),
	N = r(0, 10), RH = r(-8), LH = r(8), LTp = r(0, -0.1),
}
local RAISED = {
	W = r(5, 15), RS = r(95, 0, -35), RE = r(80), LS = r(70, 0, 30), LE = r(70),
	N = r(-5), LTp = r(0, -0.22),
	-- The doc's arm pose leaves the blade pointing back; this grip key lays it flat across the body.
	H = r(-93.7, 14.8, 58.2),
}

local function merge(...)
	local out = {}
	for _, t in ipairs({ ... }) do
		for k, v in pairs(t) do out[k] = v end
	end
	return out
end

-- Each key: { f, ease, set = overrides, reset = start from GUARD with every other joint at rest }.
-- Joints not mentioned keep the previous key's value (the doc's "Hold" / "Same").
local CLIPS = {
	{
		name = "L1", length = 23, priority = Enum.AnimationPriority.Action,
		markers = { TrailOn = 1, Hit = 3, TrailOff = 8, Settle = 15 },
		keys = {
			{ 0, "QuadOut", reset = true },
			{ 2, "CubicIn", set = { W = r(0, -35), RS = r(75, 0, 60), RE = r(70), N = r(0, 25), LTr = r(0, -10), RH = r(-10) } },
			{ 3, "Linear", set = { W = r(0, -15), RS = r(85, 0, 40), RE = r(30), N = r(0, 15) } },
			{ 6, "Linear", set = { W = r(0, 20), RS = r(90, 0, 0), RE = r(5), N = r(0, -5), RH = r(-20), LH = r(15) } },
			{ 8, "QuartOut", set = { W = r(0, 40), RS = r(85, 0, -35), RE = r(10), N = r(0, -15), LTr = r(0, 10) } },
			{ 12, "SineInOut", set = { W = r(0, 48), RS = r(70, 0, -55), RE = r(25), N = r(0, -10), LTr = r(0, 12) } },
			{ 15, "SineInOut", set = { W = r(0, 30), RS = r(55, 0, -35), RE = r(40), N = r(0, -5) } },
			{ 23, "Linear", reset = true },
		},
	},
	{
		name = "L2", length = 24, priority = Enum.AnimationPriority.Action,
		markers = { TrailOn = 2, Hit = 4, TrailOff = 9, Settle = 16 },
		keys = {
			{ 0, "QuadOut", reset = true, set = { W = r(0, 30), RS = r(55, 0, -35), RE = r(40), N = r(0, -5), RH = r(-20), LH = r(15), LTr = r(0, 12) } },
			{ 3, "CubicIn", set = { W = r(0, 45), RS = r(60, 0, -70), RE = r(80), N = r(0, -20), LTr = r(0, 12) } },
			{ 4, "Linear", set = { W = r(0, 30), RS = r(65, 0, -45), RE = r(40), N = r(0, -15) } },
			{ 7, "Linear", set = { W = r(0, 0), RS = r(95, 0, 10), RE = r(10), N = r(0, 0), RH = r(-15) } },
			{ 9, "QuartOut", set = { W = r(0, -30), RS = r(120, 0, 45), RE = r(15), N = r(0, 10), LTr = r(0, -10) } },
			{ 13, "SineInOut", set = { W = r(0, -40), RS = r(130, 0, 55), RE = r(25), N = r(0, 12), LTr = r(0, -12) } },
			{ 16, "SineInOut", set = { W = r(0, -25), RS = r(105, 0, 45), RE = r(45), N = r(0, 8) } },
			{ 24, "Linear", reset = true },
		},
	},
	{
		name = "L3", length = 32, priority = Enum.AnimationPriority.Action,
		markers = { TrailOn = 3, Hit = 5, TrailOff = 11, Settle = 22 },
		keys = {
			{ 0, "QuadOut", reset = true, set = { W = r(0, -25), RS = r(105, 0, 45), RE = r(45), N = r(0, 8), RH = r(-15), LH = r(15), LTr = r(0, -12) } },
			{ 4, "CubicIn", set = { W = r(-15, -20), RS = r(160, 0, 30), RE = r(70), N = r(10), LTp = r(0, 0.1), RH = r(10) } },
			{ 5, "Linear", set = { W = r(0, -10), RS = r(140, 0, 20), RE = r(30), N = r(5) } },
			{ 8, "Linear", set = { W = r(20, 10), RS = r(70, 0, -10), RE = r(5), N = r(-10), LTp = r(0, -0.35), RH = r(-35), RK = r(-30), LH = r(25) } },
			{ 11, "QuartOut", set = { W = r(30, 20), RS = r(20, 0, -30), RE = r(10), N = r(-15), LTp = r(0, -0.45) } },
			{ 16, "SineInOut", set = { W = r(35, 25), RS = r(5, 0, -40), RE = r(20), N = r(-12), LTp = r(0, -0.5) } },
			{ 22, "SineInOut", set = { W = r(15, 10), RS = r(25, 0, -20), RE = r(40), N = r(-5), LTp = r(0, -0.3) } },
			{ 32, "Linear", reset = true },
		},
	},
	{
		name = "Heavy", length = 50, priority = Enum.AnimationPriority.Action,
		markers = { Whoosh = 8, TrailOn = 10, Hit = 13, Ground = 20, TrailOff = 20, Settle = 39 },
		keys = {
			{ 0, "QuadOut", reset = true },
			{ 4, "SineInOut", set = { W = r(-5, -25), RS = r(60, 0, 40), RE = r(80), LS = r(40, 0, 20), N = r(0, 20), LTp = r(0, -0.25), RH = r(15) } },
			{ 11, "QuadOut", set = { W = r(-20, -30), RS = r(175, 0, 20), RE = r(60), LS = r(165, 0, -20), N = r(15, 15), LTp = r(0, 0.05), RH = r(20), LH = r(-10) } },
			{ 12, "CubicIn", set = { W = r(-22, -30), RS = r(178, 0, 20), RE = r(62), LS = r(168, 0, -20) } },
			{ 13, "Linear", set = { W = r(5, -10), RS = r(150, 0, 10), RE = r(25), LS = r(140), N = r(5), LTp = r(0, -0.1), RH = r(-20) } },
			{ 16, "Linear", set = { W = r(30, 0), RS = r(80, 0, 0), RE = r(5), LS = r(75), N = r(-10), LTp = r(0, -0.5, -0.3), RH = r(-45), RK = r(-45), LH = r(30), LK = r(-20) } },
			{ 20, "QuartOut", set = { W = r(45, 5), RS = r(25, 0, -5), RE = r(10), LS = r(20), N = r(-20), LTp = r(0, -0.7, -0.3) } },
			{ 26, "SineInOut", set = { W = r(52, 5), RS = r(15, 0, -5), RE = r(15), LS = r(12), N = r(-22), LTp = r(0, -0.75, -0.3) } },
			{ 39, "SineInOut", set = { W = r(25, 10), RS = r(35, 0, -10), RE = r(40), LS = r(25, 0, -15), N = r(-5), LTp = r(0, -0.35, -0.3), RH = r(-20) } },
			{ 50, "Linear", reset = true },
		},
	},
	{
		name = "BlockRaise", length = 6, priority = Enum.AnimationPriority.Action, upperOnly = true,
		keys = {
			{ 0, "QuartOut", reset = true },
			{ 4, "SineInOut", set = { W = r(7, 18), RS = r(98, 0, -38), RE = r(82), LS = r(72, 0, 32), LE = r(72), N = r(-7), LTp = r(0, -0.25), H = r(-97.8, 10.3, 49.2) } },
			{ 6, "Linear", set = RAISED },
		},
	},
	{
		name = "BlockHold", length = 60, priority = Enum.AnimationPriority.Action, upperOnly = true, looped = true,
		keys = {
			{ 0, "SineInOut", reset = true, set = merge(RAISED, { W = r(3, 15), RS = r(93.5, 0, -35) }) },
			{ 30, "SineInOut", set = { W = r(7, 15), RS = r(96.5, 0, -35) } },
			{ 60, "SineInOut", set = { W = r(3, 15), RS = r(93.5, 0, -35) } },
		},
	},
	{
		name = "BlockImpact", length = 10, priority = Enum.AnimationPriority.Action2, upperOnly = true,
		keys = {
			{ 0, "ExpoOut", reset = true, set = RAISED },
			{ 2, "SineInOut", set = { W = r(-8, 12), RS = r(80, 0, -32), RE = r(95), LS = r(58, 0, 28), LE = r(85), N = r(5), LTp = r(0, -0.22, 0.15), H = r(-88.2, 25, 75.7) } },
			{ 10, "Linear", set = RAISED },
		},
	},
	{
		name = "BlockRelease", length = 5, priority = Enum.AnimationPriority.Action, upperOnly = true,
		keys = {
			{ 0, "QuadIn", reset = true, set = RAISED },
			{ 5, "Linear", reset = true },
		},
	},
	{
		name = "ParryDeflect", length = 14, priority = Enum.AnimationPriority.Action2, upperOnly = true,
		markers = { Hit = 3 }, -- Not in the doc's table: marks the frame the 7 f parry freeze lands on.
		keys = {
			{ 0, "ExpoOut", reset = true, set = RAISED },
			{ 3, "Linear", set = { W = r(0, -20), RS = r(110, 0, 15), RE = r(40), LS = r(45, 0, 40), N = r(0, -10), LTp = r(0, -0.18), H = r(-31.2, 30.7, 31.3) } },
			{ 6, "SineInOut", set = { W = r(0, -22), RS = r(112, 0, 18), RE = r(38), LS = r(44, 0, 42), N = r(0, -10), H = r(-29.4, 33.6, 33.3) } },
			{ 14, "Linear", set = RAISED },
		},
	},
	{
		name = "DashForward", length = 20, priority = Enum.AnimationPriority.Action,
		markers = { Ground = 11 }, -- Not in the doc's table: brake foot plant (brake dust and skid at f11).
		keys = {
			{ 0, "ExpoOut", reset = true },
			{ 2, "Linear", set = { LTp = r(0, -0.3), LTr = r(-20), W = r(15), RH = r(-40), LH = r(30), RS = r(-30), LS = r(-30), N = r(15) } },
			{ 9, "QuartOut", set = { LTp = r(0, -0.3), LTr = r(-22), W = r(16), RH = r(-42), LH = r(32), RS = r(-32), LS = r(-32), N = r(16) } },
			{ 11, "SineInOut", set = { LTp = r(0, -0.4), LTr = r(10), W = r(-5), RH = r(20), LH = r(-35), RS = r(20), LS = r(20), N = r(-5) } },
			{ 15, "SineInOut", set = { LTp = r(0, -0.45), LTr = r(14), W = r(-7), RS = r(24), LS = r(24), N = r(-7) } },
			{ 20, "Linear", reset = true },
		},
	},
	{
		-- Not in the doc: authored as the dash's mirror (lean back, guard held up, rear foot plants).
		name = "Backstep", length = 20, priority = Enum.AnimationPriority.Action,
		markers = { Ground = 11 },
		keys = {
			{ 0, "ExpoOut", reset = true },
			{ 2, "Linear", set = { LTp = r(0, -0.3), LTr = r(12), W = r(-8, -10), RH = r(-35), LH = r(30), RS = r(45, 0, 10), LS = r(30, 0, -10), N = r(-6, 10) } },
			{ 9, "QuartOut", set = { LTp = r(0, -0.3), LTr = r(13), W = r(-9, -10), RH = r(-37), LH = r(32), RS = r(46, 0, 10), LS = r(31, 0, -10), N = r(-7, 10) } },
			{ 11, "SineInOut", set = { LTp = r(0, -0.42), LTr = r(-8), W = r(6, -10), RH = r(-25), LH = r(25), RK = r(-25), RS = r(35, 0, 10), LS = r(25, 0, -10), N = r(4, 10) } },
			{ 15, "SineInOut", set = { LTp = r(0, -0.46), LTr = r(-10), W = r(8, -10), RS = r(33, 0, 10), N = r(5, 10) } },
			{ 20, "Linear", reset = true },
		},
	},
}

-- WeaponGrip keys for the attacks, solved so the blade follows the doc's arcs
-- (horizontal forehand, rising backhand, overhead chop, floor slam). Frames
-- not listed keep the rest grip.
local HANDLE = {
	L1 = { [2] = r(-82.3, -2.1, -6.1), [3] = r(-49.3, 12.4, 17.4), [6] = r(-35.2, -7.1, -7.8), [8] = r(-36.3, -22.4, -25), [12] = r(-33, -19.3, -20.4), [15] = r(-2.4, -9.9, -6) },
	L2 = { [0] = r(-2.4, -9.9, -6), [3] = r(-94.5, -8.7, -36.9), [4] = r(-47.1, -25.7, -34.3), [7] = r(-39.2, -1.3, -1.6), [9] = r(-53.6, 22.5, 33.8), [13] = r(-62, 19.8, 35), [16] = r(-38.6, 19.2, 22.3) },
	L3 = { [0] = r(-38.6, 19.2, 22.3), [4] = r(-40.2, -19.7, -23.5), [5] = r(-38.7, 13.7, 16), [8] = r(-45.5, -0.7, -0.9), [11] = r(-44.3, -5.5, -7.1), [16] = r(-50.8, -9.9, -14.4), [22] = r(-39, -1.5, -1.7) },
	Heavy = { [4] = r(-24.6, -2.3, -2.1), [11] = r(-24.7, -16.7, -15.3), [12] = r(-24.5, -18, -16.4), [13] = r(-47.2, 8.9, 12.1), [16] = r(-72.5, 0, 0), [20] = r(-57, -3.3, -5.3), [26] = r(-63, -2.5, -4.6), [39] = r(-51.3, -11, -16) },
}
for _, clip in ipairs(CLIPS) do
	local handle = HANDLE[clip.name]
	if handle then
		for _, key in ipairs(clip.keys) do
			key.set = merge(key.set or {}, { H = handle[key[1]] or r() })
		end
	end
end

local function rad(v) return CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) end

local function buildClip(clip)
	-- Resolve each key to a full state with carry-forward.
	local states = {}
	local used = {}
	local state = {}
	for i, key in ipairs(clip.keys) do
		if key.reset then
			state = table.clone(GUARD)
			-- Joints keyed earlier in the clip but absent from the guard return to rest.
			for k in pairs(used) do
				if state[k] == nil then state[k] = r() end
			end
		else
			state = table.clone(state)
		end
		for k, v in pairs(key.set or {}) do state[k] = v end
		for k in pairs(state) do used[k] = true end
		states[i] = state
	end
	-- Back-fill joints first keyed later (rest value at earlier keys).
	for _, s in ipairs(states) do
		for k in pairs(used) do
			if s[k] == nil then s[k] = r() end
		end
	end

	local seq = Instance.new("KeyframeSequence")
	seq.Name = PREFIX .. clip.name
	seq.Priority = clip.priority
	seq.Loop = clip.looped == true
	local byFrame = {}
	for i, key in ipairs(clip.keys) do
		local f, easeName = key[1], key[2]
		local s = states[i]
		local kf = Instance.new("Keyframe")
		kf.Time = f / FPS
		kf:SetAttribute("Frame", f)
		kf:SetAttribute("DocEasing", easeName)
		local ease = EASE[easeName]
		local poses = {}
		local function pose(partName: string): Pose
			if poses[partName] then return poses[partName] end
			local p = Instance.new("Pose")
			p.Name = partName
			p.Weight = 0
			p.EasingStyle = ease[1]
			p.EasingDirection = ease[2]
			local parentName = PARENT[partName]
			p.Parent = if parentName then pose(parentName) else kf
			poses[partName] = p
			return p
		end
		for j, partName in pairs(JOINT) do
			if j == "LT" then
				if s.LTp or s.LTr then
					local p = pose(partName)
					p.CFrame = CFrame.new(table.unpack(s.LTp or r())) * rad(s.LTr or r())
					p.Weight = 1
				end
			elseif s[j] and not (clip.upperOnly and LEGS[j]) then
				local p = pose(partName)
				p.CFrame = rad(s[j])
				p.Weight = 1
			end
		end
		kf.Parent = seq
		byFrame[f] = kf
	end
	for markerName, f in pairs(clip.markers or {}) do
		local kf = byFrame[f]
		if not kf then
			kf = Instance.new("Keyframe")
			kf.Time = f / FPS
			kf:SetAttribute("Frame", f)
			kf.Parent = seq
			byFrame[f] = kf
		end
		local m = Instance.new("KeyframeMarker")
		m.Name = markerName
		m.Value = ""
		m.Parent = kf
	end
	return seq
end

local ServerStorage = game:GetService("ServerStorage")
local saves = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
if not saves then
	saves = Instance.new("Model")
	saves.Name = "RBX_ANIMSAVES"
	saves.Parent = ServerStorage
end
local rig = workspace:FindFirstChild(RIG_NAME)
local holder = saves:FindFirstChild(RIG_NAME)
if not holder then
	holder = Instance.new("ObjectValue")
	holder.Name = RIG_NAME
	holder.Parent = saves
end
holder.Value = rig

local built = {}
for _, clip in ipairs(CLIPS) do
	local old = holder:FindFirstChild(PREFIX .. clip.name)
	if old then old:Destroy() end
	local seq = buildClip(clip)
	seq.Parent = holder
	table.insert(built, ("%s (%d keys)"):format(seq.Name, #seq:GetChildren()))
end
return table.concat(built, ", ")
