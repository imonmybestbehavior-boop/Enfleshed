--!strict
-- Asset manifest for the Defend the Walls siege kit, in the same spirit as the
-- spell VFX manifest. Blockout stage: every piece is built from Parts by
-- DefendTheWallsMap, and MeshId is empty until the Blender kit
-- (tools/vfx_pipeline/blender.sh, sources under assets/siege/) is exported and
-- uploaded. When an entry gets a MeshId the builder can swap the Part blockout
-- for the mesh without touching layout code.
export type Piece = {
	Kit: string, -- builder that places it
	Source: string, -- Blender source / export path, relative to the repo
	MeshId: string, -- rbxassetid:// once uploaded; "" while blockout
	Size: Vector3, -- footprint the layout code reserves
}

local Assets: { [string]: Piece } = {
	WallSegment = {
		Kit = "Walls",
		Source = "assets/siege/wall_segment.fbx",
		MeshId = "",
		Size = Vector3.new(10, 22, 8),
	},
	PalisadeSegment = {
		Kit = "Walls",
		Source = "assets/siege/palisade_segment.fbx",
		MeshId = "",
		Size = Vector3.new(10, 14, 5),
	},
	Tower = { Kit = "Walls", Source = "assets/siege/tower.fbx", MeshId = "", Size = Vector3.new(16, 32, 16) },
	LaneGate = { Kit = "Walls", Source = "assets/siege/lane_gate.fbx", MeshId = "", Size = Vector3.new(20, 16, 2) },
	FinalDoors = { Kit = "Gate", Source = "assets/siege/final_doors.fbx", MeshId = "", Size = Vector3.new(26, 34, 3) },
	HouseWall = { Kit = "Village", Source = "assets/siege/house_wall.fbx", MeshId = "", Size = Vector3.new(16, 9, 1) },
	HouseRoof = { Kit = "Village", Source = "assets/siege/house_roof.fbx", MeshId = "", Size = Vector3.new(18, 7, 8) },
	ChapelRuin = {
		Kit = "Village",
		Source = "assets/siege/chapel_ruin.fbx",
		MeshId = "",
		Size = Vector3.new(26, 30, 38),
	},
	CorridorArch = {
		Kit = "Corridors",
		Source = "assets/siege/corridor_arch.fbx",
		MeshId = "",
		Size = Vector3.new(43, 26, 5),
	},
	CorridorWall = {
		Kit = "Corridors",
		Source = "assets/siege/corridor_wall.fbx",
		MeshId = "",
		Size = Vector3.new(3, 13, 10),
	},
	Brazier = { Kit = "Props", Source = "assets/siege/brazier.fbx", MeshId = "", Size = Vector3.new(4, 5, 4) },
	Cart = { Kit = "Props", Source = "assets/siege/cart.fbx", MeshId = "", Size = Vector3.new(5, 4, 8) },
	Gallows = { Kit = "Props", Source = "assets/siege/gallows.fbx", MeshId = "", Size = Vector3.new(12, 14, 8) },
	DeadTree = { Kit = "Props", Source = "assets/siege/dead_tree.fbx", MeshId = "", Size = Vector3.new(10, 18, 10) },
}

return Assets
