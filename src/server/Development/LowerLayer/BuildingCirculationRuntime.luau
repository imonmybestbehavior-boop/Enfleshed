--!strict
local Solid = require(script.Parent.SolidClipping)
local Layout = require(script.Parent.BuildingCirculation)
local Connections = require(script.Parent.BuildingConnections)
local Runtime = {}
function Runtime.apply(ctx, plan, placements)
	assert(#placements == #Connections.Buildings, "Rebuild building connections after changing placements")
	for i, entry in ipairs(placements) do
		local actual, expected = entry.Asset, Connections.Buildings[i]
		assert(
			actual.Name == expected.Name
				and actual.X == expected.X
				and actual.Z == expected.Z
				and actual.Yaw == expected.Yaw,
			"Stale building connections: run scripts/build_building_connections.py"
		)
		-- Retire sealed hallway doors and replace upper floor slabs with stair-ready floors.
		for _, part in ipairs(entry.Model:GetDescendants()) do
			if part:IsA("BasePart") and Layout.removeSourcePart(part.Name, part.Position.Y) then
				ctx.PartCount -= 1
				part:Destroy()
			end
		end
	end
	local layout = Layout.build(Connections, plan, Solid)
	local index = Solid.index(layout.Cuts)
	-- Cut both collision AND visible geometry. Old block masses are allowed to
	-- change wherever real circulation requires it; no invisible-wall shortcuts.
	for _, part in ipairs(ctx.Root:GetDescendants()) do
		if part:IsA("BasePart") then
			local cf, size = part.CFrame, part.Size
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local width = math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(l.X) * size.Z
			local height = math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(l.Y) * size.Z
			local depth = math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(l.Z) * size.Z
			local p = { X = cf.X, Y = cf.Y, Z = cf.Z, W = width, H = height, D = depth }
			local cuts = Solid.near(p, index)
			if #cuts > 0 then
				local pieces = Solid.parts(p, cuts)
				local unchanged = #pieces == 1
					and math.abs(pieces[1].W - width) < 0.001
					and math.abs(pieces[1].H - height) < 0.001
					and math.abs(pieces[1].D - depth) < 0.001
				if not unchanged then
					for _, piece in ipairs(pieces) do
						local replacement = part:Clone()
						replacement.Size = Vector3.new(piece.W, piece.H, piece.D)
						replacement.CFrame = CFrame.new(piece.X, piece.Y, piece.Z)
						replacement.Parent = part.Parent
					end
					ctx.PartCount += #pieces - 1
					part:Destroy()
				end
			end
		end
	end
	for _, p in ipairs(layout.Parts) do
		ctx:part(
			"Human",
			p.Name,
			Vector3.new(p.X, p.Y, p.Z),
			Vector3.new(p.W, p.H, p.D),
			ctx.Config.Colors[p.Color],
			true
		)
	end
	-- Deduplicate nearby fixtures and cap new lights; intersections remain readable.
	local lit = {}
	local lightCount = 0
	for _, p in ipairs(layout.Lights) do
		local key = math.floor(p.X / 24) .. ":" .. math.floor(p.Y / 16) .. ":" .. math.floor(p.Z / 24)
		if not lit[key] and lightCount < 320 then
			lit[key] = true
			lightCount += 1
			ctx:lamp(Vector3.new(p.X, p.Y, p.Z), 24, 1.2, false)
		end
	end
	ctx.Root:SetAttribute("InteriorConnectedBuildings", #Connections.Buildings)
	ctx.Root:SetAttribute("InteriorConnections", #Connections.Links)
	ctx.Root:SetAttribute("InteriorGraphCycles", #Connections.Links - #Connections.Buildings + 1)
	ctx.Root:SetAttribute("InteriorCirculationLevels", "36.5, 52.5")
	ctx.Root:SetAttribute("InteriorCirculationLights", lightCount)
	ctx.Root:SetAttribute("InteriorNewPartCount", #layout.Parts)
	ctx.Root:SetAttribute(
		"EnvironmentalLightCount",
		(ctx.Root:GetAttribute("EnvironmentalLightCount") or 0) + lightCount
	)
end
return Runtime
