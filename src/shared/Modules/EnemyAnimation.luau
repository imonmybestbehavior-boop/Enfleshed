--!strict
-- Enemy-only procedural prototype. No combat authority or animation asset IDs.
local Animation = {}
function Animation.sample(packet: any, motion: any, now: number, scale: number): { [string]: CFrame }
	local state, attack, step = packet.State, packet.Attack, packet.Step or 1
	local desperate, majorFlinch = packet.Desperate == true, packet.Major == true
	local out: { [string]: CFrame } = {}
	local breath = math.sin(now * (if desperate then 6 else 3))
	out.RootJoint = CFrame.new(0, breath * 0.055, 0.12) * CFrame.Angles(-0.16, 0, 0)
	out.Neck = CFrame.Angles(0.18, breath * 0.1, -0.08)
	out["Left Shoulder"] = CFrame.Angles(0.15, 0, 0.28)
	out["Right Shoulder"] = CFrame.Angles(0.32, 0, -0.34)
	out["Left Hip"] = CFrame.new()
	out["Right Hip"] = CFrame.new()
	if state == "Chase" and (motion.Speed or 0) > 0.4 then
		local stride = math.sin(motion.Phase or 0) * 0.72
		out.RootJoint *= CFrame.Angles(-0.22, 0, 0)
		out["Left Shoulder"] = CFrame.Angles(stride + 0.35, 0, 0.35)
		out["Right Shoulder"] = CFrame.Angles(-stride - 0.6, 0, -0.52)
		out["Left Hip"] = CFrame.Angles(-stride, 0, 0)
		out["Right Hip"] = CFrame.Angles(stride, 0, 0)
	elseif state == "Telegraph" then
		if attack == "PredatoryLunge" then
			out.RootJoint = CFrame.new(0, -0.25, 0.45) * CFrame.Angles(0.52, 0, 0)
			out["Left Shoulder"] = CFrame.Angles(-1.4, 0, 0.6)
			out["Right Shoulder"] = CFrame.Angles(-1.6, 0, -0.7)
		elseif attack == "FrenziedChain" then
			out.RootJoint = CFrame.Angles(-0.38, 0, if step % 2 == 0 then -0.2 else 0.2)
			out["Left Shoulder"] = CFrame.Angles(-1.05, 0, 0.7)
			out["Right Shoulder"] = CFrame.Angles(-0.55, 0, -0.75)
		elseif attack == "MaulingCombination" then
			out.RootJoint = CFrame.Angles(-0.34, 0, if step == 3 then 0.25 else -0.16)
			out["Left Shoulder"] = CFrame.Angles(-0.75, 0, 0.55)
			out["Right Shoulder"] = CFrame.Angles(-1.1, 0, -0.55)
		else
			out.RootJoint = CFrame.Angles(-0.28, 0, 0)
			out["Left Shoulder"] = CFrame.Angles(-0.65, 0, 0.45)
			out["Right Shoulder"] = CFrame.Angles(-1.3, 0, -0.5)
		end
	elseif state == "Attack" then
		out.RootJoint = CFrame.new(0, 0, -0.25) * CFrame.Angles(-0.28, 0, 0)
		if attack == "FrenziedChain" then
			if step == 1 then
				out["Right Shoulder"] = CFrame.Angles(1.5, 0, -0.6)
			elseif step == 2 then
				out["Left Shoulder"] = CFrame.Angles(1.35, 0, 0.75)
			elseif step == 3 then
				out["Right Shoulder"] = CFrame.Angles(1.1, 0, 0.8)
			else
				out.RootJoint *= CFrame.Angles(-0.28, 0, 0.35)
				out["Left Shoulder"] = CFrame.Angles(1.5, 0, 1)
				out["Right Shoulder"] = CFrame.Angles(1.55, 0, -0.8)
			end
		elseif attack == "PredatoryLunge" then
			out.RootJoint = CFrame.new(0, 0.15, -0.5) * CFrame.Angles(-0.55, 0, 0)
			out["Left Shoulder"] = CFrame.Angles(1.2, 0, 0.6)
			out["Right Shoulder"] = CFrame.Angles(1.35, 0, -0.7)
		elseif attack == "MaulingCombination" then
			out["Left Shoulder"] = CFrame.Angles(if step == 2 then 0.55 else 1.15, 0, 0.8)
			out["Right Shoulder"] = CFrame.Angles(if step == 3 then 1.65 else 0.85, 0, -0.8)
		else
			out["Right Shoulder"] = CFrame.Angles(1.35, 0, -0.35)
			out["Left Shoulder"] = CFrame.Angles(0.75, 0, 0.42)
		end
	elseif state == "Vulnerable" then
		out.RootJoint = CFrame.new(0, -0.3, 0.38) * CFrame.Angles(0.48, 0, 0.35)
		out["Left Shoulder"] = CFrame.Angles(0.9, 0, 1.1)
		out["Right Shoulder"] = CFrame.Angles(0.75, 0, -1.15)
	elseif state == "Flinch" then
		out.RootJoint = CFrame.Angles(if majorFlinch then 0.45 else 0.16, 0, if majorFlinch then -0.45 else -0.16)
		out["Left Shoulder"] = CFrame.Angles(0.65, 0, 0.8)
		out["Right Shoulder"] = CFrame.Angles(0.65, 0, -0.8)
	elseif state == "Dead" then
		out.RootJoint = CFrame.new(0, -1.1, 0.55) * CFrame.Angles(1.25, 0, -0.5)
	end
	if state == "Idle" or state == "Chase" then
		if motion.Airborne then
			out.RootJoint = CFrame.Angles(if motion.Rising then -0.22 else 0.18, 0, 0)
			out["Left Shoulder"] = CFrame.Angles(-0.55, 0, 0.8)
			out["Right Shoulder"] = CFrame.Angles(-0.8, 0, -0.8)
			out["Left Hip"] = CFrame.Angles(if motion.Rising then -0.65 else 0.2, 0, 0)
			out["Right Hip"] = CFrame.Angles(if motion.Rising then 0.45 else -0.2, 0, 0)
		elseif (motion.Landing or 0) > 0 then
			out.RootJoint = CFrame.new(0, -0.28 * motion.Landing, 0) * CFrame.Angles(0.22 * motion.Landing, 0, 0)
		end
	elseif state == "Recover" then
		local remaining = math.clamp(
			((packet.Finish or now) - now) / math.max(0.001, (packet.Finish or now) - (packet.Start or now)),
			0,
			1
		)
		out.RootJoint = CFrame.Angles(-0.3 * remaining, 0, 0.1 * remaining)
		out["Left Shoulder"] = CFrame.Angles(0.6 * remaining, 0, 0.5)
		out["Right Shoulder"] = CFrame.Angles(1.0 * remaining, 0, -0.6)
	elseif state == "Dead" then
		local t = math.clamp((now - (packet.Start or now)) / 0.65, 0, 1)
		out.RootJoint = CFrame.new(0, -2 * t, 0) * CFrame.Angles(0.3 * t, 0, 1.45 * t)
		out["Left Hip"] = CFrame.Angles(-0.4 * t, 0, 0.3 * t)
		out["Right Hip"] = CFrame.Angles(0.3 * t, 0, -0.2 * t)
	end
	-- Translations, unlike angles, must follow Model:ScaleTo.
	for name, frame in out do
		out[name] = CFrame.new(frame.Position * scale) * frame.Rotation
	end
	return out
end
return Animation
