--!nonstrict
-- Phase A only: an inspectable, axis-aligned geometry manifest shared by the
-- runtime builder and offline clearance tests. Coordinates use walkable top Y.
local Geometry = {}

function Geometry.build(plan, clipping)
	local result = { Parts = {}, Floors = {}, Stairs = {}, Doors = {}, Reservations = {}, Holes = {} }
	local planes = {}
	local function box(name, x, y, z, w, h, d, color, collision)
		local p = {
			Name = name,
			X = x,
			Y = y,
			Z = z,
			W = w,
			H = h,
			D = d,
			Color = color or "HumanDark",
			Collision = collision ~= false,
		}
		table.insert(result.Parts, p)
		return p
	end
	local function rect(x, z, w, d)
		return { x - w / 2, z - d / 2, x + w / 2, z + d / 2 }
	end
	local function reserve(r)
		table.insert(result.Reservations, r)
	end
	local function cutAll(pieces, cuts)
		for _, cut in ipairs(cuts) do
			local nextPieces = {}
			for _, piece in ipairs(pieces) do
				for _, p in ipairs(clipping.subtract(piece, cut)) do
					table.insert(nextPieces, p)
				end
			end
			pieces = nextPieces
		end
		return pieces
	end
	-- Stair wells are registered BEFORE any floor generation.
	for _, b in ipairs(plan.Buildings) do
		local p = plan.Nodes[b.Ground]
		for _, y in ipairs({ 36, 72 }) do
			result.Holes[y] = result.Holes[y] or {}
			table.insert(result.Holes[y], rect(p.X + 29, p.Z - 12, 36, 72))
		end
		reserve(rect(p.X, p.Z, 100, 124))
	end
	for _, e in ipairs(plan.Edges) do
		if e.Kind == "UndergroundStair" then
			local p = plan.Nodes[e[1]]
			result.Holes[0] = result.Holes[0] or {}
			table.insert(result.Holes[0], rect(p.X, p.Z + 52, 22, 104))
			reserve(rect(p.X, p.Z + 52, 26, 112))
		end
	end
	local function floor(name, x, y, z, w, d, color)
		local pieces = cutAll({ rect(x, z, w, d) }, result.Holes[y] or {})
		planes[y] = planes[y] or {}
		pieces = cutAll(pieces, planes[y])
		for _, r in ipairs(pieces) do
			if r[3] - r[1] > 0.01 and r[4] - r[2] > 0.01 then
				table.insert(planes[y], r)
				local p = box(name, (r[1] + r[3]) / 2, y - 0.5, (r[2] + r[4]) / 2, r[3] - r[1], 1, r[4] - r[2], color)
				table.insert(result.Floors, p)
			end
		end
	end
	local function segment(name, a, b, width, color)
		assert(a.Y == b.Y and (a.X == b.X or a.Z == b.Z), "Non-axis route " .. name)
		local w, d = math.abs(a.X - b.X) + width, math.abs(a.Z - b.Z) + width
		floor(name, (a.X + b.X) / 2, a.Y, (a.Z + b.Z) / 2, w, d, color)
		if a.Y >= 0 then
			reserve(rect((a.X + b.X) / 2, (a.Z + b.Z) / 2, w + 4, d + 4))
		end
	end
	local function point(x, y, z)
		return { X = x, Y = y, Z = z }
	end
	local function stairs(name, x, z, y, dir, rise, count, width, tread)
		local samples = {}
		for i = 1, count do
			local top = y + rise * i
			local zz = z + dir * tread * (i - 0.5)
			box(name .. "Step", x, top - 0.4, zz, width, 0.8, i == count and tread or tread + 0.2, "Human")
			table.insert(samples, point(x, top, zz))
		end
		table.insert(result.Stairs, {
			Name = name,
			Samples = samples,
			Width = width,
			Bottom = point(x, y, z),
			Top = point(x, y + rise * count, z + dir * tread * count),
		})
	end
	local function interiorVariation(b, p, y)
		local name, style = b.Name, b.Style
		local function detail(partName, x, height, z, width, depth, color)
			-- Interior detail reads as circulation variation but stays out of the
			-- enemy-compatible core path until final collision/art passes.
			box(partName, x, y + height / 2, z, width, height, depth, color, false)
		end
		if style == "BunkHall" then
			for _, z in ipairs({ -38, -12, 18, 44 }) do
				detail(name .. "BunkBay", p.X - 29, 6, p.Z + z, 24, 18, "HumanDark")
			end
			detail(name .. "GuardPost", p.X - 16, 8, p.Z - 50, 14, 10, "Military")
		elseif style == "TrainingHall" then
			for _, x in ipairs({ -30, -10, 10 }) do
				detail(name .. "TrainingBarrier", p.X + x, 4, p.Z + 20, 10, 6, "Military")
			end
			detail(name .. "ObservationDais", p.X - 30, 6, p.Z + 42, 24, 18, "HumanDark")
		elseif style == "DenseCells" then
			for _, z in ipairs({ -42, -18, 8, 34 }) do
				detail(name .. "CellPartition", p.X - 30, 16, p.Z + z, 30, 2, "HumanDark")
			end
			detail(name .. "SharedTable", p.X - 4, 4, p.Z + 26, 14, 10, "Human")
		elseif style == "SplitLevel" then
			detail(name .. "RaisedLivingBay", p.X - 31, 4, p.Z + 28, 26, 42, "HumanDark")
			detail(name .. "LowDivider", p.X - 14, 8, p.Z - 32, 2, 38, "Human")
			detail(name .. "ExteriorAddition", p.X + 34, 20, p.Z + 44, 20, 14, "HumanDark")
		elseif style == "CourtyardRooms" then
			for _, z in ipairs({ -34, 0, 34 }) do
				detail(name .. "CourtyardAlcove", p.X - 31, 12, p.Z + z, 24, 2, "HumanDark")
			end
			detail(name .. "RearSharedRoom", p.X + 5, 10, p.Z + 42, 26, 20, "Human")
		elseif style == "OpenWorkshop" then
			for _, z in ipairs({ -28, 0, 28 }) do
				detail(name .. "WorkBench", p.X - 28, 6, p.Z + z, 28, 8, "HumanDark")
			end
			detail(name .. "LoadingPlatform", p.X + 30, 8, p.Z + 38, 22, 20, "Military")
		elseif style == "StorageWorkshop" then
			for _, z in ipairs({ -40, -12, 16, 44 }) do
				detail(name .. "StorageStack", p.X - 30, 10, p.Z + z, 22, 16, "HumanDark")
			end
			detail(name .. "ServiceBench", p.X + 5, 6, p.Z - 36, 22, 10, "Human")
		elseif style == "GatheringHall" then
			for _, z in ipairs({ -34, 34 }) do
				detail(name .. "MarketStall", p.X - 28, 6, p.Z + z, 26, 14, "HumanDark")
				detail(name .. "MarketStall", p.X + 6, 6, p.Z + z, 16, 14, "Human")
			end
			detail(name .. "GatheringDais", p.X - 30, 6, p.Z, 22, 22, "Military")
		end
	end
	-- Ground routes, then buildings. All floors at a given height are clipped
	-- against preceding floors: no visible coplanar overlap, including junctions.
	for i, e in ipairs(plan.Edges) do
		if e.Kind == "Street" or e.Kind == "Alley" then
			local pts = e.Points or { plan.Nodes[e[1]], plan.Nodes[e[2]] }
			for n = 2, #pts do
				segment(
					"Route" .. i,
					pts[n - 1],
					pts[n],
					e.SegmentWidths and e.SegmentWidths[n - 1] or e.Width,
					"Human"
				)
			end
		end
	end
	for i, branch in ipairs(plan.Hive and plan.Hive.Branches or {}) do
		for n = 2, #branch do
			local a, b = branch[n - 1], branch[n]
			if a[2] == b[2] then
				segment("HiveBranch" .. i, point(a[1], a[2], a[3]), point(b[1], b[2], b[3]), 8, "Human")
			else
				local length = math.abs(b[1] - a[1]) + math.abs(b[3] - a[3])
				local dx, dz = (b[1] - a[1]) / length, (b[3] - a[3]) / length
				local count = math.ceil(math.abs(b[2] - a[2]) / 0.5)
				for step = 1, count do
					local t = (step - 0.5) / count
					local top = a[2] + (b[2] - a[2]) * step / count
					box(
						"HiveBranchStep",
						a[1] + (b[1] - a[1]) * t,
						top - 0.4,
						a[3] + (b[3] - a[3]) * t,
						dx == 0 and 8 or length / count + 0.2,
						0.8,
						dz == 0 and 8 or length / count + 0.2,
						"Human"
					)
				end
				floor(
					"HiveBranchLanding",
					b[1] + dx * 2,
					b[2],
					b[3] + dz * 2,
					dx == 0 and 8 or 4,
					dz == 0 and 8 or 4,
					"Human"
				)
				reserve(
					rect(
						(a[1] + b[1]) / 2 + dx * 2,
						(a[3] + b[3]) / 2 + dz * 2,
						math.abs(a[1] - b[1]) + 12,
						math.abs(a[3] - b[3]) + 12
					)
				)
			end
		end
	end
	for i = 1, 15 do
		local p = plan.Nodes["S" .. i]
		-- Most intersections are occupied human junctions; only selected primary
		-- nodes retain a broader market/military release for multi-enemy combat.
		local size = (i == 1 or i == 5 or i == 10) and 50 or 30
		floor("Court" .. i, p.X, 0, p.Z, size, size, "Human")
		reserve(rect(p.X, p.Z, size + 4, size + 4))
	end
	for _, b in ipairs(plan.Buildings) do
		local p = plan.Nodes[b.Ground]
		local roof = b.Roof and 72 or 36
		for _, side in ipairs({ -1, 1 }) do
			floor(b.Name .. "UpperBalcony", p.X, 36, p.Z + side * 65, 24, 14, "HumanDark")
			reserve(rect(p.X, p.Z + side * 65, 28, 18))
		end
		for y = 0, roof, 36 do
			floor(b.Name .. "Floor", p.X, y, p.Z, 96, 120, "Human")
			if y < roof then
				-- Full side walls, front/rear walls with actual 18 x 14 openings.
				for _, side in ipairs({ -1, 1 }) do
					box(b.Name .. "SideWall", p.X + side * 47, y + 17.5, p.Z, 2, 35, 120)
					for _, x in ipairs({ -28.5, 28.5 }) do
						box(b.Name .. "DoorWall", p.X + x, y + 17.5, p.Z + side * 59, 39, 35, 2)
					end
					box(b.Name .. "DoorLintel", p.X, y + 24.5, p.Z + side * 59, 18, 21, 2)
					table.insert(result.Doors, { X = p.X, Y = y, Z = p.Z + side * 59, Width = 18, Height = 14 })
				end
				-- Side rooms open onto the central north/south circulation hall.
				if b.Style ~= "TrainingHall" and b.Style ~= "OpenWorkshop" and b.Style ~= "GatheringHall" then
					for _, z in ipairs({ -26, 26 }) do
						box(b.Name .. "RoomPartition", p.X - 29, y + 8, p.Z + z, 34, 16, 2)
					end
				end
				interiorVariation(b, p, y)
				-- Two broad flights, with side-by-side returns in a reserved well.
				stairs(b.Name .. "Up", p.X + 20, p.Z - 48, y, 1, 0.75, 24, 12, 2)
				floor(b.Name .. "HalfLanding", p.X + 29, y + 18, p.Z + 8, 36, 16, "Human")
				stairs(b.Name .. "Return", p.X + 38, p.Z, y + 18, -1, 0.75, 24, 12, 2)
				-- Bottom and top landings connect the stairwell to the central hall.
				floor(b.Name .. "EntryLanding", p.X + 20, y, p.Z - 56, 52, 8, "Human")
			end
		end
		-- Upper habitable level has rooms and side walls even without roof access.
		if not b.Roof then
			for _, side in ipairs({ -1, 1 }) do
				box(b.Name .. "UpperSideWall", p.X + side * 47, 48, p.Z, 2, 24, 120)
			end
			for _, z in ipairs({ -26, 26 }) do
				box(b.Name .. "UpperRoomPartition", p.X - 29, 44, p.Z + z, 34, 16, 2)
			end
			for _, side in ipairs({ -1, 1 }) do
				for _, x in ipairs({ -28.5, 28.5 }) do
					box(b.Name .. "UpperDoorWall", p.X + x, 48, p.Z + side * 59, 39, 24, 2)
				end
				box(b.Name .. "UpperDoorLintel", p.X, 55, p.Z + side * 59, 18, 10, 2)
				table.insert(result.Doors, { X = p.X, Y = 36, Z = p.Z + side * 59, Width = 18, Height = 14 })
			end
			box(b.Name .. "SealedRoof", p.X, 61, p.Z, 96, 2, 120, "HumanDark")
		end
	end
	-- Underground junction rooms and bent passages, entirely below street level.
	for _, id in ipairs(plan.UndergroundNodes) do
		local p = plan.Nodes[id]
		floor(id .. "Junction", p.X, p.Y, p.Z, 34, 34, "AncientDark")
	end
	for i, e in ipairs(plan.Edges) do
		if e.Kind == "Tunnel" then
			for n = 2, #e.Points do
				segment("Utility" .. i, e.Points[n - 1], e.Points[n], e.Width, "AncientDark")
			end
		elseif e.Kind == "UndergroundStair" then
			local a, b = plan.Nodes[e[1]], plan.Nodes[e[2]]
			-- First tread touches the court; final tread meets the bottom landing.
			stairs("Maintenance" .. i, a.X, a.Z, 0, 1, -0.75, 48, 18, 2)
			floor("MaintenanceBottom", a.X, -36, a.Z + 104, 22, 16, "Human")
			segment("BasementLink", point(a.X, -36, a.Z + 104), point(b.X, -36, a.Z + 104), 18, "AncientDark")
			segment("BasementLink", point(b.X, -36, a.Z + 104), b, 18, "AncientDark")
		end
	end
	-- Build tunnel walls around the UNION of floor rectangles, not across
	-- junctions. Ceilings stay above the 14-stud clear passage height.
	local tunnelRects = planes[-36] or {}
	local wallRects = {}
	for _, r in ipairs(tunnelRects) do
		for _, side in ipairs({
			{ r[1] - 2, r[2], r[1], r[4] },
			{ r[3], r[2], r[3] + 2, r[4] },
			{ r[1], r[2] - 2, r[3], r[2] },
			{ r[1], r[4], r[3], r[4] + 2 },
		}) do
			for _, piece in ipairs(cutAll(cutAll(cutAll({ side }, tunnelRects), wallRects), result.Holes[0])) do
				table.insert(wallRects, piece)
				box(
					"UtilityWall",
					(piece[1] + piece[3]) / 2,
					-28,
					(piece[2] + piece[4]) / 2,
					piece[3] - piece[1],
					16,
					piece[4] - piece[2],
					"AncientDark"
				)
			end
		end
	end
	-- Covered tunnels exclude surface stair shafts, including their headroom.
	result.Holes[-20] = result.Holes[0]
	for _, r in ipairs(tunnelRects) do
		floor("UtilityCeiling", (r[1] + r[3]) / 2, -20, (r[2] + r[4]) / 2, r[3] - r[1], r[4] - r[2], "AncientDark")
	end
	for i, e in ipairs(plan.Edges) do
		if e.Kind == "Catwalk" or e.Kind == "RoofBridge" then
			local pts = e.Points or { plan.Nodes[e[1]], plan.Nodes[e[2]] }
			for n = 2, #pts do
				segment("UpperRoute" .. i, pts[n - 1], pts[n], e.Width, "HumanDark")
			end
		end
	end
	-- Remaining ordinary ground is a single non-overlapping surface partition;
	-- the four stair shafts are intentionally cut out of it.
	floor("NeighborhoodPaving", 0, 0, 1050, 1400, 1400, "HumanDark")
	reserve(rect(460, 650, 128, 128))
	local walks = {}
	for _, e in ipairs(plan.Edges) do
		if e.Kind == "Street" or e.Kind == "Alley" then
			local pts = e.Points or { plan.Nodes[e[1]], plan.Nodes[e[2]] }
			for i = 2, #pts do
				local a, b = pts[i - 1], pts[i]
				local width = e.SegmentWidths and e.SegmentWidths[i - 1] or e.Width
				table.insert(
					walks,
					rect((a.X + b.X) / 2, (a.Z + b.Z) / 2, math.abs(a.X - b.X) + width, math.abs(a.Z - b.Z) + width)
				)
			end
		end
	end
	for _, branch in ipairs(plan.Hive and plan.Hive.Branches or {}) do
		for i = 2, #branch do
			local a, b = branch[i - 1], branch[i]
			table.insert(
				walks,
				rect((a[1] + b[1]) / 2, (a[3] + b[3]) / 2, math.abs(a[1] - b[1]) + 8, math.abs(a[3] - b[3]) + 8)
			)
		end
	end
	-- Protect old working doorways/stairs where the new fabric meets them.
	for _, b in ipairs(plan.Buildings) do
		local p = plan.Nodes[b.Ground]
		table.insert(walks, rect(p.X, p.Z, 108, 144))
	end
	for i, r in ipairs(plan.Hive and plan.Hive.Accretions or {}) do
		local heights = { 0, r[5] }
		for _, y in ipairs({ 36, 72 }) do
			if y + 0.51 < r[5] then
				table.insert(heights, y + 0.51)
			end
			if y + 10 < r[5] then
				table.insert(heights, y + 10)
			end
		end
		table.sort(heights)
		for level = 2, #heights do
			local low, high = heights[level - 1], heights[level]
			local cuts = {}
			for _, edge in ipairs(plan.Edges) do
				if edge.Kind == "Catwalk" or edge.Kind == "RoofBridge" then
					local pts = edge.Points or { plan.Nodes[edge[1]], plan.Nodes[edge[2]] }
					for k = 2, #pts do
						local a, b = pts[k - 1], pts[k]
						if low >= a.Y + 0.5 and high <= a.Y + 10 then
							table.insert(
								cuts,
								rect(
									(a.X + b.X) / 2,
									(a.Z + b.Z) / 2,
									math.abs(a.X - b.X) + edge.Width,
									math.abs(a.Z - b.Z) + edge.Width
								)
							)
						end
					end
				end
			end
			for _, piece in ipairs(cutAll({ { r[1], r[2], r[3], r[4] } }, cuts)) do
				box(
					"AccretedServiceWing" .. i,
					(piece[1] + piece[3]) / 2,
					(low + high) / 2,
					(piece[2] + piece[4]) / 2,
					piece[3] - piece[1],
					high - low,
					piece[4] - piece[2],
					i % 2 == 0 and "Human" or "HumanDark"
				)
			end
		end
		reserve({ r[1], r[2], r[3], r[4] })
		for y = 16, r[5] - 8, 16 do
			box("OccupiedWingLintel", (r[1] + r[3]) / 2, y, r[2] - 0.2, r[3] - r[1], 0.7, 0.5, "Military", false)
			box(
				"OccupiedWingWindow",
				(r[1] + r[3]) / 2,
				y - 4,
				r[2] - 0.1,
				math.min(6, r[3] - r[1] - 4),
				5,
				0.25,
				"AncientDark",
				false
			)
		end
	end
	for _, e in ipairs(plan.Edges) do
		if e.Spaces then
			local pts = e.Points
			for i = 2, #pts do
				local space = e.Spaces[i - 1]
				if space == "Room" or space == "Covered" or space == "Service" then
					local a, b = pts[i - 1], pts[i]
					local width = e.SegmentWidths[i - 1]
					local x, z = (a.X + b.X) / 2, (a.Z + b.Z) / 2
					local w, d = math.abs(a.X - b.X) + width + 2, math.abs(a.Z - b.Z) + width + 2
					local shellCuts = {}
					for _, building in ipairs(plan.Buildings) do
						local p = plan.Nodes[building.Ground]
						table.insert(shellCuts, rect(p.X, p.Z, 108, 144))
					end
					for _, r in ipairs(cutAll({ rect(x, z, w, d) }, shellCuts)) do
						box(
							"Hive" .. space .. "Ceiling",
							(r[1] + r[3]) / 2,
							14.5,
							(r[2] + r[4]) / 2,
							r[3] - r[1],
							1,
							r[4] - r[2],
							"HumanDark"
						)
					end
					for _, side in ipairs({ -1, 1 }) do
						local vertical = a.X == b.X
						local wall = rect(
							x + (vertical and side * (width / 2 + 0.5) or 0),
							z + (vertical and 0 or side * (width / 2 + 0.5)),
							vertical and 1 or w,
							vertical and d or 1
						)
						for _, r in ipairs(cutAll({ wall }, walks)) do
							box(
								"Hive" .. space .. "Wall",
								(r[1] + r[3]) / 2,
								7,
								(r[2] + r[4]) / 2,
								r[3] - r[1],
								14,
								r[4] - r[2],
								"Human"
							)
						end
					end
				end
			end
		end
	end
	result.Planes = planes
	return result
end

return Geometry
