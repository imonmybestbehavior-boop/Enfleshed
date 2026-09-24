--!strict

local Topology = require(script.Parent.PhaseATopology)

local function at(node)
	return Topology.Nodes[node]
end

return table.freeze({
	Barracks_Main = { Position = at("S1"), Name = "Recruit Barracks", Category = "Barracks" },
	Checkpoint_Market = { Position = at("S4"), Name = "Market Checkpoint", Category = "Checkpoint" },
	Checkpoint_South = { Position = at("S6"), Name = "Southern Checkpoint", Category = "Checkpoint" },
	Housing_West = { Position = at("B3"), Name = "West Worker Housing", Category = "Housing" },
	Housing_East = { Position = at("B4"), Name = "East Worker Housing", Category = "Housing" },
	Workshop_West = { Position = at("B7"), Name = "West Workshop", Category = "Workshop" },
	Workshop_East = { Position = at("B6"), Name = "East Workshop", Category = "Workshop" },
	Underground_Junction = { Position = at("D5"), Name = "Utility Junction", Category = "Underground" },
})
