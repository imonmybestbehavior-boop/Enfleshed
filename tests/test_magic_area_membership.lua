local Membership = dofile("src/shared/Modules/MagicAreaMembership.luau")

local first, second, third = {}, {}, {}
local previous = { [first] = true, [second] = true }
local current, entered, exited = Membership.diff(previous, { second, third, third })

assert(current[second] and current[third] and not current[first], "Current occupancy set is incorrect")
assert(#entered == 1 and entered[1] == third, "A target should enter once even if query results repeat it")
assert(#exited == 1 and exited[1] == first, "Only targets absent from the new query should exit")

local cleared = Membership.clear(current)
assert(#cleared == 2, "Ending the area should exit every remaining occupant")
print("Magic area membership: enter, exit, duplicate-query, and cleanup transitions passed")
