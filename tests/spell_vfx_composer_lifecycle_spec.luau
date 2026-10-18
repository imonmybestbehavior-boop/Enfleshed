-- Runs the real SpellVFXComposer against a minimal Roblox instance mock to check lifecycle,
-- cleanup, ending fade, previews, casting cues, budgets and distance degradation.
-- This verifies wiring and bookkeeping only; it is not a rendered visual review.
env.script = {
	Parent = {
		SpellSpec = "spec",
		MagicVisualSpec = "visualSpec",
		Parent = { Configuration = { MagicSchema = "schema" } },
	},
}
env.require = function(value)
	if value == "spec" then
		return spec
	elseif value == "schema" then
		return schema
	elseif value == "visualSpec" then
		return visualSpec
	end
	error(value)
end
local starters = load("src/shared/Modules/GrimoireStarters.luau")
local cost = load("src/shared/Modules/MagicLabCost.luau")
local curated = {}
for _, record in ipairs(starters.buildShowcase()) do
	cost.refresh(record.Definition, spec.estimate, spec.copy)
	curated[record.Definition.Name] = record.Definition
end

-- Value types ---------------------------------------------------------------------------
local V = {}
local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(t, key)
	if key == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	end
	return nil
end
local function op(f)
	return function(a, b)
		if type(a) == "number" then
			return vec(f(a, b.X), f(a, b.Y), f(a, b.Z))
		elseif type(b) == "number" then
			return vec(f(a.X, b), f(a.Y, b), f(a.Z, b))
		end
		return vec(f(a.X, b.X), f(a.Y, b.Y), f(a.Z, b.Z))
	end
end
V.__add = op(function(a, b)
	return a + b
end)
V.__sub = op(function(a, b)
	return a - b
end)
V.__mul = op(function(a, b)
	return a * b
end)
V.__div = op(function(a, b)
	return a / b
end)
V.__unm = function(a)
	return vec(-a.X, -a.Y, -a.Z)
end
local C = {}
C.__index = C
local function cframe(position)
	return setmetatable({ Position = position }, C)
end
C.__mul = function(a, b)
	return cframe(a.Position + b.Position)
end
function C:PointToObjectSpace(point)
	return point - self.Position
end
local Color = {}
Color.__index = Color
local function color(r, g, b)
	return setmetatable({ R = r, G = g, B = b, _color = true }, Color)
