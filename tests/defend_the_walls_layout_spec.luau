local Layout = require("../src/shared/Modules/DefendTheWallsLayout")

local seed = 1693
local a = Layout.generate(seed)
local b = Layout.generate(seed)

-- Deterministic: same seed, same houses and props.
assert(#a.Village.Houses == #b.Village.Houses and #a.Village.Houses > 0, "houses are generated")
for i, house in a.Village.Houses do
	local other = b.Village.Houses[i]
	assert(house.X == other.X and house.Z == other.Z and house.Yaw == other.Yaw, "layout is deterministic")
end
local c = Layout.generate(seed + 1)
assert(c.Village.Houses[1].X ~= a.Village.Houses[1].X, "a different seed moves the village")

-- Three spawns beyond the village edge, one per lane.
assert(#a.Spawns == 3, "three enemy spawns")
local seenLanes = {}
for _, spawn in a.Spawns do
	assert(spawn.Z < a.Village.MinZ, "spawns sit beyond the village edge")
	seenLanes[spawn.Lane] = true
end
assert(seenLanes[1] and seenLanes[2] and seenLanes[3], "each lane has a spawn")

-- Three corridors, each with its own colour and landmark, and at least one crossing.
assert(#a.Lanes == 3, "three corridors")
local colours, landmarks = {}, {}
for _, lane in a.Lanes do
	local key = table.concat(lane.Color, ",")
	assert(not colours[key], "lane colours are distinct")
	assert(not landmarks[lane.Landmark], "lane landmarks are distinct")
	colours[key], landmarks[lane.Landmark] = true, true
	assert(lane.Width >= 30, "corridors fit melee crowds and summons")
	local last = lane.Points[#lane.Points]
	assert(last.X == lane.GateX, "each lane ends at its own wall 1 gate")
	local first = lane.Points[1]
	assert(first.X == a.Spawns[lane.Index].X and first.Z == a.Spawns[lane.Index].Z, "each lane starts at its spawn")
end
local crossings = Layout.laneCrossings(a.Lanes)
assert(#crossings >= 1, "at least one lane crossing")
local cross = a.Crossroads
for _, hit in crossings do
	local d = math.sqrt((hit.Point.X - cross.X) ^ 2 + (hit.Point.Z - cross.Z) ^ 2)
	assert(d <= cross.Radius, "crossings fall inside the crossroads plaza")
	assert(hit.Point.Z > a.Corridor.StartZ and hit.Point.Z < a.Corridor.EndZ, "crossings are in the corridor zone")
end
-- Every lane passes through the shared crossroads, so any lane can be intercepted there.
for _, lane in a.Lanes do
	assert(Layout.distanceToPath(lane.Points, cross) <= cross.Radius, lane.Name .. " reaches the crossroads")
end

-- Three wall levels, ordered and growing taller toward the city, then the final doors.
assert(#a.Walls == 3, "three wall levels")
for i, wall in a.Walls do
	assert(wall.Level == i, "walls are ordered")
	assert(#wall.Gates == 3, "a breachable gate per lane")
	if i > 1 then
		assert(wall.Z > a.Walls[i - 1].Z, "walls step back toward the city")
		assert(wall.Height > a.Walls[i - 1].Height, "each wall is taller than the last")
		assert(wall.Fallback.Z > a.Walls[i - 1].Fallback.Z, "defender fallback moves back")
	end
	assert(wall.Fallback.Z > wall.Z, "fallback spawn is behind its wall")
end
assert(a.Walls[1].Z > a.Corridor.EndZ, "wall 1 is past the corridors")
assert(a.Doors.Z > a.Walls[3].Z, "final doors are behind wall 3")
assert(a.Staging.Z > a.Walls[3].Z and a.Staging.Z < a.Doors.Z, "staging is behind wall 3, in front of the doors")
assert(a.City.MinZ > a.Doors.Z, "the city is behind the doors")

-- The crossroads is structured: a solid shrine plinth splits the flow but leaves wide channels.
assert(cross.Monument and cross.Monument >= 8, "crossroads has a central shrine")
assert(cross.Radius - cross.Monument >= Layout.LaneWidth * 0.9, "channels around the shrine fit a lane's crowd")

-- Walls are spaced for a real fight between them, and every bailey has content.
assert(#a.Baileys == 2, "a bailey between each pair of walls")
for i, bailey in a.Baileys do
	assert(a.Walls[i + 1].Z - a.Walls[i].Z >= 85, "walls are far enough apart to hold a bailey")
	local kinds = {}
	for _, piece in bailey.Pieces do
		kinds[piece.Kind] = (kinds[piece.Kind] or 0) + 1
		assert(piece.Z > a.Walls[i].Z and piece.Z < a.Walls[i + 1].Z, "bailey pieces sit between their walls")
	end
	assert((kinds.Barricade or 0) >= 6 and (kinds.Terrace or 0) == 2, "barricade chicanes and flank terraces")
	-- Each lane keeps a passable gap through every barricade row.
	for _, gate in a.Walls[i].Gates do
		for _, piece in bailey.Pieces do
			if piece.Kind == "Barricade" and math.abs(piece.X - gate.X) < 20 then
				local gapLeft = (piece.X - piece.W / 2) - (gate.X - 18)
				local gapRight = (gate.X + 18) - (piece.X + piece.W / 2)
				assert(math.max(gapLeft, gapRight) >= 12, "barricades leave a gap in each lane")
			end
		end
	end
	-- Buildings stay off the straight gate-to-gate lines.
	for _, piece in bailey.Pieces do
		if piece.Kind ~= "Barricade" and piece.Kind ~= "Wagon" then
			for _, gate in a.Walls[i].Gates do
				assert(math.abs(piece.X - gate.X) - piece.W / 2 >= 12, "buildings keep lanes open")
			end
		end
	end
end

-- Village props keep off the roads.
for _, house in a.Village.Houses do
	for _, lane in a.Lanes do
		assert(Layout.distanceToPath(lane.Points, house) > lane.Width / 2, "houses stay off the lanes")
	end
end

print("defend_the_walls_layout_spec: ok")
