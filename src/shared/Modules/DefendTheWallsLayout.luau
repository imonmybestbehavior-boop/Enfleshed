--!strict
-- Pure, seeded layout for the Defend the Walls siege map. No Roblox APIs, so the
-- plain Luau CLI can test it; the server map builder turns this data into parts.
-- Axes: X is across the front, Z runs from the enemy side (low) to the city (high).
-- Every point is a plain { X, Z } table; heights live with the builders.
local Layout = {}

export type Point = { X: number, Z: number }
export type Lane = {
	Index: number,
	Name: string,
	Color: { number },
	Landmark: string,
	Width: number,
	Points: { Point }, -- spawn → village edge → corridor → crossing → wall 1 gate
	GateX: number,
}
export type Wall = {
	Level: number,
	Name: string,
	Z: number,
	Height: number,
	Thickness: number,
	HalfWidth: number,
	GateWidth: number,
	Walkway: boolean,
	Gates: { { Lane: number, X: number } },
	Fallback: Point, -- defender spawn while this wall is the active line
	Rally: Point, -- where retreating guards regroup: in front of this wall, since its gates stay shut
}

Layout.HalfWidth = 215
Layout.SpawnZ = 610
Layout.VillageMinZ = 640
Layout.VillageMaxZ = 880
Layout.CorridorStartZ = 905
Layout.CorridorEndZ = 1092
Layout.CityZ = 1412
Layout.LaneWidth = 36

