-- Procedural pose branches and scaling, with a small CFrame/Vector stand-in.
-- Engine matrices, replication and client visibility are tested in Studio.
local V = {}
local vm = {}
function V.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vm)
end
function vm.__mul(v, n)
	return V.new(v.X * n, v.Y * n, v.Z * n)
end
local C = {}
local cm = {}
function C.new(a, b, c)
	local p = if type(a) == "table" then a else V.new(a, b, c)
	return setmetatable({ Position = p, X = 0, Y = 0, Z = 0 }, cm)
end
function C.Angles(x, y, z)
	local f = C.new()
	f.X, f.Y, f.Z = x, y, z
	return f
end
function cm.__index(f, k)
	if k == "Rotation" then
		return C.Angles(f.X, f.Y, f.Z)
	end
end
function cm.__mul(a, b)
	local f = C.new(a.Position.X + b.Position.X, a.Position.Y + b.Position.Y, a.Position.Z + b.Position.Z)
	f.X, f.Y, f.Z = a.X + b.X, a.Y + b.Y, a.Z + b.Z
	return f
end
local env = setmetatable({ CFrame = C }, { __index = getfenv() })
local Animation = assert(loadfile("src/shared/Modules/EnemyAnimation.luau", "t", env))()
local joints = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local function sample(state, attack, step, motion, scale, now)
	local p = Animation.sample(
		{ State = state, Attack = attack or "", Step = step or 1, Start = 10, Finish = 11, Major = true },
		motion or {},
		now or 10.3,
		scale or 1
	)
	for _, name in joints do
		assert(p[name], state .. " is missing " .. name)
		for _, n in { p[name].X, p[name].Y, p[name].Z, p[name].Position.X, p[name].Position.Y, p[name].Position.Z } do
			assert(n == n and math.abs(n) < 100)
		end
	end
	return p
end
for _, state in { "Idle", "Chase", "Telegraph", "Attack", "Recover", "Flinch", "Vulnerable", "Dead" } do
	for _, attack in { "RushingStrike", "PredatoryLunge", "FrenziedChain", "MaulingCombination", "ReversalSwipe" } do
		for step = 1, 4 do
			sample(state, attack, step)
		end
	end
end
local idle = sample("Idle")
local standing = sample("Chase", "", 1, { Speed = 0, Phase = 1 })
assert(standing["Left Hip"].X == idle["Left Hip"].X, "blocked chase must not walk in place")
local a = sample("Chase", "", 1, { Speed = 18, Phase = 1 })
local b = sample("Chase", "", 1, { Speed = 18, Phase = 2 })
assert(a["Left Hip"].X ~= b["Left Hip"].X, "locomotion follows distance phase")
local jump = sample("Chase", "", 1, { Airborne = true, Rising = true })
local fall = sample("Chase", "", 1, { Airborne = true, Rising = false })
assert(jump["Left Hip"].X ~= fall["Left Hip"].X)
assert(sample("Idle", "", 1, { Landing = 1 }).RootJoint.Position.Y < 0)
local small = sample("Telegraph", "PredatoryLunge", 1, {}, 1)
local large = sample("Telegraph", "PredatoryLunge", 1, {}, 1.5)
assert(math.abs(large.RootJoint.Position.Y - small.RootJoint.Position.Y * 1.5) < 0.0001)
assert(large["Left Shoulder"].X == small["Left Shoulder"].X, "angles do not scale")
assert(sample("Recover", "", 1, {}, 1, 10).RootJoint.X ~= sample("Recover", "", 1, {}, 1, 11).RootJoint.X)
assert(sample("Dead", "", 1, {}, 1, 10).RootJoint.Z < sample("Dead", "", 1, {}, 1, 10.65).RootJoint.Z)
for _, path in
	{
		"src/client/Controllers/EnemyAnimationController.luau",
		"src/client/EnemyAnimation.client.luau",
		"src/server/Services/EnemyAnimationCorpse.luau",
		"src/server/Services/EnemyService.luau",
	}
do
	assert(loadfile(path))
end
print("PASS: enemy pose coverage, movement/air/landing/death transitions and scaled offsets")
