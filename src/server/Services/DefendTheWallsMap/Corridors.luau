--!strict
-- Three walled sunken-road corridors that meet at one crossroads. Each lane has
-- its own light colour, edge glow and landmark; side walls are cut away wherever
-- they would cross another lane's road, which is what opens the crossings.
local Layout = require(game:GetService("ReplicatedStorage").Shared.Modules.DefendTheWallsLayout)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Corridors = {}
local C, M = Kit.Color, Kit.Material
local CHUNK = 10

local function insideAnyRoad(layout: any, p: { X: number, Z: number }, margin: number): boolean
	local cross = layout.Crossroads
	if (p.X - cross.X) ^ 2 + (p.Z - cross.Z) ^ 2 < (cross.Radius + margin) ^ 2 then
		return true
	end
	for _, lane in layout.Lanes do
		if Layout.distanceToPath(lane.Points, p) < lane.Width / 2 + margin then
			return true
		end
	end
	return false
end

local function road(parent: Instance, lane: any, color: Color3, glowFromZ: number)
	local pts = lane.Points
	for i = 1, #pts - 1 do
		local a, b = Kit.v(pts[i], 0.15), Kit.v(pts[i + 1], 0.15)
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		Kit.part(
			parent,
			"Road",
			Vector3.new(lane.Width - 4, 0.3, length + lane.Width * 0.6),
			cf,
			M.Cobble,
			C.Cobble,
			true
		)
		if math.max(a.Z, b.Z) > glowFromZ then
			for _, side in { -1, 1 } do
				local offset = cf.RightVector * side * (lane.Width / 2 - 1.2)
				Kit.strip(parent, a + offset + Vector3.new(0, 0.2, 0), b + offset + Vector3.new(0, 0.2, 0), color)
			end
		end
	end
end

local function sideWalls(parent: Instance, layout: any, lane: any)
	local height, pts = layout.Corridor.WallHeight, lane.Points
	for i = 1, #pts - 1 do
		local a, b = Kit.v(pts[i]), Kit.v(pts[i + 1])
		local length = (b - a).Magnitude
		local dir = (b - a).Unit
		local right = dir:Cross(Vector3.yAxis)
		for d = CHUNK / 2, length, CHUNK do
			for _, side in { -1, 1 } do
				local mid = a + dir * d + right * side * (lane.Width / 2 + 1.5)
				local p = { X = mid.X, Z = mid.Z }
				if
					mid.Z > layout.Corridor.StartZ
					and mid.Z < layout.Corridor.EndZ
					and not insideAnyRoad(layout, p, 0.5)
				then
					local cf =
						CFrame.lookAt(mid + Vector3.new(0, height / 2, 0), mid + Vector3.new(0, height / 2, 0) + dir)
					Kit.part(parent, "CorridorWall", Vector3.new(3, height, CHUNK + 1), cf, M.Wall, C.SlateWet)
					Kit.detail(
						parent,
						"Coping",
						Vector3.new(4, 1, CHUNK + 1),
						cf * CFrame.new(0, height / 2 + 0.5, 0),
						M.Rock,
						C.Slate
					)
					if (d / CHUNK) % 3 < 1 then
						Kit.detail(
							parent,
							"Moss",
							Vector3.new(0.3, height * 0.6, CHUNK * 0.7),
							cf * CFrame.new(-side * 1.6, -height * 0.2, 0),
							M.Moss,
							C.Moss
						)
					end
				end
			end
		end
	end
end

-- A wall across the whole front with a gap for each road, so the only ways
-- between village, corridors and the wall field are the lanes.
local function crossBarrier(parent: Instance, layout: any, z: number)
	local height = layout.Corridor.WallHeight
	for x = -layout.HalfWidth + CHUNK / 2, layout.HalfWidth, CHUNK do
		if not insideAnyRoad(layout, { X = x, Z = z }, 1) then
			Kit.part(
				parent,
				"CorridorBarrier",
				Vector3.new(CHUNK + 0.5, height, 4),
				CFrame.new(x, height / 2, z),
				M.Wall,
				C.SlateWet
			)
		end
	end
end

