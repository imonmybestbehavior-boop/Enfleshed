local Spec = assert(loadfile("src/server/Services/MagicCommandSpec.luau"))()

assert(Spec.matches(nil, "Follow"), "An unfiltered command step should match any accepted order")
assert(Spec.canExecuteCompanionSpell(false, false, "Follow"), "Instant companion casts stay role-driven")
assert(not Spec.canExecuteCompanionSpell(true, false, "Attack"), "CommandCast must wait for an owner order")
assert(not Spec.canExecuteCompanionSpell(true, true, "Follow"), "Follow must not trigger CommandCast")
assert(Spec.canExecuteCompanionSpell(true, true, "Attack"), "Attack triggers CommandCast")
assert(Spec.canExecuteCompanionSpell(true, true, "Support"), "Support triggers CommandCast")
assert(Spec.validSelectionId(1) and Spec.validSelectionId(12), "Positive integer summon IDs should be selectable")
for _, invalid in ipairs({ 0, -1, 1.5, 0 / 0, "1" }) do
	assert(not Spec.validSelectionId(invalid), "Malformed summon IDs must be rejected")
end
assert(Spec.validPointCoordinates(0, 1, -100), "Finite world points should be accepted")
assert(not Spec.validPointCoordinates(0 / 0, 0, 0), "NaN move coordinates must be rejected before raycasting")
assert(not Spec.validPointCoordinates(0, math.huge, 0), "Infinite move coordinates must be rejected before raycasting")
assert(Spec.matchesSelection(8, nil), "No selection should preserve group-wide command behavior")
assert(Spec.matchesSelection(8, 8) and not Spec.matchesSelection(8, 9), "Selection must match exactly one summon")
local commandEffects = {
	{ Player = "owner", CommandCastId = 11 },
	{ Player = "owner", CommandCastId = 11 }, -- Split/spread effects remain one command.
	{ Player = "owner", CommandCastId = 12 },
	{ Player = "other", CommandCastId = 13 },
}
assert(Spec.activeCommandCount(commandEffects, "owner") == 2, "Count distinct owner command executions")
assert(Spec.canStartActiveCommand({ commandEffects[1] }, "owner", 2), "Permit commands below the configured cap")
assert(not Spec.canStartActiveCommand(commandEffects, "owner", 2), "Enforce the cap on distinct active commands")
assert(Spec.activeCommandCount({}, "owner") == 0, "Finished command effects release their active slot")
local firstRoute, routeComplete = Spec.nextPatrolRoute(nil, "first")
assert(not routeComplete and #firstRoute == 1 and firstRoute[1] == "first", "First patrol command sets one waypoint")
local completedRoute, completed = Spec.nextPatrolRoute(firstRoute, "second")
assert(
	completed and #completedRoute == 2 and completedRoute[2] == "second",
	"Second patrol command completes the route"
)
for _, command in ipairs({ "Follow", "Protect", "Attack", "Move", "Patrol", "Hold", "Support", "Dismiss" }) do
	assert(Spec.matches(command, command), command .. " should match itself")
	for _, other in ipairs({ "Follow", "Protect", "Attack", "Move", "Patrol", "Hold", "Support", "Dismiss" }) do
		if other ~= command then
			assert(not Spec.matches(command, other), command .. " should not match " .. other)
		end
	end
end

print("Magic command spec: named command filters passed")
