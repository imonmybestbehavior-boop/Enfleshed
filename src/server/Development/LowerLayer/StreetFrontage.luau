--!strict
-- Pure deterministic geometry: cavities replace solid foundations, never widen streets.
local Frontage = {}
local kinds = { "Shopfront", "ServiceCounter", "Workshop", "MarketStall", "BoardedStore", "GuardSupply" }
function Frontage.build(lots, plan, existingParts)
	local result = { Parts = {}, Fronts = {}, ByLot = {} }
	for index, r in ipairs(lots) do
		local best, score = nil, math.huge
		local x, z, w, d = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2, r[3] - r[1], r[4] - r[2]
		for _, edge in ipairs(plan.Edges) do
			if edge.Kind == "Street" and edge.Width >= 30 then
				local points = edge.Points or { plan.Nodes[edge[1]], plan.Nodes[edge[2]] }
				for j = 2, #points do
					local a, b = points[j - 1], points[j]
					if a.Y == 0 and b.Y == 0 then
						local vertical = math.abs(a.X - b.X) < 0.01
						local horizontal = math.abs(a.Z - b.Z) < 0.01
						local along = vertical and z or x
						local low = vertical and math.min(a.Z, b.Z) or math.min(a.X, b.X)
						local high = vertical and math.max(a.Z, b.Z) or math.max(a.X, b.X)
						local width = vertical and d or w
						local depth = vertical and w or d
						local distance = vertical and math.abs(x - a.X) - w / 2 or math.abs(z - a.Z) - d / 2
						if
							(vertical or horizontal)
							and width >= 28
							and depth >= 24
							and along >= low + 16
							and along <= high - 16
							and distance >= edge.Width / 2
							and distance <= edge.Width / 2 + 24
							and distance < score
						then
							score = distance
							best = {
								Axis = vertical and "X" or "Z",
								Sign = (vertical and x < a.X or horizontal and z < a.Z) and 1 or -1,
								Width = width,
								Depth = depth,
							}
						end
					end
				end
			end
		end
		if best then
			local face = best.Axis == "X" and x + best.Sign * w / 2 or z + best.Sign * d / 2
			for step = 0, math.ceil(score) do
				local px = best.Axis == "X" and face + best.Sign * step or x
				local pz = best.Axis == "X" and z or face + best.Sign * step
				for otherIndex, other in ipairs(lots) do
					if
						otherIndex ~= index
						and px > other[1] - 2
						and px < other[3] + 2
						and pz > other[2] - 2
						and pz < other[4] + 2
					then
						best = nil
						break
					end
				end
				for _, p in ipairs(existingParts or {}) do
					if
						p.Collision
						and p.Y + p.H / 2 > 1
						and p.Y - p.H / 2 < 10
						and math.abs(px - p.X) < p.W / 2 + 2
						and math.abs(pz - p.Z) < p.D / 2 + 2
					then
						best = nil
						break
					end
				end
				if not best then
					break
				end
			end
		end
		if best then
			local f = best
			f.ApproachDistance = score
			f.Lot = index
			f.Kind = kinds[#result.Fronts % #kinds + 1]
			f.Enterable = f.Kind ~= "BoardedStore"
			f.X = x
			f.Z = z
			f.RoomDepth = math.min((f.Kind == "ServiceCounter" or f.Kind == "MarketStall") and 20 or 24, f.Depth - 2)
			f.Face = f.Axis == "X" and x + f.Sign * w / 2 or z + f.Sign * d / 2
			f.Id = "StreetFront_" .. index
			local function part(name, u, y, v, uw, h, vd, color)
				local px = f.Axis == "X" and f.Face - f.Sign * v or x + u
				local pz = f.Axis == "X" and z + u or f.Face - f.Sign * v
				table.insert(result.Parts, {
					Name = f.Id .. "_" .. name,
					X = px,
					Y = y,
					Z = pz,
					W = f.Axis == "X" and vd or uw,
					H = h,
					D = f.Axis == "X" and uw or vd,
					Color = color or "HumanDark",
					Collision = true,
				})
			end
			-- Full upper mass and solid rear remain. Interior uses the existing continuous paving/support.
			part("UpperMass", 0, 41, f.Depth / 2, f.Width, 46, f.Depth)
			part("RearMass", 0, 9, (f.Depth + f.RoomDepth) / 2, f.Width, 18, f.Depth - f.RoomDepth)
			part("LeftWall", -f.Width / 2 + 1, 9, f.RoomDepth / 2, 2, 18, f.RoomDepth)
			part("RightWall", f.Width / 2 - 1, 9, f.RoomDepth / 2, 2, 18, f.RoomDepth)
			local jamb = (f.Width - 14) / 2
			if f.Kind == "ServiceCounter" then
				part("ServiceSill", -(14 + jamb) / 2, 2, 1, jamb, 4, 2, "Human")
				part("ServiceHeader", -(14 + jamb) / 2, 12, 1, jamb, 4, 2, "Human")
				part("ServiceDesk", -(14 + jamb) / 2, 4, 2, jamb, 1, 4, "Military")
			else
				part("FrontLeft", -(14 + jamb) / 2, 7, 1, jamb, 14, 2, "Human")
			end
			part("FrontRight", (14 + jamb) / 2, 7, 1, jamb, 14, 2, "Human")
			part("Lintel", 0, 16, 1, f.Width, 4, 2, "Military")
			-- Recessed overhang and fascia stay inside the lot/route boundary.
			part("Canopy", 0, 13, 3, f.Width - 2, 1, 6, "Military")
			part(f.Kind .. "Fascia", 0, 15, 0.3, math.min(f.Width - 4, 30), 2, 0.6, "Human")
			if f.Enterable then
				part("Counter", -f.Width / 2 + 5, 2, 12, 6, 4, 7, "Human")
				part("Shelving", f.Width / 2 - 3, 4, f.RoomDepth - 4, 3, 8, 5, "Military")
				part("ShelfGoods", f.Width / 2 - 3, 8.5, f.RoomDepth - 4, 2, 1, 3, "Human")
				if f.Kind == "GuardSupply" then
					part("SupplyLocker", -f.Width / 2 + 4, 5, f.RoomDepth - 3, 4, 10, 4, "Military")
				elseif f.Kind == "Shopfront" then
					part("DisplayTable", f.Width / 2 - 4, 2, 6, 4, 4, 5, "Human")
				end
				if f.Kind == "Workshop" then
					part("WorkBench", -f.Width / 2 + 5, 3, f.RoomDepth - 3, 6, 6, 4, "Military")
				end
				if f.Kind == "MarketStall" then
					part("StallFrame", -f.Width / 2 + 5, 8, 12, 6, 1, 8, "Human")
				end
			else
				for y = 2, 10, 4 do
					part("Boards", 0, y, 1, 14, 2, 1, "Human")
				end
			end
			f.Entry = { X = f.Axis == "X" and f.Face or x, Y = 0, Z = f.Axis == "X" and z or f.Face }
			f.Home = {
				X = f.Axis == "X" and f.Face - f.Sign * (f.RoomDepth - 5) or x,
				Y = 0,
				Z = f.Axis == "X" and z or f.Face - f.Sign * (f.RoomDepth - 5),
			}
			table.insert(result.Fronts, f)
			result.ByLot[index] = f
		end
	end
	return result
end
return Frontage
