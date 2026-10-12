local spec = assert(loadfile("src/shared/Modules/MagicPresentationBudget.luau"))()
local limits = {
	MaxEmitters = 3,
	MaxContinuousRate = 20,
	MaxBurstPerSecond = 10,
	BurstCapacity = 12,
}
local budget = spec.new(limits, 0)

assert(spec.acquireEmitter(budget, 8))
assert(spec.acquireEmitter(budget, 8))
assert(not spec.acquireEmitter(budget, 8), "continuous emission rate must stay capped")
assert(budget.ActiveEmitters == 2 and budget.ContinuousRate == 16)
assert(spec.acquireEmitter(budget, 0), "one-shot emitters use the shared emitter cap, not continuous-rate cap")
assert(not spec.acquireEmitter(budget, 0), "live emitter count must stay capped")
assert(spec.releaseEmitter(budget, 8))
assert(spec.acquireEmitter(budget, 8), "released emitter capacity should be reusable")
assert(budget.ActiveEmitters == 3 and budget.ContinuousRate == 16)

assert(spec.takeBurst(budget, 12, 0) == 12, "bounded initial burst allowance")
assert(spec.takeBurst(budget, 4, 0) == 0, "bursts cannot exceed the available budget")
assert(spec.takeBurst(budget, 20, 0.5) == 5, "burst allowance refills at the configured rate")
assert(spec.takeBurst(budget, 20, 100) == 12, "refill is capped at the burst capacity")

print("Magic presentation budget: live emitter, continuous-rate, and burst caps passed")
