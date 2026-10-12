local spec = assert(loadfile("src/shared/Modules/MagicTargetDeathSpec.luau"))()
assert(spec.matches(nil, "KilledByThisSpell"), "legacy steps default to either death cause")
assert(spec.matches("Either", "DiedWhileAffected"))
assert(spec.matches("KilledByThisSpell", "KilledByThisSpell"))
assert(spec.matches("DiedWhileAffected", "DiedWhileAffected"))
assert(not spec.matches("KilledByThisSpell", "DiedWhileAffected"))
assert(not spec.matches("DiedWhileAffected", "KilledByThisSpell"))
assert(not spec.matches("KilledByThisSpell", nil))
local runtime = {}
local target = {}
assert(spec.claim(runtime, target), "the first source death event should claim its target")
assert(not spec.claim(runtime, target), "one runtime source must not dispatch duplicate target-death events")
assert(spec.claim({}, target), "different source runtimes should track their own target-death event")
print("Magic target-death spec: backward-compatible cause filtering passed")
