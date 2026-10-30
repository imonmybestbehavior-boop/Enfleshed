assert(not game:GetService("RunService"):IsRunning(),"Edit mode required")
local rs=game:GetService("ReplicatedStorage");local s=rs.Shared.SpellVFXSystem
local backup=rs.VFXRestyleSourceBackup
do local parent=s.Signature;local m=parent:FindFirstChild("ArcBeam")
if m and not backup:FindFirstChild("ArcBeam") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="ArcBeam";m.Parent=parent end
m.Source=[=[-- A connected, flickering polyline. Points are local to the authoritative beam host.
-- This owns cosmetic attachments/beams only; it never computes a hit or sends a remote.
local ArcBeam = {}
ArcBeam.__index = ArcBeam

function ArcBeam.new(host, parent, texture, colors, params, capacity, seed)
	if capacity < 3 then return nil end
	local count = math.clamp(math.floor(params.ArcSegments or 9), 3, math.min(10, capacity))
	local branchCount = math.min(2, math.floor((capacity - count) / 2))
	local self = setmetatable({ Points={}, Beams={}, Branches={}, Seed=seed or 0, Params=params }, ArcBeam)
	local function point()
		local a=Instance.new("Attachment");a.Name="ArcPoint";a.Parent=host
		return a
	end
	local function segment(a,b,branch)
		local beam=Instance.new("Beam");beam.Name=if branch then "ArcBranch" else "ConnectedArc"
		beam.Attachment0=a;beam.Attachment1=b;beam.FaceCamera=true;beam.Segments=1
		-- The existing strip's thin alpha becomes gaps when repeated on short segments.
		-- Solid ribbons keep every joint visibly connected; color comes from the same palette.
		beam.Texture="";beam.TextureMode=Enum.TextureMode.Stretch;beam.TextureSpeed=0
		beam.Color=colors;beam.LightEmission=.2;beam.LightInfluence=.25
		beam.Transparency=NumberSequence.new(if branch then .2 else 0)
		beam.Parent=parent;table.insert(self.Beams,{Beam=beam,Branch=branch})
	end
	for i=1,count+1 do self.Points[i]=point() end
	for i=1,count do segment(self.Points[i],self.Points[i+1],false) end
	for i=1,branchCount do
		local start=math.floor(count*(.25+i*.2))+1
		local mid,tip=point(),point()
		segment(self.Points[start],mid,true);segment(mid,tip,true)
		table.insert(self.Branches,{Start=start,Mid=mid,Tip=tip})
	end
	self.Count=#self.Beams
	return self
end

function ArcBeam:Update(range,width,age,shown,fading)
	local tick=math.floor(age*18)
	if tick~=self.Tick or range~=self.Range or width~=self.Width then
		self.Tick,self.Range,self.Width=tick,range,width
		local random=Random.new((self.Seed+tick*7919)%2147483647)
		local n=#self.Points-1
		local amplitude=math.min(1.6,range*.045,width*.6+.2)
		for i,a in self.Points do
			local u=(i-1)/n
			local spread=math.sin(u*math.pi)*amplitude
			a.Position=Vector3.new(random:NextNumber(-spread,spread),random:NextNumber(-spread,spread),-range*u)
		end
		-- Exact endpoints, including while a beam changes length or its host moves.
		self.Points[1].Position=Vector3.zero
		self.Points[#self.Points].Position=Vector3.new(0,0,-range)
		for i,branch in self.Branches do
			local origin=self.Points[branch.Start].Position
			local side=if i%2==0 then -1 else 1
			branch.Mid.Position=origin+Vector3.new(side*amplitude*.65,amplitude*.45,-range*.06)
			branch.Tip.Position=origin+Vector3.new(side*amplitude*1.3,-amplitude*.3,-range*.12)
		end
	end
	for _,entry in self.Beams do
		local w=math.max(.025,width*(self.Params.Width or .18))*(if entry.Branch then .45 else 1)*(1-fading)
		entry.Beam.Width0=w;entry.Beam.Width1=w*(if entry.Branch then .12 else .8)
		entry.Beam.Enabled=shown and fading<1
	end
end

return ArcBeam
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("SignatureKits")
if m and not backup:FindFirstChild("SignatureKits") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="SignatureKits";m.Parent=parent end
m.Source=[=[-- Pure data: identity kits and the form templates that turn a kit into signature layers.
-- A kit names its assets per visual role, a four-tone palette and a few motion "feel" numbers.
-- Templates then produce Projectile, Beam, Wave, Field, Aura, SelfEnhancement, Construct,
-- Manipulation, Cast (charge/release), Impact and Dissipate layers for it. Hand-authored
-- signature layers (Fire's projectile, Body's wave) replace the template for the roles they own.
--
-- Art direction: cel-shaded dark fantasy. Bodies render with low light emission so the ink
-- outlines baked into the textures (and the `_ink` hull meshes) stay visible; only sparks,
-- flashes and cores marked Glow stay additive.
local Kits = {}

local function layer(t)
	t.Params = t.Params or {}
	t.Drivers = t.Drivers or {}
	t.Limits = t.Limits or {}
	return t
end
Kits.layer = layer

-- Palette tokens every kit defines: Hi (lit), Mid (body), Lo (shadow), Smoke, plus Ink.
local INK = Color3.fromRGB(14, 10, 14)

-- Template: one entry per (role, visual job). `a` = kit.Assets, `f` = kit.Feel.
local function templates(kit)
	local a, f, id = kit.Assets, kit.Feel, kit.Name
	local L = {}
	local function add(t)
		t.Id = id .. "." .. t.Id
		table.insert(L, layer(t))
	end
	local rise = f.Rise or 2
	local light = f.Light or 0.2
	local spin = f.Spin or 1

	-- Projectile -------------------------------------------------------------------------------
	add({
		Id = "Projectile.Core",
		Slot = "Core",
		Kind = "Sprite",
		Priority = 1,
		Roles = { Projectile = true },
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = { Size = 1.35, Framerate = f.Framerate or 20, RotSpeed = 40 * spin, Light = light + 0.15 },
		Drivers = { { "Framerate", "Potency", 14 }, { "Size", "Potency", 0.25 } },
	})
	if a.CoreMesh then
		add({
			Id = "Projectile.Body",
			Slot = "Core",
			Kind = "Mesh",
			Priority = 2,
			Roles = { Projectile = true },
			Mesh = a.CoreMesh,
			Colors = "Mid",
			Params = {
				Size = f.CoreMeshSize or 0.5,
				Spin = 2.5 * spin,
				Wobble = 0.05,
				Opacity = 1,
				Material = "SmoothPlastic",
				Orient = "Travel",
				RequireAsset = 1,
				Ink = 1,
			},
			Drivers = { { "Spin", "Potency", 2 }, { "Wobble", "Potency", 0.12 } },
		})
	end
	add({
		Id = "Projectile.Stream",
		Slot = "Shell",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Projectile = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 14,
			Lifetime = 0.36,
			Speed = 2,
			Spread = 24,
			Direction = "Back",
			Size = 1.0,
			SizeEnd = 0.3,
			Framerate = f.Framerate or 24,
			Light = light,
			RotSpeed = 60,
			Drag = f.Drag or 1,
		},
		Drivers = { { "Rate", "Size", 12 }, { "Rate", "Potency", 10 }, { "Speed", "Speed", 5 } },
		Limits = { Rate = { 6, 40 } },
	})
	add({
		Id = "Projectile.Trail",
		Slot = "Trail",
		Kind = "Trail",
		Priority = 1,
		Roles = { Projectile = true },
		Texture = a.Trail,
		Colors = { "Hi", "Mid", "Lo" },
		Params = { Width = 1.1, Lifetime = 0.22, Opacity = 1, Light = light, TextureLength = 4 },
		Drivers = { { "Lifetime", "Homing", 0.35 }, { "Lifetime", "Range", 0.1 } },
		Limits = { Lifetime = { 0.12, 0.6 } },
	})
	add({
		Id = "Projectile.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Projectile = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 8,
			Lifetime = 0.6,
			Speed = 3,
			Spread = 70,
			Direction = "Back",
			Size = 0.32,
			SizeEnd = 0.05,
			Drag = 2,
			Rise = rise,
			Light = 0.6,
			Glow = 1,
			RandomRotation = 1,
			Framerate = 0,
		},
		Drivers = { { "Rate", "Potency", 14 } },
	})
	add({
		Id = "Projectile.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Projectile = true },
		Colors = "Mid",
		Params = { Brightness = 1.1, Range = 9 },
		Drivers = { { "Brightness", "Potency", 0.8 } },
	})

	-- Beam -------------------------------------------------------------------------------------
	add({
		Id = "Beam.Core",
		Slot = "Core",
		Kind = "Beam",
		Priority = 1,
		Roles = { Beam = true },
		Texture = a.Beam,
		Colors = { "Hi", "Mid" },
		Params = {
			Width = if f.BeamArc then 0.22 else 1,
			Opacity = 1,
			Light = light + 0.2,
			TextureLength = 5,
			Scroll = f.Scroll or 3,
			Wobble = f.Wobble or 0,
			ArcSegments = f.BeamArc,
		},
	})
	if not f.BeamArc then
	add({
		Id = "Beam.Outer",
		Slot = "Core",
		Kind = "Beam",
		Priority = 2,
		Roles = { Beam = true },
		Texture = a.Trail,
		Colors = { "Mid", "Lo" },
		Params = {
			Width = 2.1,
			Opacity = 0.7,
			Light = light,
			TextureLength = 7,
			Scroll = -(f.Scroll or 3) * 0.6,
			Wobble = (f.Wobble or 0) * 1.5,
		},
	})
	add({
		Id = "Beam.Origin",
		Slot = "Core",
		Kind = "Sprite",
		Priority = 1,
		Roles = { Beam = true },
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = { Size = 1.6, Framerate = f.Framerate or 20, Light = light + 0.15 },
	})
	add({
		Id = "Beam.End",
		Slot = "Secondary",
		Kind = "Sprite",
		Priority = 2,
		Roles = { Beam = true },
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = { Size = 2.2, Framerate = f.Framerate or 20, Light = light + 0.15, Placement = "End" },
	})
	-- Flow: the school's main particle streams from the caster to the beam's end.
	add({
		Id = "Beam.Flow",
		Slot = "Secondary",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Beam = true },
		Texture = a.Flow or a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 9,
			Lifetime = 0.55,
			Speed = 20,
			Spread = 5,
			Direction = "Forward",
			Size = 1.4,
			SizeEnd = 0.9,
			Light = light,
			RangeSpeed = 1,
			RotSpeed = 30,
			Framerate = f.Framerate or 20,
		},
		Drivers = { { "Rate", "Potency", 8 }, { "Size", "Size", 0.8 } },
	})
	add({
		Id = "Beam.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 3,
		Roles = { Beam = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 6,
			Lifetime = 0.5,
			Speed = 2,
			Spread = 180,
			Size = 0.3,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Line",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
	})
	end -- Connected arcs fill the path; no travelling glyphs or endpoint orbs.
	add({
		Id = "Beam.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Beam = true },
		Colors = "Mid",
		Params = { Brightness = 1.4, Range = 12, Placement = "End" },
	})

	-- Wave (template; Body overrides with its bespoke cone) ------------------------------------
	add({
		Id = "Wave.Fronts",
		Slot = "Shell",
		Kind = "Burst",
		Priority = 1,
		Roles = { Wave = true },
		Texture = a.Wave,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 3,
			Lifetime = 0.3,
			Speed = 30,
			Spread = 12,
			Direction = "Forward",
			Size = 5,
			SizeEnd = 9,
			Orientation = "VelocityPerpendicular",
			OneShot = 1,
			Light = light,
			Stagger = 0.05,
			RangeSpeed = 1,
		},
		Drivers = { { "Size", "Force", 3 }, { "Count", "Potency", 2 } },
	})
	add({
		Id = "Wave.Body",
		Slot = "Secondary",
		Kind = "Burst",
		Priority = 2,
		Roles = { Wave = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 10,
			Lifetime = 0.45,
			Speed = 26,
			Spread = 26,
			Direction = "Forward",
			Size = 1.8,
			SizeEnd = 0.6,
			Light = light,
			RandomRotation = 1,
			Framerate = f.Framerate or 24,
			RangeSpeed = 1,
			ShapeRadius = 1.2,
		},
		Drivers = { { "Count", "Potency", 10 } },
	})
	add({
		Id = "Wave.Front",
		Slot = "Impact",
		Kind = "Mesh",
		Priority = 2,
		Roles = { Wave = true },
		Mesh = "shockwave_ring",
		Colors = "Hi",
		Params = {
			Size = 0.5,
			Grow = 1,
			Duration = 0.32,
			Opacity = 0.85,
			Material = "Neon",
			Orient = "Front",
			Fade = 1,
		},
	})
	add({
		Id = "Wave.Floor",
		Slot = "Ambient",
		Kind = "Burst",
		Priority = 3,
		Roles = { Wave = true },
		Texture = a.Smoke,
		Colors = { "Smoke", "Lo" },
		Params = {
			Count = 5,
			Lifetime = 0.9,
			Speed = 12,
			Spread = 16,
			Direction = "Forward",
			Size = 2,
			SizeEnd = 4,
			Drag = 3,
			Light = 0,
			Opacity = 0.75,
			Floor = 1,
			RandomRotation = 1,
			OneShot = 1,
		},
	})

	-- Field --------------------------------------------------------------------------------------
	add({
		Id = "Field.Ground",
		Slot = "Secondary",
		Kind = "Decal",
		Priority = 1,
		Roles = { Field = true },
		Texture = a.Ground,
		Colors = "Mid",
		Params = { Opacity = 0.9, Spin = 0.08 * spin, Footprint = 1, Pulse = 0.08 },
	})
	add({
		Id = "Field.Edge",
		Slot = "Secondary",
		Kind = "Mesh",
		Priority = 1,
		Roles = { Field = true },
		Mesh = "shockwave_ring",
		Colors = "Hi",
		Params = { Opacity = 0.75, Material = "Neon", Orient = "Footprint", Spin = 0.15 * spin },
	})
	add({
		Id = "Field.Body",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Field = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 10,
			RatePerArea = 0.12,
			Lifetime = 0.9,
			Speed = 2.5,
			Spread = 15,
			Size = 1.6,
			SizeEnd = 0.6,
			Light = light,
			Placement = "Area",
			Direction = "Up",
			Rise = rise,
			Framerate = f.Framerate or 20,
			RotSpeed = 30,
		},
		Drivers = { { "Rate", "Potency", 8 } },
		Limits = { Rate = { 4, 40 } },
	})
	if a.Scatter then
		add({
			Id = "Field.Scatter",
			Slot = "Ambient",
			Kind = "Mesh",
			Priority = 2,
			Roles = { Field = true },
			Mesh = a.Scatter,
			Colors = "Mid",
			Params = {
				Count = 5,
				CountPerArea = 0.04,
				Size = f.ScatterSize or 0.9,
				Duration = 0.35,
				Opacity = 1,
				Material = "SmoothPlastic",
				Orient = "Scatter",
				RequireAsset = 1,
				Ink = 1,
			},
		})
	end
	add({
		Id = "Field.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 3,
		Roles = { Field = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 6,
			RatePerArea = 0.06,
			Lifetime = 1.4,
			Speed = 1.5,
			Spread = 25,
			Size = 0.35,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Area",
			Direction = "Up",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
		Limits = { Rate = { 2, 24 } },
	})
	add({
		Id = "Field.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Field = true },
		Colors = "Mid",
		Params = { Brightness = 0.9, Range = 14 },
	})

	-- Aura / SelfEnhancement -------------------------------------------------------------------
	add({
		Id = "Aura.Mantle",
		Slot = "Shell",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Aura = true, SelfEnhancement = true },
		Texture = a.Aura or a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 14,
			Lifetime = 0.8,
			Speed = 2,
			Spread = 10,
			Size = 1.4,
			SizeEnd = 0.4,
			Light = light,
			Placement = "Body",
			Direction = "Up",
			Rise = rise,
			Framerate = f.Framerate or 20,
			RotSpeed = 20,
		},
		Drivers = { { "Rate", "Potency", 8 } },
	})
	add({
		Id = "Aura.Motes",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Aura = true, SelfEnhancement = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 8,
			Lifetime = 1.2,
			Speed = 1,
			Spread = 40,
			Size = 0.3,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Body",
			Direction = "Up",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
	})
	add({
		Id = "Aura.Ground",
		Slot = "Ambient",
		Kind = "Decal",
		Priority = 2,
		Roles = { Aura = true },
		Texture = a.Sigil or a.Ground,
		Colors = "Mid",
		Params = { Opacity = 0.7, Spin = 0.25 * spin, Footprint = 1 },
	})
	add({
		Id = "Aura.Light",
		Slot = "Ambient",
		Kind = "Light",
		Priority = 3,
		Roles = { Aura = true, SelfEnhancement = true },
		Colors = "Mid",
		Params = { Brightness = 0.8, Range = 10 },
	})

	-- Construct / Manipulation -----------------------------------------------------------------
	add({
		Id = "Construct.Surface",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 1,
		Roles = { Construct = true, Manipulation = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 10,
			RatePerArea = 0.3,
			Lifetime = 0.9,
			Speed = 1,
			Spread = 30,
			Size = 0.4,
			SizeEnd = 0.05,
			Light = 0.6,
			Glow = 1,
			Placement = "Box",
			Rise = rise,
			RandomRotation = 1,
			Framerate = 0,
		},
		Limits = { Rate = { 4, 30 } },
	})
	add({
		Id = "Construct.Crest",
		Slot = "Ambient",
		Kind = "Emitter",
		Priority = 2,
		Roles = { Construct = true, Manipulation = true },
		Texture = a.Particle,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Rate = 6,
			Lifetime = 0.7,
			Speed = 2,
			Spread = 15,
			Size = 1.0,
			SizeEnd = 0.3,
			Light = light,
			Placement = "Top",
			Direction = "Up",
			Rise = rise,
			Framerate = f.Framerate or 20,
		},
	})

	-- Cast: charge (Gather) and release --------------------------------------------------------
	add({
		Id = "Charge.Converge",
		Slot = "Charge",
		Kind = "Emitter",
		Priority = 2,
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Rate = 10,
			Lifetime = 0.35,
			Speed = 9,
			Size = 0.32,
			SizeEnd = 0.05,
			Direction = "In",
			ShapeRadius = 3.2,
			Light = 0.7,
			Glow = 1,
			Ramp = 1,
			OffsetZ = -1.6,
			OffsetY = 0.5,
			Framerate = 0,
			RandomRotation = 1,
		},
		Drivers = { { "Rate", "Charge", 20 } },
	})
	add({
		Id = "Charge.Point",
		Slot = "Charge",
		Kind = "Sprite",
		Priority = 1,
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = {
			Size = 0.5,
			Grow = 1.3,
			Framerate = f.Framerate or 20,
			Light = light + 0.2,
			Ramp = 1,
			OffsetZ = -1.6,
			OffsetY = 0.5,
		},
		Drivers = { { "Grow", "Charge", 1 } },
	})
	add({
		Id = "Charge.Sigil",
		Slot = "Charge",
		Kind = "Decal",
		Priority = 2,
		Texture = a.Sigil or "rune_circle",
		Colors = "Mid",
		Params = { Size = 4.5, Opacity = 0.85, Spin = 0.9 * spin, Ramp = 1 },
		Drivers = { { "Spin", "Charge", 1.2 } },
	})
	add({
		Id = "Cast.Flash",
		Slot = "Cast",
		Kind = "Burst",
		Priority = 1,
		-- A small flash of the school's core at the hand (not its impact cloud).
		Texture = a.Core,
		Colors = { "Hi", "Mid" },
		Params = {
			Count = 1,
			Lifetime = 0.25,
			Speed = 0,
			Size = 1.4,
			SizeEnd = 2.2,
			Light = light + 0.25,
			Framerate = f.Framerate or 20,
			OffsetZ = -1.8,
			OffsetY = 0.5,
			RandomRotation = 1,
		},
	})
	add({
		Id = "Cast.Spray",
		Slot = "Cast",
		Kind = "Burst",
		Priority = 2,
		Texture = a.Mote,
		Colors = { "Hi", "Mid" },
		Params = {
			Count = 7,
			Lifetime = 0.4,
			Speed = 14,
			Spread = 30,
			Direction = "Forward",
			Size = 0.35,
			SizeEnd = 0.05,
			Drag = 3,
			Light = 0.7,
			Glow = 1,
			OffsetZ = -1.8,
			OffsetY = 0.5,
			RandomRotation = 1,
			Framerate = 0,
		},
	})

	-- Impact & dissipation ---------------------------------------------------------------------
	add({
		Id = "Impact.Flash",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 1,
		Roles = { Impact = true },
		Texture = "impact_frame",
		Colors = { "Hi", "Mid" },
		Params = { Count = 1, Lifetime = 0.1, Speed = 0, Size = 4.5, SizeEnd = 6, Light = 0.3, RandomRotation = 1 },
		Drivers = { { "Size", "Area", 4 } },
	})
	add({
		Id = "Impact.Burst",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 1,
		Roles = { Impact = true },
		Texture = a.Impact,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 1,
			Lifetime = 0.6,
			Speed = 0,
			Size = 6,
			SizeEnd = 8,
			Light = light,
			OneShot = 1,
			RandomRotation = 1,
		},
		Drivers = { { "Size", "Area", 7 }, { "SizeEnd", "Area", 9 }, { "Count", "Potency", 1 } },
	})
	add({
		Id = "Impact.Ring",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 2,
		Roles = { Impact = true },
		Texture = "shockwave_ring",
		Colors = { "Hi", "Mid" },
		Params = { Count = 1, Lifetime = 0.3, Speed = 0, Size = 1, SizeEnd = 11, Light = 0.4, Opacity = 0.95 },
		Drivers = { { "SizeEnd", "Area", 12 } },
	})
	add({
		Id = "Impact.Spray",
		Slot = "Impact",
		Kind = "Burst",
		Priority = 2,
		Roles = { Impact = true },
		Texture = a.Mote,
		Colors = { "Hi", "Mid", "Lo" },
		Params = {
			Count = 12,
			Lifetime = 0.7,
			Speed = 22,
			Spread = 180,
			Direction = "Out",
			Size = 0.4,
			SizeEnd = 0.05,
			Drag = 3.5,
			Rise = -14 + rise,
			Light = 0.6,
			Glow = 1,
			RandomRotation = 1,
			Framerate = 0,
		},
		Drivers = { { "Count", "Potency", 16 } },
	})
	add({
		Id = "Impact.Mark",
		Slot = "Impact",
		Kind = "Decal",
		Priority = 3,
		Roles = { Impact = true },
		Texture = a.Ground,
		Colors = "Lo",
		Params = { Size = 5, Opacity = 0.85, Duration = 1.2, Fade = 1 },
		Drivers = { { "Size", "Area", 6 } },
	})
	if a.Debris then
		add({
			Id = "Impact.Debris",
			Slot = "Impact",
			Kind = "Debris",
			Priority = 3,
			Roles = { Impact = true },
			Meshes = a.Debris,
			Colors = "Mid",
			Params = {
				Count = 3,
				Speed = 18,
				Spread = 70,
				Size = f.DebrisSize or 0.5,
				Gravity = 65,
				Lifetime = 0.9,
				Material = "SmoothPlastic",
				Direction = "Up",
				Ink = 1,
			},
			Drivers = { { "Count", "Potency", 3 } },
		})
	end
	add({
		Id = "Impact.Light",
		Slot = "Impact",
		Kind = "Light",
		Priority = 3,
		Roles = { Impact = true },
		Colors = "Mid",
		Params = { Brightness = 3, Range = 14, Flash = 0.35 },
	})
	add({
		Id = "Dissipate.Smoke",
		Slot = "Dissipate",
		Kind = "Burst",
		Priority = 2,
		Texture = a.Smoke,
		Colors = { "Smoke", "Lo" },
		Params = {
			Count = 3,
			Lifetime = 1.3,
			Speed = 2.5,
			Spread = 180,
			Direction = "Out",
			Size = 2.4,
			SizeEnd = 4.5,
			Rise = 1.5,
			Drag = 1.5,
			Light = 0,
			Opacity = 0.8,
			OneShot = 1,
			Delay = 0.12,
			RandomRotation = 1,
		},
		Drivers = { { "Count", "Area", 3 } },
	})
	return L
