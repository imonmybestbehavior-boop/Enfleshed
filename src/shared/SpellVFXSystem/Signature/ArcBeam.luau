-- A connected, flickering polyline. Points are local to the authoritative beam host.
-- This owns cosmetic attachments/beams only; it never computes a hit or sends a remote.
local ArcBeam = {}
ArcBeam.__index = ArcBeam

function ArcBeam.new(host, parent, texture, colors, params, capacity, seed)
	if capacity < 3 then
		return nil
	end
	local count = math.clamp(math.floor(params.ArcSegments or 9), 3, math.min(10, capacity))
	local branchCount = math.min(2, math.floor((capacity - count) / 2))
	local self = setmetatable({ Points = {}, Beams = {}, Branches = {}, Seed = seed or 0, Params = params }, ArcBeam)
	local function point()
		local a = Instance.new("Attachment")
		a.Name = "ArcPoint"
		a.Parent = host
		return a
	end
	local function segment(a, b, branch)
		local beam = Instance.new("Beam")
		beam.Name = if branch then "ArcBranch" else "ConnectedArc"
		beam.Attachment0 = a
		beam.Attachment1 = b
		beam.FaceCamera = true
		beam.Segments = 1
		-- The existing strip's thin alpha becomes gaps when repeated on short segments.
		-- Solid ribbons keep every joint visibly connected; color comes from the same palette.
		beam.Texture = ""
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureSpeed = 0
		beam.Color = colors
		beam.LightEmission = 0.2
		beam.LightInfluence = 0.25
		beam.Transparency = NumberSequence.new(if branch then 0.2 else 0)
		beam.Parent = parent
		table.insert(self.Beams, { Beam = beam, Branch = branch })
	end
	for i = 1, count + 1 do
		self.Points[i] = point()
	end
	for i = 1, count do
		segment(self.Points[i], self.Points[i + 1], false)
	end
	for i = 1, branchCount do
		local start = math.floor(count * (0.25 + i * 0.2)) + 1
		local mid, tip = point(), point()
		segment(self.Points[start], mid, true)
		segment(mid, tip, true)
		table.insert(self.Branches, { Start = start, Mid = mid, Tip = tip })
	end
	self.Count = #self.Beams
	return self
end

function ArcBeam:Update(range, width, age, shown, fading)
	local tick = math.floor(age * 18)
	if tick ~= self.Tick or range ~= self.Range or width ~= self.Width then
		self.Tick, self.Range, self.Width = tick, range, width
		local random = Random.new((self.Seed + tick * 7919) % 2147483647)
		local n = #self.Points - 1
		local amplitude = math.min(1.6, range * 0.045, width * 0.6 + 0.2)
		for i, a in self.Points do
			local u = (i - 1) / n
			local spread = math.sin(u * math.pi) * amplitude
			a.Position = Vector3.new(random:NextNumber(-spread, spread), random:NextNumber(-spread, spread), -range * u)
		end
		-- Exact endpoints, including while a beam changes length or its host moves.
		self.Points[1].Position = Vector3.zero
		self.Points[#self.Points].Position = Vector3.new(0, 0, -range)
		for i, branch in self.Branches do
			local origin = self.Points[branch.Start].Position
			local side = if i % 2 == 0 then -1 else 1
			branch.Mid.Position = origin + Vector3.new(side * amplitude * 0.65, amplitude * 0.45, -range * 0.06)
			branch.Tip.Position = origin + Vector3.new(side * amplitude * 1.3, -amplitude * 0.3, -range * 0.12)
		end
	end
	for _, entry in self.Beams do
		local w = math.max(0.025, width * (self.Params.Width or 0.18))
			* (if entry.Branch then 0.45 else 1)
			* (1 - fading)
		entry.Beam.Width0 = w
		entry.Beam.Width1 = w * (if entry.Branch then 0.12 else 0.8)
		entry.Beam.Enabled = shown and fading < 1
	end
end

return ArcBeam
