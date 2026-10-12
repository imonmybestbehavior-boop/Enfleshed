local Spec = assert(loadfile("src/shared/Modules/MagicLifetimeSpec.luau"))()

for _, form in ipairs({ "Field", "Aura", "SelfEnhancement", "Construct" }) do
	assert(Spec.supports(form, "UntilToggledOff"), form .. " should support persistent toggle lifetimes")
	assert(Spec.supports(form, "UntilResourceDepleted"), form .. " should support resource-bound lifetimes")
	assert(Spec.supports(form, "UntilConditionFails"), form .. " should support keep-alive condition lifetimes")
	assert(Spec.supports(form, "FixedDuration"), form .. " should keep its timed lifetime")
end
assert(Spec.supports("Construct", "UntilDestroyed"), "Constructs should support destruction-bound lifetimes")
assert(Spec.supports("Construct", "Persistent"), "Constructs should support place-persistent lifetimes")
assert(Spec.effectiveDuration("Persistent", nil) == math.huge, "Persistent Constructs should not time out")
for _, form in ipairs({ "Field", "Aura" }) do
	assert(Spec.supports(form, "UntilDestroyed"), form .. " should support marker-destruction lifetimes")
end
for _, form in ipairs({ "Projectile", "Beam", "Wave", "SelfEnhancement", "Manipulation" }) do
	assert(not Spec.supports(form, "UntilDestroyed"), form .. " should not use world-marker destruction lifetimes")
end
assert(
	Spec.supports("Projectile", "UntilConditionFails"),
	"projectiles should support condition-bound flight lifetimes"
)
for _, form in ipairs({ "Aura", "Construct" }) do
	assert(Spec.supports(form, "UntilTargetLost"), form .. " should support target-bound lifetimes")
	assert(Spec.supportsTargeting(form, "UntilTargetLost", "EntityTarget"))
	assert(Spec.supportsTargeting(form, "UntilTargetLost", "ObjectTarget"))
end
assert(Spec.supports("Field", "UntilTargetLost"), "Following Fields should support target-bound lifetimes")
assert(not Spec.supportsTargeting("Field", "UntilTargetLost", "EntityTarget", false))
assert(not Spec.supportsTargeting("Field", "UntilTargetLost", "ObjectTarget", false))
assert(Spec.supportsTargeting("Field", "UntilTargetLost", "EntityTarget", true))
assert(Spec.supportsTargeting("Field", "UntilTargetLost", "ObjectTarget", true))

for _, form in ipairs({ "Projectile", "Beam", "Manipulation" }) do
	assert(not Spec.supports(form, "UntilToggledOff"), form .. " should not toggle")
	assert(not Spec.supports(form, "UntilResourceDepleted"), form .. " should not use sustained resource lifetimes")
end
for _, form in ipairs({ "Beam", "Wave" }) do
	assert(Spec.supports(form, "UntilConditionFails"), form .. " channels should support keep-alive conditions")
end
assert(not Spec.supports("Manipulation", "UntilConditionFails"), "Manipulation should remain instantaneous")

assert(Spec.supports("Projectile", "FixedDuration"))
assert(Spec.supports("Projectile", "UntilTargetLost"), "homing projectiles may end with a lost maintained target")
assert(not Spec.supportsTargeting("Projectile", "UntilTargetLost", "AimDirection", false, true))
assert(not Spec.supportsTargeting("Projectile", "UntilTargetLost", "EntityTarget", false, false))
assert(Spec.supportsTargeting("Projectile", "UntilTargetLost", "EntityTarget", false, true))
assert(not Spec.targetLost("FixedDuration", false), "ordinary projectiles should retain their fixed lifetime")
assert(not Spec.targetLost("UntilTargetLost", true), "a living maintained target should keep the projectile active")
assert(Spec.targetLost("UntilTargetLost", false), "a lost maintained target should end its projectile lifetime")
local expiring = {}
assert(Spec.claimExpiry(expiring), "the first cleanup path should claim the expiry event")
assert(not Spec.claimExpiry(expiring), "later cleanup paths must not dispatch expiry twice")
assert(not Spec.claimExpiry(nil), "invalid runtime state cannot claim expiry")
assert(Spec.supports("Beam", "Instantaneous"))
assert(Spec.supports("Beam", "FixedDuration"))
assert(Spec.supports("Wave", "Instantaneous"))
assert(Spec.supports("Wave", "FixedDuration"), "Waves may repeat over a bounded channel lifetime")
assert(Spec.supports("Manipulation", "Instantaneous"))
assert(not Spec.supportsTargeting("Field", "UntilTargetLost", "WorldPoint", true))
assert(not Spec.supportsTargeting("Aura", "UntilTargetLost", "Self"))
assert(not Spec.supports("Unknown", "UntilToggledOff"))

assert(Spec.effectiveDuration("FixedDuration", 7) == 7)
assert(Spec.effectiveDuration("UntilConditionFails", nil) == math.huge)
assert(
	Spec.effectiveDuration("UntilConditionFails", 7) == 7,
	"A keep-alive condition can combine with a maximum active duration"
)
assert(Spec.effectiveDuration("UntilConditionFails", 3) == 3)
assert(Spec.validConditionDuration("Field", nil, 15))
assert(Spec.validConditionDuration("Field", 15, 15))
assert(not Spec.validConditionDuration("Field", 15.1, 15))
assert(not Spec.validConditionDuration("Field", 0, 15))
assert(not Spec.validConditionDuration("Projectile", nil, 15))

print("Magic lifetime spec: Form/mode compatibility passed")
