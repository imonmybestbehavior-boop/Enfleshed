--!strict
-- Builds the Defend the Walls siege map from the seeded layout: terrain, village,
-- corridors and crossroads, three wall levels with the baileys between them, the final gatehouse and city
-- backdrop, and the night lighting. Returns the gameplay handles the mode needs.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Modules.DefendTheWallsLayout)
local Config = require(game:GetService("ReplicatedStorage").Shared.Configuration.DefendTheWalls)
local Kit = require(script.Kit)
local Scene = require(script.Lighting)
local Village = require(script.Village)
local Corridors = require(script.Corridors)
local Walls = require(script.Walls)
local Baileys = require(script.Baileys)
local Gate = require(script.Gate)

local Map = {}
Map.Walls = Walls

export type Built = {
	Folder: Folder,
	Layout: any,
	Levels: { Walls.Level },
	Doors: Model,
	DoorConsole: BasePart,
	Spawns: { Vector3 },
	Staging: Vector3,
}

local function terrain(layout: any, random: any)
	local t = workspace.Terrain
	local minZ, maxZ = layout.Spawns[2].Z - 50, layout.Doors.Z + 30
	local width = layout.HalfWidth * 2 + 60
	t:FillBlock(CFrame.new(0, -6, (minZ + maxZ) / 2), Vector3.new(width, 12, maxZ - minZ), Enum.Material.Mud)
	-- Rock fills the pockets between corridors so the roads read as cut trenches.
	for z = layout.Corridor.StartZ + 8, layout.Corridor.EndZ - 8, 12 do
		for x = -layout.HalfWidth + 6, layout.HalfWidth - 6, 12 do
			local p = { X = x, Z = z }
			local clear = (p.X - layout.Crossroads.X) ^ 2 + (p.Z - layout.Crossroads.Z) ^ 2
				> (layout.Crossroads.Radius + 10) ^ 2
			for _, lane in layout.Lanes do
				if Layout.distanceToPath(lane.Points, p) < lane.Width / 2 + 10 then
					clear = false
				end
			end
			if clear then
				t:FillBall(Vector3.new(x, random.range(2, 7), z), random.range(8, 11), Enum.Material.Rock)
			end
		end
	end
	-- Muddy verges and moss patches in the village, a stagnant pond off the right road.
	for _ = 1, 30 do
		local p = Vector3.new(
			random.range(-layout.HalfWidth, layout.HalfWidth),
			-1.5,
			random.range(layout.Village.MinZ, layout.Village.MaxZ)
		)
		t:FillBall(
			p,
			random.range(5, 10),
			if random.next() < 0.5 then Enum.Material.LeafyGrass else Enum.Material.Ground
		)
	end
	local pond = Vector3.new(layout.Village.Pond.X, -3, layout.Village.Pond.Z)
	t:FillBall(pond, 12, Enum.Material.Air)
	t:FillBlock(CFrame.new(pond + Vector3.new(0, -1.5, 0)), Vector3.new(18, 3, 18), Enum.Material.Water)
end

function Map.build(): Built
	local layout = Layout.generate(Config.Map.Seed)
	local random = Layout.rng(Config.Map.Seed + 1)
	local folder = Instance.new("Folder")
	folder.Name = "DefendTheWalls"
	folder:SetAttribute("Seed", Config.Map.Seed)
	Scene.apply()
	terrain(layout, random)
	Village.build(folder, layout, random)
	Corridors.build(folder, layout)
	local levels = Walls.build(folder, layout)
	Baileys.build(folder, layout)
	local doors, doorConsole = Gate.build(folder, layout, random)
	Gate.bounds(folder, layout)
	local spawnFolder = Kit.folder(folder, "EnemySpawns")
	local spawns = {}
	for _, spawn in layout.Spawns do
		local marker = Kit.part(
			spawnFolder,
			"Spawn_" .. spawn.Name,
			Vector3.new(4, 1, 4),
			CFrame.new(spawn.X, 0.5, spawn.Z),
			Enum.Material.Mud,
			Kit.Color.Mud,
			false
		)
		marker.Transparency = 1
		marker:SetAttribute("Lane", spawn.Lane)
		spawns[spawn.Lane] = Vector3.new(spawn.X, 4, spawn.Z)
	end
	folder.Parent = workspace
	return {
		Folder = folder,
		Layout = layout,
		Levels = levels,
		Doors = doors,
		DoorConsole = doorConsole,
		Spawns = spawns,
		Staging = Kit.v(layout.Staging, 5),
	}
end

return Map
