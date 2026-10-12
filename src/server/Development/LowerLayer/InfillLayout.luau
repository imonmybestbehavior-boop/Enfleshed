--!strict
-- Deterministic graybox lot clipping. Rectangles are { minX, minZ, maxX, maxZ }.
-- Kept independent of Roblox so clearance can be checked offline.
local Layout = {}

function Layout.subtract(rect, cut)
	local x1, z1 = math.max(rect[1], cut[1]), math.max(rect[2], cut[2])
	local x2, z2 = math.min(rect[3], cut[3]), math.min(rect[4], cut[4])
	if x1 >= x2 or z1 >= z2 then
		return { rect }
	end
	local result = {}
	for _, piece in ipairs({
		{ rect[1], rect[2], x1, rect[4] },
		{ x2, rect[2], rect[3], rect[4] },
		{ x1, rect[2], x2, z1 },
		{ x1, z2, x2, rect[4] },
	}) do
		if piece[3] > piece[1] and piece[4] > piece[2] then
			table.insert(result, piece)
		end
	end
	return result
end

function Layout.build(reservations)
	local lots = {}
	for column = 0, 13 do
		local x = -675 + column * 96
		-- Offset cross passages so pursuit requires turns between adjacent rows.
		local offset = (column % 3) * 28
		for row = -1, 12 do
			local z = 350 + row * 116 + offset
			local setback = ((row + column) % 3 - 1) * 8
			local left = math.max(-675, x + setback)
			local width = ({ 88, 100, 108 })[(row + column) % 3 + 1]
			local pieces = { { left, math.max(350, z), math.min(675, left + width), math.min(1750, z + 108) } }
			local cuts = { table.unpack(reservations) }
			for _, occupied in ipairs(lots) do
				table.insert(cuts, occupied)
			end
			for _, cut in ipairs(cuts) do
				local remaining = {}
				for _, piece in ipairs(pieces) do
					for _, fragment in ipairs(Layout.subtract(piece, cut)) do
						table.insert(remaining, fragment)
					end
				end
				pieces = remaining
			end
			for _, piece in ipairs(pieces) do
				if piece[3] - piece[1] >= 12 and piece[4] - piece[2] >= 12 then
					table.insert(lots, piece)
				end
			end
		end
	end
	return lots
end

return Layout