-- Park–Miller LCG: identical sequences in Studio and the CLI test runner.
local function rng(seed: number)
	local state = math.max(1, math.floor(seed) % 2147483646)
	local self = {}
	function self.next(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	function self.range(lo: number, hi: number): number
		return lo + (hi - lo) * self.next()
	end
	return self
end
Layout.rng = rng

-- Shortest distance from p to the polyline.
function Layout.distanceToPath(points: { Point }, p: Point): number
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dz = b.X - a.X, b.Z - a.Z
		local length2 = dx * dx + dz * dz
		local t = if length2 > 0 then math.clamp(((p.X - a.X) * dx + (p.Z - a.Z) * dz) / length2, 0, 1) else 0
		local cx, cz = a.X + dx * t - p.X, a.Z + dz * t - p.Z
		best = math.min(best, math.sqrt(cx * cx + cz * cz))
	end
	return best
end

-- Proper intersection of segments ab and cd (shared endpoints do not count).
local function segmentsCross(a: Point, b: Point, c: Point, d: Point): Point?
	local rX, rZ, sX, sZ = b.X - a.X, b.Z - a.Z, d.X - c.X, d.Z - c.Z
	local denom = rX * sZ - rZ * sX
	if math.abs(denom) < 1e-9 then
		return nil
	end
	local t = ((c.X - a.X) * sZ - (c.Z - a.Z) * sX) / denom
	local u = ((c.X - a.X) * rZ - (c.Z - a.Z) * rX) / denom
	if t > 1e-6 and t < 1 - 1e-6 and u > 1e-6 and u < 1 - 1e-6 then
		return { X = a.X + rX * t, Z = a.Z + rZ * t }
	end
	return nil
end

-- Every point where two lane centre-lines cross, with the pair of lanes.
function Layout.laneCrossings(lanes: { Lane }): { { Lanes: { number }, Point: Point } }
	local found = {}
	for i = 1, #lanes do
		for j = i + 1, #lanes do
			local a, b = lanes[i].Points, lanes[j].Points
			for s = 1, #a - 1 do
				for t = 1, #b - 1 do
					local hit = segmentsCross(a[s], a[s + 1], b[t], b[t + 1])
					if hit then
						table.insert(found, { Lanes = { i, j }, Point = hit })
					end
				end
			end
		end
	end
	return found
end

local function lanes(): { Lane }
	local w = Layout.LaneWidth
	-- Left and right lanes swing through the centre crossroads and back out, so all
	-- three lanes meet there; the centre lane runs straight. Each ends at its own gate.
	return {
		{
			Index = 1,
			Name = "Left",
			Color = { 92, 196, 214 }, -- cold teal grave-lights
			Landmark = "HangedOak",
			Width = w,
			GateX = -112,
			Points = {
				{ X = -150, Z = Layout.SpawnZ },
				{ X = -150, Z = Layout.CorridorStartZ },
				{ X = 24, Z = 990 },
				{ X = -112, Z = 1072 },
				{ X = -112, Z = 1100 },
			},
		},
		{
			Index = 2,
			Name = "Centre",
			Color = { 236, 142, 64 }, -- ember amber
			Landmark = "BrokenSpire",
			Width = w,
			GateX = 0,
			Points = { { X = 0, Z = Layout.SpawnZ - 15 }, { X = 0, Z = 1100 } },
		},
		{
			Index = 3,
			Name = "Right",
			Color = { 176, 118, 232 }, -- witch-fire violet
			Landmark = "Aqueduct",
			Width = w,
			GateX = 112,
			Points = {
				{ X = 150, Z = Layout.SpawnZ },
				{ X = 150, Z = Layout.CorridorStartZ },
				{ X = -24, Z = 990 },
				{ X = 112, Z = 1072 },
				{ X = 112, Z = 1100 },
			},
		},
	}
end

local function walls(laneList: { Lane }): { Wall }
	local function gates()
		local list = {}
		for _, lane in laneList do
			table.insert(list, { Lane = lane.Index, X = lane.GateX })
		end
		return list
	end
	return {
		{
			Level = 1,
			Name = "OuterPalisade",
			Z = 1110,
			Height = 14,
			Thickness = 5,
			HalfWidth = Layout.HalfWidth,
			GateWidth = 20,
			Walkway = true,
			Gates = gates(),
			Fallback = { X = 0, Z = 1140 },
			Rally = { X = 0, Z = 1092 },
		},
		{
			Level = 2,
			Name = "CurtainWall",
			Z = 1210,
			Height = 22,
			Thickness = 8,
			HalfWidth = Layout.HalfWidth,
			GateWidth = 20,
			Walkway = true,
			Gates = gates(),
			Fallback = { X = 0, Z = 1240 },
			Rally = { X = 0, Z = 1190 },
		},
		{
			Level = 3,
			Name = "InnerBastion",
			Z = 1310,
			Height = 32,
			Thickness = 10,
			HalfWidth = Layout.HalfWidth,
			GateWidth = 20,
			Walkway = true,
			Gates = gates(),
			Fallback = { X = 0, Z = 1362 },
			Rally = { X = 0, Z = 1288 },
		},
	}
end

-- Small seeded scatter that keeps clear of every lane and of earlier picks.
local function scatter(
	random,
	count: number,
	minZ: number,
	maxZ: number,
	clearance: number,
	laneList: { Lane },
	taken: { { X: number, Z: number, R: number } }
): { Point }
	local out = {}
	local tries = 0
	while #out < count and tries < count * 40 do
		tries += 1
		local p = { X = random.range(-Layout.HalfWidth + 18, Layout.HalfWidth - 18), Z = random.range(minZ, maxZ) }
		local ok = true
		for _, lane in laneList do
			if Layout.distanceToPath(lane.Points, p) < lane.Width / 2 + clearance then
				ok = false
				break
			end
		end
		if ok then
			for _, other in taken do
				local dx, dz = other.X - p.X, other.Z - p.Z
				if dx * dx + dz * dz < (other.R + clearance) ^ 2 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(out, p)
			table.insert(taken, { X = p.X, Z = p.Z, R = clearance })
		end
	end
	return out
end

-- The ground between consecutive walls. Each bailey gets two chicane rows of
-- barricades (one per lane, alternating sides so each lane zig-zags but always
-- keeps a gap), buildings on the tower lines between lanes, and raised firing
-- terraces on both flanks with ramps on the city side. All of it collides.
export type Piece = { Kind: string, X: number, Z: number, W: number, D: number, H: number, Yaw: number? }
local function baileys(wallList: { Wall }): { { Level: number, MinZ: number, MaxZ: number, Pieces: { Piece } } }
	local out = {}
	for i = 1, #wallList - 1 do
		local a, b = wallList[i], wallList[i + 1]
		local minZ, maxZ = a.Z + a.Thickness / 2 + 6, b.Z - b.Thickness / 2 - 16
		local depth = maxZ - minZ
		local pieces: { Piece } = {}
		for row, t in { 0.3, 0.62 } do
			local z = minZ + depth * t
			for _, gate in a.Gates do
				local side = if (row + gate.Lane) % 2 == 0 then 1 else -1
				table.insert(pieces, { Kind = "Barricade", X = gate.X + side * 9, Z = z, W = 16, D = 3, H = 4 })
			end
		end
		local building = if i == 1 then "Barracks" else "Armoury"
		local other = if i == 1 then "Stables" else "WardenChapel"
		table.insert(pieces, { Kind = building, X = -56, Z = minZ + depth * 0.46, W = 24, D = 18, H = 13 })
		table.insert(pieces, { Kind = other, X = 56, Z = minZ + depth * 0.46, W = 24, D = 18, H = 13 })
		for _, side in { -1, 1 } do
			table.insert(
				pieces,
				{ Kind = "Terrace", X = side * 182, Z = minZ + depth * 0.45, W = 34, D = depth * 0.55, H = 8 }
			)
			table.insert(
				pieces,
				{ Kind = "Wagon", X = side * 150, Z = minZ + depth * 0.15, W = 6, D = 9, H = 4, Yaw = side * 30 }
			)
		end
		table.insert(out, { Level = i, MinZ = minZ, MaxZ = maxZ, Pieces = pieces })
	end
	return out
end

function Layout.generate(seed: number)
	local random = rng(seed)
	local laneList = lanes()
	local wallList = walls(laneList)
	local taken = {}
	-- Hand-placed village anchors, then seeded houses and clutter around them.
	local chapel = { X = -70, Z = 760, Yaw = 0 }
	local graveyard = { X = -72, Z = 700 }
	local well = { X = 70, Z = 780 }
	local gallows = { X = 78, Z = 700 }
	local pond = { X = 118, Z = 690 }
	for _, anchor in { { chapel, 28 }, { graveyard, 22 }, { well, 8 }, { gallows, 10 }, { pond, 14 } } do
		table.insert(taken, { X = anchor[1].X, Z = anchor[1].Z, R = anchor[2] })
	end
	local houses = {}
	for _, p in scatter(random, 14, Layout.VillageMinZ + 10, Layout.VillageMaxZ - 10, 14, laneList, taken) do
		table.insert(houses, {
			X = p.X,
			Z = p.Z,
			Yaw = math.floor(random.range(0, 4)) * 90 + random.range(-8, 8),
			Width = math.floor(random.range(14, 22)),
			Depth = math.floor(random.range(12, 16)),
			Stories = if random.next() < 0.35 then 2 else 1,
			RoofBroken = random.next() < 0.6,
		})
	end
	local carts = scatter(random, 6, Layout.VillageMinZ, Layout.VillageMaxZ, 6, laneList, taken)
	local deadTrees = scatter(random, 10, Layout.SpawnZ, Layout.CorridorEndZ, 5, laneList, taken)
	local corridorLights = {}
	for _, lane in laneList do
		local pts = lane.Points
		local spacing = 30
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local dx, dz = b.X - a.X, b.Z - a.Z
			local length = math.sqrt(dx * dx + dz * dz)
			local nx, nz = -dz / length, dx / length
			for d = spacing / 2, length, spacing do
				local t = d / length
				local side = if math.floor(d / spacing) % 2 == 0 then 1 else -1
				local offset = lane.Width / 2 - 3
				table.insert(corridorLights, {
					Lane = lane.Index,
					X = a.X + dx * t + nx * offset * side,
					Z = a.Z + dz * t + nz * offset * side,
				})
			end
		end
	end
	return {
		Seed = seed,
		HalfWidth = Layout.HalfWidth,
		Spawns = {
			{ Lane = 1, Name = "Left", X = -150, Z = Layout.SpawnZ },
			{ Lane = 2, Name = "Centre", X = 0, Z = Layout.SpawnZ - 15 },
			{ Lane = 3, Name = "Right", X = 150, Z = Layout.SpawnZ },
		},
		Village = {
			MinZ = Layout.VillageMinZ,
			MaxZ = Layout.VillageMaxZ,
			Houses = houses,
			Chapel = chapel,
			Graveyard = graveyard,
			Well = well,
			Gallows = gallows,
			Pond = pond,
			Carts = carts,
		},
		Lanes = laneList,
		Crossroads = { X = 0, Z = 990, Radius = 48, Monument = 11 },
		Corridor = { StartZ = Layout.CorridorStartZ, EndZ = Layout.CorridorEndZ, WallHeight = 13 },
		CorridorLights = corridorLights,
		DeadTrees = deadTrees,
		Walls = wallList,
		Doors = { X = 0, Z = 1392, Width = 26, Height = 34 },
		Staging = { X = 0, Z = 1362 },
		Baileys = baileys(wallList),
		City = { MinZ = Layout.CityZ },
	}
end

return Layout
