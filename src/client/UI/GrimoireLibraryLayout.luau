--!strict
-- Fixed two-page positions for library cards and tool tiles.
local Layout = {}

function Layout.compute(width: number, height: number, columns: number, count: number)
	local gap = 9
	local areaHeight = math.max(0, height - 44)
	local pageWidth = if columns == 4 then width / 2 else width
	local cell = math.max(0, math.floor(math.min((pageWidth - 26 - gap) / 2, (areaHeight - gap) / 2)))
	local pairWidth, pairHeight = cell * 2 + gap, cell * 2 + gap
	local top = math.max(0, math.floor((areaHeight - pairHeight) / 2))
	local positions = {}
	for index = 1, count do
		local side = if columns == 4 then math.floor((index - 1) / 4) else 0
		local onPage = if columns == 4 then (index - 1) % 4 else index - 1
		positions[index] = {
			X = side * pageWidth + math.floor((pageWidth - pairWidth) / 2) + (onPage % 2) * (cell + gap),
			Y = top + math.floor(onPage / 2) * (cell + gap),
		}
	end
	return { Cell = cell, Positions = positions, ArrowY = height - 38, LabelY = height - 36 }
end

return Layout
