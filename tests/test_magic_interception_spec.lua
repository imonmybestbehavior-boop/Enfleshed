-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicInterceptionSpec.luau"))()

-- Eligibility: DoT ticks and redirected damage are never intercepted.
assert(Spec.eligible(nil), "melee and monster hits")
assert(Spec.eligible({ DamageChannel = "Elemental" }), "spell hits")
assert(not Spec.eligible({ Periodic = true }), "DoT ticks")
assert(not Spec.eligible({ Redirected = true }), "redirected damage")

-- Oldest applied first, stable for ties.
local a, b, c = { AppliedAt = 5 }, { AppliedAt = 2 }, { AppliedAt = 5 }
local ordered = Spec.order({ a, b, c })
assert(ordered[1] == b and ordered[2] == a and ordered[3] == c)

-- Charges and interval.
local state = Spec.newState(2)
assert(Spec.ready(state, 0, 0.25))
assert(not Spec.use(state, 10))
assert(not Spec.ready(state, 10.1, 0.25), "0.25 s between interceptions")
assert(Spec.ready(state, 10.25, 0.25))
assert(Spec.use(state, 10.3), "spent")
assert(not Spec.ready(state, 20, 0.25), "no charges left")

-- Actions (PvE).
local fresh = Spec.newState(3)
local r = Spec.resolve(40, { Action = "Negate" }, nil, false, fresh)
assert(r.Applied and r.Kept == 0 and r.Negated)
r = Spec.resolve(40, { Action = "Reduce", Percent = 50 }, nil, false, fresh)
assert(r.Kept == 20)
r = Spec.resolve(40, { Action = "Reduce", Percent = 99 }, nil, false, fresh)
assert(math.abs(r.Kept - 4) < 1e-9, "reduce is at most 90%")
r = Spec.resolve(40, { Action = "Redirect", Percent = 50, To = "Owner" }, nil, false, fresh)
assert(r.Kept == 20 and r.Redirect.To == "Owner" and r.Redirect.Amount == 20)
r = Spec.resolve(40, {}, nil, false, fresh)
assert(r.Applied and r.Kept == 40 and r.Redirect == nil, "normal steps leave the hit alone")
r = Spec.resolve(0 / 0, { Action = "Reduce", Percent = 50 }, nil, false, fresh)
assert(r.Kept == 0, "NaN")

-- PvP caps.
local open = {
	MaxInterceptReducePercent = 50,
	MaxInterceptNegateChargesVsPlayer = 1,
	MaxInterceptRedirectToAttackerPercent = 50,
}
r = Spec.resolve(40, { Action = "Reduce", Percent = 90 }, open, true, fresh)
assert(r.Kept == 20, "PvP reduce cap")
r = Spec.resolve(40, { Action = "Redirect", Percent = 100, To = "Attacker" }, open, true, fresh)
assert(r.Kept == 20 and r.Redirect.Amount == 20, "PvP redirect-to-attacker cap")
r = Spec.resolve(40, { Action = "Redirect", Percent = 100, To = "Owner" }, open, true, fresh)
assert(r.Kept == 0 and r.Redirect.Amount == 40, "redirect to the owner is not capped")
local pvp = Spec.newState(3)
r = Spec.resolve(40, { Action = "Negate" }, open, true, pvp)
assert(r.Applied and r.Kept == 0)
Spec.use(pvp, 1, true)
r = Spec.resolve(40, { Action = "Negate" }, open, true, pvp)
assert(not r.Applied and r.Kept == 40, "one negate against player hits")
r = Spec.resolve(40, { Action = "Negate" }, open, false, pvp)
assert(r.Applied, "monster hits are not limited")

-- Cost: Negate highest.
assert(Spec.costWeight({ Action = "Negate" }) > Spec.costWeight({ Action = "Redirect", Percent = 100 }))
assert(Spec.costWeight({ Action = "Redirect", Percent = 100 }) > Spec.costWeight({ Action = "Reduce", Percent = 90 }))
print("Magic interception spec: eligibility, ordering, charges, actions, PvP caps and cost passed")
