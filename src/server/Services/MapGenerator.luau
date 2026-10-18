--!strict
-- Seeded, modular ruined-castle battlefield. All gameplay-height pieces collide.
local Terrain = workspace.Terrain
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.CombatBattleMap)
local Generator = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	collide: boolean?
): BasePart
	local object = Instance.new("Part")
	object.Name, object.Size, object.CFrame = name, size, cf
	object.Anchored = true
	object.Material, object.Color = material, color
	object.TopSurface, object.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	object.CanCollide = collide ~= false
	object.Parent = parent
	return object
end

local stone = Color3.fromRGB(91, 94, 88)
local stoneDark = Color3.fromRGB(62, 68, 66)
local wood = Color3.fromRGB(91, 68, 46)
local moss = Color3.fromRGB(68, 84, 61)

local function setupFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = name, parent
	return folder
end

-- Builds one crenellated wall run with an optional broken center gap and rubble foot.
function Generator.BuildWallSection(
	parent: Instance,
	origin: Vector3,
	length: number,
	height: number,
	yaw: number,
	broken: boolean,
	rng: Random
)
	local cf = CFrame.new(origin) * CFrame.Angles(0, yaw, 0)
	local function segment(x, width, tall, y)
		part(
			parent,
			"RuinedWallBlock",
			Vector3.new(width, tall, 5),
			cf * CFrame.new(x, y, 0),
			Enum.Material.Rock,
			stone
		)
	end
	if broken then
		segment(-length * 0.32, length * 0.28, height, height / 2)
		segment(length * 0.32, length * 0.28, height * 0.78, height * 0.39)
		segment(-length * 0.12, length * 0.16, height * 0.4, height * 0.2)
	else
		segment(0, length, height, height / 2)
	end
	for i = 1, math.floor(length / 9) do
		local x = rng:NextNumber(-length / 2, length / 2)
		local block = part(
			parent,
			"BrokenBattlement",
			Vector3.new(2.8, rng:NextNumber(1.5, 3), 5.5),
			cf * CFrame.new(x, height + 0.6, 0),
			Enum.Material.Rock,
			stoneDark
		)
		block:SetAttribute("Cover", true)
	end
	for i = 1, 5 do
		local x = rng:NextNumber(-length / 2, length / 2)
		part(
			parent,
			"WallBaseRubble",
			Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(1, 2.5), rng:NextNumber(2, 4)),
			cf
				* CFrame.new(x, 0.7, rng:NextNumber(-4, 4))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Enum.Material.Rock,
			stoneDark
		)
	end
end

-- Builds a broken round tower from repeated stone courses with a fighting platform.
function Generator.BuildTower(parent: Instance, center: Vector3, radius: number, height: number, rng: Random)
	local segments = 10
	for course = 0, math.floor(height / 7) - 1 do
		local courseY = center.Y + course * 7 + 3.5
		for index = 1, segments do
			local angle = (index / segments) * math.pi * 2 + (course % 2) * 0.12
			if not (course >= math.floor(height / 14) and index == 3 and rng:NextNumber() < 0.35) then
				local block = part(
					parent,
					"TowerStone",
					Vector3.new(radius * 0.75, 7.2, 5),
					CFrame.new(center.X, courseY, center.Z) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, radius - 1),
					Enum.Material.Rock,
					if course % 3 == 0 then stoneDark else stone
				)
				block:SetAttribute("Cover", true)
			end
		end
	end
	part(
		parent,
		"TowerInteriorFloor",
		Vector3.new(radius * 1.6, 2, radius * 1.6),
		CFrame.new(center.X, center.Y + height * 0.55, center.Z),
		Enum.Material.Slate,
		stoneDark
	)
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local block = part(
			parent,
			"TowerFall",
			Vector3.new(rng:NextNumber(3, 7), rng:NextNumber(2, 5), 5),
			CFrame.new(center.X, center.Y + rng:NextNumber(1, height * 0.7), center.Z)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), angle, rng:NextNumber(-0.4, 0.4))
				* CFrame.new(0, 0, radius),
			Enum.Material.Rock,
			stone
		)
		block:SetAttribute("Cover", true)
	end
end

