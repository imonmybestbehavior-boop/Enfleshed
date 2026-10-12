local Spec = assert(loadfile("src/shared/Modules/MagicLifetimeConditionSpec.luau"))()

assert(Spec.allowsStart("UntilConditionFails", true), "a true keep-alive predicate should allow activation")
assert(not Spec.allowsStart("UntilConditionFails", false), "a false keep-alive predicate should reject activation")
assert(not Spec.allowsStart("UntilConditionFails", nil), "an unavailable keep-alive predicate should fail closed")
assert(not Spec.shouldEnd("UntilConditionFails", true), "a true keep-alive predicate should retain the effect")
assert(Spec.shouldEnd("UntilConditionFails", false), "a false keep-alive predicate should end the effect")
assert(Spec.shouldEnd("UntilConditionFails", nil), "an unavailable keep-alive predicate should end the effect")

assert(not Spec.shouldEnd("FixedDuration", false), "ordinary end conditions should not end on false")
assert(Spec.shouldEnd("FixedDuration", true), "ordinary end conditions should still end on true")

print("Magic lifetime condition spec: activation and cleanup semantics passed")
