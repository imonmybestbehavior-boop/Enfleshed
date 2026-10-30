-- Shared client renderer: normal play and world previews use these exact layers.
-- Instantiates a pure SpellVisualPlanBuilder render plan; owns lifecycle, distance tiers and cleanup.
local RunService = game:GetService("RunService")
local Analyzer = require(script.Parent.SpellVFXAnalyzer)
local Builder = require(script.Parent.Parent.Visual.SpellVisualPlanBuilder)
local Library = require(script.Parent.Parent.Visual.SpellVisualAssetLibrary)
local Colors = require(script.Parent.Parent.Parent.Configuration.MagicElements)
local Composer = {}
local Global = Library.Budget.Global
local active = 0
local emitterCount = 0
local continuousRate = 0
local fireCount = 0
local lightCount = 0
local tau = math.pi * 2
local golden = 0.6180339
-- Client quality preset; lower tiers keep silhouettes and drop detail first.
Composer.Quality = "High"
-- Optional signature renderer (Signature/SignatureRenderer), injected by the client controller.
-- When it covers a spell, its asset-based layers replace the composer layers it names in
-- `Replaces` (Form = priority 1, Element = 2, Mechanic = 3, Detail = 4).
Composer.Signatures = nil
local REPLACED_PRIORITY = { [1] = "Form", [2] = "Element", [3] = "Mechanic", [4] = "Detail" }

local TEXTURES = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
}
local ELEMENT_TEXTURE = {}
for name, element in pairs(Library.Elements) do
	ELEMENT_TEXTURE[name] = element.Texture
end
local WEDGE = { Crystal = true, Flame = true, Wedge = true, Shard = true }
local BALL = { Bubble = true, Ripple = true, Sphere = true }

local function part(parent, color, motif)
	local p = Instance.new(if WEDGE[motif] then "WedgePart" else "Part")
	p.Name = "Element" .. motif
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow = false
	p.Material = if motif == "Stone" or motif == "Slab"
		then Enum.Material.Slate
		elseif motif == "Shell" or motif == "Band" then Enum.Material.ForceField
		else Enum.Material.Neon
	p.Color = color
	if p:IsA("Part") then
		if BALL[motif] or motif == "Shell" then
			p.Shape = Enum.PartType.Ball
		elseif motif == "Band" or motif == "Disc" then
			p.Shape = Enum.PartType.Cylinder
		end
	end
	p.Transparency = 1
	p.Parent = parent
	return p
end

-- Footprint samples, normalized in gameplay's forward (-Z), Y-up frame. Boundaries sit at
-- +/-0.49; cosmetic volumes stay inside it so they never imply a larger hit area.
local function geometrySample(plan, i, count, t, height)
	local a = i / count * tau
	local level = (i * golden) % 1
	local geometry = plan.Geometry
	if geometry == "Cone" then
		local depth = 0.2 + level * 0.8
		return Vector3.new(math.cos(a) * depth * 0.45, (level - 0.5) * height * 0.7, -depth)
	elseif geometry == "Box" or geometry == "Plane" or geometry == "Line" then
		local side = i % 4
		return Vector3.new(side < 2 and -0.46 or 0.46, (level - 0.5) * height, side % 2 == 0 and -0.46 or 0.46)
	elseif geometry == "Ring" then
		local inner = math.max(0.1, (plan.RingInner or 0.5) * 0.5)
		local r = if i % 2 == 0 then 0.47 else math.min(0.47, inner + 0.02)
		return Vector3.new(math.cos(a) * r, (level - 0.5) * height * 0.6, math.sin(a) * r)
	end
	local y = (level - 0.5) * height
	local r = (if i % 3 == 0 then 0.24 else 0.46) * math.sqrt(math.max(0, 1 - (y * 2) ^ 2))
	return Vector3.new(math.cos(a + t * 0.12) * r, y, math.sin(a + t * 0.12) * r)
end

local function boundarySample(plan, i)
	local angle = i / 8 * tau
	local offset
	if plan.Geometry == "Cone" then
		local perimeter = {
			Vector3.new(0, 0, 0),
			Vector3.new(-0.25, 0, -0.5),
			Vector3.new(-0.5, 0, -1),
			Vector3.new(-0.25, 0, -1),
			Vector3.new(0, 0, -1),
			Vector3.new(0.25, 0, -1),
			Vector3.new(0.5, 0, -1),
			Vector3.new(0.25, 0, -0.5),
		}
		offset = perimeter[(i - 1) % 8 + 1]
	elseif plan.Geometry == "Box" or plan.Geometry == "Plane" or plan.Geometry == "Line" then
		local x, z = math.cos(angle), math.sin(angle)
		local denominator = math.max(math.abs(x), math.abs(z))
		offset = Vector3.new(x / denominator * 0.49, 0, z / denominator * 0.49)
	else
		offset = Vector3.new(math.cos(angle) * 0.49, 0, math.sin(angle) * 0.49)
	end
	return Vector3.new(offset.X, -0.48, offset.Z)
end

