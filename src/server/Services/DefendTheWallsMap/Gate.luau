--!strict
-- The final doors in the inner gatehouse, the staging courtyard in front of them,
-- and the city backdrop behind (silhouettes only, sealed by invisible blockers).
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.DefendTheWalls)
local Kit = require(script.Parent.Kit)

local Gate = {}
local C, M = Kit.Color, Kit.Material

function Gate.build(parent: Instance, layout: any, random: any): (Model, BasePart)
	local root = Kit.folder(parent, "Gatehouse")
	local doors = layout.Doors
	local faceZ, height = doors.Z, 44
	-- Gatehouse face across the full width, with the door opening in the middle.
	local half = layout.HalfWidth
	for _, side in { -1, 1 } do
		local inner = doors.Width / 2
		local width = half - inner
		Kit.part(
			root,
			"GatehouseWall",
			Vector3.new(width, height, 12),
			CFrame.new(side * (inner + width / 2), height / 2, faceZ + 6),
			M.Wall,
			C.Slate
		)
		Kit.part(
			root,
			"GateTower",
			Vector3.new(18, height + 18, 18),
			CFrame.new(side * (inner + 9), (height + 18) / 2, faceZ + 4),
			M.Wall,
			C.SlateWet
		)
		Kit.brazier(root, Vector3.new(side * (inner + 6), 0, faceZ - 10), true)
		Kit.banner(root, CFrame.new(side * (inner + 9), height + 10, faceZ - 5.5), 18)
	end
	Kit.part(
		root,
		"DoorArch",
		Vector3.new(doors.Width, height - doors.Height, 12),
		CFrame.new(0, (height + doors.Height) / 2, faceZ + 6),
		M.Wall,
		C.SlateWet
	)
	local model = Instance.new("Model")
	model.Name = "FinalGate"
	local hit = Kit.part(
		model,
		"HumanoidRootPart",
		Vector3.new(doors.Width - 6, 12, 2),
		CFrame.new(0, 6, faceZ - 3),
		M.Wood,
		C.Oak,
		false
	)
	hit.Transparency, hit.CanQuery = 1, true
	for _, side in { -1, 1 } do
		local leaf = Kit.part(
			model,
			"DoorLeaf",
			Vector3.new(doors.Width / 2, doors.Height, 3),
			CFrame.new(side * doors.Width / 4, doors.Height / 2, faceZ),
			M.Wood,
			C.Oak
		)
		leaf:SetAttribute("Blocker", "City")
		for y = 4, doors.Height - 3, 6 do
			Kit.detail(
				model,
				"DoorBand",
				Vector3.new(doors.Width / 2 - 0.5, 1, 3.4),
				CFrame.new(side * doors.Width / 4, y, faceZ),
				M.Iron,
				C.Iron
			)
		end
		Kit.detail(model, "DoorRing", Vector3.new(2, 2, 0.6), CFrame.new(side * 2.5, 12, faceZ - 1.9), M.Iron, C.Iron)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth, humanoid.Health = Config.GatewayIntegrity, Config.GatewayIntegrity
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = hit
	model:SetAttribute("MissionGateway", true)
	model:SetAttribute("FinalGate", true)
	CollectionService:AddTag(model, "CityHuman")
	model.Parent = root
	local console =
		Kit.part(root, "DoorRepairConsole", Vector3.new(4, 5, 3), CFrame.new(18, 2.5, faceZ - 14), M.Iron, C.Iron)
	local rune = Kit.detail(
		root,
		"ConsoleRune",
		Vector3.new(2.5, 0.3, 2),
		CFrame.new(18, 5.2, faceZ - 14),
		Enum.Material.Neon,
		C.Bone
	)
	Kit.light(rune, C.Bone, 10, 1)
	-- Staging courtyard floor.
	Kit.part(
		root,
		"StagingFloor",
		Vector3.new(half * 2, 0.4, faceZ - layout.Walls[3].Z - 10),
		CFrame.new(0, 0.2, (faceZ + layout.Walls[3].Z) / 2 + 2),
		M.Cobble,
		C.Cobble
	)
	-- City backdrop: dark silhouettes with a few lit windows, never reachable.
	local city = Kit.folder(root, "CityBackdrop")
	for i = 1, 26 do
		local x = random.range(-half - 60, half + 60)
		local z = layout.City.MinZ + 20 + random.range(0, 220)
		local w, h = random.range(16, 34), random.range(30, 90)
		local block = Kit.part(
			city,
			"CityBlock",
			Vector3.new(w, h, w),
			CFrame.new(x, h / 2, z),
			M.Wall,
			Color3.fromRGB(22, 24, 30),
			false
		)
		block.CastShadow = false
		if random.next() < 0.45 then
			Kit.wedge(
				city,
				"CitySpire",
				Vector3.new(w * 0.4, h * 0.6, w * 0.4),
				CFrame.new(x, h + h * 0.3, z),
				M.Wall,
				Color3.fromRGB(22, 24, 30)
			).CanCollide =
				false
		end
		for _ = 1, 3 do
			local window = Kit.detail(
				city,
				"CityWindow",
				Vector3.new(1.4, 2.2, 0.2),
				CFrame.new(x + random.range(-w / 3, w / 3), random.range(8, h - 4), z - w / 2 - 0.2),
				Enum.Material.Neon,
				Color3.fromRGB(255, 190, 110)
			)
			window.Transparency = 0.15
		end
	end
	local cathedral = Kit.part(
		city,
		"Cathedral",
		Vector3.new(40, 120, 40),
		CFrame.new(0, 60, layout.City.MinZ + 160),
		M.Wall,
		Color3.fromRGB(18, 20, 26),
		false
	)
	cathedral.CastShadow = false
	local blocker = Kit.part(
		root,
		"CityBlocker",
		Vector3.new(half * 2 + 40, 200, 4),
		CFrame.new(0, 100, faceZ + 14),
		M.Wall,
		C.Slate
	)
	blocker.Transparency = 1
	return model, console
end

-- Side and rear blockers plus cliff faces so nothing leaves the playable strip.
function Gate.bounds(parent: Instance, layout: any)
	local root = Kit.folder(parent, "Bounds")
	local minZ, maxZ = layout.Spawns[2].Z - 40, layout.Doors.Z + 20
	local length = maxZ - minZ
	for _, side in { -1, 1 } do
		local x = side * (layout.HalfWidth + 4)
		Kit.part(
			root,
			"Cliff",
			Vector3.new(14, 34, length),
			CFrame.new(x + side * 4, 17, (minZ + maxZ) / 2) * CFrame.Angles(0, 0, side * -0.08),
			M.Rock,
			C.SlateWet
		)
		local wall = Kit.part(
			root,
			"Blocker",
			Vector3.new(4, 200, length),
			CFrame.new(x, 100, (minZ + maxZ) / 2),
			M.Wall,
			C.Slate
		)
		wall.Transparency = 1
	end
	local back = Kit.part(
		root,
		"Blocker",
		Vector3.new(layout.HalfWidth * 2 + 20, 200, 4),
		CFrame.new(0, 100, minZ),
		M.Wall,
		C.Slate
	)
	back.Transparency = 1
	for x = -layout.HalfWidth, layout.HalfWidth, 24 do
		Kit.part(
			root,
			"RearCliff",
			Vector3.new(26, 30, 14),
			CFrame.new(x, 15, minZ + 4) * CFrame.Angles(0.1, 0, 0),
			M.Rock,
			C.SlateWet
		)
	end
end

return Gate