-- Builds a collapsed cottage with separated interior walls, doorway gaps and roof debris.
function Generator.BuildRuinedHouse(parent: Instance, center: Vector3, yaw: number, rng: Random)
	local cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local width, depth = rng:NextNumber(19, 28), rng:NextNumber(17, 25)
	local wallHeight = rng:NextNumber(8, 13)
	local thickness = 2.2
	for _, side in { -1, 1 } do
		local wall = part(
			parent,
			"HouseSideWall",
			Vector3.new(thickness, wallHeight, depth),
			cf * CFrame.new(side * width / 2, wallHeight / 2, 0),
			Enum.Material.Rock,
			stone
		)
		wall:SetAttribute("Cover", true)
	end
	for _, zSign in { -1, 1 } do
		local z = zSign * depth / 2
		local gap = rng:NextNumber(5, 7)
		for _, side in { -1, 1 } do
			local wall = part(
				parent,
				"HouseBrokenWall",
				Vector3.new((width - gap) / 2, wallHeight * rng:NextNumber(0.62, 1), thickness),
				cf * CFrame.new(side * (width + gap) / 4, wallHeight * 0.42, z),
				Enum.Material.Rock,
				if rng:NextNumber() < 0.25 then moss else stone
			)
			wall:SetAttribute("Cover", true)
		end
	end
	for _ = 1, 6 do
		part(
			parent,
			"RoofFall",
			Vector3.new(rng:NextNumber(4, 9), 1.2, rng:NextNumber(3, 7)),
			cf
				* CFrame.new(
					rng:NextNumber(-width / 2, width / 2),
					wallHeight + rng:NextNumber(0, 4),
					rng:NextNumber(-depth / 2, depth / 2)
				)
				* CFrame.Angles(0, rng:NextNumber(-1, 1), rng:NextNumber(-0.45, 0.45)),
			Enum.Material.WoodPlanks,
			wood
		)
	end
	for _ = 1, 8 do
		part(
			parent,
			"HouseRubble",
			Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(1, 2), rng:NextNumber(2, 5)),
			cf
				* CFrame.new(rng:NextNumber(-width, width), 0.8, rng:NextNumber(-depth, depth))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Enum.Material.Rock,
			stoneDark
		)
	end
end

-- Scatters compact collision cover clusters with varied heights for crouch, peek and flank play.
function Generator.ScatterCover(parent: Instance, center: Vector3, radius: number, rng: Random, amount: number)
	for _ = 1, amount do
		local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, radius)
		local point = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local kind = rng:NextInteger(1, 6)
		if kind == 1 then
			local trunk = part(
				parent,
				"FallenTree",
				Vector3.new(rng:NextNumber(13, 23), 2.7, 3),
				CFrame.new(point + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, angle, rng:NextNumber(-0.15, 0.15)),
				Enum.Material.Wood,
				Color3.fromRGB(68, 67, 53)
			)
			trunk:SetAttribute("Cover", true)
		elseif kind == 2 then
			local boulder = part(
				parent,
				"BoulderCover",
				Vector3.new(rng:NextNumber(5, 9), rng:NextNumber(4, 8), rng:NextNumber(5, 10)),
				CFrame.new(point + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, angle, 0),
				Enum.Material.Rock,
				stoneDark
			)
			boulder.Shape = Enum.PartType.Ball
			boulder:SetAttribute("Cover", true)
		elseif kind == 3 then
			for crateIndex = 0, rng:NextInteger(1, 3) do
				local crate = part(
					parent,
					"SupplyCrate",
					Vector3.new(4, 3.5, 4),
					CFrame.new(point + Vector3.new(crateIndex * 2.4, 1.8 + crateIndex * 3.4, 0))
						* CFrame.Angles(0, angle, 0),
					Enum.Material.WoodPlanks,
					wood
				)
				crate:SetAttribute("Cover", true)
			end
		elseif kind == 4 then
			local wall = part(
				parent,
				"LowCoverWall",
				Vector3.new(rng:NextNumber(9, 15), rng:NextNumber(3, 5), 2.5),
				CFrame.new(point + Vector3.new(0, 2, 0)) * CFrame.Angles(0, angle, 0),
				Enum.Material.Rock,
				stone
			)
			wall:SetAttribute("Cover", true)
		elseif kind == 5 then
			part(
				parent,
				"HayBale",
				Vector3.new(5, 4, 5),
				CFrame.new(point + Vector3.new(0, 2, 0)) * CFrame.Angles(0, angle, 0),
				Enum.Material.Fabric,
				Color3.fromRGB(128, 119, 81)
			)
		else
			local cart = part(
				parent,
				"TippedWagon",
				Vector3.new(10, 4, 5),
				CFrame.new(point + Vector3.new(0, 2, 0))
					* CFrame.Angles(rng:NextNumber(-0.1, 0.1), angle, rng:NextNumber(-0.4, 0.4)),
				Enum.Material.WoodPlanks,
				wood
			)
			cart:SetAttribute("Cover", true)
		end
	end