local function landmark(parent: Instance, layout: any, lane: any, color: Color3)
	local pts = lane.Points
	local entry = Kit.v(pts[2]) + Vector3.new(0, 0, 18)
	local model = Instance.new("Model")
	model.Name = "Landmark_" .. lane.Landmark
	if lane.Landmark == "HangedOak" then
		local beside = entry + Vector3.new(-(lane.Width / 2 + 9), 0, 0)
		Props.deadTree(model, beside, 3)
		for i = 1, 2 do
			local cage = Kit.detail(
				model,
				"GibbetCage",
				Vector3.new(2.5, 4, 2.5),
				CFrame.new(beside + Vector3.new(i * 3, 10, 0)),
				Enum.Material.Metal,
				C.Iron
			)
			cage.Transparency = 0.3
			Props.chains(model, beside + Vector3.new(i * 3, 14.5, 0), 2.5)
		end
	elseif lane.Landmark == "BrokenSpire" then
		local beside = entry + Vector3.new(lane.Width / 2 + 8, 0, 0)
		Kit.part(model, "SpireBase", Vector3.new(7, 4, 7), CFrame.new(beside + Vector3.new(0, 2, 0)), M.Wall, C.Slate)
		Kit.part(
			model,
			"Spire",
			Vector3.new(4, 26, 4),
			CFrame.new(beside + Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0.4, 0.12),
			M.Wall,
			C.SlateWet
		)
	else
		-- Aqueduct arcade spanning the right corridor's first straight.
		local a, b = Kit.v(pts[2]), Kit.v(pts[3])
		local dir, right = (b - a).Unit, (b - a).Unit:Cross(Vector3.yAxis)
		for d = 20, 80, 24 do
			local mid = a + dir * d
			for _, side in { -1, 1 } do
				Kit.part(
					model,
					"AqueductPier",
					Vector3.new(4, 22, 4),
					CFrame.new(mid + right * side * (lane.Width / 2 + 1.5) + Vector3.new(0, 11, 0)),
					M.Wall,
					C.Slate
				)
			end
			Kit.part(
				model,
				"AqueductSpan",
				Vector3.new(lane.Width + 7, 4, 5),
				CFrame.lookAt(mid + Vector3.new(0, 24, 0), mid + Vector3.new(0, 24, 0) + right),
				M.Wall,
				C.SlateWet
			)
		end
	end
	-- One coloured beacon per landmark so the lane reads from the walls.
	local beacon = Kit.detail(
		model,
		"LaneBeacon",
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.new(entry + Vector3.new(0, 18, 0)),
		Enum.Material.Neon,
		color
	)
	Kit.light(beacon, color, 50, 2)
	model.Parent = parent
end

local function onLane(layout: any, p: { X: number, Z: number }, margin: number): boolean
	for _, lane in layout.Lanes do
		if Layout.distanceToPath(lane.Points, p) < lane.Width / 2 + margin then
			return true
		end
	end
	return false
end

