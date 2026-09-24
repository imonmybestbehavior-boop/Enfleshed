--!strict

return table.freeze({
	Patrol = {
		AssignmentId = "Patrol",
		Name = "Patrol — Market Line",
		Description = "Visit the assigned checkpoints in order.",
		AssignmentType = "Patrol",
		Route = { "Checkpoint_Market", "Checkpoint_South", "Workshop_West" },
		Reward = 18,
	},
	SupplyDelivery = {
		AssignmentId = "SupplyDelivery",
		Name = "Supply Delivery",
		Description = "Deliver field supplies to the assigned station.",
		AssignmentType = "SupplyDelivery",
		Destinations = { "Workshop_East", "Housing_West", "Housing_East" },
		Reward = 22,
	},
	Investigation = {
		AssignmentId = "Investigation",
		Name = "Infestation Investigation",
		Description = "Inspect reported signs of infestation.",
		AssignmentType = "Investigation",
		Destinations = { "Housing_West", "Housing_East", "Underground_Junction" },
		Reward = 26,
	},
	ClearInfestation = {
		AssignmentId = "ClearInfestation",
		Name = "Clear Infestation",
		Description = "Clear the assigned Nascent presence.",
		AssignmentType = "ClearInfestation",
		Destinations = { "Workshop_West", "Underground_Junction" },
		EnemyCount = 2,
		Reward = 38,
	},
	DefendPosition = {
		AssignmentId = "DefendPosition",
		Name = "Defend Position",
		Description = "Activate the post and survive the assault.",
		AssignmentType = "DefendPosition",
		Destinations = { "Checkpoint_Market", "Workshop_East" },
		EnemyCount = 2,
		Reward = 42,
	},
})