end

-- Carves a ring trench in terrain, lays a walkable muddy bed and opens two bridge crossings.
function Generator.DigMoat(center: Vector3, innerRadius: number, outerRadius: number, depth: number, rng: Random)
	local samples = 64
	for index = 1, samples do
		local angle = index / samples * math.pi * 2
		local midpoint = (innerRadius + outerRadius) / 2
		local width = outerRadius - innerRadius
		local point = center + Vector3.new(math.cos(angle) * midpoint, -depth / 2, math.sin(angle) * midpoint)
		Terrain:FillBlock(
			CFrame.new(point) * CFrame.Angles(0, -angle, 0),
			Vector3.new(width + 3, depth, width * 0.12),
			Enum.Material.Air
		)
		Terrain:FillBlock(
			CFrame.new(point.X, center.Y - depth + 2, point.Z) * CFrame.Angles(0, -angle, 0),
			Vector3.new(width, 3, width * 0.12),
			Enum.Material.Mud
		)
	end
	-- Sparse shallow pools sit below the rim; the depressed mud floor remains the main route.
	for _, side in { -1, 1 } do
		local angle = side * math.pi / 2 + rng:NextNumber(-0.15, 0.15)
		local r = (innerRadius + outerRadius) / 2
		Terrain:FillBlock(
			CFrame.new(center.X + math.cos(angle) * r, center.Y - depth + 1, center.Z + math.sin(angle) * r),
			Vector3.new(24, 0.6, 14),
			Enum.Material.Water
		)
	end
end

local function buildCastle(root: Folder, rng: Random)
	local structures = setupFolder(root, "Structures")
	local keep = setupFolder(structures, "CastleKeep")
	local center = Vector3.new(0, Config.GroundY, 0)
	part(keep, "KeepFloor", Vector3.new(118, 2, 118), CFrame.new(0, 1, 0), Enum.Material.Slate, stoneDark)
	for index = 0, 7 do
		local angle = index / 8 * math.pi * 2
		local length = if index % 2 == 0 then 42 else 34
		Generator.BuildWallSection(
			keep,
			Vector3.new(math.cos(angle) * 44, 0, math.sin(angle) * 44),
			length,
			rng:NextNumber(11, 19),
			angle + math.pi / 2,
			index % 3 == 0,
			rng
		)
	end
	Generator.BuildTower(keep, Vector3.new(-43, 0, -43), 13, 38, rng)
	Generator.BuildTower(keep, Vector3.new(44, 0, -42), 12, 29, rng)
	Generator.BuildTower(keep, Vector3.new(-42, 0, 43), 12, 26, rng)
	Generator.BuildTower(keep, Vector3.new(43, 0, 43), 14, 17, rng)
	for index = 0, 3 do
		local angle = index / 4 * math.pi * 2
		local wallCenter = Vector3.new(math.cos(angle) * 135, 0, math.sin(angle) * 135)
		Generator.BuildWallSection(
			setupFolder(structures, "OuterWard"),
			wallCenter,
			54,
			rng:NextNumber(7, 12),
			angle + math.pi / 2,
			index ~= 1,
			rng
		)
	end
	-- The keep and outer ward preserve covered lanes but leave visible entry breaches.
	return center
end

local function makeSpawn(root: Folder, index: number, position: Vector3)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Position, spawn.Size = "BattleSpawn_" .. index, position, Vector3.new(8, 1, 8)
	spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
	spawn.Material, spawn.Color, spawn.Transparency = Enum.Material.Slate, stone, 0.15
	spawn.Parent = root
	return spawn
end

