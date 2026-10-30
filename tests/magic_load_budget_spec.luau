local Budget = require("../src/shared/Modules/MagicLoadBudget")

assert(Budget.weight(nil) == 1 and Budget.weight({}) == 1, "unknown cost weighs the minimum")
assert(Budget.weight({ Cost = { Complexity = 0 } }) == 1)
assert(Budget.weight({ Cost = { Complexity = 26 } }) == 3.6, "rank-3 complexity cap weighs 3.6")
assert(Budget.weight({ Cost = { Complexity = 1e9 } }) == 1 + Budget.MaxComplexity / Budget.ComplexityScale, "clamped")
assert(Budget.weight({ Cost = { Complexity = 0 / 0 } }) == 1, "NaN complexity is ignored")

assert(Budget.allowed(16.7) == Budget.MaxLoad, "healthy server gets the full budget")
assert(Budget.allowed(Budget.CriticalFrameMs) == Budget.MaxLoad * Budget.MinShare, "critical server gets the floor")
assert(Budget.allowed(500) == Budget.MaxLoad * Budget.MinShare, "never below the floor")
local mid = Budget.allowed((Budget.HealthyFrameMs + Budget.CriticalFrameMs) / 2)
assert(mid < Budget.MaxLoad and mid > Budget.MaxLoad * Budget.MinShare, "budget shrinks smoothly")

assert(Budget.canAdd(0, 3.6, 16))
assert(not Budget.canAdd(Budget.MaxLoad - 1, 3.6, 16), "a complex spell does not fit the last unit")
assert(Budget.canAdd(Budget.MaxLoad - 1, 1, 16), "a simple spell does")
assert(not Budget.canAdd(Budget.MaxLoad * 0.6, 1, 60), "slow server refuses earlier")

local frame = 16.7
for _ = 1, 200 do
	frame = Budget.smooth(frame, 0.05)
end
assert(math.abs(frame - 50) < 0.5, "smoothing converges to the real frame time")
assert(Budget.smooth(16.7, 99) <= 16.7 + 1000 * Budget.FrameSmoothing, "huge hitches are clamped")

print("Magic load budget: weights, frame-time scaling, admission and smoothing passed")
