--!strict
-- Pure placement plan. Each ambient slot has a distinct home; events retain their own routes.
local Layout = {}
function Layout.build(plan, base, fronts, target)
	local roster = {}
	for _, entry in ipairs(base) do
		if #roster >= target then
			return roster
		end
		table.insert(roster, entry)
	end
	for _, front in ipairs(fronts) do
		if front.Enterable and #roster < target then
			table.insert(roster, {
				Name = front.Kind == "Workshop" and "Artisan" or "Merchant",
				Role = front.Kind == "Workshop" and "Worker" or "Shopkeeper",
				Nodes = { "S1", "S1" },
				Position = front.Home,
				District = "StreetFront",
			})
		end
	end
	local segments = {}
	for _, edge in ipairs(plan.Edges) do
		if edge.Kind == "Street" then
			local points = edge.Points or { plan.Nodes[edge[1]], plan.Nodes[edge[2]] }
			for i = 2, #points do
				local a, b = points[i - 1], points[i]
				local dx, dz = b.X - a.X, b.Z - a.Z
				local length = math.sqrt(dx * dx + dz * dz)
				if a.Y == 0 and b.Y == 0 and length >= 24 then
					table.insert(segments, {
						A = a,
						B = b,
						Length = length,
						Width = edge.SegmentWidths and edge.SegmentWidths[i - 1] or edge.Width,
					})
				end
			end
		end
	end
	-- Round-robin across the district before adding a second person to a segment.
	for pass = 1, 4 do
		for i, segment in ipairs(segments) do
			if #roster >= target then
				return roster
			end
			local t = ({ 0.35, 0.7, 0.15, 0.9 })[pass]
			local a, b = segment.A, segment.B
			local side = (i % 2 == 0 and 1 or -1) * (segment.Width / 2 - 4)
			local x = a.X + (b.X - a.X) * t - (b.Z - a.Z) / segment.Length * side
			local z = a.Z + (b.Z - a.Z) * t + (b.X - a.X) / segment.Length * side
			local district = z >= 1380 and "Recruit" or (math.abs(x) > 200 and "Residential" or "Market")
			local roles = district == "Recruit" and { "Recruit", "Guard", "Recruit" }
				or (
					district == "Residential" and { "Resident", "Civilian", "Resident" }
					or { "Worker", "Civilian", "Shopkeeper" }
				)
			local role = roles[(i + pass - 2) % #roles + 1]
			table.insert(roster, {
				Name = role,
				Role = role,
				Nodes = { "S1", "S1" },
				Position = { X = x, Y = 0, Z = z },
				District = district,
			})
		end
	end
	return roster
end
return Layout
