local source = assert(loadstring(__GRIMOIRE_LIBRARY_LAYOUT_SOURCE))
local layout = source()

for _, viewport in { { 766, 316, 6, 18 }, { 736, 456, 6, 18 }, { 328, 496, 3, 9 } } do
	local width, height, columns, count = table.unpack(viewport)
	local spread = layout.compute(width, height, columns, count)
	assert(spread.Cell > 0, "Cards must have a visible size")
	local pageWidth = if columns == 6 then width / 2 else width
	for index, position in ipairs(spread.Positions) do
		local side = if columns == 6 then math.floor((index - 1) / 9) else 0
		assert(
			position.X >= side * pageWidth and position.X + spread.Cell <= (side + 1) * pageWidth,
			"Card must stay on its notebook page"
		)
		assert(
			position.Y >= 0 and position.Y + spread.Cell <= height - 44,
			"All three card rows must fit above page arrows without scrolling"
		)
	end
	assert(spread.ArrowY + 35 <= height, "Page arrows must fit at the bottom")
end
print("PASS: library spreads fit nine square cards per page without vertical scrolling")
