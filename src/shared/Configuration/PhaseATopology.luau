--!strict
-- Authored routes precede architecture. Infill may not occupy route clearance.
local nodes, edges, buildings = {}, {}, {}
local function node(id, x, y, z)
	nodes[id] = Vector3.new(x, y, z)
end
local function edge(a, b, kind, width, points)
	table.insert(edges, { a, b, Kind = kind, Width = width, Points = points })
end
local surface = {
	{ 0, 1600 },
	{ 0, 1400 },
	{ 0, 1200 },
	{ 0, 1000 },
	{ 0, 800 },
	{ 0, 600 },
	{ 0, 400 },
	{ -520, 1400 },
	{ -520, 1000 },
	{ -520, 600 },
	{ 520, 1400 },
	{ 520, 1000 },
	{ 520, 600 },
	{ -300, 1600 },
	{ 300, 400 },
}
for i, p in ipairs(surface) do
	node("S" .. i, p[1], 0, p[2])
end
for i = 1, 6 do
	edge("S" .. i, "S" .. (i + 1), "Street", 52)
end
for _, p in ipairs({ { 2, 8 }, { 4, 9 }, { 6, 10 }, { 2, 11 }, { 4, 12 }, { 6, 13 }, { 1, 14 }, { 7, 15 } }) do
	edge("S" .. p[1], "S" .. p[2], "Street", p[1] == 6 and 42 or 26)
end
local definitions = {
	{ "BarracksHallA", -260, 1500, 14, 8, "BunkHall" },
	{ "BarracksHallB", 260, 1500, 1, 11, "TrainingHall" },
	{ "HousingThroughA", -260, 1200, 8, 9, "DenseCells" },
	{ "HousingThroughB", 260, 1200, 11, 12, "SplitLevel" },
	{ "HousingThroughC", -260, 800, 9, 10, "CourtyardRooms" },
	{ "WorkshopMarketA", 260, 800, 12, 13, "OpenWorkshop" },
	{ "WorkshopMarketB", -260, 500, 10, 7, "StorageWorkshop" },
	{ "CommunalHall", 260, 500, 13, 15, "GatheringHall" },
}
for i, b in ipairs(definitions) do
	local g, u = "B" .. i, "U" .. i
	node(g, b[2], 0, b[3])
	node(u, b[2], 36, b[3])
	table.insert(buildings, { Name = b[1], Ground = g, Upper = u, Width = 96, Depth = 120, Style = b[6] })
	for _, s in ipairs({ b[4], b[5] }) do
		local start = nodes["S" .. s]
		edge("S" .. s, g, "Alley", 18, { start, Vector3.new(b[2], 0, start.Z), nodes[g] })
	end
	edge(g, u, "InteriorStair", 12)
end
for _, p in ipairs({ { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 5 } }) do
	local a, b = nodes["U" .. p[1]], nodes["U" .. p[2]]
	edge(
		"U" .. p[1],
		"U" .. p[2],
		"Catwalk",
		12,
		{ a, Vector3.new(a.X, 36, a.Z + 82), Vector3.new(b.X, 36, a.Z + 82), Vector3.new(b.X, 36, b.Z + 82), b }
	)
end
for i, b in ipairs({ 1, 4, 6, 8 }) do
	local p = nodes["B" .. b]
	node("R" .. i, p.X, 72, p.Z)
	edge("U" .. b, "R" .. i, "InteriorStair", 12)
	buildings[b].Roof = "R" .. i
end
edge("R1", "R2", "RoofBridge", 14, { nodes.R1, Vector3.new(-260, 72, 1320), Vector3.new(260, 72, 1320), nodes.R2 })
edge("R3", "R4", "RoofBridge", 14)
local underground = {
	{ -400, -36, 1320 },
	{ 0, -36, 1320 },
	{ 400, -36, 1320 },
	{ -260, -36, 500 },
	{ 0, -36, 720 },
	{
		260,
		-36,
		800,
	},
	{
		0,
		-36,
		440,
	},
}
for i, p in ipairs(underground) do
	node("D" .. i, p[1], p[2], p[3])
end
for _, p in ipairs({ { 1, 2 }, { 2, 3 }, { 1, 4 }, { 2, 5 }, { 3, 6 }, { 4, 5 }, { 5, 6 }, { 4, 7 }, { 7, 6 } }) do
	local a, b = nodes["D" .. p[1]], nodes["D" .. p[2]]
	edge("D" .. p[1], "D" .. p[2], "Tunnel", 18, { a, Vector3.new(a.X, -36, b.Z), b })
end
for _, p in ipairs({ { 8, 1 }, { 11, 3 }, { 10, 4 }, { 13, 6 } }) do
	edge("S" .. p[1], "D" .. p[2], "UndergroundStair", 18)
end
-- Authored candidate anchors are separate from active wave size. They refer
-- only to real route nodes, never to decorative background city geometry.
local spawns = {}
local function spawn(id, node, kind, offset)
	table.insert(spawns, { Id = id, Node = node, Kind = kind, Offset = offset or Vector3.new(0, 0, 0) })
end
for _, id in ipairs({ "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11", "S12", "S13", "S14", "S15" }) do
	spawn("Street_" .. id .. "A", id, "Surface", Vector3.new(-12, 0, 0))
	spawn("Street_" .. id .. "B", id, "Surface")
	spawn("Street_" .. id .. "C", id, "Surface", Vector3.new(12, 0, 0))
end
for i = 1, 8 do
	spawn("Interior_" .. i, "B" .. i, "Interior", Vector3.new(-12, 0, 0))
end
for _, id in ipairs({ "D1", "D2", "D3", "D4", "D5", "D6", "D7" }) do
	spawn("Utility_" .. id .. "A", id, "Underground", Vector3.new(-8, 0, 0))
	spawn("Utility_" .. id .. "B", id, "Underground")
	spawn("Utility_" .. id .. "C", id, "Underground", Vector3.new(8, 0, 0))
end
for z = 450, 1550, 100 do
	for _, x in ipairs({ -18, 18 }) do
		table.insert(spawns, {
			Id = "Avenue_" .. x .. "_" .. z,
			Position = Vector3.new(x, 0, z),
			Kind = "Surface",
			Offset = Vector3.new(0, 0, 0),
		})
	end
end
table.insert(
	spawns,
	{ Id = "RecruitApproach", Position = Vector3.new(0, 0, 1550), Kind = "Surface", Offset = Vector3.new(0, 0, 0) }
)
return {
	Nodes = nodes,
	Edges = edges,
	Buildings = buildings,
	UpperNodes = { "U1", "U2", "U3", "U4", "U5", "U6", "U7", "U8", "R1", "R2", "R3", "R4" },
	UndergroundNodes = { "D1", "D2", "D3", "D4", "D5", "D6", "D7" },
	DebugRoutes = false,
	SpawnCandidates = spawns,
}
