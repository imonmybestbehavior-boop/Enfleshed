local Spec = require("../src/shared/Modules/TelemetrySpec")

assert(Spec.onboardingStep("Joined") == 1 and Spec.onboardingStep("BoughtUnlock") == #Spec.Onboarding)
assert(Spec.onboardingStep("Nope") == nil, "unknown steps are not logged")

local usage = {}
local fireball =
	{ Form = "Projectile", Element = "Fire", Triggers = { OnImpact = { { Payloads = { { Kind = "Damage" } } } } } }
local heal = { Form = "Aura", Triggers = { OnTick = { { Payloads = { { Kind = "Heal" } } } } } }
assert(Spec.recordCast(usage, fireball) and Spec.recordCast(usage, fireball) and Spec.recordCast(usage, heal))
assert(usage["Projectile|Fire|Damage"].Count == 2, "casts of the same shape are aggregated")
assert(usage["Aura|Neutral|Heal"].Count == 1, "missing element counts as Neutral")
assert(not Spec.recordCast(usage, nil), "invalid spells ignored")

-- Bounded: beyond MaxSpellKeys shapes, casts fold into "Other".
local bounded = {}
for i = 1, Spec.MaxSpellKeys do
	Spec.recordCast(bounded, { Form = "F" .. i, Triggers = {} })
end
assert(not Spec.recordCast(bounded, { Form = "Extra", Triggers = {} }))
Spec.recordCast(bounded, { Form = "Extra2", Triggers = {} })
local keys = 0
for _ in bounded do
	keys += 1
end
assert(keys == Spec.MaxSpellKeys + 1 and bounded.Other.Count == 2, "overflow is counted under Other")

print("Telemetry: onboarding order, spell usage aggregation and key bound passed")
