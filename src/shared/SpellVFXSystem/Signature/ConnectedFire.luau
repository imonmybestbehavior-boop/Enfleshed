-- One authored skinned body. The owning signature session supplies movement and lifetime.
-- Surface maps are configured in the asset model, never assigned by gameplay scripts.
local Poses = require(script.Parent.Parent.Assets.ConnectedFirePoses)
local Fire = {}
Fire.__index = Fire
local MAX_ACTIVE, POOL_LIMIT = 12, 8
local active, created = 0, 0
local pool = {}
local warming = false
local timing = { Updates = 0, TotalMS = 0, MaxMS = 0 }
local facing = CFrame.Angles(0, -math.pi / 2, 0)

local function template()
	local model = script.Parent.Parent.Assets:FindFirstChild("ConnectedFireRig")
	local mesh = model and model:FindFirstChild("ConnectedFireVolume")
	local frames = model and model:FindFirstChild("Frames")
	if not mesh or not mesh:IsA("MeshPart") or not frames or #frames:GetChildren() ~= 24 then return nil end
	local root = mesh:FindFirstChild("Root")
	if not root then return nil end
	for _, name in Poses.Names do
		if not root:FindFirstChild(name) then return nil end
	end
	return model
end

function Fire.ready()
	return active < MAX_ACTIVE and template() ~= nil
end

function Fire.prefetch()
	if warming then return end
	warming = true
	task.spawn(function()
		for _ = 1, POOL_LIMIT do
			if active + #pool >= POOL_LIMIT then break end
			local source = template()
			if not source then break end
			local model = source:Clone()
			model.ConnectedFireVolume.Transparency = 1
			table.insert(pool, model)
			created += 1
			task.wait() -- Spread cold skin/material cloning across startup frames.
		end
		warming = false
	end)
end

function Fire.new(parent, bodyScale)
	if active >= MAX_ACTIVE then return nil end
	local source = template()
	if not source then return nil end
	local model = table.remove(pool)
	if not model then model = source:Clone(); created += 1 end
	local mesh = model.ConnectedFireVolume
	model.PrimaryPart = mesh
	-- A 2.2-stud projectile uses a 2.2-stud wide burning mass; its wake trails behind.
	local factor = math.clamp(bodyScale or 1, 0.65, 3.5) * (2.2 / source.ConnectedFireVolume.Size.Y)
	model:ScaleTo(source:GetScale() * factor)
	mesh.Anchored = true
	mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = false, false, false
	mesh.CastShadow = false
	mesh.Transparency = 1
	mesh.LocalTransparencyModifier = 0
	mesh.Color = Color3.new(1, 1, 1)
	local root = mesh.Root
	local bones, frames = {}, {}
	for i, name in Poses.Names do bones[i] = root[name] end
	for i = 1, 24 do frames[i] = model.Frames[string.format("Frame_%03d", i)] end
	model.Name = "ConnectedFireBody"
	model.Parent = parent
	active += 1
	return setmetatable({
		Model = model, Mesh = mesh, Bones = bones, Surfaces = frames, Factor = factor,
		Offset = (Vector3.new(0.4, 0, 0) - source.ConnectedFireVolume.Root.Position) * factor,
		Texture = 0, Pose = 0, NextPoseAt = 0, Destroyed = false,
	}, Fire)
end

function Fire:Update(frame, clock, shown, opacity, quality, distant)
	if self.Destroyed then return end
	local mesh = self.Mesh
	mesh.Transparency = if shown then 1 - math.clamp(opacity, 0, 1) else 1
	if not shown then return end
	local started = os.clock()
	mesh.CFrame = frame * facing * CFrame.new(self.Offset)
	local texture = math.floor(clock * 12) % 24 + 1
	if texture ~= self.Texture then
		if self.Texture > 0 then self.Surfaces[self.Texture].Parent = self.Model.Frames end
		self.Surfaces[texture].Parent = mesh
		self.Texture = texture
	end
	local fps = if distant then 6 elseif quality == "Low" then 12 else 24
	if clock >= self.NextPoseAt then
		self.NextPoseAt = clock + 1 / fps - 0.001
		local pose = math.floor(clock * 24) % 48 + 1
		if pose ~= self.Pose then
			for i, bone in self.Bones do
				bone.Transform = CFrame.new(bone.CFrame:VectorToObjectSpace(Poses.Frames[pose][i] * self.Factor))
			end
			self.Pose = pose
		end
	end
	local cost = (os.clock() - started) * 1000
	timing.Updates += 1; timing.TotalMS += cost; timing.MaxMS = math.max(timing.MaxMS, cost)
end

function Fire:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	active -= 1
	for _, surface in self.Surfaces do surface.Parent = self.Model.Frames end
	for _, bone in self.Bones do bone.Transform = CFrame.identity end
	self.Mesh.Transparency = 1
	self.Model.Parent = nil
	if #pool < POOL_LIMIT then table.insert(pool, self.Model) else self.Model:Destroy() end
end

function Fire.stats()
	return { Active = active, Pooled = #pool, Created = created,
		Updates = timing.Updates, MeanUpdateMS = if timing.Updates > 0 then timing.TotalMS / timing.Updates else 0,
		MaxUpdateMS = timing.MaxMS }
end

function Fire.resetTiming()
	timing.Updates, timing.TotalMS, timing.MaxMS = 0, 0, 0
end

return Fire