end
function Color:Lerp(other, t)
	return color(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
end
-- Curated spells were built with the plain Color3 stub; give their palettes Lerp support.
for _, d in pairs(curated) do
	for _, key in ipairs({ "Color", "SecondaryColor", "AccentColor" }) do
		local c = d.Visual[key]
		if c then
			d.Visual[key] = color(c.R, c.G, c.B)
		end
	end
end
local function record(kind)
	return function(...)
		return { Kind = kind, ... }
	end
end

-- Instances -----------------------------------------------------------------------------
local live = {}
local Instance = {}
Instance.__index = function(self, key)
	if rawget(Instance, key) then
		return rawget(Instance, key)
	end
	return rawget(self, "_props")[key]
end
Instance.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			old._children[self] = nil
		end
		if value then
			assert(not rawget(value, "_destroyed"), "Parenting to a destroyed instance")
			value._children[self] = true
		end
	end
	props[key] = value
end
local PARTS = { Part = true, WedgePart = true }
local function new(className)
	local object =
		setmetatable({ _class = className, _props = { Name = className }, _children = {}, _attributes = {} }, Instance)
	live[object] = true
	return object
end
function Instance:IsA(name)
	return self._class == name or (name == "BasePart" and PARTS[self._class] == true)
end
function Instance:GetAttribute(name)
	return self._attributes[name]
end
function Instance:SetAttribute(name, value)
	self._attributes[name] = value
end
function Instance:GetAttributes()
	return self._attributes
end
function Instance:Destroy()
	if rawget(self, "_destroyed") then
		return
	end
	for child in pairs(self._children) do
		child:Destroy()
	end
	rawset(self, "_destroyed", true)
	live[self] = nil
	self.Parent = nil
end
local function count(className)
	local n = 0
	for object in pairs(live) do
		if object._class == className then
			n += 1
		end
	end
	return n
end

local heartbeats = {}
local workspaceObject = new("Workspace")
workspaceObject.CurrentCamera = { CFrame = cframe(vec(0, 0, 0)) }
-- Terrain height under every probe; nil means "no ground below".
local groundHeight = 0
local raycasts = 0
rawset(workspaceObject, "Raycast", function(_, origin, direction)
	raycasts += 1
	if groundHeight == nil or origin.Y < groundHeight or origin.Y + direction.Y > groundHeight then
		return nil
	end
	return { Position = vec(origin.X, groundHeight, origin.Z) }
end)
local clock = 0
env.os = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })
env.workspace = workspaceObject
env.game = {
	GetService = function(_, name)
		if name == "RunService" then
			return {
				Heartbeat = {
					Connect = function(_, fn)
						local connection = { Connected = true }
						function connection:Disconnect()
							self.Connected = false
							heartbeats[self] = nil
						end
						heartbeats[connection] = fn
						return connection
					end,
				},
			}
		elseif name == "Debris" then
			return {
				AddItem = function(_, item, lifetime)
					item._debris = clock + lifetime
				end,
			}
		elseif name == "Players" then
			return {
				GetPlayers = function()
					return {}
				end,
			}
		elseif name == "CollectionService" then
			return { AddTag = function() end }
		end
		error("Unexpected service " .. name)
	end,
}
local function step(seconds, dt)
	dt = dt or 1 / 30
	local elapsed = 0
	while elapsed < seconds - 1e-9 do
		clock += dt
		elapsed += dt
		for object in pairs(live) do
			if object._debris and clock >= object._debris then
				object._debris = nil
				object:Destroy()
			end
		end
		local snapshot = {}
		for connection, fn in pairs(heartbeats) do
			snapshot[connection] = fn
		end
		for connection, fn in pairs(snapshot) do
			if heartbeats[connection] then
				fn(dt)
			end
		end
	end
end
local function connections()
	local n = 0
	for _ in pairs(heartbeats) do
		n += 1
	end
	return n
end
env.Instance = { new = new }
env.Vector3 = { new = vec, zero = vec(0, 0, 0), one = vec(1, 1, 1) }
env.Vector2 = { new = record("Vector2") }
env.RaycastParams = {
	new = function()
		return {}
	end,
}
env.CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then
			return cframe(x)
		end
		return cframe(vec(x, y, z))
	end,
	Angles = function()
		return cframe(vec(0, 0, 0))
	end,
}
env.Color3 = {
	new = color,
	fromRGB = function(r, g, b)
		return color(r / 255, g / 255, b / 255)
	end,
}
env.ColorSequence = { new = record("ColorSequence") }
env.NumberSequence = { new = record("NumberSequence") }
env.NumberSequenceKeypoint = { new = record("Keypoint") }
env.NumberRange = { new = record("NumberRange") }
env.Enum = setmetatable({}, {
	__index = function(_, group)
		return setmetatable({}, {
			__index = function(_, item)
				return group .. "." .. item
			end,
		})
	end,
})

-- Load the real modules --------------------------------------------------------------------
local modules = {}
env.require = function(value)
	return assert(modules[value], "Unexpected require " .. tostring(value))
