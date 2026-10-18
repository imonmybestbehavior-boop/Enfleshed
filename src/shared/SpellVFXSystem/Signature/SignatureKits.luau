-- Pure data: identity kits and the form templates that turn a kit into signature layers.
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
			Width = 1,
			Opacity = 1,
			Light = light + 0.2,
			TextureLength = 5,
			Scroll = f.Scroll or 3,
			Wobble = f.Wobble or 0,
		},
	})
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
		Feel = { Light = 0.45, Rise = 0, Framerate = 30, Spin = 2, Scroll = 9, Wobble = 1.2, ScatterSize = 0.7 },
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
