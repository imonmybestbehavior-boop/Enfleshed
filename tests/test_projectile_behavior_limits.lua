local limits = assert(loadfile("src/shared/Configuration/MagicLab.luau"))()

assert(limits.MaxBounces == 5, "Bounce count should have a bounded server default")
assert(limits.MaxSplitChildren == 5 and limits.MaxSplitAngle == 60, "Split tuning should stay bounded")
assert(limits.MaxSpreadPairs == 2 and limits.MaxSpreadAngle == 45, "Spread tuning should stay bounded")
assert(limits.MaxPropagationTargets == 8, "Impact propagation should use a bounded additional-target cap")
assert(limits.MaxProjectileBehaviors == 3, "Projectile composition budget should remain bounded")
assert(limits.MaxAbsorbedProjectiles == 8, "Absorb should use a bounded interception count")
assert(limits.MaxAbsorbPotencyMultiplier == 4, "Absorb's potency gain must remain capped")
assert(limits.MaxProjectileReflections == 8, "Reflect should use a bounded interception count")
assert(limits.MaxProjectileReflectionHops == 3, "Projectile reflection loops must remain bounded")
assert(limits.MaxDuration == 15 and limits.MaxRadius == 20, "Linger safety caps should remain bounded")

print("Projectile behavior limits: Bounce, Propagate, and composition budgets passed")
