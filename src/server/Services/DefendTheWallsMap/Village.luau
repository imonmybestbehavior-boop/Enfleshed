--!strict
-- The ruined hamlet every wave walks through, and the three spawn grounds beyond it.
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Village = {}
local C, M = Kit.Color, Kit.Material

local function house(parent: Instance, spec: any)
	local model = Instance.new("Model")
	model.Name = "House"
	local base = CFrame.new(spec.X, 0, spec.Z) * CFrame.Angles(0, math.rad(spec.Yaw), 0)
	local w, d, storey = spec.Width, spec.Depth, 9
	local h = storey * spec.Stories
	-- Stone footing, plaster infill, dark oak frame.
	Kit.part(model, "Footing", Vector3.new(w + 1, 2, d + 1), base * CFrame.new(0, 1, 0), M.Rock, C.SlateWet)
	for _, side in { -1, 1 } do
		Kit.part(
			model,
			"WallLong",
			Vector3.new(w, h, 1),
			base * CFrame.new(0, 2 + h / 2, side * d / 2),
			M.Plaster,
			C.Plaster
		)
		Kit.part(
			model,
			"WallShort",
			Vector3.new(1, h, d),
			base * CFrame.new(side * w / 2, 2 + h / 2, 0),
			M.Plaster,
			C.Plaster
		)
	end
	-- Doorway gap on the front: carve by covering with a dark recess (blockout).
	Kit.detail(model, "Door", Vector3.new(4, 7, 0.4), base * CFrame.new(0, 5.5, -d / 2 - 0.6), M.Wood, C.Oak)
	for x = -w / 2, w / 2, w / 3 do
		for _, side in { -1, 1 } do
			Kit.detail(
				model,
				"Beam",
				Vector3.new(0.8, h, 0.4),
				base * CFrame.new(x, 2 + h / 2, side * (d / 2 + 0.6)),
				M.Timber,
				C.Oak
			)
		end
	end
	for level = 1, spec.Stories do
		for _, side in { -1, 1 } do
			Kit.detail(
				model,
				"Rail",
				Vector3.new(w, 0.8, 0.4),
				base * CFrame.new(0, 2 + level * storey - 0.4, side * (d / 2 + 0.6)),
				M.Timber,
				C.Oak
			)
		end
	end
	-- Pitched roof from two wedges; a broken roof loses one half and shows rafters.
	local rise = d * 0.45
	local roofY = 2 + h + rise / 2
	Kit.wedge(
		model,
		"Roof",
		Vector3.new(w + 2, rise, d / 2 + 1),
		base * CFrame.new(0, roofY, -d / 4 - 0.5),
		M.Wood,
		C.OakPale
	)
	if spec.RoofBroken then
		for x = -w / 2 + 1, w / 2 - 1, 3 do
			Kit.detail(
				model,
				"Rafter",
				Vector3.new(0.6, 0.6, d / 2 + 2),
				base * CFrame.new(x, roofY, d / 4) * CFrame.Angles(math.atan2(rise, d / 2), 0, 0),
				M.Timber,
				C.Oak
			)
		end
		Kit.detail(
			model,
			"Rubble",
			Vector3.new(w * 0.6, 1.5, 4),
			base * CFrame.new(1, 2.8, d / 2 + 3) * CFrame.Angles(0.2, 0.3, 0),
			M.Rock,
			C.Slate
		)
	else
		Kit.wedge(
			model,
			"Roof",
			Vector3.new(w + 2, rise, d / 2 + 1),
			base * CFrame.new(0, roofY, d / 4 + 0.5) * CFrame.Angles(0, math.pi, 0),
			M.Wood,
			C.OakPale
		)
	end
	Kit.lantern(model, (base * CFrame.new(w / 2 - 1.5, 7.5, -d / 2 - 1.6)).Position)
	model.Parent = parent
end