end

-- Kit definitions. Assets reference VFXAssetManifest names. Every kit uses the same template set;
-- differences come from assets, palette and feel.
Kits.Definitions = {
	Fire = {
		Palette = {
			Hi = Color3.fromRGB(255, 226, 150),
			Mid = Color3.fromRGB(255, 112, 32),
			Lo = Color3.fromRGB(150, 30, 10),
			Smoke = Color3.fromRGB(48, 36, 34),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "core_plasma",
			CoreMesh = "fire_core",
			Particle = "flame_tongue",
			Mote = "ember_streak",
			Trail = "trail_flame",
			Beam = "trail_flame",
			Wave = "flame_tongue",
			Ground = "scorch_lichtenberg",
			Impact = "explosion_fire",
			Smoke = "smoke_billow",
			Sigil = "rune_circle",
			Debris = { "debris_rock_a", "debris_rock_c" },
		},
		Feel = { Light = 0.35, Rise = 6, Framerate = 26, Scroll = 4, Wobble = 0.3 },
	},
	Ice = {
		Palette = {
			Hi = Color3.fromRGB(236, 250, 255),
			Mid = Color3.fromRGB(120, 196, 255),
			Lo = Color3.fromRGB(34, 70, 140),
			Smoke = Color3.fromRGB(150, 180, 205),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "frost_mist",
			CoreMesh = "ice_spike",
			Particle = "frost_mist",
			Mote = "ice_glint",
			Trail = "ice_trail",
			Beam = "ice_trail",
			Wave = "frost_mist",
			Ground = "frost_crack",
			Impact = "ice_shatter",
			Smoke = "frost_mist",
			Sigil = "hex_seal",
			Scatter = "ice_cluster",
			Debris = { "ice_shard_a", "ice_shard_b" },
		},
		Feel = {
			Light = 0.15,
			Rise = -1,
			Framerate = 14,
			Spin = 0.5,
			Scroll = 1.5,
			CoreMeshSize = 0.45,
			ScatterSize = 0.8,
		},
	},
	Lightning = {
		Palette = {
			Hi = Color3.fromRGB(250, 248, 255),
			Mid = Color3.fromRGB(176, 150, 255),
			Lo = Color3.fromRGB(70, 40, 150),
			Smoke = Color3.fromRGB(60, 52, 80),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "plasma_orb",
			Particle = "arc_flicker",
			Mote = "arc_flicker",
			Trail = "bolt_strip",
			Beam = "bolt_strip",
			Wave = "spark_burst",
			Ground = "scorch_lichtenberg",
			Impact = "spark_burst",
			Smoke = "smoke_billow",
			Sigil = "rune_circle",
			Scatter = "lightning_fork",
		},
		Feel = { Light = 0.45, Rise = 0, Framerate = 30, Spin = 2, Scroll = 0, Wobble = 0, ScatterSize = 0.7, BeamArc = 9 },
	},
	Water = {
		Palette = {
			Hi = Color3.fromRGB(220, 246, 255),
			Mid = Color3.fromRGB(58, 148, 230),
			Lo = Color3.fromRGB(14, 52, 110),
			Smoke = Color3.fromRGB(170, 210, 235),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "water_orb",
			Particle = "water_splash",
			Flow = "droplet",
			Mote = "droplet",
			Trail = "water_trail",
			Beam = "water_trail",
			Wave = "ripple_ring",
			Ground = "caustics",
			Impact = "water_splash",
			Smoke = "ripple_ring",
			Sigil = "ripple_ring",
			Scatter = "water_crown",
			Debris = nil,
		},
		Feel = { Light = 0.12, Rise = -10, Framerate = 18, Spin = 0.6, Scroll = 2.5, Wobble = 0.4, ScatterSize = 1.0 },
	},
	Earth = {
		Palette = {
			Hi = Color3.fromRGB(226, 196, 150),
			Mid = Color3.fromRGB(140, 104, 70),
			Lo = Color3.fromRGB(58, 40, 30),
			Smoke = Color3.fromRGB(92, 78, 64),
		},
		Tintable = { Mid = 0.5, Lo = 0.4 },
		Assets = {
			Core = "dust_plume",
			Flow = "debris_chip",
			CoreMesh = "earth_boulder",
			Particle = "dust_plume",
			Mote = "debris_chip",
			Trail = "rubble_trail",
			Beam = "rubble_trail",
			Wave = "dust_plume",
			Ground = "earth_fissure",
			Impact = "rock_burst",
			Smoke = "dust_burst",
			Sigil = "earth_fissure",
			Scatter = "earth_spire",
			Debris = { "debris_rock_a", "debris_rock_b", "debris_rock_c" },
		},
		Feel = {
			Light = 0.0,
			Rise = -18,
			Framerate = 16,
			Spin = 0.3,
			Scroll = 1,
			CoreMeshSize = 0.6,
			ScatterSize = 0.8,
			DebrisSize = 0.6,
		},
	},
	Wind = {
		Palette = {
			Hi = Color3.fromRGB(240, 255, 250),
			Mid = Color3.fromRGB(150, 232, 205),
			Lo = Color3.fromRGB(46, 120, 110),
			Smoke = Color3.fromRGB(190, 225, 215),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "wind_swirl",
			Particle = "wind_swirl",
			Mote = "leaf_scrap",
			Trail = "gust_strokes",
			Beam = "gust_strokes",
			Wave = "pressure_wave",
			Ground = "wind_swirl",
			Impact = "wind_swirl",
			Smoke = "dust_burst",
			Sigil = "rune_circle",
			Scatter = "wind_funnel",
		},
		Feel = { Light = 0.1, Rise = 3, Framerate = 22, Spin = 2.5, Scroll = 6, Wobble = 0.8, ScatterSize = 0.9 },
	},
	Poison = {
		Palette = {
			Hi = Color3.fromRGB(214, 255, 120),
			Mid = Color3.fromRGB(110, 190, 40),
			Lo = Color3.fromRGB(40, 70, 20),
			Smoke = Color3.fromRGB(70, 92, 40),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "miasma",
			CoreMesh = "poison_bubbles",
			Particle = "miasma",
			Mote = "toxic_bubble",
			Trail = "drip_trail",
			Beam = "drip_trail",
			Wave = "miasma",
			Ground = "toxic_pool",
			Impact = "acid_splat",
			Smoke = "miasma",
			Sigil = "toxic_pool",
			Scatter = "poison_thorn",
		},
		Feel = {
			Light = 0.1,
			Rise = 1.5,
			Framerate = 12,
			Spin = 0.5,
			Scroll = 1.2,
			CoreMeshSize = 0.5,
			ScatterSize = 0.7,
		},
	},
	Arcane = {
		Palette = {
			Hi = Color3.fromRGB(246, 226, 255),
			Mid = Color3.fromRGB(176, 110, 255),
			Lo = Color3.fromRGB(70, 30, 130),
			Smoke = Color3.fromRGB(60, 44, 80),
		},
		Tintable = { Mid = 0.7, Lo = 0.6, Hi = 0.25 },
		Assets = {
			Core = "arcane_orb",
			CoreMesh = "arcane_prism",
			Particle = "arcane_glyphs",
			Mote = "arcane_glyphs",
			Trail = "glyph_chain",
			Beam = "glyph_chain",
			Wave = "arcane_burst",
			Ground = "hex_seal",
			Impact = "arcane_burst",
			Smoke = "smoke_billow",
			Sigil = "rune_circle",
			Scatter = "arcane_prism",
		},
		Feel = { Light = 0.3, Rise = 1, Framerate = 8, Spin = 1, Scroll = 2, CoreMeshSize = 0.4, ScatterSize = 0.6 },
	},
	Force = {
		Palette = {
			Hi = Color3.fromRGB(255, 255, 255),
			Mid = Color3.fromRGB(196, 210, 236),
			Lo = Color3.fromRGB(70, 82, 110),
			Smoke = Color3.fromRGB(150, 156, 170),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "kinetic_burst",
			Particle = "pressure_wave",
			Mote = "ember_streak",
			Trail = "force_streak",
			Beam = "force_streak",
			Wave = "pressure_wave",
			Ground = "ward_hex",
			Impact = "kinetic_burst",
			Smoke = "dust_burst",
			Sigil = "hex_seal",
			Scatter = "ward_dome",
			Aura = "ward_hex",
		},
		Feel = { Light = 0.15, Rise = 0, Framerate = 24, Spin = 0.8, Scroll = 8, ScatterSize = 1.2 },
	},
	Body = {
		Palette = {
			Hi = Color3.fromRGB(240, 222, 198),
			Mid = Color3.fromRGB(176, 52, 40),
			Lo = Color3.fromRGB(64, 22, 26),
			Smoke = Color3.fromRGB(96, 84, 74),
		},
		Tintable = { Mid = 0.55, Lo = 0.4 },
		Assets = {
			Core = "glow_soft",
			CoreMesh = "flesh_shard",
			Particle = "dust_burst",
			Mote = "debris_chip",
			Trail = "sinew_trail",
			Beam = "sinew_trail",
			Wave = "pressure_wave",
			Ground = "earth_fissure",
			Impact = "kinetic_burst",
			Smoke = "dust_burst",
			Sigil = "earth_fissure",
			Scatter = "sinew_tendril",
			Debris = { "flesh_shard", "debris_rock_a" },
			Aura = "pressure_wave",
		},
		Feel = {
			Light = 0.05,
			Rise = -2,
			Framerate = 18,
			Spin = 0.4,
			Scroll = 3,
			CoreMeshSize = 0.45,
			ScatterSize = 0.8,
		},
	},
	Spirit = {
		Palette = {
			Hi = Color3.fromRGB(220, 255, 246),
			Mid = Color3.fromRGB(80, 220, 190),
			Lo = Color3.fromRGB(16, 70, 76),
			Smoke = Color3.fromRGB(40, 60, 64),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "soul_wisp",
			CoreMesh = "soul_skull",
			Particle = "soul_wisp",
			Mote = "skull_mote",
			Trail = "ghost_trail",
			Beam = "ghost_trail",
			Wave = "soul_burst",
			Ground = "soul_sigil",
			Impact = "soul_burst",
			Smoke = "smoke_billow",
			Sigil = "soul_sigil",
			Scatter = "chain_link",
		},
		Feel = {
			Light = 0.25,
			Rise = 4,
			Framerate = 14,
			Spin = 0.6,
			Scroll = 2,
			Wobble = 0.6,
			CoreMeshSize = 0.55,
			ScatterSize = 0.6,
		},
	},
	Space = {
		Palette = {
			Hi = Color3.fromRGB(236, 226, 255),
			Mid = Color3.fromRGB(130, 100, 255),
			Lo = Color3.fromRGB(16, 8, 40),
			Smoke = Color3.fromRGB(30, 22, 52),
		},
		Tintable = { Mid = 0.6, Lo = 0.3 },
		Assets = {
			Core = "void_orb",
			CoreMesh = "void_shard",
			Particle = "rift_tear",
			Mote = "star_mote",
			Trail = "shard_trail",
			Beam = "shard_trail",
			Wave = "warp_implode",
			Ground = "portal_rings",
			Impact = "warp_implode",
			Smoke = "smoke_billow",
			Sigil = "portal_rings",
			Scatter = "void_shard",
			Debris = { "void_shard" },
		},
		Feel = { Light = 0.2, Rise = 0, Framerate = 16, Spin = 1.5, Scroll = 3, CoreMeshSize = 0.45, ScatterSize = 0.7 },
	},
	Time = {
		Palette = {
			Hi = Color3.fromRGB(255, 244, 210),
			Mid = Color3.fromRGB(226, 182, 92),
			Lo = Color3.fromRGB(96, 64, 26),
			Smoke = Color3.fromRGB(150, 128, 92),
		},
		Tintable = { Mid = 0.6, Lo = 0.5 },
		Assets = {
			Core = "time_ripple",
			Flow = "gear_mote",
			CoreMesh = "chrono_gear",
			Particle = "sand_trail",
			Mote = "gear_mote",
			Trail = "sand_trail",
			Beam = "sand_trail",
			Wave = "time_ripple",
			Ground = "clock_dial",
			Impact = "time_ripple",
			Smoke = "dust_burst",
			Sigil = "clock_dial",
			Scatter = "hourglass",
			Aura = "time_ripple",
		},
		Feel = { Light = 0.2, Rise = -1, Framerate = 12, Spin = 0.5, Scroll = 1, CoreMeshSize = 0.4, ScatterSize = 0.7 },
	},
}