-- Even, deterministic spread over the authoritative ground footprint (x, z in -0.5..0.5).
-- Golden-angle spiral for round areas, an R2 low-discrepancy grid for boxes; inside 0.46.
local function groundPoint(plan, i, n, phase)
	local geometry = plan.Geometry
	local u = (i - 0.5) / math.max(n, 1)
	if geometry == "Box" or geometry == "Plane" or geometry == "Line" then
		return ((i * 0.7548777 + phase / tau) % 1 - 0.5) * 0.9, ((i * 0.5698403 + 0.31) % 1 - 0.5) * 0.9
	elseif geometry == "Cone" then
		local depth = 0.15 + math.sqrt(u) * 0.8
		local across = ((i * golden + phase / tau) % 1 - 0.5) * depth * 0.85
		return across, -depth
	end
	local a = i * 2.3999632 + phase
	local r
	if geometry == "Ring" then
		local inner = math.max(0.1, (plan.RingInner or 0.5) * 0.5)
		r = inner + (0.46 - inner) * ((i * golden) % 1)
	else
		r = math.sqrt(u) * 0.46
	end
	return math.cos(a) * r, math.sin(a) * r
end

-- Footprint point from two unit values. Used when something resurfaces each cycle, so
-- successive spots scatter instead of walking outward along the ordered spiral.
local function groundScatter(plan, u, v)
	local geometry = plan.Geometry
	if geometry == "Box" or geometry == "Plane" or geometry == "Line" then
		return (u - 0.5) * 0.9, (v - 0.5) * 0.9
	elseif geometry == "Cone" then
		local depth = 0.15 + math.sqrt(u) * 0.8
		return (v - 0.5) * depth * 0.85, -depth
	end
	local r
	if geometry == "Ring" then
		local inner = math.max(0.1, (plan.RingInner or 0.5) * 0.5)
		r = inner + (0.46 - inner) * u
	else
		r = math.sqrt(u) * 0.46
	end
	return math.cos(v * tau) * r, math.sin(v * tau) * r
end

-- Arrangements that rest on the field floor and stay upright instead of tumbling.
local GROUNDED = { Ground = true, Carpet = true, GroundRadial = true, EdgeBeat = true }
-- Floating accents become ground marks inside a field footprint.
local FIELD_ACCENT = {
	Branches = "GroundRadial",
	Wings = "GroundRadial",
	Seeker = "GroundRadial",
	Lance = "GroundRadial",
	Satellites = "Ground",
	Echo = "Ground",
	Crown = "Ground",
}

-- Offset for node i of a layer at animation time t.
local function sample(plan, layer, i, n, t)
	local p = layer.Params
	local arrangement = layer.Arrangement
	local a = i / n * tau + layer.Phase
	local spin = t * (p.RotationSpeed or 0.5)
	if arrangement == "Core" or arrangement == "Shell" or arrangement == "BeamCore" or arrangement == "BeamAura" then
		return Vector3.zero
	elseif arrangement == "Comet" then
		local r = (p.Spread or 0.55) * 0.5
		return Vector3.new(math.cos(a + spin) * r, math.sin(a + spin) * r, (i % 3) * 0.2 * (1 + (plan.Stretch or 0)))
	elseif arrangement == "Helix" then
		local r = p.Spread or 0.35
		local twist = a * 2 + spin
		return Vector3.new(math.cos(twist) * r, math.sin(twist) * r, -i / n)
	elseif arrangement == "Boundary" then
		return boundarySample(plan, i)
	elseif arrangement == "Volume" or arrangement == "Crest" or arrangement == "Lattice" then
		if arrangement == "Lattice" then
			local side = i % 4
			local level = (i * golden) % 1
			return Vector3.new(side < 2 and -0.48 or 0.48, level - 0.5, side % 2 == 0 and -0.48 or 0.48)
		end
		return geometrySample(plan, i, n, t, p.Height or 0.8)
	elseif arrangement == "Orbit" or arrangement == "Mantle" then
		local r = if arrangement == "Mantle" then 0.5 else 0.42
		local level = (i * golden) % 1
		return Vector3.new(math.cos(a + spin) * r, (level - 0.5) * (p.Height or 0.6), math.sin(a + spin) * r)
	elseif arrangement == "Branches" then
		local elevation = (((i * golden + layer.Curve) % 1) - 0.5) * 1.2
		local dir =
			Vector3.new(math.cos(a) * math.cos(elevation), math.sin(elevation), math.sin(a) * math.cos(elevation))
		return dir * (p.Length or 0.5)
	elseif arrangement == "Satellites" then
		local r = (p.Spread or 0.7) * 0.5
		return Vector3.new(math.cos(a + spin) * r, math.sin(a + spin) * r * 0.6, math.sin(a + spin) * r * 0.4)
	elseif arrangement == "Ascent" then
		local rise = ((t * (p.Speed or 0.5) + i / n) % 1) - 0.5
		return Vector3.new(math.cos(a) * 0.28, rise * 0.9, math.sin(a) * 0.28)
	elseif arrangement == "Bands" then
		return Vector3.new(0, (i / (n + 1) - 0.5) * 0.8, 0)
	elseif arrangement == "Wings" then
		local side = if i % 2 == 0 then 1 else -1
		local rank = math.floor((i - 1) / 2)
		local flap = math.sin(t * (p.Speed or 1) * 3 + layer.Phase) * 0.06
		return Vector3.new(side * (0.3 + rank * 0.12), 0.08 + flap + rank * 0.05, 0.2 + rank * 0.12)
	elseif arrangement == "Seeker" then
		return Vector3.new(0, 0, -(0.45 + (p.Lead or 0.1) + (i - 1) * 0.12))
	elseif arrangement == "Lance" then
		return Vector3.new(0, 0, -(0.5 + (p.Length or 0.6) * 0.5))
	elseif arrangement == "Echo" then
		return Vector3.new(0, 0, i * 0.45)
	elseif arrangement == "Runes" then
		return Vector3.new(math.cos(a + spin) * 0.4, -0.47, math.sin(a + spin) * 0.4)
	elseif arrangement == "Crown" then
		return Vector3.new(math.cos(a + spin) * 0.3, 0.5, math.sin(a + spin) * 0.3)
	elseif arrangement == "Ring" then
		local swell = 1 + (p.PulseAmplitude or 0.1) * math.sin(t * (p.PulseFrequency or 1) * tau + layer.Phase)
		local base = if plan.Form == "Projectile" then 0.32 else 0.42
		local r = math.min(0.49, base * swell)
		local y = if plan.Form == "Projectile" then 0 else -0.47
		return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	end
	return Vector3.zero
