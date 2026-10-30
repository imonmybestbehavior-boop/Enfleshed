--!strict
local Run = game:GetService("RunService")
local Collection = game:GetService("CollectionService")
local Http = game:GetService("HttpService")
local Animation = require(game:GetService("ReplicatedStorage").Shared.Modules.EnemyAnimation)
local Controller = {}
local records: { [Model]: any } = {}
local pending: { [Model]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local names = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
local frames, writes = 0, 0
local started = false
local function release(model: Model)
	local record = records[model]
	if record then
		for _, joint in record.Joints do
			if joint.Parent then
				joint.Transform = CFrame.identity
			end
		end
		records[model] = nil
	end
	pending[model] = nil
end
local function bind(model: Model): boolean
	if not model:IsDescendantOf(workspace) then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local joints = {}
	for _, object in model:GetDescendants() do
		if object:IsA("Motor6D") then
			joints[object.Name] = object
		end
	end
	for _, name in names do
		if not joints[name] then
			return false
		end
	end
	records[model] = {
		Root = root,
		Humanoid = model:FindFirstChildOfClass("Humanoid"),
		Joints = joints,
		Raw = "",
		Packet = nil,
		Phase = 0,
		Airborne = false,
		Landing = 0,
		LastPosition = root.Position,
	}
	pending[model] = nil
	return true
end
function Controller.start()
	if started then
		return
	end
	started = true
	local function add(object: Instance)
		if object:IsA("Model") then
			pending[object] = true
		end
	end
	for _, tag in { "Enfleshed", "EnemyAnimatedCorpse" } do
		table.insert(connections, Collection:GetInstanceAddedSignal(tag):Connect(add))
		table.insert(
			connections,
			Collection:GetInstanceRemovedSignal(tag):Connect(function(object)
				if object:IsA("Model") then
					release(object)
				end
			end)
		)
		for _, object in Collection:GetTagged(tag) do
			add(object)
		end
	end
	table.insert(
		connections,
		Run.PreSimulation:Connect(function(delta)
			frames += 1
			local now = workspace:GetServerTimeNow()
			for model in pending do
				if not model.Parent then
					pending[model] = nil
				else
					bind(model)
				end
			end
			for model, record in records do
				if not model:IsDescendantOf(workspace) then
					release(model)
					continue
				end
				local raw = model:GetAttribute("EnemyPose")
				if type(raw) ~= "string" then
					continue
				end
				if raw ~= record.Raw then
					local ok, packet = pcall(Http.JSONDecode, Http, raw)
					if ok and type(packet) == "table" and type(packet.State) == "string" then
						record.Raw, record.Packet = raw, packet
					end
				end
				local packet = record.Packet
				if not packet then
					continue
				end
				local dt = math.min(delta, 0.1)
				local root = record.Root
				local scale = model:GetScale()
				local v = root.AssemblyLinearVelocity
				local speed = Vector3.new(v.X, 0, v.Z).Magnitude
				-- Server-owned root replication can arrive in discrete steps. Velocity is
				-- preferred to frame displacement so interpolation does not freeze the gait.
				record.Phase += speed * dt / (3.8 * scale) * math.pi * 2
				local state = if record.Humanoid then record.Humanoid:GetState() else Enum.HumanoidStateType.Dead
				local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
				if record.Airborne and not airborne then
					record.Landing = 1
				end
				record.Airborne = airborne
				record.Landing = math.max(0, record.Landing - dt / 0.18)
				local motion = {
					Phase = record.Phase,
					Speed = speed,
					Airborne = airborne,
					Rising = v.Y > 1,
					Landing = record.Landing,
				}
				local sampled = Animation.sample(packet, motion, now, scale)
				for name, frame in sampled do
					local joint = record.Joints[name]
					-- Strike poses take effect immediately on receipt of the authoritative
					-- Attack phase. Never ease an active strike behind its damage window.
					local snap = packet.State == "Attack" or packet.State == "Flinch" or packet.State == "Dead"
					joint.Transform = if snap then frame else joint.Transform:Lerp(frame, 1 - math.exp(-dt * 28))
					writes += 1
				end
				record.LastPosition = root.Position
			end
		end)
	)
end
function Controller.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for model in records do
		release(model)
	end
	table.clear(pending)
	started = false
end
function Controller.diagnostics(): any
	local count, waiting = 0, 0
	for _ in records do
		count += 1
	end
	for _ in pending do
		waiting += 1
	end
	return { Started = started, Active = count, Pending = waiting, Frames = frames, JointWrites = writes }
end
return Controller