-- Builds a full signature from a kit, then lets hand-authored layers (same Slot, owning Roles)
-- replace template layers for the roles they cover.
function Kits.build(name, bespoke)
	local kit = table.clone(Kits.Definitions[name])
	kit.Name = name
	local palette = table.clone(kit.Palette)
	palette.Ink = INK
	local layers = templates(kit)
	local owned = (bespoke and bespoke.Owns) or {}
	if bespoke then
		local kept = {}
		for _, t in ipairs(layers) do
			local roles = t.Roles
			local overlapped = false
			if roles then
				for role in pairs(roles) do
					if owned[role] then
						overlapped = true
					end
				end
			elseif owned.Cast and (t.Slot == "Charge" or t.Slot == "Cast") then
				overlapped = true
			end
			if not overlapped then
				table.insert(kept, t)
			end
		end
		-- Role-less authored layers (wisps, embers, dissipation) belong to the roles the author owns,
		-- except slot-wide ones (Charge/Cast/Dissipate) which replace the template's role-less layers.
		local authoredSlots = {}
		for _, t in ipairs(bespoke.Layers) do
			if not t.Roles then
				authoredSlots[t.Slot] = true
			end
		end
		layers = {}
		for _, t in ipairs(kept) do
			if t.Roles or not authoredSlots[t.Slot] then
				table.insert(layers, t)
			end
		end
		for _, t in ipairs(bespoke.Layers) do
			local copy = table.clone(t)
			if not copy.Roles and copy.Slot ~= "Charge" and copy.Slot ~= "Cast" and copy.Slot ~= "Dissipate" then
				copy.Roles = table.clone(owned)
			end
			table.insert(layers, copy)
		end
		for token, color in pairs(bespoke.Palette or {}) do
			palette[token] = color
		end
	end
	local tintable = table.clone(kit.Tintable)
	for token, amount in pairs((bespoke and bespoke.Tintable) or {}) do
		tintable[token] = amount
	end
	local all = { Form = true, Element = true, Mechanic = true, Detail = true }
	return {
		Name = name,
		Palette = palette,
		Tintable = tintable,
		Layers = layers,
		-- Kits cover every role, so the procedural composer's layers are fully replaced; it still
		-- renders whenever a signature session cannot be created (budget, disabled).
		Replaces = { Default = all },
	}