end

local function elongation(layer)
	local motif, arrangement, p = layer.Motif, layer.Arrangement, layer.Params
	local e = Vector3.one
	if WEDGE[motif] then
		local stretch = p.Elongation or 2.4
		e = Vector3.new(0.6, stretch, 0.8)
	elseif motif == "Ribbon" or motif == "Fork" then
		e = Vector3.new(0.18, 0.3, 3)
	elseif motif == "Rune" or motif == "Glyph" then
		e = Vector3.new(1, 0.12, 1)
	elseif motif == "Slab" then
		e = Vector3.new(1.4, 0.5, 1)
	end
	if arrangement == "Lance" then
		e = Vector3.new(0.3, 0.3, (p.Length or 0.6) * 3)
	elseif arrangement == "Wings" then
		e = Vector3.new((p.Length or 0.4) * 3, 0.12, 0.6)
	elseif arrangement == "Seeker" then
		e = Vector3.new(0.4, 0.4, 1.6)
	end
	return e
end

-- Cosmetic only: finds the visible floor under a field. Gameplay areas are centred on the
-- cast point, so the lower half of the hit volume is usually below the terrain.
local function probeFloor(frame, size, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = table.clone(ignore)
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	params.FilterDescendantsInstances = excluded
	local top = frame.Position + Vector3.new(0, size.Y * 0.5, 0)
	local hit = workspace:Raycast(top, Vector3.new(0, -(size.Y + 6), 0), params)
	if not hit then
		return -size.Y * 0.5
	end
	return math.clamp(frame:PointToObjectSpace(hit.Position).Y, -size.Y * 0.5, size.Y * 0.45)
end

local function maxPriorityAt(distance)
	for _, tier in ipairs(Library.Budget.DistanceTiers) do
		if distance < tier[1] then
			return tier[2]
		end
	end
	return 0
end

function Composer.attach(anchor, plan, options)
	options = options or {}
	plan = Analyzer.forPhase(plan, anchor:GetAttribute("VFXPhase") or plan.Phase, anchor.Name)
	local castingCue = plan.CastingCue
	if active >= Global.MaxSessions then
		return nil
	end
	active += 1
	local render = Builder.build(plan, { Quality = options.Quality or Composer.Quality })
	-- A release at the caster is an acknowledgement, never an impact. Enforce this
	-- even if the signature renderer is disabled or has exhausted its budget.
	if castingCue and anchor:GetAttribute("VFXPhase") == "Release" then
		render.Layers = {}
	end
	local signature = Composer.Signatures and Composer.Signatures.attach(anchor, plan, options)
	if signature then
		local kept = {}
		for _, layer in ipairs(render.Layers) do
			if not signature.Replaces[REPLACED_PRIORITY[layer.Priority] or ""] then
				table.insert(kept, layer)
			end
		end
		render.Layers = kept
	end
	local folder = Instance.new("Folder")
	folder.Name = "ComposedSpellLayers"
	folder.Parent = options.Parent or workspace
	local primary = plan.Color or Colors[plan.Element] or Colors.Neutral
	local secondary = plan.SecondaryColor or primary:Lerp(Color3.new(0.1, 0.1, 0.2), 0.35)
	local accent = plan.AccentColor or primary:Lerp(Color3.new(1, 1, 1), 0.75)
	-- One invisible host carries emitters, light and trails at the composition centre.
	local host = part(folder, primary, "Host")
	host.Size = Vector3.one * 0.2
	local hostAttachment = Instance.new("Attachment")
	hostAttachment.Parent = host
	-- Fields emit from their whole floor so particles rise across the real footprint.
	local grounded = plan.Form == "Field" and not castingCue
	local areaHost
	if grounded then
		areaHost = part(folder, primary, "Host")
		areaHost.Size = Vector3.one * 0.2
		for _, layer in ipairs(render.Layers) do
			if layer.Priority == 3 and FIELD_ACCENT[layer.Arrangement] then
				layer.Arrangement = FIELD_ACCENT[layer.Arrangement]
			elseif layer.Arrangement == "Ring" then
				-- Tick/DoT/growth pulses add no objects; they make the field's own outline and
				-- floor throb at the pulse frequency.
				layer.Arrangement = "EdgeBeat"
			end
		end
	end
	local round = plan.Geometry ~= "Box"
		and plan.Geometry ~= "Plane"
		and plan.Geometry ~= "Line"
		and plan.Geometry ~= "Cone"
	local layers = {}
	local owned = { Emitters = 0, Rate = 0, Fire = 0, Lights = 0 }
	local flameHosts = {}
	for _, layer in ipairs(render.Layers) do
		local p = layer.Params
		local entry = { Layer = layer, Nodes = {}, Links = {}, Emitters = {}, Fires = {}, Trails = {} }
		if layer.Kind == "Nodes" then
			local motif = layer.Motif
			if layer.Arrangement == "Shell" then
				motif = "Shell"
			elseif layer.Arrangement == "Bands" then
				motif = "Band"
			end
			local nodeCount = p.Count
			if layer.Arrangement == "EdgeBeat" then
				entry.Beat = true
				nodeCount = 0
			end
			for i = 1, nodeCount do
				local isAccent = layer.Priority == 3 or i % 3 == 0 or layer.Arrangement == "Core"
				local color = if isAccent then accent else primary
				local nodeMotif = motif
				if grounded and layer.Arrangement == "Carpet" then
					-- Murky floor in the element's darker tone; boxy footprints get a block.
					color = if i == 1 then secondary else primary:Lerp(secondary, 0.5)
					if i == 1 and not round and plan.Geometry ~= "Ring" then
						nodeMotif = "Floor"
					end
				elseif grounded and (motif == "Bubble" or motif == "Ripple") then
					color = if i % 3 == 0 then primary:Lerp(accent, 0.3) else primary:Lerp(secondary, 0.25)
				end
				local node = part(folder, color, nodeMotif)
				local attachment = Instance.new("Attachment")
				attachment.Parent = node
				entry.Nodes[i] = { Part = node, Attachment = attachment, Motif = nodeMotif }
				if layer.Id == "Fire.Flames" then
					table.insert(flameHosts, node)
				end
			end
			-- Scattered ground bodies are not a chain: linking them draws random streaks across
			-- the field. Only lightning keeps links there, as flickering arcs.
			local links = p.LinkCount or 0
			if grounded and GROUNDED[layer.Arrangement] and layer.Motif ~= "Fork" then
				links = 0
			end
			for i = 1, links do
				local beam = Instance.new("Beam")
				local closed = layer.Arrangement == "Boundary" or layer.Arrangement == "Crest"
				local j = if closed or i < p.Count then i % p.Count + 1 else i
				beam.Attachment0, beam.Attachment1 = entry.Nodes[i].Attachment, entry.Nodes[j].Attachment
				beam.Color = ColorSequence.new(primary, accent)
				beam.FaceCamera = true
				beam.LightEmission = 0.8
				beam.Transparency = NumberSequence.new(0.18)
				beam.Segments = 8
				beam.Parent = folder
				entry.Links[i] = beam
			end
		elseif layer.Kind == "Emitter" then
			local rate = p.Rate
			if emitterCount < Global.MaxEmitters and continuousRate + rate <= Global.MaxContinuousRate then
				emitterCount += 1
				continuousRate += rate
				owned.Emitters += 1
				owned.Rate += rate
				local e = Instance.new("ParticleEmitter")
				local texture = if layer.Texture == "Element" then ELEMENT_TEXTURE[plan.Element] else layer.Texture
				e.Texture = TEXTURES[texture or "Sparkle"] or TEXTURES.Sparkle
				e.Color = ColorSequence.new(accent, secondary)
				e.LightEmission = if texture == "Smoke" then 0.2 else 0.8
				e.Rate = rate
				e.Lifetime = NumberRange.new(p.Lifetime * 0.7, p.Lifetime)
				e.Speed = NumberRange.new((p.Speed or 1) * 0.6, p.Speed or 1)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Transparency = NumberSequence.new(1 - (p.Opacity or 0.88), 1)
				e.Acceleration = Vector3.new(0, p.Rise or 0, 0)
				if areaHost then
					e.Shape = if round then Enum.ParticleEmitterShape.Disc else Enum.ParticleEmitterShape.Box
					e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
					e.EmissionDirection = Enum.NormalId.Top
					e.SpreadAngle = Vector2.new(18, 18)
					e.Parent = areaHost
				else
					e.Parent = host
				end
				entry.Emitters[1] = e
			end
		elseif layer.Kind == "Fire" then
			for i = 1, p.Count do
				if fireCount >= Global.MaxFire then
					break
				end
				local flame = Instance.new("Fire")
				flame.Color, flame.SecondaryColor = primary, accent
				flame.Heat = p.Heat
				flame.Size = p.Size
				flame.Parent = flameHosts[i] or host
				fireCount += 1
				owned.Fire += 1
				entry.Fires[i] = flame
			end
		elseif layer.Kind == "Light" then
			if lightCount < Global.MaxLights then
				lightCount += 1
				owned.Lights += 1
				local light = Instance.new("PointLight")
				light.Color, light.Shadows = primary, false
				light.Parent = host
				entry.Light = light
			end
		elseif layer.Kind == "Trail" and not castingCue then
			for i = 1, p.Count do
				local half = p.Width * (if i == 1 then 0.6 else 1.4) * 0.5
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(-half, 0, 0), Vector3.new(half, 0, 0)
				a0.Parent, a1.Parent = host, host
				local trail = Instance.new("Trail")
				trail.Attachment0, trail.Attachment1 = a0, a1
				trail.Color = ColorSequence.new(accent, primary)
				trail.Lifetime = p.Lifetime
				trail.LightEmission = 1
				trail.FaceCamera = true
				trail.Transparency = NumberSequence.new(1 - (p.Opacity or 0.85), 1)
				trail.Parent = folder
				entry.Trails[i] = { Trail = trail, A0 = a0, A1 = a1, Half = half }
			end
		end
		table.insert(layers, entry)
	end
	local start, ending, ended = os.clock(), nil, false
	local lastFrame = anchor.CFrame
	local lastSize = if plan.Form == "Construct" and not options.Size
		then anchor.Size
		else anchor:GetAttribute("VFXSize") or options.Size or anchor.Size
	local connection
	local floorY, lastProbe = nil, -math.huge
	-- Render plan and live layer handles are exposed read-only for tooling and tests.
	local session = { Render = render, Layers = layers, Signature = signature }
	function session:Finish()
		if not ending then
			ending = os.clock() - start
		end
		if signature then
			signature:Finish()
		end
	end
	function session:Stop(cancel)
		if ended then
			return
		end
		ended = true
		active -= 1
		emitterCount -= owned.Emitters
		continuousRate -= owned.Rate
		fireCount -= owned.Fire
		lightCount -= owned.Lights
		if connection then
			connection:Disconnect()
		end
		-- Visibility cancellation must not masquerade as a spell ending or hit.
		if signature then
			if cancel then signature:Stop() else signature:Finish() end
		end
		folder:Destroy()
	end
	connection = RunService.Heartbeat:Connect(function()
		if not folder.Parent then
			session:Stop()
			return
		end
		local t = os.clock() - start
		if not anchor.Parent then
			session:Finish()
		end
		local phase = anchor:GetAttribute("VFXPhase") or plan.Phase
		if phase == "End" and not ending then
			ending = t
		end
		if ending and t - ending > 0.6 then
			session:Stop()
			return
		end
		if options.Duration and t > options.Duration then
			session:Finish()
		end
		local camera = workspace.CurrentCamera
		local distance = camera and (camera.CFrame.Position - lastFrame.Position).Magnitude or 0
		local visible = distance < Library.Budget.HiddenDistance
		local tierPriority = maxPriorityAt(distance)
		local fade = ending and math.clamp((t - ending) / 0.6, 0, 1) or 0
		local envelope = math.min(1, t / 0.16) * (1 - fade)
		if anchor.Parent then
			lastSize = if plan.Form == "Construct" and not options.Size
				then anchor.Size
				else anchor:GetAttribute("VFXSize") or options.Size or anchor.Size
			lastFrame = anchor.CFrame
		end
		local size, frame = lastSize, lastFrame
		if castingCue then
			size *= 0.35
		end
		if options.Travel then
			frame *= CFrame.new(0, 0, -t * 5)
		end
		if anchor:GetAttribute("VFXRotated") then
			frame *= CFrame.Angles(0, 0, -math.pi / 2)
		end
		host.CFrame = frame
		if grounded and (floorY == nil or t - lastProbe > 0.5) then
			lastProbe = t
			floorY = probeFloor(frame, size, { folder, anchor })
		end
		local floor = floorY or -size.Y * 0.5
		if areaHost then
			if plan.Geometry == "Cone" then
				areaHost.Size = Vector3.new(size.X * 0.4, 0.2, size.Z * 0.7)
				areaHost.CFrame = frame * CFrame.new(0, floor + 0.1, -size.Z * 0.55)
			else
				areaHost.Size = Vector3.new(size.X * 0.88, 0.2, size.Z * 0.88)
				areaHost.CFrame = frame * CFrame.new(0, floor + 0.1, 0)
			end
		end
		if phase == "Gather" then
			envelope *= 0.55 + math.min(t, 1) * 0.45
		end
		-- Slow/time dilation make the whole composition move heavier.
		local anim = t * render.TimeScale
		-- Field throb: the strongest pulse accent (DoT tick, channel tick, growth) at its
		-- real frequency, sharpened so each tick reads as a beat.
		local beat = 0
		for _, entry in layers do
			if entry.Beat then
				local p = entry.Layer.Params
				local wave = math.max(0, math.sin(anim * (p.PulseFrequency or 1) * tau + entry.Layer.Phase))
				beat = math.max(beat, math.min(1, (p.PulseAmplitude or 0.2) * 2.4) * wave ^ 3)
			end
		end
		local minDim = math.min(size.X, size.Y, size.Z)
		local base = math.clamp(math.min(size.X, math.max(size.Y, 2), size.Z) * 0.17, 0.45, 3)
		for _, entry in layers do
			local layer = entry.Layer
			local p = layer.Params
			local shown = visible and layer.Priority <= math.max(1, tierPriority)
			local speed = render.ElementSpeed * (if plan.Form == "Projectile" then render.MotionRate else 1)
			local n = #entry.Nodes
			for i, node in entry.Nodes do
				local arrangement = layer.Arrangement
				local pulse = 1
					+ (p.PulseAmplitude or 0.08)
						* math.sin(anim * (p.PulseFrequency or plan.Speed or 1) * tau * 0.5 + layer.Phase + i)
				local offset = sample(plan, layer, i, n, anim * speed * 0.4)
				if p.Turbulence then
					offset += Vector3.new(
						math.sin(anim * 3.1 + i),
						math.sin(anim * 2.3 + i * 1.7),
						math.cos(anim * 2.7 + i)
					) * p.Turbulence * 0.06
				end
				if phase == "Gather" and layer.Priority ~= 1 then
					local angle = i / n * tau + anim * 2
					offset = Vector3.new(math.cos(angle) * 0.6, math.sin(angle) * 0.4, 0)
				end
				if phase == "Impact" then
					offset *= (0.35 + t * 2.5) * (p.BurstSize or 1)
				end
				if arrangement == "Crest" then
					offset *= math.min(1, 0.2 + t * 2)
				end
				if grounded and (arrangement == "Boundary" or arrangement == "Ring" or arrangement == "Runes") then
					offset = Vector3.new(offset.X, (floor + 0.05) / math.max(size.Y, 0.01), offset.Z)
				end
				local partSize
				local groundOpacity
				local cframe = frame * CFrame.new(offset * size)
				if grounded and GROUNDED[arrangement] then
					-- Grounded field layers: evenly spread inside the footprint, resting on the
					-- visible ground and never above the top of the authoritative volume.
					local x, z = groundPoint(plan, i, n, layer.Phase)
					local footprint = math.min(size.X, size.Z)
					local yaw = i * 2.3999632 + layer.Phase
					local variation = 0.65 + 0.7 * ((i * golden + layer.Phase / tau) % 1)
					local ceiling = size.Y * 0.5 - floor
					local motif = layer.Motif
					if arrangement == "Carpet" then
						if i == 1 then
							-- One faint surface that fills the real footprint (rings stay open).
							local inset = if plan.Geometry == "Cone" then 0.7 else 0.94
							if node.Motif == "Floor" then
								partSize = Vector3.new(size.X * inset, 0.05, size.Z * inset) * envelope
								local zOffset = if plan.Geometry == "Cone" then -size.Z * 0.5 else 0
								cframe = frame * CFrame.new(0, floor + 0.03, zOffset)
							else
								local d = footprint * 0.94
								partSize = Vector3.new(0.05, d, d) * envelope
								cframe = frame * CFrame.new(0, floor + 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2)
							end
							-- Ring fields keep their open centre, so they get no full surface.
							groundOpacity = if plan.Geometry == "Ring"
								then 0
								else (p.Opacity or 0.22) * 0.9 * (1 + 0.8 * beat)
						else
							-- A few dim, irregular blotches for texture rather than bright pads.
							local d = footprint * 0.16 * variation * pulse
							local aspect = 0.55 + 0.4 * ((i * 0.37 + layer.Phase / tau) % 1)
							partSize = Vector3.new(0.05, d, d * aspect) * envelope
							cframe = frame
								* CFrame.new(x * size.X, floor + 0.04 + i * 0.003, z * size.Z)
								* CFrame.Angles(0, yaw, math.pi / 2)
							groundOpacity = (p.Opacity or 0.22) * 0.55
						end
					elseif arrangement == "GroundRadial" then
						local length = footprint * (0.12 + (p.Length or 0.4) * 0.25)
						local width = math.max(0.15, base * (p.Scale or 0.4) * 0.5)
						partSize = Vector3.new(width, 0.08, length) * envelope
						cframe = frame
							* CFrame.new(x * size.X, floor + 0.05, z * size.Z)
							* CFrame.Angles(0, math.atan2(-x, -z) + math.pi, 0)
					elseif motif == "Bubble" or motif == "Ripple" then
						-- Cyclic surface events: bubbles swell then pop, ripples spread then fade.
						-- Faster DoT ticks bubble faster; each cycle surfaces somewhere new.
						local rate = math.max(0.35, (p.PulseFrequency or 0.8) * 0.45)
						local cycle = anim * rate * render.TimeScale + (i * golden)
						local k = math.floor(cycle)
						local f = cycle - k
						local u = (i * golden + k * 0.7548777 + layer.Phase / tau) % 1
						local v = (i * 0.5698403 + k * 0.3819660 * 1.7 + 0.71) % 1
						x, z = groundScatter(plan, u, v)
						if motif == "Bubble" then
							local maxD = math.clamp(footprint * 0.05 * (p.Scale or 0.6), 0.25, 1.2) * variation
							local grow = if f < 0.8 then (f / 0.8) ^ 0.7 else 1 + (f - 0.8) * 1.5
							local d = maxD * grow * (if f > 0.92 then 0 else 1) * envelope
							partSize = Vector3.one * math.max(0.02, d)
							local rise = math.min(f * 0.35 * maxD, math.max(0, ceiling - d))
							cframe = frame * CFrame.new(x * size.X, floor + d * 0.3 + rise, z * size.Z)
							groundOpacity = 0.55 * (1 - math.max(0, f - 0.75) * 2)
						else
							local d = footprint * 0.28 * variation * f
							partSize = Vector3.new(0.04, math.max(0.05, d), math.max(0.05, d)) * envelope
							cframe = frame
								* CFrame.new(x * size.X, floor + 0.05, z * size.Z)
								* CFrame.Angles(0, 0, math.pi / 2)
							groundOpacity = 0.6 * (1 - f)
						end
					elseif motif == "Rune" or motif == "Glyph" then
						-- Glyphs lie flat on the ground and turn slowly.
						local d = math.clamp(footprint * 0.12 * (p.Scale or 0.5) * variation, 0.6, 3) * pulse
						partSize = Vector3.new(d, 0.06, d) * envelope
						cframe = frame
							* CFrame.new(x * size.X, floor + 0.05, z * size.Z)
							* CFrame.Angles(0, yaw + anim * (p.RotationSpeed or 0.5) * 0.3, 0)
					elseif motif == "Stone" or motif == "Slab" then
						-- Rubble rests half-buried; it does not sway or spin.
						local d = math.clamp(footprint * 0.08 * (p.Scale or 0.8) * variation, 0.5, ceiling)
						partSize = Vector3.new(d, d * (if motif == "Slab" then 0.4 else 0.75), d * 0.85) * envelope
						cframe = frame
							* CFrame.new(x * size.X, floor + partSize.Y * 0.25, z * size.Z)
							* CFrame.Angles(layer.Tilt, yaw, layer.Tilt * 0.5)
					else
						-- Upright bodies (flames, crystals, forks, ribbons) surge in height with their
						-- pulse (DoT tick rate/strength) and sway rather than tumble.
						local stretch = if WEDGE[motif]
							then (p.Elongation or 2.2)
							else (if motif == "Ribbon" or motif == "Fork" then 2 else 1)
						local maxHeight = math.max(0.5, ceiling * 0.95)
						local height = math.clamp(
							footprint * 0.15 * (p.Scale or 0.6) * variation * pulse,
							0.8,
							maxHeight
						) * envelope
						local width = math.max(0.3, height / stretch * 1.3)
						if motif == "Fork" or motif == "Ribbon" then
							width *= 0.35
						end
						partSize = Vector3.new(width * 0.8, math.max(0.05, height), width * 0.55)
						local sway = math.sin(anim * 1.7 + i * 1.3) * 0.12 * ((p.Turbulence or 0.2) + 0.2)
						cframe = frame
							* CFrame.new(x * size.X, floor + height * 0.5, z * size.Z)
							* CFrame.Angles(sway, yaw, sway * 0.6)
					end
				elseif grounded and arrangement == "Bands" then
					-- Drag/bind bands hug the floor of a field instead of floating.
					local r = (p.Spread or 0.45) * 2 * math.min(size.X, size.Z)
					partSize = Vector3.new(0.05, r, r) * envelope
					cframe = frame
						* CFrame.new(0, floor + 0.08 + i * 0.12, 0)
						* CFrame.Angles(0, anim * (p.Speed or 0.2), math.pi / 2)
				elseif arrangement == "Core" then
					local d = math.max(0.1, minDim * p.Scale * envelope * pulse)
					partSize = Vector3.new(d, d, d * (1 + (p.Stretch or 0) * 2))
					cframe *= CFrame.Angles(anim, anim * 0.6, 0)
				elseif arrangement == "BeamCore" or arrangement == "BeamAura" then
					local scale = p.Scale * (if arrangement == "BeamCore" then envelope * pulse else 1)
					partSize = Vector3.new(math.max(0.08, size.X * scale), math.max(0.08, size.Y * scale), size.Z)
					cframe = frame * CFrame.new(0, 0, -size.Z / 2)
				elseif arrangement == "Shell" then
					local cap = if plan.Form == "Projectile" then 0.75 else 0.98
					local d = minDim * math.min(cap, 0.6 + (i - 1) * p.Thickness * 2) * envelope
					partSize = Vector3.one * math.max(0.1, d)
				elseif arrangement == "Bands" then
					local r = (p.Spread or 0.45) * 2 * math.min(size.X, size.Z)
					partSize = Vector3.new(math.max(0.05, minDim * 0.04), r, r) * envelope
					cframe = frame * CFrame.new(offset * size) * CFrame.Angles(0, anim * (p.Speed or 0.2), math.pi / 2)
				else
					local s = if arrangement == "Helix" then math.clamp(size.X * 0.18, 0.12, 0.5) else base
					partSize = elongation(layer) * math.max(0.02, s * (p.Scale or 0.6) * pulse * envelope)
					cframe *= CFrame.Angles(
						anim * 0.4 + layer.Tilt,
						i + anim * (p.RotationSpeed or 0.5) * speed,
						i * 0.7 + layer.Tilt
					)
				end
				node.Part.Size = partSize
				node.Part.CFrame = cframe
				local opacity = p.Opacity or (if layer.Priority == 3 then 0.75 else 0.85)
				if grounded and arrangement == "Boundary" then
					-- The outline line carries the boundary; no orbs at its corners.
					opacity = 0
				elseif groundOpacity then
					opacity = math.max(0, groundOpacity)
				elseif arrangement == "Shell" then
					opacity *= 1 - (i - 1) * 0.15
				elseif arrangement == "Echo" then
					opacity *= 1 - i * 0.18
				end
				node.Part.Transparency = if shown then math.clamp(1 - opacity * (1 - fade), 0, 1) else 1
			end
			for i, beam in entry.Links do
				beam.Enabled = shown and (distance < 90 or i % 2 == 0)
				local s = if layer.Arrangement == "Helix" then math.clamp(size.X * 0.18, 0.12, 0.5) else base
				beam.Width0 = math.max(0.01, s * (p.LinkWidth or 0.6) * envelope)
				beam.Width1 = beam.Width0 * 0.45
				if grounded and layer.Arrangement == "Boundary" then
					beam.Width0 *= 1 + 1.2 * beat
					beam.Width1 = beam.Width0
					beam.Transparency = NumberSequence.new(math.clamp(0.35 - 0.3 * beat, 0, 1))
				end
				local curl = (layer.Motif == "Ribbon" or layer.Motif == "Ripple") and s * 2 or 0
				beam.CurveSize0, beam.CurveSize1 = curl * math.sin(anim + i + layer.Curve), -curl
				if p.Flicker then
					local hop = math.floor(anim * (p.PulseFrequency or 12))
					beam.Attachment1 = entry.Nodes[(i + hop) % n + 1].Attachment
					beam.Enabled = shown and (i + hop) % 3 ~= 0
				end
			end
			for _, e in entry.Emitters do
				e.Enabled = shown and not ending
				e.Rate = if distance < 70 then p.Rate else p.Rate * 0.5
				local particle = math.clamp(minDim * 0.25, 0.5, 2.5) * (p.Size or 1)
				e.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, particle),
					NumberSequenceKeypoint.new(0.5, particle * 1.6),
					NumberSequenceKeypoint.new(1, 0),
				})
			end
			for i, flame in entry.Fires do
				flame.Enabled = shown and not ending and (distance < 90 or i % 2 == 1)
				local footprint = math.clamp(math.max(size.X, size.Z) / 4, 0.5, 1.5)
				flame.Size = math.clamp(p.Size * footprint * envelope, 2, 14)
			end
			if entry.Light then
				entry.Light.Enabled = shown and distance < 90
				entry.Light.Brightness = p.Brightness * envelope
				entry.Light.Range = math.min(p.Range, math.max(8, math.max(size.X, size.Z) * 1.2))
			end
			for _, trail in entry.Trails do
				trail.Trail.Enabled = shown
				trail.A0.Position = Vector3.new(-trail.Half * minDim, 0, 0)
				trail.A1.Position = Vector3.new(trail.Half * minDim, 0, 0)
			end
		end
	end)
	return session
