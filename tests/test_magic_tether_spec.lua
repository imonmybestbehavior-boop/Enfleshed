-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicTetherSpec.luau"))()

local settings = { MaxLength = 30, BreakOnLineOfSight = true, Grace = 0.5, Pull = false, PullStart = 0.8 }

-- Length.
assert(Spec.length(50, nil, 60) == 50)
assert(Spec.length(50, 40, 60) == 40, "PvP cap")
assert(Spec.length(90, nil, 60) == 60, "hard limit")

-- Distance snap.
local state = Spec.newState()
assert(Spec.step(state, 20, true, 0.1, settings) == "Hold")
local result, reason = Spec.step(state, 31, true, 0.1, settings)
assert(result == "Snap" and reason == "Distance")

-- Line-of-sight grace: a short break holds, a long one snaps.
state = Spec.newState()
assert(Spec.step(state, 10, false, 0.3, settings) == "Hold", "blocked 0.3 s")
assert(Spec.step(state, 10, true, 0.1, settings) == "Hold", "seen again: grace resets")
assert(Spec.step(state, 10, false, 0.3, settings) == "Hold")
assert(Spec.step(state, 10, false, 0.15, settings) == "Hold", "0.45 s")
result, reason = Spec.step(state, 10, false, 0.1, settings)
assert(result == "Snap" and reason == "LineOfSight", "0.55 s blocked")
local noLos = table.clone(settings)
noLos.BreakOnLineOfSight = false
assert(Spec.step(Spec.newState(), 10, false, 5, noLos) == "Hold", "line of sight ignored when off")

-- Pull between 80% and 100%, still snaps beyond.
local pulling = table.clone(settings)
pulling.Pull = true
assert(Spec.step(Spec.newState(), 23, true, 0.1, pulling) == "Hold", "below 80%")
assert(Spec.step(Spec.newState(), 26, true, 0.1, pulling) == "Pull")
assert(Spec.step(Spec.newState(), 31, true, 0.1, pulling) == "Snap", "pull still snaps beyond MaxLength")
assert(Spec.pullSpeed(24, 30, 0.8, 12) == 0 and Spec.pullSpeed(30, 30, 0.8, 12) == 12)
assert(Spec.pullSpeed(27, 30, 0.8, 12) == 6)

-- Sharing.
assert(Spec.shareable(nil) and Spec.shareable({ Periodic = true }), "DoT ticks are shared")
assert(not Spec.shareable({ Shared = true }) and not Spec.shareable({ Redirected = true }), "never shared again")
local moved, kept = Spec.share(40, 50, nil)
assert(moved == 20 and kept == 20)
moved, kept = Spec.share(40, 50, 35)
assert(moved == 14 and kept == 26, "PvP share cap")
moved = Spec.share(40, 99, nil)
assert(moved == 36, "at most 90%")

-- Limits.
local a, b = { StartedAt = 1 }, { StartedAt = 2 }
local ending = Spec.toEnd({ b, a }, 2)
assert(#ending == 1 and ending[1] == a, "the oldest ends for a third tether")
assert(#Spec.toEnd({ a }, 2) == 0)
assert(Spec.anchorFull(3, 3) and not Spec.anchorFull(2, 3))
print("Magic tether spec: length, distance and line-of-sight snaps, pull, sharing and limits passed")