end
env.script = { Parent = {} }
modules.curves = load("src/shared/SpellVFXSystem/Visual/VisualCurves.luau")
modules.colors = load("src/shared/Configuration/MagicElements.luau")
modules.geometry = load("src/shared/Modules/MagicGeometry.luau")
env.script = { Parent = { VisualCurves = "curves" } }
modules.extractor = load("src/shared/SpellVFXSystem/Visual/SpellVisualFeatureExtractor.luau")
modules.fingerprint = load("src/shared/SpellVFXSystem/Visual/SpellVisualFingerprint.luau")
modules.library = load("src/shared/SpellVFXSystem/Visual/SpellVisualAssetLibrary.luau")
env.script = {
	Parent = {
		VisualCurves = "curves",
		SpellVisualAssetLibrary = "library",
		SpellVisualFingerprint = "fingerprint",
		SpellVisualFeatureExtractor = "extractor",
	},
}
modules.builder = load("src/shared/SpellVFXSystem/Visual/SpellVisualPlanBuilder.luau")
local visualFolder = {
	SpellVisualFeatureExtractor = "extractor",
	SpellVisualFingerprint = "fingerprint",
	SpellVisualPlanBuilder = "builder",
	SpellVisualAssetLibrary = "library",
}
env.script = { Parent = { Parent = { Visual = visualFolder } } }
modules.analyzer = load("src/shared/SpellVFXSystem/Core/SpellVFXAnalyzer.luau")
env.script = {
	Parent = {
		SpellVFXAnalyzer = "analyzer",
		Parent = {
			Visual = visualFolder,
			Parent = { Configuration = { MagicElements = "colors" }, Modules = { MagicGeometry = "geometry" } },
		},
	},
}
local composer = load("src/shared/SpellVFXSystem/Core/SpellVFXComposer.luau")
local analyzer, library = modules.analyzer, modules.library

local function anchorFor(size, phase, name)
	local anchor = new("Part")
	anchor.Name = name or "MagicProjectile"
	anchor.Size = size
	anchor.CFrame = cframe(vec(0, 0, 0))
	anchor.Parent = workspaceObject
	anchor:SetAttribute("VFXSize", size)
	anchor:SetAttribute("VFXPhase", phase or "Sustain")
	return anchor
end
local function setCamera(distance)
	workspaceObject.CurrentCamera.CFrame = cframe(vec(0, 0, distance))
end
local function layersByPriority(session, priority)
	local list = {}
	for _, entry in ipairs(session.Layers) do
		if entry.Layer.Priority == priority then
			table.insert(list, entry)
		end
	end
	return list
end

-- Instantiation matches the bounded render plan exactly.
local fire = curated["Cinder Comet"]
local plan = analyzer.resolve(fire)
local anchor = anchorFor(vec(2.7, 2.7, 2.7))
setCamera(20)
local session = assert(composer.attach(anchor, plan))
local totals = session.Render.Totals
assert(count("Part") + count("WedgePart") == totals.Parts + 1 + 1, "Parts = plan parts + host + anchor")
assert(count("Beam") == totals.Links and count("Trail") == totals.Trails)
assert(count("ParticleEmitter") == totals.Emitters and count("Fire") == totals.Fire)
assert(count("PointLight") == totals.Lights)
step(0.5)
for _, entry in ipairs(session.Layers) do
	for _, node in ipairs(entry.Nodes) do
		assert(node.Part.Transparency < 1, entry.Layer.Id .. " must be visible up close")
		assert(node.Part.Size.X > 0 and node.Part.Size.X == node.Part.Size.X, "Node size must be finite")
	end
end
-- Truthfulness: the projectile core stays within 0.6x the hit diameter.
for _, entry in ipairs(session.Layers) do
	if entry.Layer.Arrangement == "Core" then
		assert(entry.Nodes[1].Part.Size.X <= 2.7 * 0.6 * 1.6 + 1e-6, "Core must not imply a larger hitbox")
	end
end

