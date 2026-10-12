--!strict
-- One authored S3/S4–B3 validation precinct. No topology edits or city-wide rules.
local Pilot = {}
Pilot.Bounds = { -330, 985, 80, 1310 }
Pilot.Assets = {
	{ Name = "Commercial", X = -18, Z = 1100, Yaw = -90, Bounds = { -54, 1045, -16, 1155 } },
	{ Name = "Tenement", X = -140, Z = 1152, Yaw = -90, Bounds = { -178, 1105, -126, 1199 } },
}
function Pilot.build(plan, geometry, clipping, lots)
	local result = { Parts = {}, ReplacedLots = {}, Cuts = {}, Release = { -32, 1000, 51, 1035 } }
	-- Identify authored lots geometrically, not by unstable procedural ordinals.
	for i, r in ipairs(lots) do
		if
			(r[1] == -195 and r[2] == 1102)
			or (r[1] == -99 and (r[2] == 1046 or r[2] == 1011))
			or (r[1] == 29 and r[2] == 1011)
		then
			result.ReplacedLots[i] = true
		end
	end
	local cuts = {}
	for _, r in ipairs(geometry.Reservations) do
		-- One existing service lane becomes nine studs clear; endpoints and centerline stay fixed.
		if r[1] == -125.5 and r[3] == -114.5 and r[2] < 1000 and r[4] > 1200 then
			table.insert(cuts, { r[1] + 1, r[2], r[3] - 1, r[4] })
		else
			table.insert(cuts, r)
		end
	end
	for _, asset in ipairs(Pilot.Assets) do
		table.insert(cuts, asset.Bounds)
	end
	table.insert(cuts, result.Release)
	-- All current event/ambient spawn points remain usable, including avenue edges.
	for _, s in ipairs(plan.SpawnCandidates) do
		local p = s.Position or plan.Nodes[s.Node]
		if p.Y + s.Offset.Y == 0 then
			local x, z = p.X + s.Offset.X, p.Z + s.Offset.Z
			table.insert(cuts, { x - 4, z - 4, x + 4, z + 4 })
		end
	end
	local function box(name, x, y, z, w, h, d, color)
		table.insert(result.Parts, {
			Name = "Pilot_" .. name,
			X = x,
			Y = y,
			Z = z,
			W = w,
			H = h,
			D = d,
			Color = color or "HumanDark",
			Collision = true,
		})
	end
	local function mass(name, r, height)
		local fragments = { r }
		for _, cut in ipairs(cuts) do
			local remaining = {}
			for _, piece in ipairs(fragments) do
				for _, fragment in ipairs(clipping.subtract(piece, cut)) do
					table.insert(remaining, fragment)
				end
			end
			fragments = remaining
		end
		for _, r in ipairs(fragments) do
			if r[3] - r[1] >= 2 and r[4] - r[2] >= 2 then
				box(name, (r[1] + r[3]) / 2, height / 2, (r[2] + r[4]) / 2, r[3] - r[1], height, r[4] - r[2])
			end
		end
	end
	-- Continuous occupied block backs close the former unassigned pavement gaps.
	-- Route/building reservations carve real connected passages out of these masses.
	mass("ResidentialBlockBack", { -207, 1012, -112, 1270 }, 88)
	mass("CommercialBlockBack", { -116, 1035, -18, 1184 }, 92)
	mass("EasternWorkshopWall", { 29, 1035, 80, 1184 }, 72)
	-- Replaced intersection lot becomes a bounded release; retain its occupied far side.
	mass("YardWorkshopWing", { 29, 1011, 77, 1058 }, 64)
	mass("YardServiceWing", { -99, 1011, -27, 1035 }, 64)
	-- Upper additions bear on the new block masses and old housing, never on paths.
	box("CommercialUpperHabitation", -64, 122, 1100, 92, 72, 108)
	box("TenementUpperHabitation", -169, 125, 1152, 78, 74, 104)
	local function overbuild(name, x, y, z, w, h, d, windows)
		-- Actual enclosed room volume with inset apertures, not a suspended solid cube.
		box(name .. "Rear", x, y, z + d / 2 - 1, w, h, 2, "Human")
		box(name .. "Roof", x, y + h / 2 - 0.5, z, w, 1, d, "HumanDark")
		for _, side in ipairs({ -1, 1 }) do
			box(name .. "Side", x + side * (w / 2 - 1), y, z, 2, h, d, "Human")
		end
		box(name .. "Spandrel", x, y - h / 2 + 1.5, z - d / 2 + 1, w, 3, 2, "Human")
		box(name .. "Lintel", x, y + h / 2 - 1, z - d / 2 + 1, w, 2, 2, "Human")
		local edge = x - w / 2
		for _, wx in ipairs(windows) do
			local l, r = wx - 2.5, wx + 2.5
			box(name .. "Pier", (edge + l) / 2, y + 0.5, z - d / 2 + 1, l - edge, h - 5, 2, "Human")
			box(name .. "InsetWindow", wx, y + 0.5, z - d / 2 + 1.9, 5, h - 5, 0.2, "AncientDark")
			box(name .. "WindowSill", wx, y - h / 2 + 3, z - d / 2 + 0.4, 5.5, 0.4, 2.5, "Military")
			box(name .. "WindowMullion", wx, y + 0.5, z - d / 2 + 1.6, 0.2, h - 5, 0.3, "Military")
			edge = r
		end
		box(name .. "EndPier", (edge + x + w / 2) / 2, y + 0.5, z - d / 2 + 1, x + w / 2 - edge, h - 5, 2, "Human")
	end
	-- Supported enclosed cross-street rooms: not traversable platforms or fake stairs.
	-- Their soffits provide compression without obstructing ground or Y=36 routes.
	overbuild("AvenueCrossingResidence", 4, 27, 1125, 112, 12, 18, { -12, 4, 20 })
	box("AvenueCrossingFloor", 4, 20.5, 1125, 112, 1, 19, "Military")
	overbuild("ServiceLaneOverbuild", -120, 22, 1080, 40, 12, 22, { -120 })
	box("ServiceLaneSoffit", -120, 15.5, 1080, 40, 1, 23, "Military")
	-- Window openings are suggested only on inaccessible upper additions; street-level
	-- commercial/residential architecture comes from the approved authored assets.
	for _, z in ipairs({ 1060, 1092, 1124, 1156 }) do
		box("UpperInhabitedWindow", -18.05, 104, z, 0.25, 7, 4, "Light")
	end
	-- Keep the existing B3 stair -> U3 balcony -> cross-block catwalk unobstructed.
	-- A high service span frames the balcony rather than adding a dead-end route.
	box("HighServiceSpan", -223, 58, 1276, 136, 12, 24, "Military")
	return result
end
return Pilot
