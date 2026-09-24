local vector = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
}
local topology = assert(
	loadfile("src/shared/Configuration/PhaseATopology.luau", "t", { Vector3 = vector, table = table, ipairs = ipairs })
)()
local dataTable = setmetatable({
	freeze = function(value)
		return value
	end,
}, { __index = table })
local locations = assert(loadfile("src/shared/Configuration/AssignmentLocations.luau", "t", {
	script = { Parent = { PhaseATopology = "topology" } },
	require = function()
		return topology
	end,
	table = dataTable,
}))()
local assignments = assert(loadfile("src/shared/Configuration/Assignments.luau", "t", { table = dataTable }))()
local expected = { "Patrol", "SupplyDelivery", "Investigation", "ClearInfestation", "DefendPosition" }
for _, id in ipairs(expected) do
	local definition = assert(assignments[id])
	assert(definition.AssignmentId == id and definition.Reward > 0)
	for _, location in ipairs(definition.Destinations or definition.Route) do
		assert(locations[location])
	end
end
assert(assignments.ClearInfestation.EnemyCount > 0 and assignments.DefendPosition.EnemyCount > 0)
print("PASS: assignment definitions reference valid Phase A locations")
