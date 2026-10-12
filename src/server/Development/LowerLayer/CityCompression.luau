--!strict
-- Phase A architecture follows existing reservations; it never authors routes.
-- The approved static buildings remain unchanged, including their internal depth.
local City = {}
City.Bounds = { -675, 350, 675, 1750 }
local function overlaps(a, b)
	return a[1] < b[3] and a[3] > b[1] and a[2] < b[4] and a[4] > b[2]
end
local function rect(x, z, w, d)
	return { x - w / 2, z - d / 2, x + w / 2, z + d / 2 }
end
function City.build(plan, geometry, clipping, lots, pilot, pilotModule, sites)
	local result = { Parts = {}, Assets = {}, RetainedLots = {}, Homes = {}, Overbuilds = 0 }
	local cuts = {}
	for _, r in ipairs(geometry.Reservations) do
		table.insert(cuts, r)
	end
	for _, s in ipairs(plan.SpawnCandidates) do
		local p = s.Position or plan.Nodes[s.Node]
		if p.Y + s.Offset.Y == 0 then
			table.insert(cuts, rect(p.X + s.Offset.X, p.Z + s.Offset.Z, 8, 8))
		end
	end

	local function box(name, x, y, z, w, h, d, color, collision)
		table.insert(result.Parts, {
			Name = "City_" .. name,
			X = x,
			Y = y,
			Z = z,
			W = w,
			H = h,
			D = d,
			Color = color or "HumanDark",
			Collision = collision ~= false,
		})
	end
	local function position(a, u, v)
		local angle = math.rad(a.Yaw)
		return a.X + math.cos(angle) * u + math.sin(angle) * v, a.Z - math.sin(angle) * u + math.cos(angle) * v
	end
	-- Keep detailed buildings as anchors, not as a mandate for straight roads.
	for _, a in ipairs(pilotModule.Assets) do
		table.insert(cuts, { a.Bounds[1] - 3, a.Bounds[2] - 3, a.Bounds[3] + 3, a.Bounds[4] + 3 })
	end
	for _, site in ipairs(sites) do
		local a = {}
		for k, v in pairs(site) do
			a[k] = v
		end
		local vertical = a.Yaw == 90 or a.Yaw == -90
		local front = a.Name == "Commercial" and 8 or 17
		local half = a.Name == "Commercial" and 56 or 48
		local x, z = position(a, 0, (38 - front) / 2)
		a.Bounds = rect(x, z, vertical and 38 + front or half * 2, vertical and half * 2 or 38 + front)
		table.insert(result.Assets, a)
		table.insert(cuts, a.Bounds)
		if a.Name == "Commercial" then
			local hx, hz = position(a, -47, 14)
			local ex, ez = position(a, -47, -1)
			table.insert(result.Homes, { X = hx, Z = hz, EntryX = ex, EntryZ = ez })
		end
	end
	for _, r in ipairs(plan.Hive.Accretions) do
		table.insert(cuts, { r[1], r[2], r[3], r[4] })
	end
	-- Infill is subordinate to the new circulation and occupied extensions.
	for i, r in ipairs(lots) do
		do
			local pieces = {
				{
					math.max(-675, r[1] - 3.5),
					math.max(350, r[2] - 3),
					math.min(675, r[3] + 3.5),
					math.min(1750, r[4] + 3),
				},
			}
			for _, cut in ipairs(cuts) do
				local nextPieces = {}
				for _, piece in ipairs(pieces) do
					for _, fragment in ipairs(clipping.subtract(piece, cut)) do
						table.insert(nextPieces, fragment)
					end
				end
				pieces = nextPieces
			end
			for _, f in ipairs(pieces) do
				local w, d = f[3] - f[1], f[4] - f[2]
				if w >= 2 and d >= 2 then
					local x, z = (f[1] + f[3]) / 2, (f[2] + f[4]) / 2
					box("OccupiedBlock", x, 44, z, w, 88, d)
					local top = 220 + (i % 6) * 40
					box("UpperHabitation", x, (88 + top) / 2, z, w, top - 88, d, "Human", false)
					-- Restrained recessed-looking residential panels and masonry surrounds.
					-- They stay within the solid footprint, never protruding into a lane.
					if w >= 16 and d >= 16 then
						-- Detail the nearest ground-route-facing side only. Hidden
						-- party walls do not need thousands of replicated trim Parts.
						local nearest, distance = nil, 65
						for _, edge in ipairs(plan.Edges) do
							if edge.Kind == "Street" or edge.Kind == "Alley" then
								local points = edge.Points or { plan.Nodes[edge[1]], plan.Nodes[edge[2]] }
								for k = 2, #points do
									local a, b = points[k - 1], points[k]
									if a.X == b.X and z >= math.min(a.Z, b.Z) and z <= math.max(a.Z, b.Z) then
										local delta = math.abs(a.X - x) - w / 2
										if delta < distance then
											nearest = { Axis = "X", Sign = a.X < x and -1 or 1 }
											distance = delta
										end
									elseif a.Z == b.Z and x >= math.min(a.X, b.X) and x <= math.max(a.X, b.X) then
										local delta = math.abs(a.Z - z) - d / 2
										if delta < distance then
											nearest = { Axis = "Z", Sign = a.Z < z and -1 or 1 }
											distance = delta
										end
									end
								end
							end
						end
						if nearest then
							local vertical = nearest.Axis == "X"
							local length = vertical and d or w
							for y = 16, 76, 20 do
								for u = -length / 2 + 8, length / 2 - 6, 18 do
									local px = vertical and x + nearest.Sign * (w / 2 - 0.08) or x + u
									local pz = vertical and z + u or z + nearest.Sign * (d / 2 - 0.08)
									box(
										"WindowReveal",
										px,
										y,
										pz,
										vertical and 0.2 or 4.8,
										7,
										vertical and 4.8 or 0.2,
										"AncientDark",
										false
									)
									box(
										"WindowSill",
										px,
										y - 3.6,
										pz,
										vertical and 0.3 or 5.4,
										0.5,
										vertical and 5.4 or 0.3,
										"Military",
										false
									)
								end
							end
						end
					end
				end
			end
		end
	end
	-- Back-supported upper occupation above each approved building, never in its
	-- rooms. The ground floor, roofline and source model proportions stay intact.
	for _, a in ipairs(result.Assets) do
		local x, z = position(a, 0, 22)
		local vertical = a.Yaw == 90 or a.Yaw == -90
		local width = a.Name == "Commercial" and 102 or 86
		local base = a.Name == "Commercial" and 87 or 88
		box(
			"BuildingUpperOccupation",
			x,
			(base + 230) / 2,
			z,
			vertical and 26 or width,
			230 - base,
			vertical and width or 26,
			"HumanDark",
			false
		)
	end
	return result
end
return City
