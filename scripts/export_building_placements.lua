local env = setmetatable(
	{ Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	} },
	{ __index = _G }
)
local p = assert(loadfile("src/shared/Configuration/PhaseATopology.luau", "t", env))()
local clip = dofile("src/server/Development/LowerLayer/InfillLayout.luau")
local g = dofile("src/server/Development/LowerLayer/RouteGeometry.luau").build(p, clip)
local lots = clip.build(g.Reservations)
local pm = dofile("src/server/Development/LowerLayer/CompressionPilot.luau")
local pilot = { Parts = {}, ReplacedLots = {} }
local city = dofile("src/server/Development/LowerLayer/CityCompression.luau").build(
	p,
	g,
	clip,
	lots,
	pilot,
	pm,
	dofile("src/server/Development/LowerLayer/BuildingSites.luau")
)
for _, a in ipairs(pm.Assets) do
	print("A", a.Name, a.X, a.Z, a.Yaw)
end
for _, a in ipairs(city.Assets) do
	print("A", a.Name, a.X, a.Z, a.Yaw)
end
for _, b in ipairs(p.Buildings) do
	local n = p.Nodes[b.Ground]
	print("B", n.X, n.Z)
end
