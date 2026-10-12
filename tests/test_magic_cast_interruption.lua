local interruption = assert(loadfile("src/shared/Modules/MagicCastInterruption.luau"))()

assert(not interruption.damage({ InterruptOnDamage = false }, 1))
assert(not interruption.damage({ InterruptOnDamage = true }, 0))
assert(interruption.damage({ InterruptOnDamage = true }, 0.1))
assert(not interruption.movement({ InterruptMoveDistance = 0 }, 100))
assert(not interruption.movement({ InterruptMoveDistance = 3 }, 3))
assert(interruption.movement({ InterruptMoveDistance = 3 }, 3.01))

print("Magic cast interruption: damage and movement thresholds passed")
