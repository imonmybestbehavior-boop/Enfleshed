local spec = assert(loadfile("src/shared/Modules/MagicCastingSpec.luau"))()
for _, form in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura", "SelfEnhancement" }) do
	assert(spec.supportsChannel(form), form .. " should support maintained channel casting")
end
for _, form in ipairs({ "Construct", "Manipulation", "Unknown" }) do
	assert(not spec.supportsChannel(form), form .. " must not advertise unsupported channels")
end
assert(spec.supportsAimUpdate("Beam", "Channeled"))
assert(spec.supportsAimUpdate("Projectile", "Channeled"))
assert(not spec.supportsAimUpdate("Field", "Channeled"))
assert(not spec.supportsAimUpdate("Beam", "Instant"))
assert(spec.movementMultiplier({ CanMoveWhileCasting = true, MovementPenalty = 0 }) == 1)
assert(math.abs(spec.movementMultiplier({ CanMoveWhileCasting = true, MovementPenalty = 0.3 }) - 0.7) < 1e-6)
assert(spec.movementMultiplier({ CanMoveWhileCasting = false, MovementPenalty = 0 }) == 0)
assert(not spec.rotationLocked({ CanRotateWhileCasting = true }))
assert(spec.rotationLocked({ CanRotateWhileCasting = false }))
assert(spec.supportsToggle("Field"), "Fields should support explicit toggle casting")
assert(spec.supportsToggle("Aura"), "Auras should support explicit toggle casting")
assert(spec.supportsToggle("SelfEnhancement"), "Self Enhancements should support explicit toggle casting")
assert(spec.supportsToggle("Construct"), "Constructs should support explicit toggle casting")
assert(not spec.supportsToggle("Projectile"), "Projectiles must not offer toggle casting")
assert(spec.isChargeMode("Charged"), "Charged must remain a charge mode")
assert(spec.isChargeMode("HoldAndRelease"), "HoldAndRelease must be a charge mode")
assert(not spec.isChargeMode("Instant"), "Instant must not carry charge timing")
for _, form in ipairs({ "Projectile", "Beam", "Wave", "Field", "Aura" }) do
	assert(spec.supportsCommandCast(form), form .. " should support summon command casting")
end
assert(not spec.supportsCommandCast("Manipulation"), "Manipulation should not be a companion command cast")
assert(spec.supportsSustained("Construct"), "Constructs should support held sustained geometry")
assert(not spec.supportsSustained("Field"), "Field should use its channel or lifetime modes instead")
assert(spec.isHeldMode("Sustained") and spec.isHeldMode("Channeled"), "Both maintained modes require key release")
assert(
	spec.hasFreeHand({ RequiresFreeHand = false }, 0),
	"Spells without the hand requirement should remain unaffected"
)
assert(spec.hasFreeHand({ RequiresFreeHand = true }, 1))
assert(not spec.hasFreeHand({ RequiresFreeHand = true }, 0), "Free-hand requirements must be enforceable")
print("Magic casting spec: channels and composable movement policy passed")
