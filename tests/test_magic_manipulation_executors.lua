local Manipulation = assert(loadfile("src/server/Services/MagicManipulationExecutors.luau"))()

assert(Manipulation.offset("Raise", 3) == 3)
assert(Manipulation.offset("Lower", 3) == -3)
assert(Manipulation.offset("Teleport", 3) == nil)

print("PASS: generic Matter Manipulation operations resolve bounded vertical offsets")
