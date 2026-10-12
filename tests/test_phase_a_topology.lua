local env = setmetatable(
	{ Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	} },
	{ __index = _G }
)
local graph = assert(loadfile("src/shared/Configuration/PhaseATopology.luau", "t", env))()
local count, adjacency = 0, {}
for id in pairs(graph.Nodes) do
	count = count + 1
	adjacency[id] = {}
end
assert(count >= 42 and #graph.Edges >= 61)
local undergroundEdges, aboveEdges, entrances = 0, 0, 0
local spaces = {}
for _, e in ipairs(graph.Edges) do
	assert(graph.Nodes[e[1]] and graph.Nodes[e[2]], "Missing endpoint")
	assert(e[1] ~= e[2] and e.Width >= (e.Space == "NarrowAlley" and 6 or 10))
	assert(
		e.Space == "NarrowAlley"
			or e.Space == "CompressedStreet"
			or e.Space == "NormalStreet"
			or e.Space == "CombatStreet"
			or e.Space == "CombatCourtyard"
	)
	spaces[e.Space] = (spaces[e.Space] or 0) + 1
	table.insert(adjacency[e[1]], e[2])
	table.insert(adjacency[e[2]], e[1])
	if e.Kind == "Tunnel" then
		undergroundEdges = undergroundEdges + 1
	elseif e.Kind == "UndergroundStair" then
		entrances = entrances + 1
	else
		aboveEdges = aboveEdges + 1
	end
	if e.Points then
		local first, last = e.Points[1], e.Points[#e.Points]
		local a, b = graph.Nodes[e[1]], graph.Nodes[e[2]]
		assert(first.X == a.X and first.Y == a.Y and first.Z == a.Z)
		assert(last.X == b.X and last.Y == b.Y and last.Z == b.Z)
	end
end
assert((spaces.NarrowAlley or 0) >= 1 and (spaces.NormalStreet or 0) >= 1 and (spaces.CombatCourtyard or 0) >= 1)
local seen = {}
local function visit(id)
	if seen[id] then
		return
	end
	seen[id] = true
	for _, other in ipairs(adjacency[id]) do
		visit(other)
	end
end
visit("S1")
for id in pairs(graph.Nodes) do
	assert(seen[id], "Disconnected node " .. id)
end
for _, b in ipairs(graph.Buildings) do
	assert(#adjacency[b.Ground] >= 3, "Building missing two entrances or stairs")
	assert(#adjacency[b.Upper] >= 1, "Upper floor has no access")
	if b.Roof then
		assert(#adjacency[b.Roof] >= 2, "Roof has no onward route")
	end
end
local styles = {}
for _, building in ipairs(graph.Buildings) do
	assert(type(building.Style) == "string")
	styles[building.Style] = true
end
local styleCount = 0
for _ in pairs(styles) do
	styleCount = styleCount + 1
end
assert(styleCount == 8, "Every primary building needs a distinct interior layout style")
assert(#graph.Buildings == 8 and entrances == 4 and #graph.UndergroundNodes == 7)
local kinds = {}
assert(#graph.SpawnCandidates >= 90, "Phase A needs dense spawn coverage")
for _, candidate in ipairs(graph.SpawnCandidates) do
	assert(candidate.Id and candidate.Kind and candidate.Offset)
	assert(candidate.Position or graph.Nodes[candidate.Node], "Spawn candidate has no route position")
	kinds[candidate.Kind] = (kinds[candidate.Kind] or 0) + 1
end
assert((kinds.Surface or 0) >= 60 and (kinds.Interior or 0) >= 8 and (kinds.Underground or 0) >= 21)
assert(undergroundEdges - 7 + 1 >= 3)
assert(aboveEdges - (count - 7) + 1 >= 14)
assert(#graph.Edges - count + 1 >= 20)
print("PASS: primary backbone plus deterministic micro-topology remains connected")