end
function Composer.preview(spell, frame)
	local plan = Analyzer.resolve(spell)
	local anchor = Instance.new("Part")
	anchor.Name = "SpellCompositionPreview"
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Transparency = 1
	anchor.CFrame = frame
	anchor.Parent = workspace
	local config = spell[plan.Form] or {}
	local size
	if plan.Form == "Projectile" then
		-- Hit diameter only: cosmetic scale never implies a larger hitbox.
		size = Vector3.one * (config.Radius or 1) * 2
	elseif plan.Form == "Beam" then
		size = Vector3.new((config.Width or 1) * 2, (config.Width or 1) * 2, math.min(config.Range or 18, 30))
	elseif plan.Form == "Field" or plan.Form == "Aura" then
		local areaConfig = table.clone(config)
		local defaults = {
			Radius = 6,
			Height = 8,
			Width = 12,
			Depth = 12,
			Range = 12,
			Angle = 60,
			InnerRadius = 3,
			OuterRadius = 6,
			Thickness = 1,
		}
		for key, value in pairs(defaults) do
			if areaConfig[key] == nil then
				areaConfig[key] = value
			end
		end
		size = require(script.Parent.Parent.Parent.Modules.MagicGeometry).areaSize(plan.Geometry, areaConfig)
	elseif plan.Form == "Construct" then
		size = Vector3.new(config.Width or 8, config.Height or 10, config.Depth or 4)
	elseif plan.Form == "Wave" then
		local range = config.Range or 10
		size = plan.Geometry == "Sphere" and Vector3.one * range * 2 or Vector3.new(range * 2, 5, range)
	else
		size = Vector3.new(5, 6, 5)
	end
	local session = Composer.attach(anchor, plan, { Size = size, Duration = 3.4, Travel = plan.Form == "Projectile" })
	game:GetService("Debris"):AddItem(anchor, 4.1)
	return session
end
return Composer
