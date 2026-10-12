local spec = assert(loadfile("src/shared/Modules/MagicAerialMovementSpec.luau"))()

assert(spec.clampSpeed(32, 48) == 32)
assert(spec.clampSpeed(100, 48) == 48)
assert(spec.clampSpeed(-5, 48) == 0)
assert(spec.clampSpeed(0 / 0, 48) == nil)

local x, y, z = spec.normalizeInput(0.5, 0.5, 0.5, 1.1)
assert(math.abs(x - 0.5) < 1e-6 and math.abs(y - 0.5) < 1e-6 and math.abs(z - 0.5) < 1e-6)
x, y, z = spec.normalizeInput(0.75, 0.75, 0, 1.1)
assert(math.abs(x - math.sqrt(0.5)) < 1e-6 and math.abs(y - math.sqrt(0.5)) < 1e-6 and z == 0)
assert(spec.normalizeInput(1, 1, 1, 1.1) == nil)
assert(spec.normalizeInput(math.huge, 0, 0, 1.1) == nil)
assert(spec.normalizeInput(0 / 0, 0, 0, 1.1) == nil)
assert(spec.normalizeInput(0, 0, 0, 1.1) == 0)

print("magic aerial movement spec: ok")