-- Distance degradation: detail first, silhouette last.
assert(#layersByPriority(session, 1) > 0 and #layersByPriority(session, 3) > 0 and #layersByPriority(session, 4) > 0)
local detailEmitters = 0
for _, entry in ipairs(layersByPriority(session, 4)) do
	detailEmitters += #entry.Emitters
end
assert(detailEmitters > 0, "Fixture must exercise detail emitters")
setCamera(100)
step(0.1)
for _, entry in ipairs(layersByPriority(session, 4)) do
	for _, e in ipairs(entry.Emitters) do
		assert(e.Enabled == false, "Detail particles drop beyond 70 studs")
	end
end
setCamera(150)
step(0.1)
for _, entry in ipairs(layersByPriority(session, 3)) do
	for _, node in ipairs(entry.Nodes) do
		assert(node.Part.Transparency == 1, "Mechanic accents drop beyond 120 studs")
	end
end
for _, entry in ipairs(layersByPriority(session, 1)) do
	assert(entry.Nodes[1].Part.Transparency < 1, "Silhouette survives at 150 studs")
end
setCamera(200)
step(0.1)
for _, entry in ipairs(session.Layers) do
	for _, node in ipairs(entry.Nodes) do
		assert(node.Part.Transparency == 1, "Everything hides beyond 180 studs")
	end
end
setCamera(20)

-- Ending phase fades for 0.6 s, then all owned instances and the heartbeat are released.
anchor:SetAttribute("VFXPhase", "End")
step(0.3)
assert(connections() == 1, "Fading session is still alive")
step(0.4)
assert(connections() == 0, "Session must disconnect after the ending fade")
assert(count("ParticleEmitter") == 0 and count("Fire") == 0 and count("Beam") == 0 and count("Trail") == 0)
assert(count("Part") + count("WedgePart") == 1, "Only the gameplay anchor remains")
anchor:Destroy()

-- A removed anchor finishes at its last transform instead of leaving immortal emitters.
local orphan = anchorFor(vec(8, 4, 8), "Sustain", "MagicField")
local fieldSession = assert(composer.attach(orphan, analyzer.resolve(curated["Bell of Cinders"])))
step(0.2)
orphan:Destroy()
step(0.7)
assert(connections() == 0 and count("ParticleEmitter") == 0 and count("Fire") == 0, "Orphaned session must clean up")
assert(fieldSession.Render.Totals.Parts > 0)

-- Fields are grounded: bodies stand on the floor inside the footprint, never above its height,
-- and particles emit from the floor instead of the centre.
local pulsingFields = 0
for _, name in ipairs({ "Bell of Cinders", "Gravemire", "Undertow Ring", "Witchfire Fan" }) do
	local d = curated[name]
	local fieldSize = vec(16, 8, 16)
	local area = anchorFor(fieldSize, "Sustain", "MagicField")
	local fieldPlan = analyzer.resolve(d)
	local s = assert(composer.attach(area, fieldPlan))
	step(0.6)
	local groundedNodes = 0
	for _, entry in ipairs(s.Layers) do
		local arrangement = entry.Layer.Arrangement
		if arrangement == "Ground" or arrangement == "Carpet" or arrangement == "GroundRadial" then
			for _, node in ipairs(entry.Nodes) do
				groundedNodes += 1
				local position, partSize = node.Part.CFrame.Position, node.Part.Size
				-- Cones extend from the apex at the anchor along -Z, like the boundary layer.
				local zMin, zMax = -fieldSize.Z * 0.5, fieldSize.Z * 0.5
				if d.Geometry == "Cone" then
					zMin, zMax = -fieldSize.Z, 0
				end
				assert(
					math.abs(position.X) <= fieldSize.X * 0.5 and position.Z >= zMin and position.Z <= zMax,
					name .. ": " .. entry.Layer.Id .. " left the footprint"
				)
				-- The anchor sits on the terrain (y = 0); half the hit volume is underground.
				assert(position.Y >= -1e-6, name .. ": " .. entry.Layer.Id .. " is buried below the visible ground")
				local motif = entry.Layer.Motif
				local upright = motif == "Flame"
					or motif == "Wedge"
					or motif == "Crystal"
					or motif == "Shard"
					or motif == "Fork"
					or motif == "Ribbon"
				-- Flat discs/ripples are cylinders turned on their side, so their Size.Y is a diameter.
				local flatDisc = arrangement == "Carpet" or motif == "Ripple"
				assert(
					flatDisc or position.Y + partSize.Y * 0.5 <= fieldSize.Y * 0.5 + 1e-6,
					name .. ": body must stay within the field height"
				)
				if arrangement == "Ground" and upright then
					assert(
						math.abs(position.Y - partSize.Y * 0.5) < 0.05,
						name .. ": upright body must stand on the ground"
					)
					assert(partSize.Y >= 0.79, name .. ": upright field bodies must be clearly visible")
				elseif arrangement == "Ground" and (motif == "Bubble" or motif == "Ripple") then
					assert(
						math.max(partSize.X, partSize.Z) <= fieldSize.X * 0.3,
						name .. ": surface bubbles/ripples stay small"
					)
					assert(position.Y <= fieldSize.Y * 0.25, name .. ": bubbles stay at the surface")
				else
					assert(position.Y <= 0.6, name .. ": ground marks must hug the ground")
				end
			end
		end
		for _, e in ipairs(entry.Emitters) do
			assert(
				e.Parent ~= nil and e.Parent.Size.X > fieldSize.X * 0.3,
				name .. ": field particles must emit from the floor area"
			)
			assert(e.EmissionDirection == "NormalId.Top")
		end
	end
	assert(groundedNodes >= 12, name .. ": field must render a well-filled grounded body, got " .. groundedNodes)
	-- No beam streaks across the floor: only the boundary ring (and lightning arcs) link nodes.
	for _, entry in ipairs(s.Layers) do
		local arrangement = entry.Layer.Arrangement
		if
			(arrangement == "Ground" or arrangement == "Carpet" or arrangement == "GroundRadial")
			and entry.Layer.Motif ~= "Fork"
		then
			assert(#entry.Links == 0, name .. ": " .. entry.Layer.Id .. " must not draw links across the field")
		end
	end
	-- No orbs on the edge: the outline line is the boundary, and pulse accents create no
	-- objects; instead the outline throbs at the tick frequency.
	local outline, beats = nil, false
	for _, entry in ipairs(s.Layers) do
		assert(entry.Layer.Arrangement ~= "Ring", name .. ": fields must not use swelling pulse rings")
		if entry.Layer.Arrangement == "EdgeBeat" then
			beats = true
			assert(#entry.Nodes == 0, name .. ": pulse accents must not add orbs")
		elseif entry.Layer.Arrangement == "Boundary" then
			outline = entry
			for _, node in ipairs(entry.Nodes) do
				assert(node.Part.Transparency == 1, name .. ": no orbs at the outline corners")
			end
		end
	end
	assert(outline and #outline.Links > 0, name .. ": the outline line must remain")
	if beats then
		local low, high = math.huge, 0
		for _ = 1, 40 do
			step(0.05)
			low = math.min(low, outline.Links[1].Width0)
			high = math.max(high, outline.Links[1].Width0)
		end
		assert(high > low * 1.15, name .. ": the outline must throb with the field's ticks")
		pulsingFields += 1
	end
	-- One faint floor surface, then small dim blotches (no large bright pads).
	for _, entry in ipairs(s.Layers) do
		if entry.Layer.Arrangement == "Carpet" then
			assert(#entry.Nodes <= 5, name .. ": floor uses one surface plus few blotches")
			for k, node in ipairs(entry.Nodes) do
				assert(node.Part.Transparency >= 0.6, name .. ": floor must stay faint")
				if k > 1 then
					assert(
						math.max(node.Part.Size.Y, node.Part.Size.Z) <= fieldSize.X * 0.3,
						name .. ": blotches stay small"
					)
				end
			end
		end
	end
	-- Bubbling: surface bubbles pop and resurface elsewhere over time.
	if d.Element == "Poison" then
		local bubbles
		for _, entry in ipairs(s.Layers) do
			if entry.Layer.Id == "Poison.Bubbles" then
				bubbles = entry
			end
		end
		assert(bubbles, name .. ": poison field must have bubbles")
		local before = bubbles.Nodes[1].Part.CFrame.Position
		local popped = false
		for _ = 1, 40 do
			step(0.1)
			popped = popped or bubbles.Nodes[1].Part.Transparency >= 0.99 or bubbles.Nodes[1].Part.Size.X <= 0.05
		end
		local after = bubbles.Nodes[1].Part.CFrame.Position
		-- Resurfacing scatters: it must not march steadily outward from the centre.
		local radii, outward = {}, 0
		for _ = 1, 60 do
			step(0.1)
			local position = bubbles.Nodes[1].Part.CFrame.Position
			local r = math.sqrt(position.X * position.X + position.Z * position.Z)
			if #radii == 0 or math.abs(r - radii[#radii]) > 0.05 then
				table.insert(radii, r)
			end
		end
		for k = 2, #radii do
			outward += if radii[k] > radii[k - 1] then 1 else 0
		end
		assert(#radii >= 4 and outward < #radii - 1, name .. ": bubbles must not drift outward cycle after cycle")
		assert(popped, name .. ": bubbles must pop")
		assert((after - before).Magnitude > 0.1, name .. ": bubbles must resurface somewhere new")
	end
	assert(raycasts > 0, name .. ": field must probe for the visible ground")
	for _, entry in ipairs(s.Layers) do
		assert(entry.Layer.Arrangement ~= "Volume", name .. ": fields no longer use the floating volume")
	end
	s:Stop()
	area:Destroy()
end
assert(pulsingFields > 0, "At least one fixture field must exercise the tick throb")
assert(connections() == 0)

-- Casting cues never draw trails or the hit silhouette around the caster.
local gather = anchorFor(vec(3, 4, 3), "Gather", "SpellGatherComposition")
local cue = assert(composer.attach(gather, analyzer.resolve(fire)))
assert(count("Trail") == 0, "Gather cue has no trails")
for _, entry in ipairs(cue.Layers) do
	assert(entry.Layer.Id ~= "Projectile.Core", "Gather cue must not draw the projectile silhouette")
end
cue:Stop()
gather:Destroy()
assert(connections() == 0)

-- Session cap and global particle/fire budgets hold under pressure, and capacity is reusable.
local sessions, anchors = {}, {}
for i = 1, library.Budget.Global.MaxSessions + 5 do
	local a = anchorFor(vec(2.7, 2.7, 2.7))
	table.insert(anchors, a)
	local s = composer.attach(a, plan)
	if i <= library.Budget.Global.MaxSessions then
		assert(s, "Sessions up to the cap must start")
		table.insert(sessions, s)
	else
		assert(s == nil, "Sessions beyond the cap must be refused")
	end
end
assert(count("ParticleEmitter") <= library.Budget.Global.MaxEmitters, "Global emitter cap")
assert(count("Fire") <= library.Budget.Global.MaxFire, "Global native Fire cap")
assert(count("PointLight") <= library.Budget.Global.MaxLights, "Global light cap")
local liveRate = 0
for object in pairs(live) do
	if object._class == "ParticleEmitter" then
		liveRate += object.Rate
	end
end
assert(liveRate <= library.Budget.Global.MaxContinuousRate + 1e-6, "Global continuous rate cap")
for _, s in ipairs(sessions) do
	s:Stop()
	s:Stop() -- idempotent
end
for _, a in ipairs(anchors) do
	a:Destroy()
end
assert(connections() == 0 and count("ParticleEmitter") == 0)
local again = anchorFor(vec(2.7, 2.7, 2.7))
local reused = assert(composer.attach(again, plan), "Capacity must be reusable after stopping")
assert(count("ParticleEmitter") == reused.Render.Totals.Emitters, "Released emitter budget is reusable")
reused:Stop()
again:Destroy()

-- Previews use the same renderer, never cast, and expire on their own.
local preview = assert(composer.preview(curated["Undertow Ring"], cframe(vec(0, 8, 0))))
assert(preview.Render.Form == "Field")
step(3.5)
step(0.7)
assert(connections() == 0 and count("ParticleEmitter") == 0, "Preview must finish and clean up")
assert(count("Part") + count("WedgePart") == 0, "Preview anchor is removed by Debris")
print(
	"Composer lifecycle: plan-exact instantiation, distance tiers, ending fade, orphan cleanup, casting cues, session/emitter/fire/light/rate caps and previews passed"
)
