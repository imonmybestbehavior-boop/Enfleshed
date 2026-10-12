--!strict
-- Axis-aligned, six-piece subtraction shared by assembly and offline tests.
-- Bounds use minX/minY/minZ/maxX/maxY/maxZ. No CSG or runtime unions.
local Solid = {}
function Solid.bounds(p)
	return { p.X - p.W / 2, p.Y - p.H / 2, p.Z - p.D / 2, p.X + p.W / 2, p.Y + p.H / 2, p.Z + p.D / 2 }
end
function Solid.subtract(a, b)
	local x, y, z = math.max(a[1], b[1]), math.max(a[2], b[2]), math.max(a[3], b[3])
	local xx, yy, zz = math.min(a[4], b[4]), math.min(a[5], b[5]), math.min(a[6], b[6])
	if x >= xx - 0.0001 or y >= yy - 0.0001 or z >= zz - 0.0001 then
		return { a }
	end
	local result = {}
	for _, r in ipairs({
		{ a[1], a[2], a[3], x, a[5], a[6] },
		{ xx, a[2], a[3], a[4], a[5], a[6] },
		{ x, a[2], a[3], xx, y, a[6] },
		{ x, yy, a[3], xx, a[5], a[6] },
		{ x, y, a[3], xx, yy, z },
		{ x, y, zz, xx, yy, a[6] },
	}) do
		if r[4] - r[1] > 0.01 and r[5] - r[2] > 0.01 and r[6] - r[3] > 0.01 then
			table.insert(result, r)
		end
	end
	return result
end
function Solid.parts(p, cuts)
	local pieces = { Solid.bounds(p) }
	for _, cut in ipairs(cuts) do
		local nextPieces = {}
		for _, piece in ipairs(pieces) do
			for _, r in ipairs(Solid.subtract(piece, cut)) do
				table.insert(nextPieces, r)
			end
		end
		pieces = nextPieces
	end
	local result = {}
	for _, r in ipairs(pieces) do
		local copy = {}
		for k, v in pairs(p) do
			copy[k] = v
		end
		copy.X, copy.Y, copy.Z = (r[1] + r[4]) / 2, (r[2] + r[5]) / 2, (r[3] + r[6]) / 2
		copy.W, copy.H, copy.D = r[4] - r[1], r[5] - r[2], r[6] - r[3]
		table.insert(result, copy)
	end
	return result
end
function Solid.index(cuts)
	local grid = {}
	for id, r in ipairs(cuts) do
		for x = math.floor(r[1] / 64), math.floor(r[4] / 64) do
			for z = math.floor(r[3] / 64), math.floor(r[6] / 64) do
				local key = x .. ":" .. z
				grid[key] = grid[key] or {}
				table.insert(grid[key], id)
			end
		end
	end
	return { Grid = grid, Cuts = cuts }
end
function Solid.near(p, index)
	local bounds = Solid.bounds(p)
	local ids = {}
	local seen = {}
	for x = math.floor(bounds[1] / 64), math.floor(bounds[4] / 64) do
		for z = math.floor(bounds[3] / 64), math.floor(bounds[6] / 64) do
			for _, id in ipairs(index.Grid[x .. ":" .. z] or {}) do
				local r = index.Cuts[id]
				if not seen[id] and bounds[2] < r[5] and bounds[5] > r[2] then
					seen[id] = true
					table.insert(ids, id)
				end
			end
		end
	end
	table.sort(ids)
	local cuts = {}
	for _, id in ipairs(ids) do
		table.insert(cuts, index.Cuts[id])
	end
	return cuts
end
return Solid
