local Spec = assert(loadfile("src/shared/Modules/MagicProximitySpec.luau"))()

for _, form in ipairs({ "SelfEnhancement", "Construct" }) do
	assert(Spec.SupportedForms[form], form .. " should support active proximity events")
end
assert(not Spec.SupportedForms.Field, "Fields use geometry and their OnEnter lifecycle")

local defaults = Spec.Defaults
assert(Spec.validate(defaults, 20, 0.1, 16))
assert(not Spec.validate({ Radius = 0, Interval = 0.2, MaxTargets = 1 }, 20, 0.1, 16))
assert(not Spec.validate({ Radius = 4, Interval = 0.01, MaxTargets = 1 }, 20, 0.1, 16))
assert(not Spec.validate({ Radius = 4, Interval = 0.2, MaxTargets = 1.5 }, 20, 0.1, 16))

local targetA = {}
local targetB = {}
local state = Spec.newState(3)
assert(Spec.isDue(state, 3, 2))
Spec.beginSample(state, 3, defaults.Interval)
assert(not Spec.isDue(state, 3.1, 2), "Sampling must honor its cadence")
assert(Spec.isDue(state, 3.2, 2))
assert(Spec.claim(state, targetA, 2))
assert(not Spec.claim(state, targetA, 2), "A target can trigger only once per effect")
assert(Spec.claim(state, targetB, 2))
assert(not Spec.isDue(state, 10, 2), "Sampling must stop at the target cap")

print("Magic proximity spec: bounds, cadence, de-duplication, and cap passed")
