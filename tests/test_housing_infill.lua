local layout = assert(loadfile("src/server/Development/LowerLayer/InfillLayout.luau"))()

local function overlaps(a, b)
	return a[1] < b[3] and a[3] > b[1] and a[2] < b[4] and a[4] > b[2]
end

local function area(rect)
	return (rect[3] - rect[1]) * (rect[4] - rect[2])
end

-- Interior cuts, partial intersections and edge touches must preserve exactly
-- the unreserved area without fragments overlapping one another.
for _, cut in ipairs({ { 3, 3, 7, 7 }, { -5, 3, 7, 12 }, { 10, 0, 15, 10 }, { -1, -1, 11, 11 } }) do
	local box = { 0, 0, 10, 10 }
	local fragments, total = layout.subtract(box, cut), 0
	for i, fragment in ipairs(fragments) do
		assert(not overlaps(fragment, cut), "Clipping encroaches on reserved route")
		total = total + area(fragment)
		for j = 1, i - 1 do
			assert(not overlaps(fragment, fragments[j]), "Clipping duplicates housing")
		end
	end
	local removed = math.max(0, math.min(10, cut[3]) - math.max(0, cut[1]))
		* math.max(0, math.min(10, cut[4]) - math.max(0, cut[2]))
	assert(total == 100 - removed)
end

local reserved = {
	{ -25, 350, 25, 1750 }, -- avenue
	{ -600, 628, 600, 672 }, -- market street
	{ 396, 586, 524, 714 }, -- spawn pocket
	{ -191, 1455, -109, 1565 }, -- barracks footprint
	{ -159, 1375, -141, 1645 }, -- two entrance approaches
}
local lots, total = layout.build(reserved), 0
assert(#lots > 100, "Housing no longer fills the wider neighborhood")
for i, lot in ipairs(lots) do
	assert(lot[1] >= -675 and lot[3] <= 675 and lot[2] >= 350 and lot[4] <= 1750)
	for _, cut in ipairs(reserved) do
		assert(not overlaps(lot, cut), "Housing seals a protected route or spawn pocket")
	end
	for j = 1, i - 1 do
		assert(not overlaps(lot, lots[j]), "Housing lots overlap")
	end
	total = total + area(lot)
end
assert(total / (1350 * 1400) > 0.55, "Unoccupied lots remain too sparse")
-- The new district deliberately retires continuous column-wide escape lanes.
-- Explicit reservations, rather than a rectangular lattice, guarantee access.
print("PASS: irregular housing density, nonoverlap, and reserved route clearance")