end

-- Selection, by data only: element first, then the expression or principle for elementless
-- schools, then Arcane for everything else (Neutral, Unawakened).
Kits.Match = {
	Element = {
		Fire = "Fire",
		Ice = "Ice",
		Lightning = "Lightning",
		Water = "Water",
		Earth = "Earth",
		Wind = "Wind",
		Poison = "Poison",
	},
	Expression = {
		Force = "Force",
		BodyEnhancement = "Body",
		Spirit = "Spirit",
		SpatialFold = "Space",
		TemporalShift = "Time",
	},
	Principle = { Body = "Body", Soul = "Spirit", Space = "Space", Time = "Time" },
	Fallback = "Arcane",
}

return Kits
]=];end
do local parent=s.Signature;local m=parent:FindFirstChild("SignatureRenderer")
if m and not backup:FindFirstChild("SignatureRenderer") then m:Clone().Parent=backup end
if not m then m=Instance.new("ModuleScript");m.Name="SignatureRenderer";m.Parent=parent end
m.Source=[=[-- Client renderer for signature layers (SignaturePlanner output) on server-stamped VFX anchors.
-- Cosmetic only: never touches gameplay state, hit detection or the anchor itself (beyond hiding
-- the server's primitive projectile stand-in locally).
--
-- Layer kinds
--   Sprite  locked-to-host flipbook billboard(s) (cores, charge points, beam ends)
--   Emitter continuous ParticleEmitter (streams, motes, field/aura/construct bodies)
--   Burst   one-shot ParticleEmitter:Emit (flashes, explosions, fronts)
--   Mesh    pooled generated MeshPart(s) animated by script (cores, rings, scattered crystals)
--   Debris  a few pooled meshes flung ballistically, no physics or collisions
--   Trail   Trail on the host with a generated strip texture
--   Beam    Roblox Beam along the authoritative beam path, scrolling a strip texture
--   Decal   ground decal (field ground, casting sigil, impact mark); custom textures only
--   Light   PointLight, sustained or flashed
-- Placement (emitters, sprites, lights): Host (default), End (beam endpoint), Line (along the
-- beam), Area (field floor), Body (around the caster), Box (construct surface), Top (construct top).
-- Cel style: Mesh layers with Ink = 1 get their `<mesh>_ink` inverted hull drawn in ink colour.
-- Units: projectile layer sizes are studs at body scale 1 (a 2.2-stud hit diameter); areas use the
-- anchor's real size, impacts the real explode radius through the Area scalar.
local RunService = game:GetService("RunService")
local Planner = require(script.Parent.SignaturePlanner)
local Library = require(script.Parent.SignatureLibrary)
local Assets = require(script.Parent.Parent.Assets.VFXAssets)
local DirectionalSprite = require(script.Parent.DirectionalSprite)
local ConnectedFire = require(script.Parent.ConnectedFire)
local ArcBeam = require(script.Parent.ArcBeam)

local Renderer = {}
Renderer.Enabled = true
Renderer.Quality = "High"
-- Directional painted cards remain an opt-in study while the 3D approach is evaluated.
Renderer.UseDirectionalSprites = false
Renderer.UseConnectedFire = true

local Budget = Library.Budget
local Styled = require(script.Parent.Parent.Assets.StyledVFXManifest)
local Style = if Styled.Enabled then { LightInfluence=0.25, Brightness=1, InkScale=0 } else Library.Style or {}
local usage = { Sessions = 0, Emitters = 0, Rate = 0, Meshes = 0, Lights = 0, Trails = 0 }
local burstWindow, burstCount = 0, 0
local sessions = {}
local connection: RBXScriptConnection? = nil
local rootFolder: Folder? = nil
local INK = Color3.fromRGB(14, 10, 14)
local GOLDEN = 2.3999632

local ORIENTATION = {
	VelocityParallel = Enum.ParticleOrientation.VelocityParallel,
	VelocityPerpendicular = Enum.ParticleOrientation.VelocityPerpendicular,
	FacingCameraWorldUp = Enum.ParticleOrientation.FacingCameraWorldUp,
}
local DIRECTION = {
	Back = Enum.NormalId.Back,
	Forward = Enum.NormalId.Front,
	Up = Enum.NormalId.Top,
}
local ONE_SHOT_ROLES = { Cast = true, Impact = true, Wave = true }
local GROUNDED_ROLES = { Field = true, Aura = true, SelfEnhancement = true }
local HIDDEN_DISTANCE, DETAIL_DISTANCE = 180, 120

local function folder(): Folder
	if rootFolder and rootFolder.Parent then
		return rootFolder
	end
	local f = Instance.new("Folder")
	f.Name = "SignatureVFX"
	f.Parent = workspace
	rootFolder = f
	return f
end

local function colorSequence(colors)
	if #colors <= 1 then
		return ColorSequence.new(colors[1] or Color3.new(1, 1, 1))
	end
	local keys = {}
	for i, color in ipairs(colors) do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keys)
end

local function sizeSequence(a, b)
	a, b = math.max(0, a), math.max(0, b)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, a),
		NumberSequenceKeypoint.new(0.35, a + (b - a) * 0.6),
		NumberSequenceKeypoint.new(1, b),
	})
