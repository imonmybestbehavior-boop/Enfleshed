--!strict
-- The ground between walls, so losing a wall means fighting through somewhere,
-- not crossing an empty strip. Pieces come from the layout (DefendTheWallsLayout
-- baileys): barricade chicanes per lane, a building on each tower line, raised
-- firing terraces on the flanks, and burnt wagons. Everything here collides.
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)

local Baileys = {}
local C, M = Kit.Color, Kit.Material

local function barricade(parent: Instance, piece: any)
	local model = Instance.new("Model")
	model.Name = "Barricade"
	local base = CFrame.new(piece.X, 0, piece.Z)
	Kit.part(model, "Beam", Vector3.new(piece.W, 1.2, 1.2), base * CFrame.new(0, piece.H * 0.55, 0), M.Timber, C.Oak)
	Kit.part(
		model,
		"Block",
		Vector3.new(piece.W, piece.H * 0.5, piece.D),
		base * CFrame.new(0, piece.H * 0.25, 0),
		M.Wood,
		C.OakPale
	)
	for x = -piece.W / 2 + 1, piece.W / 2 - 1, 2.5 do
		for _, tilt in { -0.6, 0.6 } do
			Kit.detail(
				model,
				"Stake",
				Vector3.new(0.5, 0.5, 5),
				base * CFrame.new(x, piece.H * 0.6, 0) * CFrame.Angles(tilt, 0, 0),
				M.Timber,
				C.Oak
			)
		end
	end
	model.Parent = parent
end

-- Roofless ruined building with a doorway on each lane-facing side and a lit interior.
local function building(parent: Instance, piece: any)
	local model = Instance.new("Model")
	model.Name = piece.Kind
	local base = CFrame.new(piece.X, 0, piece.Z)
	local w, d, h = piece.W, piece.D, piece.H
	local stone = piece.Kind ~= "Stables"
	local material, color = if stone then M.Wall else M.Wood, if stone then C.Slate else C.Oak
	Kit.part(model, "Floor", Vector3.new(w, 0.6, d), base * CFrame.new(0, 0.3, 0), M.Cobble, C.Cobble)
	for _, side in { -1, 1 } do
		Kit.part(model, "Wall", Vector3.new(w, h, 1.5), base * CFrame.new(0, h / 2, side * d / 2), material, color)
		-- Short walls split around a doorway.
		local doorway = 6
		local seg = (d - doorway) / 2
		for _, half in { -1, 1 } do
			Kit.part(
				model,
				"Wall",
				Vector3.new(1.5, h, seg),
				base * CFrame.new(side * w / 2, h / 2, half * (doorway + seg) / 2),
				material,
				color
			)
		end
		Kit.part(
			model,
			"Lintel",
			Vector3.new(1.5, h - 8, doorway),
			base * CFrame.new(side * w / 2, 8 + (h - 8) / 2, 0),
			material,
			color
		)
	end
	-- Collapsed roof beams and rubble inside.
	for x = -w / 2 + 3, w / 2 - 3, 5 do
		Kit.detail(
			model,
			"RoofBeam",
			Vector3.new(0.8, 0.8, d),
			base * CFrame.new(x, h - 0.5, 0) * CFrame.Angles(0, 0, (x % 3) * 0.05),
			M.Timber,
			C.Oak
		)
	end
	Kit.part(
		model,
		"Rubble",
		Vector3.new(6, 2, 4),
		base * CFrame.new(-w / 4, 1, -d / 4) * CFrame.Angles(0.15, 0.4, 0.1),
		M.Rock,
		C.SlateWet
	)
	if piece.Kind == "WardenChapel" then
		for i = -2, 2 do
			local candle = Kit.detail(
				model,
				"Candle",
				Vector3.new(0.3, 1, 0.3),
				base * CFrame.new(i * 1.5, 1.6, d / 2 - 2),
				Enum.Material.Neon,
				C.Flame
			)
			if i == 0 then
				Kit.light(candle, C.Flame, 18, 1.4)
			end
		end
	elseif piece.Kind == "Armoury" or piece.Kind == "Barracks" then
		Kit.brazier(model, (base * CFrame.new(w / 4, 0, 0)).Position)
		for i = -2, 2 do
			Kit.detail(
				model,
				"WeaponRack",
				Vector3.new(0.4, 5, 0.4),
				base * CFrame.new(i * 1.2 - w / 4, 2.5, d / 2 - 1.5) * CFrame.Angles(0.2, 0, 0),
				M.Timber,
				C.Oak
			)
		end
	else
		Kit.lantern(model, (base * CFrame.new(0, 8, 0)).Position)
	end
	Kit.banner(model, base * CFrame.new(0, h + 1, -d / 2 - 0.9), 6)
	model.Parent = parent
