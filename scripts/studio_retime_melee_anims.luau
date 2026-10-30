-- Builds starter clips for the Greatsword, Dagger and Spear from the Sword clips
-- (ServerStorage.RBX_ANIMSAVES.MeleeAnimDummy_Sword), retimed piecewise so contact,
-- end of active and settle land on each archetype's MeleeProfiles Startup / Active /
-- Recovery frames. The tail after Settle scales with recovery (6-14 frames).
-- Block, parry and dash clips are copied unchanged. Requires the per-archetype
-- dummies (MeleeAnimDummy_<Archetype>) and RBX_ANIMSAVES holders to exist.
--
-- Pose keys keep their exact remapped time, snapped to whole frames when that keeps
-- them distinct and ordered; markers are re-placed at their own remapped frame.
local MP = require(game.ReplicatedStorage.Shared.Configuration.MeleeProfiles).Profiles
local saves = game.ServerStorage.RBX_ANIMSAVES
local swordSaves = saves.MeleeAnimDummy_Sword
-- Sword phase boundaries in frames: contact, end of active, settle, clip end.
local SWORD = { L1 = { 3, 8, 15, 23 }, L2 = { 4, 9, 16, 24 }, L3 = { 5, 11, 22, 32 }, Heavy = { 13, 20, 39, 50 } }
-- Which Sword clip each archetype's chain step is built from.
local MAP = {
	Greatsword = { L1 = "L1", L2 = "L3" },
	Dagger = { L1 = "L1", L2 = "L2", L3 = "L1", L4 = "L3" },
	Spear = { L1 = "L1", L2 = "L2", L3 = "L3" },
}
local SHARED = { "BlockRaise", "BlockHold", "BlockImpact", "BlockRelease", "ParryDeflect", "DashForward", "Backstep" }

local function frames(s) return math.max(1, math.floor(s * 60 + 0.5)) end

local function remapper(src, timing)
	local S, A, R = frames(timing.Startup), frames(timing.Active), frames(timing.Recovery)
	local tail = math.clamp(math.floor((src[4] - src[3]) * R / (src[3] - src[2]) + 0.5), 6, 14)
	local from = { 0, src[1], src[2], src[3], src[4] }
	local to = { 0, S, S + A, S + A + R, S + A + R + tail }
	return function(frame)
		for i = 1, 4 do
			if frame <= from[i + 1] then
				return to[i] + (frame - from[i]) / (from[i + 1] - from[i]) * (to[i + 1] - to[i])
			end
		end
		return to[5]
	end, to
end

local function retime(holder, arch, srcName, dstName, timing)
	local old = holder:FindFirstChild(arch .. "_" .. dstName)
	if old then old:Destroy() end
	local source = swordSaves["Sword_" .. srcName]
	local seq = source:Clone()
	seq.Name = arch .. "_" .. dstName
	local remap, to = remapper(SWORD[srcName], timing)

	local srcFrames = {}
	for _, kf in ipairs(source:GetChildren()) do
		for _, mk in ipairs(kf:GetChildren()) do
			if mk:IsA("KeyframeMarker") then srcFrames[mk.Name] = kf:GetAttribute("Frame") end
		end
	end
	local poseKfs, markers = {}, {}
	for _, kf in ipairs(seq:GetChildren()) do
		for _, mk in ipairs(kf:GetChildren()) do
			if mk:IsA("KeyframeMarker") then table.insert(markers, mk) end
		end
		if kf:FindFirstChildWhichIsA("Pose") then table.insert(poseKfs, kf) end
	end
	for _, mk in ipairs(markers) do mk.Parent = nil end
	for _, kf in ipairs(seq:GetChildren()) do
		if not kf:FindFirstChildWhichIsA("Pose") then kf:Destroy() end
	end
	table.sort(poseKfs, function(a, b) return a.Time < b.Time end)

	local times = {}
	for i, kf in ipairs(poseKfs) do times[i] = remap(kf:GetAttribute("Frame")) end
	for i, t in ipairs(times) do
		local r = math.floor(t + 0.5)
		local prev = if i > 1 then times[i - 1] else -1
		local nextT = times[i + 1]
		if r > prev and (not nextT or r < math.floor(nextT + 0.5) or r < nextT) then times[i] = r end
	end
	local byFrame = {}
	for i, kf in ipairs(poseKfs) do
		kf.Time = times[i] / 60
		kf:SetAttribute("Frame", times[i])
		byFrame[times[i]] = kf
	end
	for _, mk in ipairs(markers) do
		local fr = math.floor(remap(srcFrames[mk.Name]) + 0.5)
		local kf = byFrame[fr]
		if not kf then
			kf = Instance.new("Keyframe")
			kf.Time = fr / 60
			kf:SetAttribute("Frame", fr)
			kf.Parent = seq
			byFrame[fr] = kf
		end
		mk.Parent = kf
	end
	seq:SetAttribute("Timing", ("S %d / A %d / R %d f"):format(to[2], to[3] - to[2], to[4] - to[3]))
	seq:SetAttribute("SourceClip", source.Name)
	seq.Parent = holder
	return seq.Name
end

local built = {}
for arch, lights in pairs(MAP) do
	local holder = saves["MeleeAnimDummy_" .. arch]
	local profile = MP[arch]
	for i = 1, #profile.Lights do
		table.insert(built, retime(holder, arch, lights["L" .. i], "L" .. i, profile.Lights[i]))
	end
	table.insert(built, retime(holder, arch, "Heavy", "Heavy", profile.Heavy))
	for _, name in ipairs(SHARED) do
		local old = holder:FindFirstChild(arch .. "_" .. name)
		if old then old:Destroy() end
		local copy = swordSaves["Sword_" .. name]:Clone()
		copy.Name = arch .. "_" .. name
		copy.Parent = holder
	end
	task.wait()
end
return table.concat(built, ", ")