end

local function fadeSequence(opacity)
	local base = math.clamp(1 - opacity, 0, 1)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.min(1, base + 0.25)),
		NumberSequenceKeypoint.new(0.12, base),
		NumberSequenceKeypoint.new(0.7, math.min(1, base + (1 - base) * 0.3)),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function invisiblePart(name, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Parent = parent
	return p
end

local function ease(k)
	return 1 - (1 - k) ^ 3
end

local function floorBelow(position: Vector3, ignore: { Instance }, reach: number): (Vector3?, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true
	local hit = workspace:Raycast(position + Vector3.new(0, 0.5, 0), Vector3.new(0, -reach, 0), params)
	if hit then
		return hit.Position, hit.Normal
	end
	return nil, nil
end

-- Footprint of an area anchor in studs, and whether it is round.
local function footprint(session)
	local size = session.Size
	return size.X, size.Z, session.Round
end

local function areaOf(session)
	local fx, fz = footprint(session)
	return fx * fz
end

-- World Y of the visible floor under the session (refreshed periodically for grounded roles).
local function floorY(session, frame)
	return session.FloorY or (frame.Position.Y - session.Size.Y * 0.5)
end

-- Shape hosts follow the composition frame and its live size.
local function placeShape(session, shape, frame)
	local p = shape.Layer.Params
	local placement = p.Placement
	local size = session.Size
	local part = shape.Part
	if placement == "Line" then
		local range = session.Range or 6
		local w = math.max(0.5, (session.Width or 1) * 1.2)
		part.Size = Vector3.new(w, w, math.max(0.5, range))
		part.CFrame = frame * CFrame.new(0, 0, -range * 0.5)
	elseif placement == "Area" then
		local fx, fz = footprint(session)
		part.Size = Vector3.new(math.max(0.5, fx * 0.85), 0.3, math.max(0.5, fz * 0.85))
		local y = floorY(session, frame) - frame.Position.Y
		part.CFrame = frame * CFrame.new(0, y + 0.25, 0)
	elseif placement == "Body" then
		part.Size = Vector3.new(math.max(2, size.X * 0.75), math.max(2, size.Y * 0.9), math.max(2, size.Z * 0.75))
		part.CFrame = frame
	elseif placement == "Box" then
		part.Size = size * 1.02
		part.CFrame = frame
	elseif placement == "Top" then
		part.Size = Vector3.new(size.X, 0.2, size.Z)
		part.CFrame = frame * CFrame.new(0, size.Y * 0.5, 0)
	elseif (p.Floor or 0) > 0 then
		local range = session.Range or 6
		part.Size = Vector3.new(math.max(1, (session.Width or range) * 0.4), 0.2, math.max(1, range * 0.5))
		part.CFrame = frame * CFrame.new(0, -2.3, -range * 0.3)
	else
		part.CFrame = frame * CFrame.new(0, p.OffsetY or 0, p.OffsetZ or 0)
	end
end

local function addShape(session, layer, size)
	local host = invisiblePart(layer.Id .. ".Shape", session.Folder)
	host.Size = size
	local shape = { Part = host, Layer = layer }
	table.insert(session.ShapeHosts, shape)
	-- Positioned before any immediate Emit so bursts never spawn at the world origin.
	placeShape(session, shape, session.Host.CFrame)
	return host
end

-- Particle emitter configured from a layer. Shapes that need a volume get their own host part.
local function makeEmitter(session, layer, scale)
	local p = layer.Params
	local texture, layout, _, baked = Assets.texture(layer.Texture, session.Signature)
	local parent: Instance = session.Attachment
	local direction = p.Direction or "Back"
	local placement = p.Placement
	local e = Instance.new("ParticleEmitter")
	e.Name = layer.Id
	e.Texture = texture
	e.FlipbookLayout = layout
	if layout ~= Enum.ParticleFlipbookLayout.None then
		e.FlipbookMode = if (p.OneShot or 0) > 0
			then Enum.ParticleFlipbookMode.OneShot
			else Enum.ParticleFlipbookMode.Loop
		e.FlipbookStartRandom = (p.OneShot or 0) <= 0
		if p.Framerate == 0 then
			-- Random still frame (glyph sets, scraps): pick a frame per particle, never animate.
			e.FlipbookMode = Enum.ParticleFlipbookMode.Random
		elseif (p.Framerate or 0) > 0 and (p.OneShot or 0) <= 0 then
			e.FlipbookFramerate = NumberRange.new(p.Framerate * 0.85, p.Framerate)
		end
	end
	e.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
	local light = if baked then math.min(p.Light or 0.3, 0.2) else p.Light or 0.3
	e.LightEmission = light
	-- Cel look: flat colour that scene lighting barely dims; emission stays low so ink shows.
	e.LightInfluence = Style.LightInfluence or (1 - light)
	e.Brightness = if baked then 1 else (Style.Brightness or 1) + light * 0.6
	e.Size = sizeSequence((p.Size or 1) * scale, (p.SizeEnd or p.Size or 1) * scale)
	e.Transparency = fadeSequence(p.Opacity or 1)
	local life = math.max(0.05, p.Lifetime or 0.5)
	e.Lifetime = NumberRange.new(life * 0.75, life)
	local speed = (p.Speed or 0) * (if layer.Kind == "Burst" then 1 else scale ^ 0.5)
	if (p.RangeSpeed or 0) > 0 and session.Range then
		speed = math.max(speed, session.Range / life * 0.95)
	end
	e.Speed = NumberRange.new(speed * 0.7, speed)
	e.SpreadAngle = Vector2.new(p.Spread or 0, p.Spread or 0)
	e.Drag = p.Drag or 0
	e.Acceleration = Vector3.new(0, p.Rise or 0, 0)
	e.Orientation = ORIENTATION[p.Orientation or ""] or Enum.ParticleOrientation.FacingCamera
	if (p.Stretch or 0) > 0 then
		e.Squash = NumberSequence.new(-math.clamp(p.Stretch * 0.3, 0, 2.5))
	end
	if (p.RandomRotation or 0) > 0 or (p.RotSpeed or 0) > 0 then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-(p.RotSpeed or 30), p.RotSpeed or 30)
	end
	e.LockedToPart = layer.Kind == "Sprite"
	e.ZOffset = if layer.Kind == "Sprite" then 0.5 else 0
	if
		placement == "Line"
		or placement == "Area"
		or placement == "Body"
		or placement == "Box"
		or placement == "Top"
	then
		local host = addShape(session, layer, Vector3.one)
		if placement == "Area" then
			e.Shape = if session.Round then Enum.ParticleEmitterShape.Disc else Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		elseif placement == "Body" then
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		elseif placement == "Box" then
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		else
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end
		e.EmissionDirection = DIRECTION[direction] or Enum.NormalId.Top
		parent = host
	elseif
		direction == "In"
		or direction == "Out"
		or direction == "Flat"
		or (p.ShapeRadius or 0) > 0
		or (p.Floor or 0) > 0
	then
		local radius = (p.ShapeRadius or 0.5) * (if direction == "In" then 1 else scale)
		local host = addShape(session, layer, Vector3.one * math.max(0.2, radius * 2))
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		if direction == "In" then
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		elseif direction == "Out" then
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		elseif direction == "Flat" then
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
			host.Size = Vector3.new(radius * 2, 0.2, radius * 2)
		else
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.EmissionDirection = DIRECTION[direction] or Enum.NormalId.Front
		end
		parent = host
	else
		e.EmissionDirection = DIRECTION[direction] or Enum.NormalId.Back
		if placement == "End" or (p.OffsetY or 0) ~= 0 or (p.OffsetZ or 0) ~= 0 then
			local offset = Instance.new("Attachment")
			offset.Position = Vector3.new(0, p.OffsetY or 0, p.OffsetZ or 0)
			offset.Parent = session.Host
			parent = offset
			if placement == "End" then
				table.insert(session.EndAttachments, offset)
			end
		end
	end
	e.Enabled = false
	e.Rate = 0
	e.Parent = parent
	return e
end

local function canEmitBurst(count)
	local now = os.clock()
	if now - burstWindow > 1 then
		burstWindow, burstCount = now, 0
	end
	if burstCount + count > Budget.MaxBurstPerSecond then
		return false
	end
	burstCount += count
	return true
end

-- A mesh and (when requested and uploaded) its inverted-hull ink outline.
local function acquirePair(session, name, p)
	local part, custom = Assets.acquireMesh(name)
	part.Material = Enum.Material[p.Material or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.CFrame = session.Host.CFrame
	part.Parent = session.Folder
	local ink
	if (p.Ink or 0) > 0 and custom and Assets.hasCustomMesh(name .. "_ink") then
		ink = Assets.acquireMesh(name .. "_ink")
		ink.Material = Enum.Material.SmoothPlastic
		ink.Color = if ink:GetAttribute("VFXBakedColors") then Color3.new(1, 1, 1) else (Styled.Palettes[session.Signature] or {})[5] or INK
		ink.Transparency = 1
		ink.CFrame = session.Host.CFrame
		ink.Parent = session.Folder
	end
	usage.Meshes += if ink then 2 else 1
	session.Owned.Meshes += if ink then 2 else 1
	return part, ink, custom
end

-- Places a mesh and its hull. The hull is authored inflated, so it scales by the same factor.
local function placePair(name, part, ink, cf, size, transparency)
	Assets.place(part, cf, size)
	part.Transparency = transparency
	if ink then
		local native, hull = Assets.meshSize(name), Assets.meshSize(name .. "_ink")
		local ratio = Vector3.new(
			hull.X / math.max(native.X, 1e-3),
			hull.Y / math.max(native.Y, 1e-3),
			hull.Z / math.max(native.Z, 1e-3)
		)
		-- Extra InkScale thickens the rim beyond the authored hull (relative to the mesh size).
		Assets.place(ink, cf, size * ratio * (1 + (Style.InkScale or 0)))
		-- A translucent body would show the hull through it; ink only while the body is solid.
		ink.Transparency = if transparency < 0.08 then 0 else 1
	end
end

-- Builds every layer of a resolved plan into the session.
local function buildLayers(session, layers)
	for _, layer in ipairs(layers) do
		local p = layer.Params
		local critical = layer.Priority == 1
		local entry = { Layer = layer, Start = session.Clock }
		if layer.Kind == "DirectionalSprite" then
			local definition = Assets.directionalSprite(layer.DirectionalAsset)
			if definition then
				entry.Directional = DirectionalSprite.new(session.Host, session.Folder, definition, (p.Size or 4.2)*session.Scale)
			end
		elseif layer.Kind == "Sprite" or layer.Kind == "Emitter" then
			local base = if layer.Kind == "Sprite" then 3 / math.max(0.1, p.Lifetime or 0.35) else p.Rate or 0
			if (p.RatePerArea or 0) > 0 then
				base = math.min(40, base + p.RatePerArea * areaOf(session))
			end
			local rate = math.min(Budget.MaxEmitterRate, base)
			if layer.Kind == "Sprite" then
				p.Lifetime = p.Lifetime or 0.35
				p.SizeEnd = p.SizeEnd or (p.Size or 1) * 1.1
				p.Speed = 0
				p.RotSpeed = p.RotSpeed or 45
			end
			local fits = usage.Emitters < Budget.MaxEmitters and usage.Rate + rate <= Budget.MaxContinuousRate
			if fits or critical then
				usage.Emitters += 1
				usage.Rate += rate
				session.Owned.Emitters += 1
				session.Owned.Rate += rate
				entry.Emitter = makeEmitter(session, layer, session.Scale)
				entry.Rate = rate
				entry.Emitter.Rate = rate
				entry.Emitter.Enabled = true
				entry.BaseSize = (p.Size or 1) * session.Scale
				entry.EndSize = (p.SizeEnd or p.Size or 1) * session.Scale
			end
		elseif layer.Kind == "Burst" then
			local count = math.min(Budget.MaxBurstCount, math.max(1, math.floor(p.Count or 1)))
			if canEmitBurst(count) or critical then
				local scale = if session.Role == "Impact" or session.Role == "Cast" then 1 else session.Scale
				local e = makeEmitter(session, layer, scale)
				entry.Emitter = e
				local delay = p.Delay or 0
				local stagger = p.Stagger or 0
				local function fire()
					if session.Stopped or not e.Parent then
						return
					end
					if stagger > 0 then
						for i = 1, count do
							task.delay((i - 1) * stagger, function()
								if not session.Stopped and e.Parent then
									e:Emit(1)
								end
							end)
						end
					else
						e:Emit(count)
					end
				end
				if delay > 0 then
					task.delay(delay, fire)
				else
					fire()
				end
				session.Linger = math.max(session.Linger, delay + stagger * count + (p.Lifetime or 0.5))
			end
		elseif layer.Kind == "Mesh" then
			local skip = (p.RequireAsset or 0) > 0 and not Assets.hasCustomMesh(layer.Mesh)
			local count = 1
			if p.Orient == "Scatter" then
				count = math.clamp(math.floor((p.Count or 4) + (p.CountPerArea or 0) * areaOf(session) + 0.5), 1, 10)
			end
			local fits = usage.Meshes + count <= Budget.MaxMeshes
			if layer.Mesh and not skip and (fits or critical) then
				entry.Parts, entry.Inks = {}, {}
				local custom = true
				for i = 1, count do
					local part, ink, isCustom = acquirePair(session, layer.Mesh, p)
					part.Color = if part:GetAttribute("VFXBakedColors") then Color3.new(1, 1, 1) else layer.Colors[1]
					entry.Parts[i], entry.Inks[i] = part, ink
					custom = isCustom
				end
				-- Fallback primitives of open shapes (rings, cones, shells) read as solid blobs; keep them faint.
				entry.FallbackDim = if custom then 1 else 0.35
				entry.Native = Assets.meshSize(layer.Mesh)
				if (p.Duration or 0) > 0 and ONE_SHOT_ROLES[session.Role] then
					session.Linger = math.max(session.Linger, (p.Delay or 0) + p.Duration)
				end
				if p.Orient == "Ground" then
					local floor = floorBelow(session.Host.Position, { session.Folder, session.Anchor }, 9)
					entry.Floor = floor
						or (session.Host.Position - Vector3.new(0, if session.Role == "Cast" then 2.9 else 0.5, 0))
				end
			end
		elseif layer.Kind == "Decal" then
			local texture, _, custom, baked = Assets.texture(layer.Texture, session.Signature)
			-- Built-in particle textures make poor ground decals; decals need the uploaded art.
			if custom then
				local plate = invisiblePart(layer.Id, session.Folder)
				local decal = Instance.new("Decal")
				decal.Face = Enum.NormalId.Top
				decal.Texture = texture
				decal.Color3 = if baked then Color3.new(1, 1, 1) else layer.Colors[1]
				decal.Transparency = 1
				decal.Parent = plate
				entry.Plate, entry.Decal = plate, decal
				if session.Role == "Cast" or session.Role == "Impact" then
					local floor = floorBelow(session.Host.Position, { session.Folder, session.Anchor }, 9)
					if not floor and session.Role == "Impact" then
						-- Mid-air impacts leave no ground mark.
						plate:Destroy()
						entry.Plate, entry.Decal = nil, nil
					end
					entry.Floor = floor or (session.Host.Position - Vector3.new(0, 2.9, 0))
				end
				if (p.Duration or 0) > 0 then
					session.Linger = math.max(session.Linger, p.Duration)
				end
			end
		elseif layer.Kind == "Beam" then
			if usage.Trails < Budget.MaxTrails or critical then
				local texture, _, _, baked = Assets.texture(layer.Texture, session.Signature)
				local colors = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
				local arc = if p.ArcSegments then ArcBeam.new(session.Host, session.Folder, texture, colorSequence(layer.Colors), p,
					math.max(0, Budget.MaxTrails - usage.Trails), session.Seed) else nil
				if arc then
					entry.Arc=arc
					usage.Trails+=arc.Count;session.Owned.Trails+=arc.Count
				else
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Parent, a1.Parent = session.Host, session.Host
				table.insert(session.EndAttachments, a1)
				local beam = Instance.new("Beam")
				beam.Name = layer.Id
				beam.Attachment0, beam.Attachment1 = a0, a1
				local texture, _, _, baked = Assets.texture(layer.Texture, session.Signature)
				beam.Texture = texture
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = p.TextureLength or 5
				beam.TextureSpeed = p.Scroll or 2
				beam.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
				beam.LightEmission = if baked then 0.2 else p.Light or 0.3
				beam.LightInfluence = Style.LightInfluence or (1 - (p.Light or 0.3))
				beam.FaceCamera = true
				beam.Segments = if (p.Wobble or 0) > 0 then 12 else 1
				beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1 - (p.Opacity or 1) * 0.7),
					NumberSequenceKeypoint.new(0.08, 1 - (p.Opacity or 1)),
					NumberSequenceKeypoint.new(0.92, 1 - (p.Opacity or 1)),
					NumberSequenceKeypoint.new(1, 1 - (p.Opacity or 1) * 0.7),
				})
				beam.Parent = session.Folder
				entry.Beam = beam
				usage.Trails += 1
				session.Owned.Trails += 1
				end
			end
		elseif layer.Kind == "Debris" then
			local count = math.min(8, math.max(1, math.floor(p.Count or 1)))
			if (usage.Meshes + count * 2 <= Budget.MaxMeshes) or critical then
				entry.Pieces = {}
				local random = Random.new((session.Seed or 0) + #session.Entries * 7919)
				local floor = floorBelow(session.Host.Position, { session.Folder, session.Anchor }, 12)
				entry.FloorY = if floor then floor.Y else session.Host.Position.Y - 6
				local frame = session.Host.CFrame
				for i = 1, count do
					local name = layer.Meshes[(i - 1) % #layer.Meshes + 1]
					local part, ink = acquirePair(session, name, p)
					part.Color = if part:GetAttribute("VFXBakedColors") then Color3.new(1, 1, 1) else layer.Colors[1]
					local spread = math.rad(p.Spread or 45)
					local yaw, pitch = random:NextNumber(-spread, spread), random:NextNumber(-spread, spread)
					local dir
					if p.Direction == "Forward" then
						dir = (frame * CFrame.Angles(pitch * 0.5, yaw, 0)).LookVector
					elseif p.Direction == "Up" then
						dir = (CFrame.Angles(pitch, 0, yaw) * CFrame.new()).UpVector
					else
						dir =
							Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0, 1), random:NextNumber(-1, 1)).Unit
					end
					local size = Assets.meshSize(name) * (p.Size or 0.5) * random:NextNumber(0.6, 1.2)
					placePair(name, part, ink, frame, size, 0)
					local piece = {
						Name = name,
						Part = part,
						Ink = ink,
						Position = frame.Position + dir * 0.6,
						Velocity = dir * (p.Speed or 20) * random:NextNumber(0.6, 1),
						Spin = Vector3.new(
							random:NextNumber(-9, 9),
							random:NextNumber(-9, 9),
							random:NextNumber(-9, 9)
						),
						Rotation = CFrame.Angles(random:NextNumber(0, 6), random:NextNumber(0, 6), 0),
						Size = size,
					}
					if (p.Trail or 0) > 0 and usage.Trails < Budget.MaxTrails then
						local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
						a0.Position, a1.Position = Vector3.new(0, size.Y * 0.4, 0), Vector3.new(0, -size.Y * 0.4, 0)
						a0.Parent, a1.Parent = part, part
						local trail = Instance.new("Trail")
						trail.Attachment0, trail.Attachment1 = a0, a1
						local texture, _, _, baked = Assets.texture("force_streak", session.Signature)
						trail.Texture = texture
						trail.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
						trail.Lifetime = 0.18
						trail.FaceCamera = true
						trail.LightEmission = 0.2
						trail.Transparency = NumberSequence.new(0.35, 1)
						trail.Parent = part
					end
					table.insert(entry.Pieces, piece)
				end
				session.Linger = math.max(session.Linger, p.Lifetime or 0.8)
			end
		elseif layer.Kind == "Trail" then
			if usage.Trails < Budget.MaxTrails or critical then
				local half = (p.Width or 1) * session.Scale * 0.5
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(-half, 0, 0), Vector3.new(half, 0, 0)
				a0.Parent, a1.Parent = session.Host, session.Host
				local trail = Instance.new("Trail")
				trail.Name = layer.Id
				trail.Attachment0, trail.Attachment1 = a0, a1
				local texture, _, _, baked = Assets.texture(layer.Texture, session.Signature)
				trail.Texture = texture
				trail.TextureMode = Enum.TextureMode.Wrap
				trail.TextureLength = (p.TextureLength or 4) * session.Scale
				trail.Color = if baked then ColorSequence.new(Color3.new(1, 1, 1)) else colorSequence(layer.Colors)
				trail.Lifetime = p.Lifetime or 0.2
				trail.LightEmission = if baked then 0.2 else p.Light or 1
				trail.LightInfluence = Style.LightInfluence or (1 - (p.Light or 1))
				trail.FaceCamera = true
				trail.MinLength = 0.05
				trail.WidthScale = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(1, 0.15),
				})
				trail.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1 - (p.Opacity or 0.9)),
					NumberSequenceKeypoint.new(1, 1),
				})
				trail.Parent = session.Folder
				entry.Trail = trail
				usage.Trails += 1
				session.Owned.Trails += 1
				session.Linger = math.max(session.Linger, trail.Lifetime)
			end
		elseif layer.Kind == "Light" then
			if usage.Lights < Budget.MaxLights then
				local attachment = Instance.new("Attachment")
				attachment.Position = Vector3.new(0, p.OffsetY or 0, p.OffsetZ or 0)
				attachment.Parent = session.Host
				if p.Placement == "End" then
					table.insert(session.EndAttachments, attachment)
				end
				local light = Instance.new("PointLight")
				light.Color = layer.Colors[1]
				light.Shadows = false
				light.Range = math.min(24, (p.Range or 10))
				light.Brightness = 0
				light.Parent = attachment
				entry.Light = light
				usage.Lights += 1
				session.Owned.Lights += 1
				if (p.Flash or 0) > 0 then
					session.Linger = math.max(session.Linger, p.Flash)
				end
			end
		end
		table.insert(session.Entries, entry)
	end