-- The crossroads as a walled ruin rather than an open field: a ring wall with an
-- opening only where a road passes, a shrine plinth in the middle that splits the
-- flow into two channels, low cover walls in the wedges between roads to hold
-- from, and broken columns. Lane braziers on the plinth face their own exits.
local function junction(root: Instance, layout: any)
	local folder = Kit.folder(root, "Crossroads")
	local cross = layout.Crossroads
	local centre = Vector3.new(cross.X, 0, cross.Z)
	local plaza = Kit.part(
		folder,
		"CrossroadsFloor",
		Vector3.new(0.4, cross.Radius * 2, cross.Radius * 2),
		CFrame.new(cross.X, 0.2, cross.Z) * CFrame.Angles(0, 0, math.pi / 2),
		M.Cobble,
		C.Cobble
	)
	plaza.Shape = Enum.PartType.Cylinder
	plaza:SetAttribute("Lanes", "1,2,3")
	local height = layout.Corridor.WallHeight
	-- Ring wall, cut wherever a road crosses it.
	local ringRadius = cross.Radius + 1.5
	local steps = 40
	for i = 0, steps - 1 do
		local angle = (i + 0.5) / steps * math.pi * 2
		local p = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * ringRadius
		if not onLane(layout, { X = p.X, Z = p.Z }, 1) then
			local length = 2 * math.pi * ringRadius / steps + 0.6
			local tall = if i % 7 == 3 then height * 0.55 else height -- a few collapsed bays
			local cf = CFrame.lookAt(p, centre) * CFrame.new(0, tall / 2, 0)
			Kit.part(folder, "RingWall", Vector3.new(length, tall, 3), cf, M.Wall, C.SlateWet)
			if i % 4 == 0 then
				Kit.part(folder, "RingPier", Vector3.new(4, tall + 3, 4), cf * CFrame.new(0, 1.5, -1), M.Wall, C.Slate)
			end
		end
	end
	-- Shrine plinth: solid, so the lanes have to choose a side of it.
	local plinthRadius = cross.Monument
	local plinth = Kit.part(
		folder,
		"ShrinePlinth",
		Vector3.new(3, plinthRadius * 2, plinthRadius * 2),
		CFrame.new(cross.X, 1.5, cross.Z) * CFrame.Angles(0, 0, math.pi / 2),
		M.Rock,
		C.SlateWet
	)
	plinth.Shape = Enum.PartType.Cylinder
	Kit.part(
		folder,
		"SaintStatue",
		Vector3.new(5, 15, 4),
		CFrame.new(cross.X, 10.5, cross.Z) * CFrame.Angles(0, 0.3, 0.05),
		M.Wall,
		C.Slate
	)
	Kit.detail(
		folder,
		"SaintHead",
		Vector3.new(2.4, 2.6, 2.4),
		CFrame.new(cross.X + 0.4, 19.2, cross.Z) * CFrame.Angles(0.4, 0.3, 0),
		M.Wall,
		C.Slate
	)
	for _, lane in layout.Lanes do
		-- Each lane's brazier sits on the plinth edge facing where that lane leaves.
		local exit = Kit.v(lane.Points[#lane.Points])
		local dir = Vector3.new(exit.X - cross.X, 0, exit.Z - cross.Z).Unit
		local spot = centre + dir * (plinthRadius - 2) + Vector3.new(0, 3, 0)
		local bowl = Kit.detail(
			folder,
			"LaneFire",
			Vector3.new(2.2, 1.6, 2.2),
			CFrame.new(spot + Vector3.new(0, 0.8, 0)),
			Enum.Material.Neon,
			Kit.rgb(lane.Color)
		)
		Kit.light(bowl, Kit.rgb(lane.Color), 34, 2.4, lane.Index == 2)
	end
	-- Low cover walls and broken columns in the wedges between roads.
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local cover = centre + dir * (cross.Radius - 16)
		if not onLane(layout, { X = cover.X, Z = cover.Z }, 3) then
			Kit.part(
				folder,
				"CoverWall",
				Vector3.new(9, 3.6, 2),
				CFrame.lookAt(cover, centre) * CFrame.new(0, 1.8, 0),
				M.Rock,
				C.Slate
			)
		end
		local column = centre + dir * (cross.Radius - 5)
		if i % 2 == 0 and not onLane(layout, { X = column.X, Z = column.Z }, 2) then
			local tall = 6 + (i * 5) % 9
			Kit.part(
				folder,
				"BrokenColumn",
				Vector3.new(3, tall, 3),
				CFrame.new(column + Vector3.new(0, tall / 2, 0)) * CFrame.Angles(0, angle, 0.04),
				M.Wall,
				C.Slate
			)
		end
	end
	for i = 0, 1 do
		Kit.brazier(folder, centre + Vector3.new(if i == 0 then -1 else 1, 0, 0) * (cross.Radius - 9), i == 0)
	end
end

function Corridors.build(parent: Instance, layout: any)
	local root = Kit.folder(parent, "Corridors")
	for _, lane in layout.Lanes do
		local folder = Kit.folder(root, "Lane_" .. lane.Name)
		folder:SetAttribute("Lane", lane.Index)
		local color = Kit.rgb(lane.Color)
		road(folder, lane, color, layout.Corridor.StartZ - 40)
		sideWalls(folder, layout, lane)
		landmark(folder, layout, lane, color)
	end
	junction(root, layout)
	crossBarrier(root, layout, layout.Corridor.StartZ)
	crossBarrier(root, layout, layout.Corridor.EndZ)
	-- Lane lights: warm torches in the corridors, lane-tinted lanterns in the village.
	local lights = Kit.folder(root, "LaneLights")
	for _, spot in layout.CorridorLights do
		local lane = layout.Lanes[spot.Lane]
		local tint = Kit.rgb(lane.Color)
		if spot.Z >= layout.Corridor.StartZ then
			Kit.torch(lights, Vector3.new(spot.X, 0, spot.Z), tint:Lerp(C.Flame, 0.55))
		elseif spot.Z > layout.Spawns[1].Z + 20 then
			Kit.detail(
				lights,
				"LanternPost",
				Vector3.new(0.5, 9, 0.5),
				CFrame.new(spot.X, 4.5, spot.Z),
				M.Timber,
				C.Oak
			)
			Kit.lantern(lights, Vector3.new(spot.X + 1, 7, spot.Z), tint)
		end
	end
	for i, p in layout.DeadTrees do
		Props.deadTree(root, Kit.v(p), i)
	end
	return root
end

return Corridors
