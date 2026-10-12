local env = setmetatable(
	{ Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	} },
	{ __index = _G }
)
local plan = assert(loadfile("src/shared/Configuration/PhaseATopology.luau", "t", env))()
local clip = dofile("src/server/Development/LowerLayer/InfillLayout.luau")
local geometry = dofile("src/server/Development/LowerLayer/RouteGeometry.luau").build(plan, clip)
local lots = clip.build(geometry.Reservations)
local generated = dofile("src/server/Development/LowerLayer/CityCompression.luau").build(
	plan,
	geometry,
	clip,
	lots,
	{ Parts = {}, ReplacedLots = {} },
	dofile("src/server/Development/LowerLayer/CompressionPilot.luau"),
	dofile("src/server/Development/LowerLayer/BuildingSites.luau")
)
local fronts = {}
for _, home in ipairs(generated.Homes) do
	table.insert(fronts, { Kind = "Shopfront", Enterable = true, Home = { X = home.X, Y = 0, Z = home.Z } })
end
assert(#generated.Assets == 45 and #fronts == 9)
local layout = dofile("src/server/Services/CityPopulationLayout.luau")
local city =
	assert(loadfile(
		"src/shared/Configuration/CityLife.luau",
		"t",
		setmetatable(
			{ Vector3 = env.Vector3, Color3 = {
				fromRGB = function(...)
					return { ... }
				end,
			} },
			{ __index = _G }
		)
	))()
local roster = layout.build(plan, city.NPCs.Roster, fronts, city.NPCs.AmbientTarget)
assert(#roster == 72 and city.NPCs.MaxPopulation - #roster >= city.NPCs.EventReserve)
local districts = {}
for _, entry in ipairs(roster) do
	if entry.Position then
		districts[entry.District] = true
	end
end
assert(districts.Recruit and districts.Residential and districts.Market and districts.StreetFront)
print("PASS: current commercial homes, 72 ambient slots, district distribution and event reserve")