end

local function release(session)
	usage.Emitters -= session.Owned.Emitters
	usage.Rate -= session.Owned.Rate
	usage.Meshes -= session.Owned.Meshes
	usage.Lights -= session.Owned.Lights
	usage.Trails -= session.Owned.Trails
	session.Owned = { Emitters = 0, Rate = 0, Meshes = 0, Lights = 0, Trails = 0 }
end

local Session = {}
Session.__index = Session

-- Graceful end: continuous layers stop, dissipation plays at the last transform, then cleanup.
function Session:Finish()
	if self.Ending or self.Stopped then
		return
	end
	self.Ending = self.Clock
	-- Linger now counts from the end, not the start.
	self.Linger = 0.3
	for _, entry in self.Entries do
		if entry.Emitter and entry.Layer.Kind ~= "Burst" then
			entry.Emitter.Enabled = false
			self.Linger = math.max(self.Linger, entry.Layer.Params.Lifetime or 0.5)
		end
		if entry.Trail then
			entry.Trail.Enabled = true
		end
	end
	if not self.OneShot and not self.ConnectedFire then
		local plan = Planner.plan(self.Plan, "End", { Quality = self.Quality })
		if plan then
			local start = #self.Entries
			buildLayers(self, plan.Layers)
			for i = start + 1, #self.Entries do
				self.Entries[i].Start = self.Clock
			end
		end
	end
	-- One-shots already outlived their layers; sustained effects wait for their dissipation.
	self.EndAt = self.Clock + (if self.OneShot then 0.35 else math.min(3, self.Linger + 0.1))
