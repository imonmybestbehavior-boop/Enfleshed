--!strict

local Layout = require(script.Parent.InfillLayout)
local Housing = {}

function Housing.build(ctx: any)
	local reservations = {}
	local function reserve(x: number, z: number, width: number, depth: number)
		table.insert(reservations, { x - width / 2, z - depth / 2, x + width / 2, z + depth / 2 })
	end
	-- Read the assembled geometry, reserving real route floors and existing
	-- structures rather than only relying on the abstract topology graph.
	for _, part in ctx.Groups.Human:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local p, s = part.Position, part.Size
		local paving = string.find(part.Name, "NeighborhoodPaving", 1, true)
		if not paving and p.Y - s.Y / 2 < 62 and p.Y + s.Y / 2 >= 0 then
			reserve(p.X, p.Z, s.X + 2, s.Z + 2)
		end
		if string.find(part.Name, "InteriorFloor", 1, true) then
			-- Both open ends retain a broad approach through the added housing.
			reserve(p.X, p.Z, 18, s.Z + 160)
		end
		if string.find(part.Name, "Apron", 1, true) then
			-- Partial buildings are open on their west side. Connect that opening
			-- across at least one infill column to the surrounding alley network.
			reserve(p.X - s.X / 2 - 48, p.Z, 98, 18)
		end
	end
	reserve(0, 1550, 70, 70)
	reserve(460, 650, 128, 128)
	reserve(0, 410, 66, 152)
	-- Existing upper routes need headroom too; housing tops remain below Y=62.
	local lots = Layout.build(reservations)
	local c = ctx.Config.Colors
	for index, lot in lots do
		local width, depth = lot[3] - lot[1], lot[4] - lot[2]
		local x, z = (lot[1] + lot[3]) / 2, (lot[2] + lot[4]) / 2
		local height = 40 + (index % 4) * 6
		local name = "InfillHousing" .. index
		ctx:part("Human", name, Vector3.new(x, height / 2, z), Vector3.new(width, height, depth), c.HumanDark)
		ctx:part(
			"Human",
			name .. "UpperDwelling",
			Vector3.new(x, height - 5, z),
			Vector3.new(width - 2, 10, depth - 2),
			c.Human
		)
		-- Thin facade bands suggest stacked occupied floors without adding lights
		-- or detail objects to every dwelling. All decoration stays inside its lot.
		for _, y in { 12, 24 } do
			local strip = ctx:part(
				"Human",
				name .. "WindowBand",
				Vector3.new(x, y, z - depth / 2 - 0.05),
				Vector3.new(width - 4, 1.5, 0.1),
				c.Light,
				false
			)
			strip.CanQuery = false
		end
	end
	ctx.Root:SetAttribute("InfillHousingCount", #lots)
end

return Housing
