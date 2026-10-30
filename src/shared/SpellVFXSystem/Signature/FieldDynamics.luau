-- Grounded, timed motifs built from existing atlases/meshes. No gameplay or physics ownership.
local Assets = require(script.Parent.Parent.Assets.VFXAssets)
local Manifest = require(script.Parent.Parent.Assets.VFXAssetManifest)
local ArcBeam = require(script.Parent.ArcBeam)
local Dynamics = {}
Dynamics.__index = Dynamics
local TAU = math.pi * 2
local function clamp(x)
	return math.clamp(x, 0, 1)
end
local function hash(i)
	return (i * 0.61803398875) % 1
end
local function part(parent, name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.05
	p.Parent = parent
	return p
end
local function atlas(image, name, identity)
	local id = Assets.texture(name, identity)
	local meta = Manifest.Textures[name]
	image.Image = id
	local grid = if meta and meta.Flipbook == "Grid4x4" then 4 elseif meta and meta.Flipbook == "Grid8x8" then 8 else 1
	local cell = if meta then meta.Size.X / grid else 256
	image.ImageRectSize = Vector2.one * cell
	return { Image = image, Grid = grid, Cell = cell, Frames = grid * grid }
end
local function frame(a, index)
	index = math.clamp(index, 0, a.Frames - 1)
	a.Image.ImageRectOffset = Vector2.new(index % a.Grid, math.floor(index / a.Grid)) * a.Cell
end
local function card(parent, name, identity, ground)
	local p = part(parent, "Motif_" .. name)
	local gui
	if ground then
		gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.CanvasSize = Vector2.one * 256
	else
		gui = Instance.new("BillboardGui")
		gui.Adornee = p
		gui.MaxDistance = 180
	end
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0.15
	gui.Enabled = false
	gui.Parent = p
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.ImageColor3 = Color3.new(1, 1, 1)
	image.Parent = gui
	return { Part = p, Gui = gui, Atlas = atlas(image, name, identity), Ground = ground }
end
local function display(c, cf, size, opacity, index)
	c.Part.CFrame = cf
	if c.Ground then
		c.Part.Size = Vector3.new(size, 0.025, size)
	else
		c.Gui.Size = UDim2.fromScale(size, size)
	end
	c.Gui.Enabled = opacity > 0.001
	c.Atlas.Image.ImageTransparency = 1 - clamp(opacity)
	frame(c.Atlas, index)
end

function Dynamics.new(parent, params, identity, bands, meshCapacity, trailCapacity, quality, seed)
	local self = setmetatable({
		Parent = parent,
		Params = params,
		Mode = params.Mode,
		Identity = identity,
		Bands = bands,
		Nodes = {},
		Surfaces = {},
		Meshes = 0,
		Trails = 0,
		Seed = seed or 0,
	}, Dynamics)
	local density = if quality == "Low" then 0.5 elseif quality == "Medium" then 0.75 else 1
	local mode = self.Mode
	local wanted = if mode == "Crystals"
		then 34
		elseif mode == "Runes" then 48
		elseif mode == "Flames" then 30
		elseif mode == "Wisps" then 20
		elseif mode == "OrbitWisps" then 12
		elseif mode == "Ripples" then 24
		elseif mode == "Void" then 10
		elseif mode == "Gusts" then 3
		else 2
	local count = math.min(math.max(2, math.floor(wanted * density)), math.max(0, meshCapacity))
	if mode == "Gusts" then
		count = math.min(count, trailCapacity)
	end
	if mode == "Storm" then
		count = math.min(count, math.floor(trailCapacity / 3))
	end
	if count < 1 then
		return nil
	end
	local variants = { "ice_shard_a", "ice_shard_b", "ice_cluster", "ice_spike" }
	for i = 1, count do
		local node = { U = hash(i), V = hash(i * 3.17), Phase = hash(i * 2.31), Yaw = i * 2.399963, Index = i }
		if mode == "Crystals" then
			local name = variants[(i - 1) % #variants + 1]
			node.Part = Assets.acquireMesh(name)
			node.Part.Color = Color3.new(1, 1, 1)
			node.Part.Material = Enum.Material.SmoothPlastic
			node.Part.Transparency = 1
			node.Part.Parent = parent
			node.Native = Assets.meshSize(name)
			node.Mesh = true
		elseif mode == "Storm" then
			node.Part = part(parent, "StrikeHost")
			node.Arc = ArcBeam.new(
				node.Part,
				parent,
				"",
				ColorSequence.new(bands[3]),
				{ Width = 0.28, ArcSegments = 6 },
				math.min(6, trailCapacity - self.Trails),
				i * 173
			)
			if node.Arc then
				self.Trails += node.Arc.Count
			end
		elseif mode == "Gusts" then
			node.Part = part(parent, "GustHost")
			local a, b = Instance.new("Attachment"), Instance.new("Attachment")
			a.Parent = node.Part
			b.Parent = node.Part
			local beam = Instance.new("Beam")
			beam.Name = "AdvectingGust"
			beam.Attachment0 = a
			beam.Attachment1 = b
			beam.FaceCamera = true
			beam.Segments = 12
			beam.Texture = Assets.texture("gust_strokes", identity)
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.TextureSpeed = 2
			beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
			beam.LightInfluence = 0.15
			beam.LightEmission = 0.1
			beam.Parent = parent
			node.Beam, node.A, node.B = beam, a, b
			self.Trails += 1
		elseif mode == "Void" and i > 1 then
			node.Part = Assets.acquireMesh("void_shard")
			node.Part.Color = Color3.new(1, 1, 1)
			node.Part.Material = Enum.Material.SmoothPlastic
			node.Part.Transparency = 1
			node.Part.Parent = parent
			node.Native = Assets.meshSize("void_shard")
			node.Mesh = true
		else
			local texture = if mode == "Flames"
				then "flame_tongue"
				elseif mode == "Ripples" then "ripple_ring"
				elseif mode == "Runes" then "rune_circle"
				elseif mode == "Void" then "portal_rings"
				else "soul_wisp"
			node.Card = card(
				parent,
				texture,
				identity,
				mode == "Runes" or mode == "Ripples" or (mode == "Void" and params.Ground ~= false)
			)
			node.Part = node.Card.Part
		end
		self.Meshes += 1
		table.insert(self.Nodes, node)
	end
	if mode == "Flames" or mode == "Ripples" or (mode == "Void" and params.Ground ~= false) then
		for i = 1, math.min(3, math.max(0, meshCapacity - self.Meshes)) do
			local p = part(parent, "CelGroundBand")
			p.Shape = Enum.PartType.Cylinder
			p.Material = Enum.Material.SmoothPlastic
			p.Color = if mode == "Void"
				then (if i == 1 then bands[1] else bands[5])
				else bands[if i == 1 then 1 elseif i == 2 then 2 else 3]
			table.insert(self.Surfaces, p)
			self.Meshes += 1
		end
	end
	return self
end

function Dynamics:Update(cf, size, floor, age, shown, fade, role)
	local mode = self.Mode
	local opacity = if shown then 1 - fade else 0
	local sx, sz = math.max(2, size.X), math.max(2, size.Z)
	local center = Vector3.new(cf.Position.X, floor, cf.Position.Z)
	if mode == "Void" and role ~= "Field" then
		self.VoidOrigin = self.VoidOrigin or (if self.Params.Ground == false then cf.Position else center)
		center = self.VoidOrigin
	end
	for i, p in self.Surfaces do
		local scale = ({ 1, 0.87, 0.48 })[i]
		p.Size = Vector3.new(0.03, sx * scale, sz * scale)
		p.CFrame = CFrame.new(center + Vector3.new(if i == 3 then sx * 0.12 else 0, 0.035 + i * 0.025, 0))
			* CFrame.Angles(0, 0, math.pi / 2)
		p.Transparency = 1 - opacity * (if mode == "Flames" then 0.9 else 0.78)
	end
	for i, node in self.Nodes do
		local angle = node.U * TAU
		local radius = math.sqrt(node.V) * 0.46
		local base = center + Vector3.new(math.cos(angle) * radius * sx, 0, math.sin(angle) * radius * sz)
		if role == "Field" and not node.FloorChecked then
			local hit = workspace:Raycast(base + Vector3.yAxis * 5, -Vector3.yAxis * 15)
			node.GroundY = if hit then hit.Position.Y else floor
			node.FloorChecked = true
		end
		base = Vector3.new(base.X, node.GroundY or floor, base.Z)
		local phase = (age / (if mode == "Ripples" then 1.1 elseif mode == "Runes" then 3.5 else 2.6) + node.Phase) % 1
		local born = true
		if mode == "Wisps" or mode == "OrbitWisps" then
			local localAge = age - i * 0.09
			born = localAge >= 0
			phase = (math.max(0, localAge) / (2.2 + node.V * 0.8)) % 1
		end
		if mode == "Crystals" then
			local scale = 0.65 + node.V * 1.7
			local v = node.Native * Vector3.new(scale * (0.65 + node.U * 0.6), scale, scale * (0.6 + node.Phase * 0.8))
			local emerge = clamp((age - i * 0.006) / 0.4)
			Assets.place(
				node.Part,
				CFrame.new(base + Vector3.yAxis * (v.Y * 0.45 - (1 - emerge) * v.Y))
					* CFrame.Angles(0.12 * math.sin(i), node.Yaw, 0.1 * math.cos(i)),
				v
			)
			node.Part.Transparency = 1 - opacity
		elseif mode == "Flames" then
			local h = 1.8 + node.V * 1.5
			display(
				node.Card,
				CFrame.new(base + Vector3.yAxis * h * 0.42),
				h,
				opacity * (0.85 + 0.15 * math.sin(age * 9 + i)),
				math.floor((age * 22 + i * 5) % node.Card.Atlas.Frames)
			)
		elseif mode == "Runes" then
			local a = clamp(phase / 0.12) * clamp((1 - phase) / 0.18)
			display(
				node.Card,
				CFrame.new(base + Vector3.yAxis * 0.09) * CFrame.Angles(0, node.Yaw, 0),
				0.9 + node.V * 1.6,
				opacity * a,
				0
			)
		elseif mode == "Ripples" then
			display(
				node.Card,
				CFrame.new(base + Vector3.yAxis * 0.15),
				1.5 + node.V * 2.5,
				opacity * clamp((1 - phase) * 3),
				math.floor(phase * (node.Card.Atlas.Frames - 1))
			)
		elseif mode == "Wisps" or mode == "OrbitWisps" then
			local h = 1.1 + node.V * 0.7
			local pos
			if mode == "Wisps" then
				pos = base + Vector3.yAxis * (-h * 0.5 + phase * (3.5 + h))
			else
				local theta = phase * TAU + node.Yaw
				local r = math.sin(phase * math.pi) * (1.8 + node.V)
				pos = cf.Position
					+ Vector3.new(math.cos(theta) * r, (phase - 0.5) * math.max(4, size.Y), math.sin(theta) * r)
			end
			local a = clamp((1 - phase) / 0.25) * (if mode == "OrbitWisps" then clamp(phase / 0.12) else 1)
			display(
				node.Card,
				CFrame.new(pos),
				h,
				if born then opacity * a else 0,
				math.floor((age * 14 + i * 3) % node.Card.Atlas.Frames)
			)
		elseif mode == "Storm" then
			local cycle = math.floor(age * 1.8 + node.Phase)
			local t = (age * 1.8 + node.Phase) % 1
			local x = math.sin(cycle * 12.7 + i) * sx * 0.42
			local z = math.cos(cycle * 5.2 + i) * sz * 0.42
			local target = center + Vector3.new(x, 0.1, z)
			node.Part.CFrame = CFrame.lookAt(target + Vector3.yAxis * 8, target)
			if node.Arc then
				node.Arc:Update(8, 0.65, age, shown and t < 0.26, if t < 0.26 then t / 0.26 else 1)
			end
		elseif mode == "Gusts" then
			local width = math.min(sx, sz)
			local direction = if role == "Field" then cf.RightVector else cf.LookVector
			local p = center
				+ direction * ((phase - 0.5) * sx)
				+ cf.RightVector * ((node.V - 0.5) * sz * 0.5)
				+ Vector3.yAxis * (1 + node.V * 2)
			node.Part.CFrame = CFrame.lookAt(p, p + direction)
			node.A.CFrame = CFrame.Angles(0, 0, math.pi / 2)
			node.B.CFrame = CFrame.new(0, 0, -math.max(3, width * 0.6)) * CFrame.Angles(0, 0, math.pi / 2)
			node.Beam.Width0 = 0.5 + width * 0.06
			node.Beam.Width1 = 0.2
			node.Beam.CurveSize0 = width * 0.12
			node.Beam.CurveSize1 = -width * 0.1
			node.Beam.Transparency = NumberSequence.new(1 - opacity * math.sin(phase * math.pi))
			node.Beam.Enabled = shown and fade < 1
		elseif mode == "Void" then
			local portalSize = math.max(3, math.min(sx, sz) * 0.85)
			if node.Card then
				local pos = center
				local opened = age
				if role == "Projectile" then
					if not node.Fixed or age - (node.Opened or 0) > 1.1 then
						node.Fixed = cf.Position
						node.Opened = age
					end
					pos = node.Fixed - Vector3.yAxis * 0.3
					opened = age - node.Opened
				end
				self.PortalPosition = pos
				display(
					node.Card,
					CFrame.new(pos + Vector3.yAxis * 0.14),
					portalSize * clamp(opened / 0.25),
					opacity * (if role == "Projectile" then clamp((1.1 - opened) / 0.2) else 1),
					0
				)
			else
				local pos = self.PortalPosition or center
				local a = phase * TAU + node.Yaw
				local r = math.sin(phase * math.pi) * portalSize * 0.3
				local v = node.Native * (0.15 + node.V * 0.22)
				Assets.place(
					node.Part,
					CFrame.new(pos + Vector3.new(math.cos(a) * r, phase * 5, math.sin(a) * r))
						* CFrame.Angles(0, a, 0.25),
					v
				)
				node.Part.Transparency = 1 - opacity * clamp((1 - phase) / 0.3)
			end
		end
	end
end

function Dynamics:Destroy()
	for _, node in self.Nodes do
		if node.Mesh then
			Assets.releaseMesh(node.Part)
		else
			node.Part:Destroy()
		end
	end
	for _, p in self.Surfaces do
		p:Destroy()
	end
end

return Dynamics
