--!strict
-- The three defensive lines. Each has a breachable gate per lane: a Humanoid
-- proxy the enemies attack (all gates of one level share that level's integrity,
-- see DefendTheWallsService) and a solid leaf that blocks everyone until the wall
-- is breached. Defenders reach the front by the walkway ramps and dropping over;
-- a "Climb back over" postern prompt on each wall's face brings players back.
-- Walkways, ramps, guard posts and the per-level repair console are created here too.
local Players = game:GetService("Players")
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Walls = {}
local C, M = Kit.Color, Kit.Material

export type Level = {
	Level: number,
	Gates: { [number]: Model },
	Leaves: { BasePart },
	Console: BasePart,
	SpearPosts: { CFrame },
	BowPosts: { CFrame },
	Fallback: Vector3,
	Rally: Vector3,
}

-- Players-only way back over a closed wall (enemies never get prompts).
local function postern(parent: Instance, wall: any, x: number)
	local front = wall.Z - wall.Thickness / 2
	local ladder = Kit.part(
		parent,
		"PosternLadder",
		Vector3.new(3, wall.Height - 1, 0.6),
		CFrame.new(x, (wall.Height - 1) / 2, front - 0.4),
		M.Timber,
		C.OakPale,
		false
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Climb back over", "Wall " .. wall.Level
	prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 0.6, 8, false
	prompt.Parent = ladder
	local landing = CFrame.new(x, 4, wall.Z + wall.Thickness / 2 + 10)
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 and Players:GetPlayerFromCharacter(character) == player then
			character:PivotTo(landing)
		end
	end)
end

local function gateModel(parent: Instance, wall: any, gate: any, laneName: string, height: number): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = string.format("Wall%dGate_%s", wall.Level, laneName)
	local front = wall.Z - wall.Thickness / 2
	local root = Kit.part(
		model,
		"HumanoidRootPart",
		Vector3.new(wall.GateWidth - 4, 10, 2),
		CFrame.new(gate.X, 5, front - 2.5),
		M.Wood,
		C.Oak,
		false
	)
	root.Transparency, root.CanQuery = 1, true
	local leaf = Kit.part(
		model,
		"GateLeaf",
		Vector3.new(wall.GateWidth, height, 2),
		CFrame.new(gate.X, height / 2, front + 0.5),
		if wall.Level == 1 then M.Timber else M.Wood,
		C.Oak
	)
	-- Iron banding on stone gates; sharpened tops on the palisade gate.
	if wall.Level == 1 then
		for x = -wall.GateWidth / 2 + 1, wall.GateWidth / 2 - 1, 2 do
			Kit.detail(
				model,
				"GateStake",
				Vector3.new(1.2, 2, 1.2),
				CFrame.new(gate.X + x, height + 0.6, front + 0.5) * CFrame.Angles(0, math.pi / 4, 0),
				M.Timber,
				C.Oak
			)
		end
	end
	for y = 3, height - 2, 5 do
		Kit.detail(
			model,
			"IronBand",
			Vector3.new(wall.GateWidth, 0.6, 2.3),
			CFrame.new(gate.X, y, front + 0.5),
			M.Iron,
			C.Iron
		)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("MissionGateway", true)
	model:SetAttribute("WallLevel", wall.Level)
	model:SetAttribute("Lane", gate.Lane)
	model.Parent = parent
	return model, leaf
end

local function towers(parent: Instance, wall: any, xs: { number })
	for _, x in xs do
		local size = wall.Thickness + 6
		local height = wall.Height + 10
		Kit.part(parent, "Tower", Vector3.new(size, height, size), CFrame.new(x, height / 2, wall.Z), M.Wall, C.Slate)
		Kit.part(
			parent,
			"TowerTop",
			Vector3.new(size + 2, 1.5, size + 2),
			CFrame.new(x, height + 0.75, wall.Z),
			M.Rock,
			C.SlateWet
		)
		for i = 0, 3 do
			local angle = i * math.pi / 2
			Kit.detail(
				parent,
				"Merlon",
				Vector3.new(2.5, 3, 2.5),
				CFrame.new(x + math.cos(angle) * size / 2, height + 3, wall.Z + math.sin(angle) * size / 2),
				M.Wall,
				C.Slate
			)
		end
		local roof = Kit.wedge(
			parent,
			"TowerRoof",
			Vector3.new(size, 10, size / 2),
			CFrame.new(x, height + 6.5, wall.Z - size / 4),
			M.Wood,
			C.SlateWet
		)
		Kit.wedge(
			parent,
			"TowerRoof",
			Vector3.new(size, 10, size / 2),
			roof.CFrame * CFrame.new(0, 0, size / 2) * CFrame.Angles(0, math.pi, 0),
			M.Wood,
			C.SlateWet
		)
	end
