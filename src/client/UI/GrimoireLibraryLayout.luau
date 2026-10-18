--!strict
-- Nine square cards per physical page: 18 per wide spread, nine when stacked.
local Layout = {}
function Layout.compute(width: number, height: number, columns: number, count: number)
	local gap = 8
	local areaHeight = math.max(0, height - 44)
	local twoPages = columns == 6
	local pageWidth = if twoPages then width / 2 else width
	local cell = math.max(0, math.floor(math.min((pageWidth - 26 - gap * 2) / 3, (areaHeight - gap * 2) / 3)))
	local gridSize = cell * 3 + gap * 2
	local top = math.max(0, math.floor((areaHeight - gridSize) / 2))
	local positions = {}
	for index = 1, count do
		local side = if twoPages then math.floor((index - 1) / 9) else 0
		local onPage = (index - 1) % 9
		positions[index] = {
			X = side * pageWidth + math.floor((pageWidth - gridSize) / 2) + (onPage % 3) * (cell + gap),
			Y = top + math.floor(onPage / 3) * (cell + gap),
		}
	end
	return { Cell = cell, Positions = positions, ArrowY = height - 38, LabelY = height - 36 }
end
return Layout