local function addLandmarks(root: Folder)
	local names = {
		"KeepCourtyard",
		"NorthBridge",
		"SouthBridge",
		"WestFarmstead",
		"EastGrove",
		"CliffCaves",
		"OuterWard",
		"MoatLowland",
	}
	local positions = {
		Vector3.new(0, 2, 0),
		Vector3.new(0, 1, -134),
		Vector3.new(0, 1, 134),
		Vector3.new(-300, 1, 60),
		Vector3.new(290, 1, 75),
		Vector3.new(450, 2, 10),
		Vector3.new(-150, 2, -150),
		Vector3.new(125, -9, 0),
	}
	for index, name in names do
		local flag = part(
			root,
			"Landmark_" .. name,
			Vector3.new(2, 2, 2),
			CFrame.new(positions[index]),
			Enum.Material.Neon,
			Color3.fromRGB(209, 174, 105),
			false
		)
		flag.Transparency = 1
		flag:SetAttribute("LandmarkId", name)
		local marker = Instance.new("BillboardGui")
		marker.Name, marker.Size, marker.StudsOffset, marker.AlwaysOnTop =
			"LandmarkLabel", UDim2.fromOffset(180, 30), Vector3.new(0, 4, 0), false
		marker.MaxDistance, marker.LightInfluence = 140, 0
		marker.Parent = flag
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, name
		label.TextColor3, label.TextStrokeTransparency, label.TextSize = Color3.fromRGB(235, 218, 179), 0.25, 15
		label.Font, label.Parent = Enum.Font.GothamBold, marker
	end
end