end

function Walls.build(parent: Instance, layout: any): { Level }
	local root = Kit.folder(parent, "Walls")
	local levels: { Level } = {}
	for _, wall in layout.Walls do
		local folder = Kit.folder(root, string.format("Wall%d_%s", wall.Level, wall.Name))
		folder:SetAttribute("WallLevel", wall.Level)
		local gateHeight = math.min(wall.Height, 16)
		local walkwayY = wall.Height - 4
		local back = wall.Z + wall.Thickness / 2
		local front = wall.Z - wall.Thickness / 2
		-- Solid runs between gates.
		-- Runs overlap the side blockers so nothing squeezes past the wall ends.
		local edges = { -wall.HalfWidth - 6 }
		for _, gate in wall.Gates do
			table.insert(edges, gate.X - wall.GateWidth / 2)
			table.insert(edges, gate.X + wall.GateWidth / 2)
		end
		table.insert(edges, wall.HalfWidth + 6)
		local material = if wall.Level == 1 then M.Timber else M.Wall
		local color = if wall.Level == 1 then C.Oak else C.Slate
		for i = 1, #edges, 2 do
			local a, b = edges[i], edges[i + 1]
			local cx, width = (a + b) / 2, b - a
			Kit.part(
				folder,
				"WallRun",
				Vector3.new(width, wall.Height, wall.Thickness),
				CFrame.new(cx, wall.Height / 2, wall.Z),
				material,
				color
			)
			if wall.Level == 1 then
				-- Stone footing under the timber palisade, stakes along the top.
				Kit.part(
					folder,
					"Footing",
					Vector3.new(width, 4, wall.Thickness + 2),
					CFrame.new(cx, 2, wall.Z),
					M.Rock,
					C.SlateWet
				)
				for x = a + 1, b - 1, 2.2 do
					Kit.detail(
						folder,
						"PalisadeStake",
						Vector3.new(1.4, 3, 1.4),
						CFrame.new(x, wall.Height + 1.2, front + 1) * CFrame.Angles(0, math.pi / 4, 0),
						M.Timber,
						C.Oak
					)
				end
				Props.spikes(folder, Vector3.new(a + 2, 0, front - 6), Vector3.new(b - 2, 0, front - 6))
			else
				for x = a + 2, b - 2, 5 do
					Kit.detail(
						folder,
						"Merlon",
						Vector3.new(2.6, 3, 1.6),
						CFrame.new(x, wall.Height + 1.5, front + 0.8),
						M.Wall,
						C.Slate
					)
				end
			end
		end
		-- Lintels over the gates on taller walls keep the line continuous.
		for _, gate in wall.Gates do
			if wall.Height > gateHeight then
				Kit.part(
					folder,
					"GateArch",
					Vector3.new(wall.GateWidth, wall.Height - gateHeight, wall.Thickness),
					CFrame.new(gate.X, (wall.Height + gateHeight) / 2, wall.Z),
					M.Wall,
					C.SlateWet
				)
			end
		end
		-- Walkway behind the parapet, with ramps at both ends (along X so they never cut the field).
		local walkwayDepth = 6
		Kit.part(
			folder,
			"Walkway",
			Vector3.new(wall.HalfWidth * 2, 1, walkwayDepth),
			CFrame.new(0, walkwayY - 0.5, back + walkwayDepth / 2),
			M.Wood,
			C.OakPale
		)
		local rampLength = walkwayY * 2.2
		for _, side in { -1, 1 } do
			local x = side * (wall.HalfWidth - 6 - rampLength / 2)
			local ramp = Kit.wedge(
				folder,
				"Ramp",
				Vector3.new(walkwayDepth, walkwayY, rampLength),
				CFrame.new(x, walkwayY / 2, back + walkwayDepth * 1.5) * CFrame.Angles(0, side * math.pi / 2, 0),
				M.Wood,
				C.OakPale
			)
			ramp:SetAttribute("Access", "Walkway")
		end
		if wall.Level >= 2 then
			towers(folder, wall, { -wall.HalfWidth + 8, -56, 56, wall.HalfWidth - 8 })
		end
		if wall.Level == 3 then
			-- Buttresses, gargoyles and braziers on the bastion face.
			for x = -wall.HalfWidth + 20, wall.HalfWidth - 20, 26 do
				local clear = true
				for _, gate in wall.Gates do
					if math.abs(x - gate.X) < wall.GateWidth then
						clear = false
					end
				end
				if clear then
					Kit.wedge(
						folder,
						"Buttress",
						Vector3.new(4, wall.Height * 0.8, 8),
						CFrame.new(x, wall.Height * 0.4, front - 4) * CFrame.Angles(0, math.pi, 0),
						M.Wall,
						C.SlateWet
					)
					Kit.detail(
						folder,
						"Gargoyle",
						Vector3.new(2, 2.5, 4),
						CFrame.new(x, wall.Height - 2, front - 2) * CFrame.Angles(0.3, 0, 0),
						M.Rock,
						C.Slate
					)
				end
			end
		end
		-- Braziers on every walkway: the warm light pool that frames each line.
		for i, x in { -150, -70, 70, 150 } do
			Kit.brazier(folder, Vector3.new(x, walkwayY, back + 3), wall.Level == 3 and i == 2)
		end
		for _, x in { -170, -40, 40, 170 } do
			Kit.banner(folder, CFrame.new(x, wall.Height - 1, front - 0.6), 8 + wall.Level * 2)
		end
		local gates: { [number]: Model } = {}
		local leaves = {}
		local spear, bow = {}, {}
		for _, gate in wall.Gates do
			local lane = layout.Lanes[gate.Lane]
			local model, leaf = gateModel(folder, wall, gate, lane.Name, gateHeight)
			gates[gate.Lane] = model
			table.insert(leaves, leaf)
			-- Lane-coloured lamp over each gate ties the corridor to its gate.
			local lamp = Kit.detail(
				folder,
				"GateLamp",
				Vector3.new(1.2, 1.2, 1.2),
				CFrame.new(gate.X, gateHeight + 1.5, front - 1.5),
				Enum.Material.Neon,
				Kit.rgb(lane.Color)
			)
			Kit.light(lamp, Kit.rgb(lane.Color), 26, 1.8)
			for _, dx in { -5, 5 } do
				table.insert(spear, CFrame.new(gate.X + dx, 3, front - 9) * CFrame.Angles(0, math.pi, 0))
			end
			for _, dx in { -16, 16 } do
				table.insert(bow, CFrame.new(gate.X + dx, walkwayY + 3, back + 2) * CFrame.Angles(0, math.pi, 0))
			end
		end
		for _, x in { -84, 84 } do
			postern(folder, wall, x)
		end
		local console = Kit.part(
			folder,
			"RepairConsole",
			Vector3.new(4, 5, 3),
			CFrame.new(10, 2.5, back + walkwayDepth + 6),
			M.Iron,
			C.Iron
		)
		local rune = Kit.detail(
			folder,
			"ConsoleRune",
			Vector3.new(2.5, 0.3, 2),
			CFrame.new(10, 5.2, back + walkwayDepth + 6),
			Enum.Material.Neon,
			C.Bone
		)
		Kit.light(rune, C.Bone, 10, 1)
		levels[wall.Level] = {
			Level = wall.Level,
			Gates = gates,
			Leaves = leaves,
			Console = console,
			SpearPosts = spear,
			BowPosts = bow,
			Fallback = Kit.v(wall.Fallback, 5),
			Rally = Kit.v(wall.Rally, 3),
		}
	end
	return levels
end

-- Opens (true) or closes a level's gates: breached leaves drop and stop blocking.
function Walls.setBreached(level: Level, breached: boolean)
	for _, leaf in level.Leaves do
		leaf.CanCollide = not breached
		leaf.Transparency = if breached then 1 else 0
		for _, sibling in (leaf.Parent :: Instance):GetChildren() do
			if sibling:IsA("BasePart") and sibling.Name ~= "HumanoidRootPart" and sibling ~= leaf then
				sibling.Transparency = if breached then 1 else 0
			end
		end
	end
end

return Walls