end

function Session:Stop()
	if self.Stopped then
		return
	end
	self.Stopped = true
	if self.ConnectedFire then self.ConnectedFire:Destroy() end
	release(self)
	usage.Sessions -= 1
	sessions[self] = nil
	for _, entry in self.Entries do
		for _, part in entry.Parts or {} do
			Assets.releaseMesh(part)
		end
		for _, ink in entry.Inks or {} do
			Assets.releaseMesh(ink)
		end
		for _, piece in entry.Pieces or {} do
			Assets.releaseMesh(piece.Part)
			if piece.Ink then
				Assets.releaseMesh(piece.Ink)
			end
		end
	end
	self.Folder:Destroy()
end

-- Scatter point i of n inside the footprint (golden-angle spiral or R2 grid), in host space.
local function scatterPoint(session, i, n)
	local fx, fz, round = footprint(session)
	if round then
		local r = math.sqrt((i - 0.5) / n) * 0.4
		local a = i * GOLDEN + (session.Seed % 100) * 0.01
		return math.cos(a) * r * fx, math.sin(a) * r * fz
	end
	return ((i * 0.7548777) % 1 - 0.5) * 0.8 * fx, ((i * 0.5698403 + 0.31) % 1 - 0.5) * 0.8 * fz
end

local function updateMesh(session, entry, t, frame, shown, opacity)
	local layer = entry.Layer
	local p = layer.Params
	local native = entry.Native
	local age = session.Clock - entry.Start
	local delay = p.Delay or 0
	local k = if (p.Duration or 0) > 0 then math.clamp((age - delay) / p.Duration, 0, 1) else 1
	if (p.Fade or 0) > 0 then
		opacity *= 1 - math.clamp((k - 0.35) / 0.65, 0, 1)
	end
	if age < delay then
		opacity = 0
	end
	local wobble = p.Wobble or 0
	local jitter = Vector3.new(
		1 + wobble * math.sin(t * 13.1),
		1 + wobble * math.sin(t * 11.7 + 1.3),
		1 + wobble * math.sin(t * 9.3 + 2.1)
	)
	local transparency = if shown then math.clamp(1 - opacity, 0, 1) else 1
	local n = #entry.Parts
	for i, part in entry.Parts do
		local size, cf
		if p.Orient == "Scatter" then
			-- Upright bodies spread over the footprint, growing in (and sinking away on end).
			local x, z = scatterPoint(session, i, n)
			local variation = 0.7 + 0.6 * ((i * 0.618034 + (session.Seed % 37) * 0.01) % 1)
			local grow = ease(math.clamp((age - i * 0.05) / math.max(0.05, p.Duration or 0.35), 0, 1))
			if session.Ending then
				grow *= 1 - math.clamp((session.Clock - session.Ending) / 0.35, 0, 1)
			end
			local s = (p.Size or 1) * variation * math.max(0.02, grow)
			size = native * s
			local y = floorY(session, frame) - frame.Position.Y
			local yaw = i * GOLDEN
			local lean = 0.12 * math.sin(i * 1.7)
			cf = frame
				* CFrame.new(x, y + size.Y * 0.45, z)
				* CFrame.Angles(lean, yaw + t * (p.Spin or 0) * 0.1, lean * 0.5)
		elseif p.Orient == "Footprint" then
			local fx, fz = footprint(session)
			size = Vector3.new(fx, native.Y * math.min(fx, fz) / math.max(native.X, 0.01) * 0.5, fz)
			local y = floorY(session, frame) - frame.Position.Y
			cf = frame * CFrame.new(0, y + 0.08, 0) * CFrame.Angles(0, t * (p.Spin or 0), 0)
		elseif p.Orient == "Ground" then
			local s = (p.Size or 1) + ((p.Grow or p.Size or 1) - (p.Size or 1)) * ease(k)
			size = Vector3.new(s, native.Y * s / math.max(native.X, 0.01), s)
			cf = CFrame.new(entry.Floor + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, t * (p.Spin or 0), 0)
		elseif p.Orient == "Area" then
			-- The force cone is stretched to the real wave range, overshoots, then settles.
			local range = session.Range or 10
			local reach = ease(k) * (1 + (p.Overshoot or 0) * math.sin(math.min(k, 1) * math.pi))
			local width = math.min(session.Width or range, range * 1.6)
			local length = math.max(0.3, range * reach)
			size = Vector3.new(width * (0.35 + 0.65 * ease(k)), math.max(2.5, width * 0.4), length)
			cf = frame * CFrame.new(0, 0, -length * 0.5)
		elseif p.Orient == "Front" then
			local range = session.Range or 10
			local width = math.min(session.Width or range, range * 1.6)
			local d = width * (0.3 + 0.7 * ease(k))
			size = Vector3.new(d, native.Y * d * 0.5, d * 0.62)
			cf = frame * CFrame.new(0, 0, -range * (0.55 + 0.4 * ease(k))) * CFrame.Angles(math.pi / 2, 0, 0)
		else
			local body = (p.Size or 1) * session.Scale
			local stretch = p.Stretch or 1
			size = native * body * jitter * Vector3.new(1, 1, stretch)
			cf = frame * CFrame.Angles(0, 0, t * (p.Spin or 0)) * CFrame.Angles(t * 0.7, t * 0.45, 0)
			if stretch ~= 1 then
				-- Shells streak backwards from the core instead of tumbling.
				cf = frame * CFrame.new(0, 0, size.Z * 0.12) * CFrame.Angles(0, 0, t * (p.Spin or 0))
			end
		end
		placePair(layer.Mesh, part, entry.Inks[i], cf, size, transparency)
	end
end

local function updateEntry(session, entry, t, dt, frame, tier)
	local layer = entry.Layer
	local p = layer.Params
	local shown = tier >= layer.Priority
	local age = session.Clock - entry.Start
	local ramp = if (p.Ramp or 0) > 0 then session.Ramp else 1
	local fading = if session.Ending then math.clamp((session.Clock - session.Ending) / 0.3, 0, 1) else 0
	if entry.Directional then
		entry.Directional:Update(frame, workspace.CurrentCamera, t, shown, (p.Opacity or 1)*(1-fading))
	end
	if entry.Emitter and layer.Kind ~= "Burst" then
		entry.Emitter.Enabled = shown and not session.Ending and ramp > 0.02
		if layer.Kind == "Sprite" then
			local throb = 1 + (if (p.Throb or 0) > 0 then 0.12 * math.sin(t * p.Throb * math.pi) else 0)
			local grow = 1 + ((p.Grow or 1) - 1) * ramp
			local s = entry.BaseSize * grow * throb * (0.35 + 0.65 * ramp)
			if not entry.LastSize or math.abs(entry.LastSize - s) > 0.03 then
				entry.LastSize = s
				entry.Emitter.Size = sizeSequence(s, s * 1.1)
			end
		elseif (p.Ramp or 0) > 0 then
			entry.Emitter.Rate = entry.Rate * (0.25 + 0.75 * ramp)
		end
		if (p.RangeSpeed or 0) > 0 and session.Range then
			-- Streams travel the live beam length in one lifetime, so they end where the beam ends.
			local speed = math.max(p.Speed or 0, session.Range / math.max(0.05, p.Lifetime or 0.5) * 0.95)
			if not entry.LastSpeed or math.abs(entry.LastSpeed - speed) > 0.5 then
				entry.LastSpeed = speed
				entry.Emitter.Speed = NumberRange.new(speed * 0.92, speed)
			end
		end
	end
	if entry.Parts then
		updateMesh(session, entry, t, frame, shown, (p.Opacity or 0.8) * ramp * (1 - fading) * entry.FallbackDim)
	end
	if entry.Plate then
		local fx, fz
		if (p.Footprint or 0) > 0 then
			fx, fz = footprint(session)
			fx, fz = fx * 0.98, fz * 0.98
		else
			fx = (p.Size or 4)
			fz = fx
		end
		local y
		if entry.Floor then
			y = entry.Floor.Y
		else
			y = floorY(session, frame)
		end
		local opacity = (p.Opacity or 0.8) * ramp * (1 - fading)
		if (p.Duration or 0) > 0 and (p.Fade or 0) > 0 then
			opacity *= 1 - math.clamp((age - p.Duration * 0.5) / (p.Duration * 0.5), 0, 1)
		end
		if (p.Pulse or 0) > 0 then
			opacity *= 1 - p.Pulse + p.Pulse * math.sin(t * 2.4) ^ 2
		end
		local pos = if entry.Floor
			then Vector3.new(entry.Floor.X, y + 0.04, entry.Floor.Z)
			else Vector3.new(frame.Position.X, y + 0.04, frame.Position.Z)
		local _, yaw0 = frame:ToOrientation()
		entry.Plate.Size = Vector3.new(math.max(0.2, fx), 0.05, math.max(0.2, fz))
		entry.Plate.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw0 + t * (p.Spin or 0), 0)
		entry.Decal.Transparency = if shown then math.clamp(1 - opacity, 0, 1) else 1
	end
	if entry.Arc then
		entry.Arc:Update(session.Range or 10, session.Width or 1, age, shown, fading)
	end
	if entry.Beam then
		local beam = entry.Beam
		local width = math.max(0.15, (p.Width or 1) * (session.Width or 1))
		local surge = 1 + 0.12 * math.sin(t * 9 + (p.Width or 1))
		beam.Width0, beam.Width1 = width * surge * (1 - fading), width * 0.85 * surge * (1 - fading)
		if (p.Wobble or 0) > 0 then
			local range = session.Range or 10
			beam.CurveSize0 = math.sin(t * 7.3) * p.Wobble * range * 0.06
			beam.CurveSize1 = math.cos(t * 6.1) * p.Wobble * range * 0.06
		end
		beam.Enabled = shown
	end
	if entry.Pieces then
		local life = p.Lifetime or 0.8
		local fade = math.clamp((age - life * 0.6) / (life * 0.4), 0, 1)
		for _, piece in entry.Pieces do
			piece.Velocity += Vector3.new(0, -(p.Gravity or 50) * dt, 0)
			local nextPosition = piece.Position + piece.Velocity * dt
			if nextPosition.Y < entry.FloorY + piece.Size.Y * 0.3 then
				nextPosition = Vector3.new(nextPosition.X, entry.FloorY + piece.Size.Y * 0.3, nextPosition.Z)
				piece.Velocity =
					Vector3.new(piece.Velocity.X * 0.55, math.abs(piece.Velocity.Y) * 0.25, piece.Velocity.Z * 0.55)
				piece.Spin *= 0.5
			end
			piece.Position = nextPosition
			piece.Rotation *= CFrame.Angles(piece.Spin.X * dt, piece.Spin.Y * dt, piece.Spin.Z * dt)
			placePair(
				piece.Name,
				piece.Part,
				piece.Ink,
				CFrame.new(piece.Position) * piece.Rotation,
				piece.Size * (1 - fade * 0.5),
				if shown then fade else 1
			)
		end
	end
	if entry.Light then
		local brightness = p.Brightness or 1
		if (p.Flash or 0) > 0 then
			brightness *= math.max(0, 1 - age / p.Flash) ^ 2
		end
		entry.Light.Brightness = brightness * ramp * (1 - fading)
		entry.Light.Enabled = shown and brightness > 0.01
	end
	if entry.Trail then
		entry.Trail.Enabled = shown
	end
