--!strict
-- Opt-in Studio check; never runs during ordinary wave updates. This tests the
-- engine navmesh, not an NPC chase. See PHASE_A_REPORT.md for physical playtests.
local Pathfinding = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Plan = require(Shared.Configuration.PhaseATopology)
local Agent = require(Shared.Configuration.Sandbox).Enemy.Navigation
local Check = {}

function Check.run()
	assert(RunService:IsStudio(), "Development navigation check is Studio-only")
	assert(workspace:FindFirstChild("LowerLayerGraybox"), "Start a play session before checking navigation")
	local results = {}
	for _, test in
		{
			{ "Recruit Avenue", "S1", "S4" },
			{ "Residential alley", "S8", "B3" },
			{ "Courtyard to housing", "S11", "B4" },
			{ "Housing upper floor", "B3", "U3" },
			{ "Barracks upper floor", "B1", "U1" },
			{ "Workshop West", "S10", "B7" },
			{ "Market cross avenue", "S10", "S13" },
			{ "Underground entry", "S8", "D1" },
			{ "Underground loop", "D1", "D6" },
		}
	do
		local path = Pathfinding:CreatePath({
			AgentRadius = Agent.AgentRadius,
			AgentHeight = Agent.AgentHeight,
			AgentCanJump = Agent.AgentCanJump,
			WaypointSpacing = Agent.WaypointSpacing,
		})
		local ok, err = pcall(function()
			path:ComputeAsync(Plan.Nodes[test[2]] + Vector3.new(0, 3, 0), Plan.Nodes[test[3]] + Vector3.new(0, 3, 0))
		end)
		local success = ok and path.Status == Enum.PathStatus.Success
		table.insert(
			results,
			{ Route = test[1], Success = success, Error = if ok then tostring(path.Status) else tostring(err) }
		)
		print(
			"Phase A navigation",
			test[1],
			if success then "PASS" else "FAIL",
			if ok then tostring(path.Status) else tostring(err)
		)
		path:Destroy()
		task.wait(0.1)
	end
	return results
end

return Check