end

-- Raised timber firing terrace on a flank, ramp on the city side.
local function terrace(parent: Instance, piece: any)
	local model = Instance.new("Model")
	model.Name = "Terrace"
	local base = CFrame.new(piece.X, 0, piece.Z)
	Kit.part(model, "Deck", Vector3.new(piece.W, 1, piece.D), base * CFrame.new(0, piece.H, 0), M.Wood, C.OakPale)
	Kit.part(
		model,
		"Base",
		Vector3.new(piece.W, piece.H - 0.5, piece.D),
		base * CFrame.new(0, (piece.H - 0.5) / 2, 0),
		M.Rock,
		C.SlateWet
	)
	Kit.part(
		model,
		"Parapet",
		Vector3.new(piece.W, 3, 1),
		base * CFrame.new(0, piece.H + 2, -piece.D / 2 + 0.5),
		M.Timber,
		C.Oak
	)
	local inward = if piece.X > 0 then -1 else 1
	local rampLength = piece.H * 2.4
	-- A wedge's tall end is local +Z; turn it to face the deck from the inner side.
	Kit.wedge(
		model,
		"Ramp",
		Vector3.new(8, piece.H, rampLength),
		base
			* CFrame.new(inward * (piece.W / 2 + rampLength / 2), piece.H / 2, piece.D / 4)
			* CFrame.Angles(0, inward * -math.pi / 2, 0),
		M.Wood,
		C.OakPale
	)
	Kit.torch(model, (base * CFrame.new(inward * (piece.W / 2 - 2), piece.H, -piece.D / 2 + 2)).Position)
	model.Parent = parent
end

function Baileys.build(parent: Instance, layout: any)
	local root = Kit.folder(parent, "Baileys")
	for _, bailey in layout.Baileys do
		local folder = Kit.folder(root, "Bailey" .. bailey.Level)
		for _, piece in bailey.Pieces do
			if piece.Kind == "Barricade" then
				barricade(folder, piece)
			elseif piece.Kind == "Terrace" then
				terrace(folder, piece)
			elseif piece.Kind == "Wagon" then
				Props.cart(folder, Vector3.new(piece.X, 0, piece.Z), math.rad(piece.Yaw or 0))
				local fire = Instance.new("Fire")
				fire.Size, fire.Heat = 6, 8
				local anchor = Kit.detail(
					folder,
					"WagonFire",
					Vector3.new(1, 1, 1),
					CFrame.new(piece.X, 3, piece.Z),
					M.Rock,
					C.Iron
				)
				anchor.Transparency = 1
				fire.Parent = anchor
				Kit.light(anchor, C.Flame, 24, 1.8)
			else
				building(folder, piece)
			end
		end
		-- Torches down the middle of each bailey so the fight between walls stays lit.
		for _, x in { -84, -28, 28, 84 } do
			Kit.torch(folder, Vector3.new(x, 0, (bailey.MinZ + bailey.MaxZ) / 2 + 12))
		end
	end
	return root
end

return Baileys