end

local function refreshSize(session)
	local anchor = session.Anchor
	local size
	if session.Options.Size then
		size = session.Options.Size
	elseif session.Role == "Construct" or session.Role == "Manipulation" then
		size = anchor.Size
	else
		size = anchor:GetAttribute("VFXSize") or anchor.Size
	end
	if typeof(size) ~= "Vector3" then
		size = anchor.Size
	end
	session.Size = size
	if session.Role == "Wave" or session.Role == "Beam" then
		session.Range = size.Z
		session.Width = size.X
	end
end

local function step(dt)
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for session in pairs(sessions) do
		session.Clock = now - session.Born
		local t = session.Clock
		local anchor = session.Anchor
		local alive = anchor.Parent ~= nil
		if alive then
			local phase = anchor:GetAttribute("VFXPhase")
			if phase == "End" and not session.Ending then
				session:Finish()
			end
			session.Frame = anchor.CFrame
			if session.Options.Travel then
				session.Frame *= CFrame.new(0, 0, -t * 5)
			end
			refreshSize(session)
		elseif not session.Ending and not session.OneShot then
			session:Finish()
		end
		if session.Options.Duration and t > session.Options.Duration and not session.Ending then
			session:Finish()
		end
		if session.OneShot and not session.Ending and t > session.Linger + 0.05 then
			session:Finish()
		end
		if session.EndAt and t > session.EndAt then
			session:Stop()
			continue
		end
		if session.Stopped then
			continue
		end
		-- Projectiles face their actual motion so trails, streaks and stretched shells follow
		-- curved/homing paths; everything else uses the anchor's authoritative frame.
		local frame = session.Frame
		if session.Role == "Projectile" then
			local position = frame.Position
			if session.LastPosition and dt > 0 then
				local velocity = (position - session.LastPosition) / dt
				if velocity.Magnitude > 2 then
					local target = velocity.Unit
					session.Heading = if session.Heading
						then session.Heading:Lerp(target, math.min(1, dt * 18))
						else target
				end
			end
			session.LastPosition = position
			if session.Heading and session.Heading.Magnitude > 0.01 then
				frame = CFrame.lookAt(position, position + session.Heading)
			end
		end
		session.Host.CFrame = frame
		if GROUNDED_ROLES[session.Role] and (session.FloorAt == nil or t - session.FloorAt > 0.5) then
			session.FloorAt = t
			local top = frame.Position + Vector3.new(0, session.Size.Y * 0.5, 0)
			local floor = floorBelow(top, { session.Folder, anchor }, session.Size.Y + 8)
			session.FloorY = if floor then floor.Y else nil
		end
		for _, attachment in session.EndAttachments do
			attachment.Position = Vector3.new(0, 0, -(session.Range or 10))
		end
		for _, shape in session.ShapeHosts do
			placeShape(session, shape, frame)
		end
		if session.Role == "Cast" and session.Phase == "Gather" then
			session.Ramp = math.clamp(t / session.ChargeTime, 0, 1) ^ 0.7
		end
		local distance = if camera then (camera.CFrame.Position - frame.Position).Magnitude else 0
		local tier = if distance > HIDDEN_DISTANCE then 0 elseif distance > DETAIL_DISTANCE then 1 else 3
		if session.ConnectedFire then
			local fade = if session.Ending then 1 - math.clamp((t - session.Ending) / 0.3, 0, 1) else 1
			session.ConnectedFire:Update(frame, t, tier > 0, fade, session.Quality, distance > DETAIL_DISTANCE)
		end
		for _, entry in session.Entries do
			updateEntry(session, entry, t, dt, frame, tier)
		end
	end
end

function Renderer.start()
	if connection and connection.Connected then
		return
	end
	Assets.prefetch()
	ConnectedFire.prefetch()
	connection = RunService.Heartbeat:Connect(step)
end

-- Returns a session (with .Replaces for the composer) or nil when no signature covers the plan.
function Renderer.attach(anchor: BasePart, plan, options)
	options = options or {}
	if not Renderer.Enabled or usage.Sessions >= Budget.MaxSessions then
		return nil
	end
	local phase = anchor:GetAttribute("VFXPhase") or plan.Phase or "Sustain"
	local quality = options.Quality or Renderer.Quality
	local resolved = Planner.plan(plan, phase, { CastingCue = plan.CastingCue, Quality = quality, DirectionalSprites = Renderer.UseDirectionalSprites and Assets.UseCustom })
	if not resolved or #resolved.Layers == 0 then
		return nil
	end
	if not connection or not connection.Connected then
		Renderer.start()
	end
	local f = Instance.new("Folder")
	f.Name = "Signature_" .. resolved.Signature .. "_" .. resolved.Role
	f.Parent = options.Parent or folder()
	local host = invisiblePart("Host", f)
	host.CFrame = anchor.CFrame
	local attachment = Instance.new("Attachment")
	attachment.Parent = host
	local geometry = plan.Geometry or "Sphere"
	local session = setmetatable({
		Anchor = anchor,
		Plan = plan,
		Options = options,
		Quality = quality,
		Role = resolved.Role,
		Signature = resolved.Signature,
		Phase = phase,
		Replaces = resolved.Replaces,
		Scalars = resolved.Scalars,
		Folder = f,
		Host = host,
		Attachment = attachment,
		Entries = {},
		ShapeHosts = {},
		EndAttachments = {},
		Owned = { Emitters = 0, Rate = 0, Meshes = 0, Lights = 0, Trails = 0 },
		Born = os.clock(),
		Clock = 0,
		Linger = 0.2,
		Ramp = if resolved.Role == "Cast" and phase == "Gather" then 0 else 1,
		-- Inverse of the extractor's sqrt(cast / 5) curve, so the ramp tracks the real charge time.
		ChargeTime = math.max(0.25, (resolved.Scalars.Charge ^ 2) * 5),
		Seed = tonumber(plan.Seed) or 0,
		Frame = anchor.CFrame,
		OneShot = ONE_SHOT_ROLES[resolved.Role] == true,
		Round = geometry ~= "Box" and geometry ~= "Plane" and geometry ~= "Line",
	}, Session)
	refreshSize(session)
	-- Body scale follows the real hit size (diameter 2.2 = scale 1); areas keep their own extents.
	-- Small darts keep a readable floor so their signature doesn't shrink to a speck.
	if resolved.Role == "Projectile" then
		local size = session.Size
		session.Scale = math.clamp(math.min(size.X, size.Y, size.Z) / 2.2, 0.65, 3.5)
	else
		session.Scale = 1
	end
	if GROUNDED_ROLES[session.Role] then
		local top = anchor.Position + Vector3.new(0, session.Size.Y * 0.5, 0)
		local floor = floorBelow(top, { f, anchor }, session.Size.Y + 8)
		session.FloorY = if floor then floor.Y else nil
		session.FloorAt = 0
	end
	for _, a in session.EndAttachments do
		a.Position = Vector3.new(0, 0, -(session.Range or 10))
	end
	usage.Sessions += 1
	sessions[session] = true
	local layers = resolved.Layers
	if Renderer.UseConnectedFire and Assets.UseCustom and resolved.Signature == "Fire" and resolved.Role == "Projectile"
		and phase ~= "End" and usage.Meshes < Budget.MaxMeshes then
		session.ConnectedFire = ConnectedFire.new(f, session.Scale)
		if session.ConnectedFire then
			usage.Meshes += 1
			session.Owned.Meshes += 1
			-- The approved body includes its wake; retain only the existing budgeted light.
			layers = {}
			for _, layer in resolved.Layers do
				if layer.Kind == "Light" then table.insert(layers, layer) end
			end
			session.ConnectedFire:Update(anchor.CFrame, 0, true, 1, quality, false)
		end
	end
	buildLayers(session, layers)
	for _, a in session.EndAttachments do
		a.Position = Vector3.new(0, 0, -(session.Range or 10))
	end
	-- The server's projectile part is a primitive stand-in; hide it locally (it still exists and
	-- moves authoritatively) whenever this signature draws the projectile body instead.
	if resolved.Role == "Projectile" and resolved.Replaces.Form then
		anchor.LocalTransparencyModifier = 1
		for _, child in anchor:GetChildren() do
			if child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("PointLight") then
				child.Enabled = false
			end
		end
	end
	-- Field/aura markers are translucent Neon volumes stamped as the anchor itself (capsules carry
	-- welded caps, cones edge beams). The signature draws the area instead, so hide them locally.
	if (resolved.Role == "Field" or resolved.Role == "Aura") and resolved.Replaces.Form then
		if anchor.Transparency < 1 then
			anchor.LocalTransparencyModifier = 1
		end
		for _, child in anchor:GetDescendants() do
			if child:IsA("BasePart") then
				child.LocalTransparencyModifier = 1
			elseif child:IsA("Beam") then
				child.Enabled = false
			end
		end
	end
	return session
end

function Renderer.stats()
	return table.clone(usage)
end

function Renderer.stopAll()
	for session in pairs(sessions) do
		session:Stop()
	end
end

return Renderer
]=];end
return "Installed connected endpoint-anchored lightning; removed travelling arc glyphs"
