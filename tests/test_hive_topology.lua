local env = setmetatable(
	{ Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	} },
	{ __index = _G }
)
local plan = assert(loadfile("src/shared/Configuration/PhaseATopology.luau", "t", env))()
local links = dofile("src/server/Development/LowerLayer/BuildingConnections.luau")
local routes, segments, maximum, widths, spaces = 0, 0, 0, {}, {}
local function inspect(points, ws, types, axis)
	assert(#ws == #points - 1 and #types == #points - 1)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		assert(a[1] == b[1] or a[axis] == b[axis], "Diagonal passage")
		local length = math.abs(a[1] - b[1]) + math.abs(a[axis] - b[axis])
		assert(length > 0 and length <= 96, "Long uninterrupted authored passage: " .. length)
		assert(ws[i - 1] >= 8 and ws[i - 1] <= 24)
		widths[ws[i - 1]] = true
		spaces[types[i - 1]] = true
		segments = segments + 1
		maximum = math.max(maximum, length)
	end
end
for _, r in pairs(plan.Hive.Routes) do
	routes = routes + 1
	inspect(r.Points, r.Widths, r.Spaces, 3)
end
assert(routes == 36 and #plan.Hive.Accretions == 28)
for _, link in ipairs(links.Links) do
	inspect(link.Points, link.Widths, link.Spaces, 2)
end
assert(#links.Buildings == 47 and #links.Links == 91)
assert(plan.Hive.RejoiningBranches == 12 and plan.Hive.EntranceBranches == 114)
local raised = 0
for _, branch in ipairs(plan.Hive.Branches) do
	for i = 2, #branch do
		local a, b = branch[i - 1], branch[i]
		assert(a[1] == b[1] or a[3] == b[3])
		if a[2] ~= b[2] then
			raised = raised + 1
			assert(math.abs(a[2] - b[2]) == 3)
		end
	end
end
assert(raised == plan.Hive.RaisedBranches and raised >= 1)
assert(widths[8] and widths[24] and spaces.Room and spaces.Court and spaces.Balcony and spaces.Bridge)
print(
	("PASS: %d rebuilt ground routes, %d ground/upper segments (max %.1f studs), 12 rejoining branches, 114 entrance approaches, raised branch landings validated"):format(
		routes,
		segments,
		maximum
	)
)