-- Generates the full terrain, central fortress, moat, outer ward, outskirts and landmarks.
function Generator.Generate(seed: number?): Folder
	local selectedSeed = seed or Config.Seed
	local rng = Random.new(selectedSeed)
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local root = setupFolder(workspace, "Map")
	root:SetAttribute("Seed", selectedSeed)
	root:SetAttribute("HalfExtent", Config.HalfExtent)
	for _, name in { "Structures", "Cover", "Props", "Spawns", "Landmarks", "Terrain" } do
		setupFolder(root, name)
	end
	-- Lighting is global; the Defend the Walls night scene owns it when that mode is built.
	if Lighting:GetAttribute("SceneOwner") == nil then
		Lighting.ClockTime = 17.8
		Lighting.Brightness = 1.6
		Lighting.Ambient = Color3.fromRGB(93, 99, 94)
		Lighting.OutdoorAmbient = Color3.fromRGB(108, 112, 105)
		Lighting.FogColor = Color3.fromRGB(115, 122, 119)
		Lighting.FogStart, Lighting.FogEnd = 260, 950
		local atmosphere = Lighting:FindFirstChild("BattleMapAtmosphere") or Instance.new("Atmosphere")
		atmosphere.Name, atmosphere.Density, atmosphere.Offset = "BattleMapAtmosphere", 0.28, 0.05
		atmosphere.Color, atmosphere.Decay, atmosphere.Glare, atmosphere.Haze =
			Color3.fromRGB(183, 190, 184), Color3.fromRGB(93, 101, 101), 0.1, 1.4
		atmosphere.Parent = Lighting
	end
	setupFolder(root, "Terrain")
	-- Clear only this map's footprint so other generated arenas keep their terrain.
	Terrain:FillBlock(
		CFrame.new(0, 0, 0),
		Vector3.new(Config.HalfExtent * 2 + 120, 80, Config.HalfExtent * 2 + 120),
		Enum.Material.Air
	)
	Terrain:FillBlock(
		CFrame.new(0, -5, 0),
		Vector3.new(Config.HalfExtent * 2, 12, Config.HalfExtent * 2),
		Enum.Material.Grass
	)
	-- Rolling mounds around the outside provide varied sightlines without an exposed flat perimeter.
	for _ = 1, Config.HillCount do
		local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(230, Config.HalfExtent - 24)
		local radius = rng:NextNumber(18, 48)
		local point = Vector3.new(math.cos(angle) * distance, -2, math.sin(angle) * distance)
		Terrain:FillBall(point, radius, if rng:NextNumber() < 0.7 then Enum.Material.Grass else Enum.Material.Ground)
	end
	local castleCenter = Vector3.new(0, Config.GroundY, 0)
	Generator.DigMoat(castleCenter, Config.MoatInnerRadius, Config.MoatOuterRadius, Config.MoatDepth, rng)
	buildCastle(root, rng)
	local cover = root:FindFirstChild("Cover") :: Folder
	local structures = root:FindFirstChild("Structures") :: Folder
	local houses = setupFolder(structures, "FarmsteadsAndRuins")
	local debris = root:FindFirstChild("Props") :: Folder
	-- Farmsteads and broken hamlets are distributed as cover nodes around open sprint lanes.
	for index = 1, 24 do
		local angle = (index / 24) * math.pi * 2 + rng:NextNumber(-0.14, 0.14)
		local radius = rng:NextNumber(190, 470)
		local point = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if rng:NextNumber() < 0.55 then
			Generator.BuildRuinedHouse(houses, point, rng:NextNumber(0, math.pi * 2), rng)
		end
		Generator.ScatterCover(cover, point, 20, rng, rng:NextInteger(9, 15))
	end
	-- A lattice guarantees every outskirts route remains near collision cover.
	local spacing = Config.OutskirtsCoverSpacing
	for x = -Config.HalfExtent + 28, Config.HalfExtent - 28, spacing do
		for z = -Config.HalfExtent + 28, Config.HalfExtent - 28, spacing do
			local distance = Vector2.new(x, z).Magnitude
			if distance > 174 and rng:NextNumber() < Config.CoverProbability then
				Generator.ScatterCover(cover, Vector3.new(x, 0, z), Config.CoverJitter, rng, rng:NextInteger(2, 5))
			end
		end
	end
	-- Cliffs along the eastern boundary; interleaved rocks leave a winding cave approach.
	for index = 0, 14 do
		local z = -430 + index * 62
		local cliff = part(
			cover,
			"BoundaryCliff",
			Vector3.new(30, rng:NextNumber(34, 66), rng:NextNumber(54, 84)),
			CFrame.new(470, 0, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.08, 0.08)),
			Enum.Material.Rock,
			stoneDark
		)
		cliff:SetAttribute("Cover", true)
		if index % 3 == 0 then
			local cave =
				part(cover, "Overhang", Vector3.new(28, 6, 26), CFrame.new(447, 17, z), Enum.Material.Rock, stoneDark)
			cave:SetAttribute("Cover", true)
		end
	end
	for _ = 1, 30 do
		local point = Vector3.new(rng:NextNumber(-460, 460), 0, rng:NextNumber(-460, 460))
		if point.Magnitude > 170 then
			part(
				debris,
				"CrackedSiegeBeam",
				Vector3.new(rng:NextNumber(12, 25), 1.8, 2.4),
				CFrame.new(point + Vector3.new(0, 1, 0))
					* CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
				Enum.Material.Wood,
				wood
			)
		end
	end
	-- Two broad bridge decks and rubble ramps make moat crossings legible and contestable.
	for _, z in { -133, 133 } do
		local bridge =
			part(debris, "StoneBridge", Vector3.new(25, 5, 58), CFrame.new(0, -1, z), Enum.Material.Slate, stone)
		bridge:SetAttribute("LandmarkRoute", true)
		for _, x in { -1, 1 } do
			local ramp = part(
				debris,
				"BridgeRamp",
				Vector3.new(17, 5, 26),
				CFrame.new(x * 19, -3, z) * CFrame.Angles(0, 0, x * -0.18),
				Enum.Material.Rock,
				stoneDark
			)
			ramp:SetAttribute("Cover", true)
		end
	end
	local spawnFolder = root:FindFirstChild("Spawns") :: Folder
	for index = 1, Config.SpawnCount do
		local angle = (index - 1) / Config.SpawnCount * math.pi * 2
		local radius = Config.SpawnRadius + rng:NextNumber(-24, 24)
		makeSpawn(spawnFolder, index, Vector3.new(math.cos(angle) * radius, 1, math.sin(angle) * radius))
	end
	addLandmarks(root:FindFirstChild("Landmarks") :: Folder)
	-- Named guide near the default spawn retains the existing practice navigation cues.
	local guide = part(
		debris,
		"PracticeGuide",
		Vector3.new(20, 7, 0.5),
		CFrame.new(0, 6, 368),
		Enum.Material.Slate,
		Color3.fromRGB(49, 56, 47)
	)
	local surface = Instance.new("SurfaceGui")
	surface.Face, surface.CanvasSize, surface.Parent = Enum.NormalId.Back, Vector2.new(800, 280), guide
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.TextColor3 = UDim2.fromScale(1, 1), 1, Color3.fromRGB(244, 231, 200)
	label.Font, label.TextSize, label.TextWrapped = Enum.Font.Gotham, 28, true
	label.Text = "RUINED KINGDOM BATTLEFIELD\nP: Grimoire · 1–9: cast\nTraining dummies via Review & Test"
	label.Parent = surface
	return root
end

return Generator
