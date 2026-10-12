--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Plan = require(Shared.Configuration.PhaseATopology)
local Geometry = require(script.Parent.RouteGeometry)
local Clipping = require(script.Parent.InfillLayout)
local City = require(script.Parent.CityCompression)
local Pilot = require(script.Parent.CompressionPilot)
local Circulation = require(script.Parent.BuildingCirculationRuntime)
local Sites = require(script.Parent.BuildingSites)
local PhaseA = {}

function PhaseA.build(ctx: any)
	local manifest = Geometry.build(Plan, Clipping)
	local c = ctx.Config.Colors
	local environmentalLights = 0
	local lit = {}
	local function lamp(position: Vector3, range: number, brightness: number)
		local key = math.floor(position.X / 24)
			.. ":"
			.. math.floor(position.Y / 16)
			.. ":"
			.. math.floor(position.Z / 24)
		if lit[key] then
			return
		end
		lit[key] = true
		ctx:lamp(position, range, brightness, false)
		environmentalLights += 1
	end
	for _, p in manifest.Parts do
		ctx:part("Human", p.Name, Vector3.new(p.X, p.Y, p.Z), Vector3.new(p.W, p.H, p.D), c[p.Color], p.Collision)
	end
	-- Invisible backup surfaces follow the same shaft cutouts. Their top is a
	-- full stud below the visible collision floor, so they cannot z-fight.
	for _, r in manifest.Planes[0] do
		local support = ctx:part(
			"Navigation",
			"GroundSafetySupport",
			Vector3.new((r[1] + r[3]) / 2, -2, (r[2] + r[4]) / 2),
			Vector3.new(r[3] - r[1] + 0.5, 2, r[4] - r[2] + 0.5),
			c.AncientDark
		)
		support.Transparency = 1
	end
	local lots = Clipping.build(manifest.Reservations)
	local pilot = { Parts = {}, ReplacedLots = {} }
	local city = City.build(Plan, manifest, Clipping, lots, pilot, Pilot, Sites)
	for _, p in city.Parts do
		ctx:part("Human", p.Name, Vector3.new(p.X, p.Y, p.Z), Vector3.new(p.W, p.H, p.D), c[p.Color], p.Collision)
	end
	for _, p in pilot.Parts do
		ctx:part("Human", p.Name, Vector3.new(p.X, p.Y, p.Z), Vector3.new(p.W, p.H, p.D), c[p.Color], p.Collision)
	end
	local assets = game:GetService("ServerStorage"):WaitForChild("CompressionPilotAssets")
	local pilotGroup = Instance.new("Folder")
	pilotGroup.Name, pilotGroup.Parent = "CompressionPilot", ctx.Root
	local cityGroup = Instance.new("Folder")
	cityGroup.Name, cityGroup.Parent = "CityCompression", ctx.Root
	local placements = {}
	for _, a in Pilot.Assets do
		table.insert(placements, { Asset = a, Parent = pilotGroup })
	end
	for _, a in city.Assets do
		table.insert(placements, { Asset = a, Parent = cityGroup })
	end
	for index, entry in placements do
		local placement = entry.Asset
		local model = assets:WaitForChild(placement.Name):Clone()
		-- Static asset coordinates are authored about the façade origin, not its bounding-box pivot.
		local transform = CFrame.new(placement.X, 0, placement.Z) * CFrame.Angles(0, math.rad(placement.Yaw), 0)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = transform * part.CFrame
				if part.Name == "ContinuousGroundFloor" then
					part.CFrame += Vector3.new(0, 0.03, 0)
				end
				ctx.PartCount += 1
			end
		end
		model.Name = placement.Name .. "_" .. index
		model.Parent = entry.Parent
		entry.Model = model
	end
	ctx.Root:SetAttribute("CompressionPilotBounds", "X -330..80 / Z 985..1310")
	local markers = Instance.new("Folder")
	markers.Name, markers.Parent = "StreetFronts", ctx.Root
	-- Existing population consumes these safe commercial-room homes unchanged.
	for index, home in city.Homes do
		local marker = Instance.new("Vector3Value")
		marker.Name, marker.Value, marker.Parent = "Commercial_" .. index, Vector3.new(home.X, 0, home.Z), markers
		marker:SetAttribute("Archetype", "Shopfront")
		marker:SetAttribute("Enterable", true)
		marker:SetAttribute("Entrance", Vector3.new(home.EntryX, 0, home.EntryZ))
		lamp(marker.Value + Vector3.new(0, 10, 0), 22, 1.3)
	end
	ctx.Root:SetAttribute("StreetFrontCount", #city.Homes)
	ctx.Root:SetAttribute("CompressionPilotPartCount", #pilot.Parts)
	ctx.Root:SetAttribute("CompressionPilotStatus", "HiveTopology")
	ctx.Root:SetAttribute("HiveOccupiedExtensions", #Plan.Hive.Accretions)
	ctx.Root:SetAttribute("HiveSideBranches", #Plan.Hive.Branches - Plan.Hive.EntranceBranches)
	ctx.Root:SetAttribute("HiveRejoiningBranches", Plan.Hive.RejoiningBranches)
	ctx.Root:SetAttribute("CityCompressionBounds", "X -675..675 / Z 350..1750")
	ctx.Root:SetAttribute("CityCompressionBuildingCount", #city.Assets + #Pilot.Assets)
	ctx.Root:SetAttribute("CityCompressionOverbuildCount", city.Overbuilds)
	ctx.Root:SetAttribute("CityCompressionPartCount", #city.Parts)
	for i, r in lots do
		if not city.RetainedLots[i] then
			continue
		end
		local x, z = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
		local w, d = r[3] - r[1], r[4] - r[2]
		local top = 220 + (i % 6) * 56
		-- Solid street housing; upper accretions are visual, without extra collision.
		do
			ctx:part("Human", "HousingFoundation" .. i, Vector3.new(x, 32, z), Vector3.new(w, 64, d), c.HumanDark)
		end
		-- Selected lots gain only a few large, named generations near street level.
		-- These are future modular-asset seams, not decorative scatter.
		if i % 4 == 0 then
			local side = i % 8 == 0 and 1 or -1
			ctx:part(
				"Human",
				"WorkshopExtension" .. i,
				Vector3.new(x + side * w * 0.42, 10, z - d * 0.22),
				Vector3.new(math.max(10, w * 0.32), 20, math.max(12, d * 0.36)),
				c.Human,
				false
			)
			ctx:part(
				"Human",
				"StairTower" .. i,
				Vector3.new(x - side * w * 0.38, 18, z + d * 0.25),
				Vector3.new(math.max(8, w * 0.16), 36, math.max(10, d * 0.2)),
				c.Military,
				false
			)
			ctx:part(
				"Human",
				"ProjectedHousingAddition" .. i,
				Vector3.new(x + side * w * 0.3, 52, z - d * 0.1),
				Vector3.new(math.max(12, w * 0.46), 20, math.max(12, d * 0.38)),
				c.HumanDark,
				false
			)
		end
		for level = 0, 3 do
			local h = (top - 64) / 4
			local inset = (level % 2) * 2
			ctx:part(
				"Human",
				"AccretedHabitation" .. i,
				Vector3.new(x, 64 + (level + 0.5) * h, z),
				Vector3.new(w - inset, h, d - inset),
				if (i + level) % 2 == 0 then c.Human else c.HumanDark,
				false
			)
			local band = ctx:part(
				"Human",
				"UpperWindowBand",
				Vector3.new(x, 70 + level * h, z - d / 2 - 0.1),
				Vector3.new(math.max(4, w - 4), 1.2, 0.2),
				c.Light,
				false
			)
			band.CanQuery = false
		end
		-- Later generations project rooms over the lanes above playable roofs.
		-- Alternating sides break the silhouette without blocking circulation.
		for layer = 1, 2 do
			local side = if (i + layer) % 2 == 0 then 1 else -1
			ctx:part(
				"Human",
				"GraftedUpperRooms",
				Vector3.new(x + side * w * 0.4, 100 + layer * 50, z),
				Vector3.new(w * 0.5, 18 + layer * 4, math.max(10, d * 0.6)),
				c.Human,
				false
			)
		end
	end
	-- Bridges and additions ABOVE the playable roofs give the avenue several
	-- overhead layers. They are clearly inaccessible background habitation.
	for i, z in { 480, 690, 910, 1120, 1330, 1550 } do
		ctx:part(
			"Human",
			"SuspendedUpperStreet",
			Vector3.new(0, 160 + (i % 3) * 65, z),
			Vector3.new(620, 12, 26),
			c.HumanDark,
			false
		)
		ctx:part(
			"Human",
			"SuspendedWorkshop",
			Vector3.new(if i % 2 == 0 then 80 else -100, 186 + (i % 3) * 65, z),
			Vector3.new(110, 40, 40),
			c.Human,
			false
		)
	end
	-- Layered ancient ribs remain much larger than the human additions. The six
	-- persistent shell faces are only a distant occlusion backstop.
	for _, x in { -870, 870 } do
		ctx:part("Ancient", "ShaftWall", Vector3.new(x, 440, 1050), Vector3.new(180, 1100, 1800), c.Ancient)
	end
	for i, z in { 400, 900, 1450, 1800 } do
		ctx:part(
			"Ancient",
			"AncientOverheadRib",
			Vector3.new(0, 600 + (i % 2) * 90, z),
			Vector3.new(1850, 100, 110),
			c.Ancient,
			false
		)
		ctx:part(
			"Ancient",
			"SuspendedAncientMass",
			Vector3.new(if i % 2 == 0 then -400 else 380, 760, z),
			Vector3.new(640, 170, 190),
			c.AncientDark,
			false
		)
	end
	local lo, hi = ctx.Config.Enclosure.Minimum, ctx.Config.Enclosure.Maximum
	local mid, size = (lo + hi) / 2, hi - lo
	local t = ctx.Config.Enclosure.Thickness
	for _, f in
		{
			{ Vector3.new(mid.X, lo.Y, mid.Z), Vector3.new(size.X + t, t, size.Z + t) },
			{ Vector3.new(mid.X, hi.Y, mid.Z), Vector3.new(size.X + t, t, size.Z + t) },
			{ Vector3.new(lo.X, mid.Y, mid.Z), Vector3.new(t, size.Y + t, size.Z + t) },
			{ Vector3.new(hi.X, mid.Y, mid.Z), Vector3.new(t, size.Y + t, size.Z + t) },
			{ Vector3.new(mid.X, mid.Y, lo.Z), Vector3.new(size.X + t, size.Y + t, t) },
			{ Vector3.new(mid.X, mid.Y, hi.Z), Vector3.new(size.X + t, size.Y + t, t) },
		}
	do
		local shell = ctx:part("Enclosure", "AncientEnclosure", f[1], f[2], c.AncientDark, false)
		shell.CanQuery = false
	end
	-- Keep the development safety boundary and catch floor.
	for _, f in
		{
			{ Vector3.new(-710, 150, 1050), Vector3.new(4, 450, 1404) },
			{ Vector3.new(710, 150, 1050), Vector3.new(4, 450, 1404) },
			{ Vector3.new(0, 150, 340), Vector3.new(1424, 450, 4) },
			{ Vector3.new(0, 150, 1760), Vector3.new(1424, 450, 4) },
		}
	do
		local boundary = ctx:part("Debug", "DevelopmentBoundary", f[1], f[2], c.AncientDark)
		boundary.Transparency = 1
	end
	-- Route lights intentionally follow the authored circulation rather than the
	-- visual infill. This leaves alleys darker but keeps paths legible.
	for _, edge in Plan.Edges do
		if edge.Kind == "Street" or edge.Kind == "Alley" then
			local points = edge.Points or { Plan.Nodes[edge[1]], Plan.Nodes[edge[2]] }
			for index = 2, #points do
				local start, finish = points[index - 1], points[index]
				for fraction = 0.5, 0.5 do
					lamp(
						start:Lerp(finish, fraction) + Vector3.new(0, 10, 0),
						34,
						if edge.Kind == "Street" then 2.2 else 1.35
					)
				end
			end
		end
	end
	for _, id in Plan.UndergroundNodes do
		local p = Plan.Nodes[id]
		lamp(p + Vector3.new(-8, 10, 0), 28, 1.45)
		lamp(p + Vector3.new(8, 10, 0), 28, 1.15)
	end
	for _, edge in Plan.Edges do
		if edge.Kind == "UndergroundStair" then
			local p = Plan.Nodes[edge[1]]
			lamp(p + Vector3.new(0, 8, 32), 26, 1.6)
		end
	end
	for _, b in Plan.Buildings do
		local p = Plan.Nodes[b.Ground]
		for _, y in { 8, 26, 44, 58 } do
			lamp(p + Vector3.new(-8, y, -40), 25, 1.5)
		end
		for _, side in { -1, 1 } do
			lamp(p + Vector3.new(0, 10, side * 58), 22, 1.8)
		end
	end
	for _, node in Plan.UpperNodes do
		local p = Plan.Nodes[node]
		for level = 1, 4 do
			local light = ctx:part(
				"Human",
				"UpperCityWindow",
				p + Vector3.new((level % 2 == 0 and 22 or -22), 90 + level * 72, 8),
				Vector3.new(2, 3, 1),
				c.Light,
				false
			)
			light.Material = Enum.Material.Neon
		end
	end
	ctx:part("Military", "PhaseBConstructionGate", Vector3.new(0, 18, 360), Vector3.new(70, 36, 8), c.Military)
	ctx:marker("RecruitSpawn", ctx.Config.PhaseA.RecruitSpawn)
	ctx:marker("MarketCombatYard", ctx.Config.PhaseA.MarketCombatYard)
	if ctx.Config.SpawnDebug then
		for _, candidate in Plan.SpawnCandidates do
			local position = (candidate.Position or Plan.Nodes[candidate.Node]) + candidate.Offset
			ctx:marker("Spawn_" .. candidate.Kind .. "_" .. candidate.Id, position + Vector3.new(0, 0.12, 0))
		end
	end
	if Plan.DebugRoutes then
		for index, edge in Plan.Edges do
			if edge.Kind == "Street" or edge.Kind == "Alley" then
				local a, b = Plan.Nodes[edge[1]], Plan.Nodes[edge[2]]
				ctx:marker("RouteSpace_" .. edge.Space .. "_" .. index, (a + b) / 2 + Vector3.new(0, 0.2, 0))
			end
		end
	end
	local count = 0
	for id, p in Plan.Nodes do
		count += 1
		if Plan.DebugRoutes then
			ctx:marker(id, p + Vector3.new(0, 0.1, 0))
		end
	end
	ctx.Root:SetAttribute("RouteNodeCount", count)
	ctx.Root:SetAttribute("RouteConnectionCount", #Plan.Edges)
	ctx.Root:SetAttribute("IndependentLoopCount", #Plan.Edges - count + 1)
	ctx.Root:SetAttribute("InfillHousingCount", #lots)
	ctx.Root:SetAttribute("StairFlightCount", #manifest.Stairs)
	ctx.Root:SetAttribute("HumanVisualHeight", 500)
	ctx.Root:SetAttribute("SpawnCandidateCount", #Plan.SpawnCandidates)
	ctx.Root:SetAttribute("EnvironmentalLightCount", environmentalLights)
	Circulation.apply(ctx, Plan, placements)
end
return PhaseA