local function chapel(parent: Instance, at: any)
	local model = Instance.new("Model")
	model.Name = "Chapel"
	local base = CFrame.new(at.X, 0, at.Z)
	local w, d, h = 20, 36, 18
	Kit.part(model, "Floor", Vector3.new(w, 1, d), base * CFrame.new(0, 0.5, 0), M.Cobble, C.Cobble)
	for _, side in { -1, 1 } do
		Kit.part(model, "Nave", Vector3.new(2, h, d), base * CFrame.new(side * w / 2, h / 2, 0), M.Wall, C.Slate)
		for z = -d / 2 + 4, d / 2 - 4, 8 do
			Kit.part(
				model,
				"Buttress",
				Vector3.new(3, h * 0.7, 2.5),
				base * CFrame.new(side * (w / 2 + 2), h * 0.35, z),
				M.Wall,
				C.SlateWet
			)
		end
	end
	Kit.part(model, "Apse", Vector3.new(w, h, 2), base * CFrame.new(0, h / 2, d / 2), M.Wall, C.Slate)
	-- Façade with an arched doorway gap, then the collapsed spire: a broken stump plus fallen blocks.
	for _, side in { -1, 1 } do
		Kit.part(model, "Facade", Vector3.new(7, h, 2), base * CFrame.new(side * 6.5, h / 2, -d / 2), M.Wall, C.Slate)
	end
	Kit.part(model, "Lintel", Vector3.new(6, 6, 2), base * CFrame.new(0, h - 3, -d / 2), M.Wall, C.Slate)
	Kit.part(
		model,
		"SpireStump",
		Vector3.new(8, 12, 8),
		base * CFrame.new(0, h + 6, -d / 2 + 4) * CFrame.Angles(0, 0, 0.08),
		M.Wall,
		C.SlateWet
	)
	for i, offset in { Vector3.new(-14, 2, -8), Vector3.new(-18, 1.5, 2), Vector3.new(-11, 3, 10) } do
		Kit.part(
			model,
			"FallenSpire",
			Vector3.new(5, 5, 9 - i),
			base * CFrame.new(offset) * CFrame.Angles(0.3 * i, 0.9 * i, 0.2),
			M.Wall,
			C.Slate
		)
	end
	-- Candles in the nave: the one warm interior.
	for z = 6, d / 2 - 4, 4 do
		for _, x in { -4, 4 } do
			local candle = Kit.detail(
				model,
				"Candle",
				Vector3.new(0.3, 1, 0.3),
				base * CFrame.new(x, 1.5, z),
				Enum.Material.Neon,
				C.Flame
			)
			if z == 10 then
				Kit.light(candle, C.Flame, 16, 1.4)
			end
		end
	end
	model.Parent = parent
end

local function graveyard(parent: Instance, at: any, random: any)
	local model = Instance.new("Model")
	model.Name = "Graveyard"
	for row = -2, 2 do
		for col = -3, 3 do
			if random.next() < 0.75 then
				local p = Vector3.new(at.X + col * 5 + random.range(-1, 1), 0, at.Z + row * 6)
				Kit.part(
					model,
					"Headstone",
					Vector3.new(2.4, 3 + random.next() * 1.5, 0.6),
					CFrame.new(p + Vector3.new(0, 1.6, 0))
						* CFrame.Angles(random.range(-0.15, 0.15), 0, random.range(-0.12, 0.12)),
					M.Rock,
					C.Slate,
					false
				)
			end
		end
	end
	Props.fenceLoop(model, Vector3.new(at.X, 0, at.Z), 40, 34)
	model.Parent = parent
end

local function spawnGround(parent: Instance, spawn: any, lane: any)
	local color = Kit.rgb(lane.Color)
	local pad = Kit.part(
		parent,
		"EnemySpawn_" .. spawn.Name,
		Vector3.new(30, 0.4, 18),
		CFrame.new(spawn.X, 0.2, spawn.Z),
		Enum.Material.Mud,
		C.Mud,
		false
	)
	pad:SetAttribute("Lane", spawn.Lane)
	-- Broken arch on the spawn edge marks the lane entrance, lit in the lane colour.
	for _, side in { -1, 1 } do
		Kit.part(
			parent,
			"SpawnArchPier",
			Vector3.new(4, 16, 4),
			CFrame.new(spawn.X + side * 16, 8, spawn.Z + 12),
			M.Wall,
			C.SlateWet
		)
	end
	local lintel = Kit.part(
		parent,
		"SpawnArch",
		Vector3.new(36, 3, 4),
		CFrame.new(spawn.X, 17, spawn.Z + 12)
			* CFrame.Angles(0, 0, if spawn.Lane == 2 then 0 else 0.06 * (spawn.Lane - 2)),
		M.Wall,
		C.Slate
	)
	local glow = Kit.detail(
		parent,
		"SpawnGlow",
		Vector3.new(2, 2, 2),
		CFrame.new(spawn.X, 15, spawn.Z + 10),
		Enum.Material.Neon,
		color
	)
	Kit.light(glow, color, 40, 2.5)
	Kit.label(lintel, string.upper(lane.Name) .. " ROAD", color, 80)
end

function Village.build(parent: Instance, layout: any, random: any)
	local root = Kit.folder(parent, "Village")
	for _, spec in layout.Village.Houses do
		house(root, spec)
	end
	chapel(root, layout.Village.Chapel)
	graveyard(root, layout.Village.Graveyard, random)
	Props.well(root, Kit.v(layout.Village.Well))
	Props.gallows(root, Kit.v(layout.Village.Gallows))
	for _, p in layout.Village.Carts do
		Props.cart(root, Kit.v(p), random.range(0, math.pi * 2))
	end
	for _, spawn in layout.Spawns do
		spawnGround(root, spawn, layout.Lanes[spawn.Lane])
	end
	return root
end

return Village
