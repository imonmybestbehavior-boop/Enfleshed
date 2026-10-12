local source = assert(loadstring(__GRIMOIRE_LIBRARY_LAYOUT_SOURCE))
local layout = source()

for _, viewport in { { 766, 316, 4, 8 }, { 736, 456, 4, 8 }, { 328, 496, 2, 4 } } do
	local width, height, columns, count = table.unpack(viewport)
	local spread = layout.compute(width, height, columns, count)
	assert(spread.Cell > 0, "Cards must have a visible size")
	local pageWidth = if columns == 4 then width / 2 else width
	for index, position in ipairs(spread.Positions) do
		local side = if columns == 4 then math.floor((index - 1) / 4) else 0
		assert(position.X >= side * pageWidth and position.X + spread.Cell <= (side + 1) * pageWidth,
			"Card must stay on its notebook page")
		assert(position.Y >= 0 and position.Y + spread.Cell <= height - 44,
			"Both card rows must fit above page arrows without scrolling")
	end
	assert(spread.ArrowY + 35 <= height, "Page arrows must fit at the bottom")
end
print("PASS: library spreads fit eight square cards across two pages without vertical scrolling")
