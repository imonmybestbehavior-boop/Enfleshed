-- Geometry for the first spread: exactly three columns on the left page.
local Layout = {}

function Layout.compute(width, height)
	width = math.max(0, width)
	height = math.max(0, height)
	local gap = 8
	if width >= 620 then
		local half = width / 2
		local cell = math.max(60, math.floor(math.min((half - 34) / 3, (height - gap * 2) / 3)))
		local gridSize = cell * 3 + gap * 2
		local createSize = math.max(96, math.floor(math.min(half * 0.86, height - 36, 390)))
		return {
			TwoPages = true,
			Cell = cell,
			GridSize = gridSize,
			SlotsX = math.floor((half - gridSize) / 2),
			SlotsY = math.max(0, math.floor((height - gridSize) / 2)),
			CreateX = math.floor(half + (half - createSize) / 2),
			CreateY = math.max(0, math.floor((height - createSize) / 2)),
			CreateSize = createSize,
			CanvasHeight = math.max(height, gridSize + 8),
		}
	end
	local cell = math.max(60, math.floor((width - 32) / 3))
	local gridSize = cell * 3 + gap * 2
	local createSize = math.max(96, math.floor(math.min(width * 0.72, 270)))
	local slotsY = createSize + 28
	return {
		TwoPages = false,
		Cell = cell,
		GridSize = gridSize,
		SlotsX = math.floor((width - gridSize) / 2),
		SlotsY = slotsY,
		CreateX = math.floor((width - createSize) / 2),
		CreateY = 4,
		CreateSize = createSize,
		CanvasHeight = slotsY + gridSize + 12,
	}
end

return Layout
