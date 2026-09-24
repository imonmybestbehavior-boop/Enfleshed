local env = setmetatable(
	{ Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	} },
	{ __index = _G }
)
local plan = assert(loadfile("src/shared/Configuration/PhaseATopology.luau", "t", env))()
local clip = assert(loadfile("src/server/Development/LowerLayer/InfillLayout.luau"))()
local geometry = assert(loadfile("src/server/Development/LowerLayer/RouteGeometry.luau"))().build(plan, clip)
local obstacles = { table.unpack(geometry.Parts) }
for _, r in ipairs(clip.build(geometry.Reservations)) do
	table.insert(obstacles, {
		Name = "Housing infill",
		X = (r[1] + r[3]) / 2,
		Y = 32,
		Z = (r[2] + r[4]) / 2,
		W = r[3] - r[1],
		H = 64,
		D = r[4] - r[2],
		Collision = true,
	})
end
-- Approximate the configured Stage 1 navigation envelope (radius 2, height 9).
-- Ignore the first 1.6 studs above a tread so ordinary step risers are legal.
local function blocksAgent(p, x, y, z)
	return p.Collision
		and math.abs(x - p.X) < p.W / 2 + 1.95
		and math.abs(z - p.Z) < p.D / 2 + 1.95
		and p.Y + p.H / 2 > y + 1.6
		and p.Y - p.H / 2 < y + 9
end
local function support(x, y, z)
	for _, p in ipairs(geometry.Parts) do
		if
			p.Collision
			and math.abs(p.Y + p.H / 2 - y) < 0.81
			and math.abs(x - p.X) <= p.W / 2 + 0.1
			and math.abs(z - p.Z) <= p.D / 2 + 0.1
		then
			return true
		end
	end
	return false
end
local issues = {}
local function issue(message)
	if #issues < 30 then
		table.insert(issues, message)
	end
end
for _, stair in ipairs(geometry.Stairs) do
	assert(stair.Width >= 12)
	for _, point in ipairs(stair.Samples) do
		for _, p in ipairs(obstacles) do
			if blocksAgent(p, point.X, point.Y, point.Z) then
				issue(stair.Name .. " blocked by " .. p.Name .. " at " .. point.Y)
			end
		end
	end
	if not support(stair.Bottom.X, stair.Bottom.Y, stair.Bottom.Z) then
		issue(stair.Name .. " missing bottom landing")
	end
	if not support(stair.Top.X, stair.Top.Y, stair.Top.Z) then
		issue(stair.Name .. " missing top landing")
	end
	local dir = stair.Top.Z > stair.Bottom.Z and 1 or -1
	assert(
		support(stair.Top.X, stair.Top.Y, stair.Top.Z + dir * 2),
		stair.Name .. " has no usable destination beyond last tread"
	)
	assert(support(stair.Bottom.X, stair.Bottom.Y, stair.Bottom.Z - dir * 2), stair.Name .. " has no usable approach")
end
for _, d in ipairs(geometry.Doors) do
	assert(d.Width >= 12 and d.Height >= 12)
	for _, p in ipairs(obstacles) do
		if blocksAgent(p, d.X, d.Y, d.Z) then
			issue("Door blocked by " .. p.Name)
		end
	end
end
-- Every emitted floor rectangle on each plane is non-overlapping.
for y, rects in pairs(geometry.Planes) do
	for i, a in ipairs(rects) do
		for j = 1, i - 1 do
			local b = rects[j]
			assert(
				not (a[1] < b[3] - 0.001 and a[3] > b[1] + 0.001 and a[2] < b[4] - 0.001 and a[4] > b[2] + 0.001),
				"Coplanar floors at " .. y
			)
		end
	end
end
for i, e in ipairs(plan.Edges) do
	if e.Kind ~= "InteriorStair" and e.Kind ~= "UndergroundStair" then
		local pts = e.Points or { plan.Nodes[e[1]], plan.Nodes[e[2]] }
		for n = 2, #pts do
			local a, b = pts[n - 1], pts[n]
			local steps = math.max(1, math.ceil((math.abs(b.X - a.X) + math.abs(b.Z - a.Z)) / 4))
			for step = 0, steps do
				local x, z = a.X + (b.X - a.X) * step / steps, a.Z + (b.Z - a.Z) * step / steps
				assert(support(x, a.Y, z), "Route " .. i .. " has no floor")
				for _, p in ipairs(obstacles) do
					if blocksAgent(p, x, a.Y, z) then
						issue("Route " .. i .. " blocked by " .. p.Name)
					end
				end
			end
		end
	end
end
for _, candidate in ipairs(plan.SpawnCandidates) do
	local base = candidate.Position or plan.Nodes[candidate.Node]
	local source = { X = base.X + candidate.Offset.X, Y = base.Y + candidate.Offset.Y, Z = base.Z + candidate.Offset.Z }
	assert(support(source.X, source.Y, source.Z), "Spawn " .. candidate.Id .. " lacks a floor")
	for _, p in ipairs(obstacles) do
		assert(
			not blocksAgent(p, source.X, source.Y, source.Z),
			"Spawn " .. candidate.Id .. " is obstructed by " .. p.Name
		)
	end
end
assert(#issues == 0, table.concat(issues, "\n"))
print(
	string.format(
		"PASS: generated geometry: %d parts, %d stair flights, %d door openings, %d infill lots",
		#geometry.Parts,
		#geometry.Stairs,
		#geometry.Doors,
		#clip.build(geometry.Reservations)
	)
)
local routeLights = 0
for _, edge in ipairs(plan.Edges) do
	if edge.Kind == "Street" or edge.Kind == "Alley" then
		local points = edge.Points or { plan.Nodes[edge[1]], plan.Nodes[edge[2]] }
		routeLights = routeLights + (#points - 1) * 2
	end
end
local environmentalLights = routeLights + #plan.UndergroundNodes * 2 + 4 + #plan.Buildings * 6
local expectedParts = #geometry.Parts
	+ #geometry.Planes[0]
	+ #clip.build(geometry.Reservations) * 11
	+ 12
	+ 2
	+ 8
	+ 6
	+ 4
	+ environmentalLights
	+ #plan.UpperNodes * 4
	+ #plan.Buildings
	+ 2
print(
	"Phase A expected generated Part count: "
		.. expectedParts
		.. " (includes hidden support, enclosure, markers and lights)"
)
