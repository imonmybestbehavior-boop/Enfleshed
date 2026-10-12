--!strict
-- Shared stairs, cross-property halls and two inter-building circulation tiers.
-- Pure geometry, consumed identically by Studio assembly and offline validation.
local Circulation = {}
function Circulation.position(a, x, y, z)
	local angle = math.rad(a.Yaw)
	local c, s = math.floor(math.cos(angle) + 0.5), math.floor(math.sin(angle) + 0.5)
	return a.X + c * x + s * z, y, a.Z - s * x + c * z
end
function Circulation.removeSourcePart(name, y)
	return name == "RoomShadow"
		or name == "ClosedInnerResidentialDoor"
		or name == "EntryHallRear"
		or name == "InnerDoorFrame"
		or name == "InnerDoorHeader"
		or (name == "ApartmentFloor" and (y == 36 or y == 52 or y == 68))
		or name == "FloorSlab_33"
		or name == "FloorSlab_65"
		or name == "FloorSlab_49"
end
function Circulation.build(data, plan, solid)
	local out = { Parts = {}, Cuts = {}, Samples = {}, Lights = {}, Links = data.Links, Buildings = data.Buildings }
	local walkCuts = {}
	local function box(name, x, y, z, w, h, d, color)
		local p = {
			Name = "Circulation_" .. name,
			X = x,
			Y = y,
			Z = z,
			W = w,
			H = h,
			D = d,
			Color = color or "HumanDark",
			Collision = true,
		}
		table.insert(out.Parts, p)
		return p
	end
	local function sample(name, x, y, z)
		table.insert(out.Samples, { Name = name, X = x, Y = y, Z = z })
	end
	local function segmentSamples(name, a, b, y)
		local steps = math.max(1, math.ceil((math.abs(a[1] - b[1]) + math.abs(a[2] - b[2])) / 2))
		for i = 0, steps do
			sample(name, a[1] + (b[1] - a[1]) * i / steps, y, a[2] + (b[2] - a[2]) * i / steps)
		end
	end
	for i, a in ipairs(data.Buildings) do
		local residential = a.Name == "Tenement"
		local base = residential and 4.5 or 0
		local half = residential and 46 or 54
		local function localBox(n, x, y, z, w, h, d, c)
			local xx, yy, zz = Circulation.position(a, x, y, z)
			local turn = a.Yaw == 90 or a.Yaw == -90
			return box(i .. "_" .. n, xx, yy, zz, turn and d or w, h, turn and w or d, c)
		end
		local function cut(x1, y1, z1, x2, y2, z2)
			local p = localBox("Cut", (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2, x2 - x1, y2 - y1, z2 - z1)
			table.remove(out.Parts)
			table.insert(out.Cuts, solid.bounds(p))
		end
		local function localSample(n, x, y, z)
			sample(i .. "_" .. n, Circulation.position(a, x, y, z))
		end
		local function localPath(n, x, z, xx, zz, y)
			local ax, _, az = Circulation.position(a, x, y, z)
			local bx, _, bz = Circulation.position(a, xx, y, zz)
			segmentSamples(i .. "_" .. n, { ax, az }, { bx, bz }, y)
			table.insert(walkCuts, {
				math.min(ax, bx) - 4,
				y + 0.01,
				math.min(az, bz) - 4,
				math.max(ax, bx) + 4,
				y + 12,
				math.max(az, bz) + 4,
			})
		end
		-- Shops remain distinct at the street but open into a shared back passage.
		-- Residential inner doors are removed; the two halls now feed a common stair.
		cut(-half + 2, base + 0.01, 12, half - 2, base + 12, 20)
		cut(-28, base + 0.01, 8, -18, base + 12, 30)
		cut(-18, base + 0.01, 7, 42, 80.5, 28)
		local doors = residential and { -23, 21 } or { -47, -2, 9, 47 }
		for _, door in ipairs(doors) do
			localPath("Entry", door, 8, door, 16, base)
			localPath("SharedGroundHall", door, 16, -23, 16, base)
		end
		localPath("StairApproach", -23, 16, -23, 23, base)
		localPath("StairApproach", -23, 23, -10, 23, base)
		-- Four compact flights: broad treads, supported returns, no precision jumps.
		local levels = { base, residential and 20.5 or 18, 36.5, 52.5, 68.5 }
		for flight = 1, 4 do
			local low, high = levels[flight], levels[flight + 1]
			local forward = flight % 2 == 1
			local z = forward and 23 or 11
			for step = 1, 28 do
				local x = forward and (-10 + (step - 0.5) * 1.5) or (32 - (step - 0.5) * 1.5)
				local top = low + (high - low) * step / 28
				localBox("StairTread", x, top - 0.4, z, 1.6, 0.8, 8, "Human")
				localSample("Stair", x, top, z)
				if step % 4 == 0 then
					local gx = forward and x - 2.25 or x + 2.25
					for _, side in ipairs({ -1, 1 }) do
						localBox("StairGuard", gx, top + 1.8, z + side * 4.25, 6.05, 3.6, 0.4, "Military")
					end
				end
			end
			local x = forward and 36.5 or -14
			localBox("ReturnLanding", x, high - 0.5, 17, forward and 9 or 8, 1, 20, "Human")
			localPath("Landing", forward and 32 or -10, z, x, z, high)
			localPath("Landing", x, 23, x, 11, high)
			localBox("WellFrontGuard", 7, high + 1.8, 6.9, 50, 3.6, 0.4, "Military")
			localBox("WellRearGuard", 12, high + 1.8, 28.2, 60, 3.6, 0.4, "Military")
			if forward then
				-- The half landings also open onto the existing intermediate-floor rooms.
				localPath("IntermediateRoom", 36.5, 11, 36.5, 4.5, high)
				if flight == 3 then
					localPath("UpperHall", 36.5, 4.5, -23, 4.5, high)
					localPath("UpperHall", -23, 4.5, -23, 30.5, high)
					localPath("SideExit", -23, 30.5, -half - 1, 30.5, high)
				end
			else
				localPath("UpperHall", -14, 11, -23, 11, high)
				localPath("UpperHall", -23, 11, -23, flight == 4 and 29 or 30.5, high)
				if flight == 2 then
					localPath("SideExit", -23, 30.5, -half - 1, 30.5, high)
				end
			end
		end
		-- Public upper floors connect rooms as well as the stair. Each floor has a
		-- generous stairwell opening; a side gallery leads to actual party-wall exits.
		for _, y in ipairs({ 36.5, 52.5, 68.5 }) do
			if y ~= 68.5 then
				cut(-half - 2, y - 0.51, 25.5, -18, y + 12, 36.5)
			end
			local floor = {
				Name = "UpperFloor",
				X = 0,
				Y = y - 0.5,
				Z = 17,
				W = 2 * half - 4,
				H = 1,
				D = 32,
				Color = "Human",
				Collision = true,
			}
			for _, p in ipairs(solid.parts(floor, { { -18, y - 1, 7, 42, y + 1, 28 } })) do
				localBox(p.Name, p.X, p.Y, p.Z, p.W, p.H, p.D, p.Color)
			end
			if y ~= 68.5 then
				localBox("SideGallery", (-half - 1 - 18) / 2, y - 0.5, 30.5, half - 17, 1, 10, "Human")
				localBox("GalleryRear", (-half - 1 - 18) / 2, y + 6, 35.5, half - 17, 12, 1)
			end
			-- Two real rooms beside the public gallery. Continuous partitions,
			-- framed openings and the existing outer walls enclose usable space.
			for _, span in ipairs({ { 2, 5 }, { 13, 18 }, { 26, 27 } }) do
				localBox("RoomPartition", -29, y + 5.5, (span[1] + span[2]) / 2, 1, 11, span[2] - span[1], "Human")
			end
			for _, doorZ in ipairs({ 9, 22 }) do
				localBox("RoomDoorHeader", -29, y + 10, doorZ, 1.4, 2, 8, "Military")
				localPath("RoomEntry", -23, doorZ, -half + 10, doorZ, y)
			end
			localBox("RoomDivider", (-half + 2 - 29) / 2, y + 5.5, 15.5, half - 31, 11, 1, "Human")
			localBox("RoomRearPartition", (-half + 2 - 29) / 2, y + 5.5, 27, half - 31, 11, 1, "Human")
			localBox("GalleryDoorHeader", -29, y + 10, 30.5, 1.4, 2, 7, "Military")
			localBox("GalleryGuard", -18.5, y + 1.8, 20, 1, 3.6, 12, "Military")
			local lx, ly, lz = Circulation.position(a, -23, y + 9, 30.5)
			table.insert(out.Lights, { X = lx, Y = ly, Z = lz })
		end
		local lx, ly, lz = Circulation.position(a, -23, base + 10, 16)
		table.insert(out.Lights, { X = lx, Y = ly, Z = lz })
	end
	-- Collect every passage's clear volume before constructing its walls. This
	-- makes shared junctions open; overlapping corridor modules cannot seal exits.
	local segments = {}
	for i, link in ipairs(data.Links) do
		for k = 2, #link.Points do
			local a, b = link.Points[k - 1], link.Points[k]
			local x, z = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
			local width = link.Widths and link.Widths[k - 1] or 10
			local w, d = math.abs(a[1] - b[1]) + width + 2, math.abs(a[2] - b[2]) + width + 2
			table.insert(out.Cuts, { x - w / 2, link.Y - 0.51, z - d / 2, x + w / 2, link.Y + 13, z + d / 2 })
			table.insert(
				walkCuts,
				{ x - (w - 2) / 2, link.Y + 0.01, z - (d - 2) / 2, x + (w - 2) / 2, link.Y + 12, z + (d - 2) / 2 }
			)
			table.insert(segments, {
				A = a,
				B = b,
				Y = link.Y,
				Id = i,
				Width = width,
				Space = link.Spaces and link.Spaces[k - 1] or "Service",
			})
			segmentSamples("Link_" .. i, a, b, link.Y)
		end
	end
	-- Where the new network crosses an old catwalk, retain access both ways.
	for _, edge in ipairs(plan.Edges) do
		if edge.Kind == "Catwalk" or edge.Kind == "RoofBridge" then
			local points = edge.Points or { plan.Nodes[edge[1]], plan.Nodes[edge[2]] }
			for k = 2, #points do
				local a, b = points[k - 1], points[k]
				table.insert(out.Cuts, {
					math.min(a.X, b.X) - edge.Width / 2,
					a.Y + 0.51,
					math.min(a.Z, b.Z) - edge.Width / 2,
					math.max(a.X, b.X) + edge.Width / 2,
					a.Y + 10,
					math.max(a.Z, b.Z) + edge.Width / 2,
				})
				table.insert(walkCuts, {
					math.min(a.X, b.X) - edge.Width / 2,
					a.Y + 0.01,
					math.min(a.Z, b.Z) - edge.Width / 2,
					math.max(a.X, b.X) + edge.Width / 2,
					a.Y + 10,
					math.max(a.Z, b.Z) + edge.Width / 2,
				})
			end
		end
	end
	local laidFloors = {}
	for _, s in ipairs(segments) do
		local a, b, y = s.A, s.B, s.Y
		local x, z = (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
		local w, d = math.abs(a[1] - b[1]) + s.Width + 2, math.abs(a[2] - b[2]) + s.Width + 2
		local open = s.Space == "Balcony" or s.Space == "Bridge"
		laidFloors[y] = laidFloors[y] or {}
		local tile = { X = x, Y = y - 0.5, Z = z, W = w, H = 1, D = d }
		for _, piece in ipairs(solid.parts(tile, laidFloors[y])) do
			box("ConnectingFloor", piece.X, piece.Y, piece.Z, piece.W, 1, piece.D, "Human")
			if not open then
				box("ConnectingCeiling", piece.X, piece.Y + 13, piece.Z, piece.W, 1, piece.D)
			end
			table.insert(laidFloors[y], solid.bounds(piece))
		end
		for _, side in ipairs({ -1, 1 }) do
			local vertical = a[1] == b[1]
			local p = {
				Name = "PassageWall",
				X = x + (vertical and side * (s.Width / 2 + 0.5) or 0),
				Y = y + (open and 1.8 or 6),
				Z = z + (vertical and 0 or side * (s.Width / 2 + 0.5)),
				W = vertical and 1 or w,
				H = open and 3.6 or 12,
				D = vertical and d or 1,
				Color = "HumanDark",
				Collision = true,
			}
			for _, piece in ipairs(solid.parts(p, walkCuts)) do
				box(piece.Name, piece.X, piece.Y, piece.Z, piece.W, piece.H, piece.D, piece.Color)
			end
		end
		if math.abs(a[1] - b[1]) + math.abs(a[2] - b[2]) > 24 then
			table.insert(out.Lights, { X = x, Y = y + 10, Z = z })
		end
	end
	local finished = {}
	for _, p in ipairs(out.Parts) do
		if string.find(p.Name, "GalleryRear") then
			for _, piece in ipairs(solid.parts(p, walkCuts)) do
				table.insert(finished, piece)
			end
		else
			table.insert(finished, p)
		end
	end
	out.Parts = finished
	return out
end
return Circulation
