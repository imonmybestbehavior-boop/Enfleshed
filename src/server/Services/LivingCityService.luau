--!strict
-- A bounded population, one update loop and one shared navigation computation.
local Collection = game:GetService("CollectionService")
local Pathfinding = game:GetService("PathfindingService")
local Run = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Configuration.CityLife).NPCs
local Plan = require(Shared.Configuration.PhaseATopology)
local Spawn = require(script.Parent.WorldSpawnService)
local Damage = require(script.Parent.DamageService)
local PopulationLayout = require(script.Parent.CityPopulationLayout)
local City = {}
local entries, mobilizations = {}, {}
local folder, computing, cursor, nextPathStart = nil, false, 0, 0

local function groundedAround(point)
	for _, offset in
		{ Vector3.zero, Vector3.new(5, 0, 0), Vector3.new(-5, 0, 0), Vector3.new(0, 0, 5), Vector3.new(0, 0, -5) }
	do
		local result = Spawn.ground(point + offset, 5, 2.5)
		if result then
			return result
		end
	end
	return nil
end
local function rig(name, role, position)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Role", role)
	local function part(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, CFrame.new(position + offset)
		p.Color, p.Material = color, Enum.Material.Fabric
		p.CanCollide, p.CanTouch = false, false
		p.Parent = model
		return p
	end
	local skin, cloth = Color3.fromRGB(157, 120, 91), Color3.fromRGB(92, 83, 67)
	if role == "Guard" or role == "Patrol" then
		cloth = Color3.fromRGB(64, 74, 71)
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, cloth)
	root.Transparency, root.CanCollide = 1, true
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.zero, cloth)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0), skin)
	local function joint(a, b, name)
		local motor = Instance.new("Motor6D")
		motor.Name, motor.Part0, motor.Part1 = name, a, b
		motor.C0, motor.Parent = a.CFrame:ToObjectSpace(b.CFrame), a
	end
	joint(root, torso, "RootJoint")
	joint(torso, head, "Neck")
	for _, side in { -1, 1 } do
		local prefix = if side < 0 then "Left" else "Right"
		joint(
			torso,
			part(prefix .. " Arm", Vector3.new(1, 2, 1), Vector3.new(side * 1.5, 0, 0), cloth),
			prefix .. " Shoulder"
		)
		joint(
			torso,
			part(prefix .. " Leg", Vector3.new(1, 2, 1), Vector3.new(side * 0.5, -2, 0), cloth),
			prefix .. " Hip"
		)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth, humanoid.Health, humanoid.WalkSpeed = Config.Health, Config.Health, Config.Speed
	humanoid.Parent = model
	model.PrimaryPart, model.Parent = root, folder
	root:SetNetworkOwner(nil)
	Collection:AddTag(model, "CityHuman")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText, prompt.ActionText = name .. " · " .. role, "Listen"
	prompt.KeyboardKeyCode, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = Enum.KeyCode.K, 8, true
	prompt.Parent = head
	prompt.Triggered:Connect(function(player)
		if humanoid.Health <= 0 or not player:GetAttribute("OpeningComplete") then
			return
		end
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude <= 10 then
			player:SetAttribute(
				"CityRemark",
				if role == "Guard" or role == "Patrol"
					then "Stay alert. We hold these streets together."
					else "Work goes on. Keep clear of the lower passages."
			)
		end
	end)
	return model, humanoid, root
end
function City.create(name, role, nodes, temporary, home)
	if not folder or #entries >= Config.MaxPopulation then
		return nil
	end
	local position = groundedAround(home or Plan.Nodes[nodes[1]])
	if not position then
		return nil
	end
	local model, humanoid, root = rig(name, role, position)
	local entry = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Role = role,
		Nodes = nodes,
		Index = 2,
		Home = position,
		NextPath = 0,
		NextHit = 0,
		NextIdle = 0,
		Temporary = temporary,
		Finished = false,
		Path = nil,
		Waypoint = 1,
	}
	table.insert(entries, entry)
	return entry
end
function City.remove(entry)
	if not entry then
		return
	end
	entry.Removed = true
	entry.Model:Destroy()
end
function City.near(point, guardsOnly)
	local nearest, distance = nil, math.huge
	for _, entry in entries do
		if
			not entry.Removed
			and entry.Humanoid.Health > 0
			and (not guardsOnly or entry.Role == "Guard" or entry.Role == "Patrol")
		then
			local d = (entry.Root.Position - point).Magnitude
			if d < distance then
				nearest, distance = entry, d
			end
		end
	end
	return nearest, distance
end
function City.mobilize(id, defense, retreat)
	mobilizations[id] = { Defense = defense, Retreat = retreat }
end
function City.release(id)
	mobilizations[id] = nil
end
local function visible(a, b, exclude)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances, params.RespectCanCollide = exclude, true
	return workspace:Raycast(a, b - a, params) == nil
end
function City.start()
	if folder or not Config.Enabled then
		return
	end
	folder = Instance.new("Folder")
	folder.Name, folder.Parent = "LivingCity", workspace
	local roster = {}
	local fronts = {}
	local geometry = workspace:FindFirstChild("LowerLayerGraybox")
	local markers = geometry and geometry:FindFirstChild("StreetFronts")
	if markers then
		local ordered = markers:GetChildren()
		table.sort(ordered, function(a, b)
			return a.Name < b.Name
		end)
		for _, marker in ordered do
			table.insert(fronts, {
				Kind = marker:GetAttribute("Archetype"),
				Enterable = marker:GetAttribute("Enterable"),
				Home = marker.Value,
			})
		end
	end
	local target = math.min(
		Config.MaxPopulation - Config.EventReserve,
		math.floor(Config.AmbientTarget * math.max(0, Config.Scale))
	)
	local definitions = PopulationLayout.build(Plan, Config.Roster, fronts, target)
	for i = 1, math.min(target, #definitions) do
		table.insert(roster, { Definition = definitions[i], Retry = 0 })
	end
	folder:SetAttribute("AmbientTarget", #roster)
	local updateCursor = 0
	local nextTick = 0
	Run.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextTick then
			return
		end
		nextTick = now + Config.Tick
		local spawnAttempts = 0
		for _, slot in roster do
			if slot.Entry and (slot.Entry.Removed or slot.Entry.Humanoid.Health <= 0) then
				slot.Entry = nil
				slot.Retry = now + Config.RespawnSeconds
			end
			if not slot.Entry and now >= slot.Retry and spawnAttempts < Config.SpawnAttemptsPerTick then
				spawnAttempts += 1
				local d = slot.Definition
				local home = if d.Position then Vector3.new(d.Position.X, d.Position.Y, d.Position.Z) else nil
				slot.Entry = City.create(d.Name, d.Role, d.Nodes, false, home)
				if slot.Entry then
					slot.Entry.Model:SetAttribute("District", d.District or "Authored")
				end
				slot.Retry = now + Config.RespawnSeconds
			end
		end
		local threats = Collection:GetTagged("Enfleshed")
		for i = #entries, 1, -1 do
			if entries[i].Removed or not entries[i].Model.Parent then
				table.remove(entries, i)
			end
		end
		local living = 0
		for _, entry in entries do
			if entry.Humanoid.Health > 0 then
				living += 1
			end
		end
		folder:SetAttribute("LivingCount", living)
		for _ = 1, math.min(Config.UpdatesPerTick, #entries) do
			updateCursor = updateCursor % #entries + 1
			local e = entries[updateCursor]
			if e.Removed or not e.Model.Parent then
				continue
			end
			if e.Humanoid.Health <= 0 then
				e.DeadAt = e.DeadAt or now
				if now - e.DeadAt > 4 then
					City.remove(e)
				end
				continue
			end
			local threat, distance = nil, Config.DangerRadius
			for _, model in threats do
				local h = model:FindFirstChildOfClass("Humanoid")
				local r = model:FindFirstChild("HumanoidRootPart")
				if h and h.Health > 0 and r then
					local d = (r.Position - e.Root.Position).Magnitude
					if d < distance and visible(e.Root.Position, r.Position, { e.Model, model }) then
						threat, distance = model, d
					end
				end
			end
			local guard = e.Role == "Guard" or e.Role == "Patrol"
			local goal = nil
			e.Humanoid.WalkSpeed = Config.Speed
			if threat then
				local r = threat.HumanoidRootPart
				if guard then
					goal = if distance <= Config.GuardRange then e.Root.Position else r.Position
					if distance <= Config.GuardRange and now >= e.NextHit then
						e.NextHit = now + Config.GuardCooldown
						Damage.apply(e.Model, threat:FindFirstChildOfClass("Humanoid"), Config.GuardDamage)
					end
				else
					e.Humanoid.WalkSpeed = Config.FleeSpeed
					local away = e.Root.Position - r.Position
					if away.Magnitude > 0 then
						goal = groundedAround(e.Root.Position + away.Unit * 16)
					end
					goal = goal or e.Home
				end
			else
				for _, orders in mobilizations do
					if (e.Home - orders.Defense).Magnitude < 350 then
						goal = (if guard then orders.Defense else orders.Retreat) + Vector3.new(0, 3, 0)
						break
					end
				end
				if not goal then
					if e.Nodes[1] == e.Nodes[2] then
						if e.Role == "Shopkeeper" or e.Role == "Guard" then
							goal = e.Home
						else
							if now >= e.NextIdle then
								e.NextIdle = now + 8
								e.IdleGoal = groundedAround(
									e.Home + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
								) or e.Home
							end
							goal = e.IdleGoal
						end
					elseif not e.Finished then
						goal = Plan.Nodes[e.Nodes[e.Index]] + Vector3.new(0, 3, 0)
						if (goal - e.Root.Position).Magnitude < 7 then
							e.Index += 1
							e.Path = nil
							if e.Index > #e.Nodes then
								if e.Temporary then
									e.Finished = true
								else
									e.Index = 1
								end
							end
						end
					end
				end
			end
			if e.Goal and goal and (e.Goal - goal).Magnitude > 12 then
				e.Path = nil
			end
			e.Goal = goal
			if not goal or (goal - e.Root.Position).Magnitude < 3 then
				e.NeedPath = false
				e.Humanoid:MoveTo(e.Root.Position)
				continue
			end
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { folder }
			params.RespectCanCollide = true
			-- A broad sweep prevents repeated straight-line commands into door frames.
			local direction = goal - e.Root.Position
			local blocked = workspace:Blockcast(CFrame.new(e.Root.Position), Vector3.new(2, 3, 2), direction, params)
			if not blocked and math.abs(direction.Y) < 4 then
				e.Path = nil
				e.NeedPath = false
				e.Humanoid:MoveTo(goal)
			else
				e.NeedPath = true
				if e.Path then
					local waypoint = e.Path[e.Waypoint]
					if waypoint and (waypoint.Position - e.Root.Position).Magnitude < 5 then
						e.Waypoint += 1
						waypoint = e.Path[e.Waypoint]
					end
					if waypoint then
						e.Humanoid.Jump = waypoint.Action == Enum.PathWaypointAction.Jump
						e.Humanoid:MoveTo(waypoint.Position)
					end
				end
			end
		end
		if not computing and now >= nextPathStart and #entries > 0 then
			for _ = 1, #entries do
				cursor = cursor % #entries + 1
				local e = entries[cursor]
				if e.NeedPath and e.Goal and now >= e.NextPath and e.Humanoid.Health > 0 and not e.Removed then
					computing = true
					nextPathStart = now + 1 / Config.PathStartsPerSecond
					e.NextPath = now + Config.RepathSeconds
					local goal = e.Goal
					task.spawn(function()
						local path = Pathfinding:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
						local ok = pcall(function()
							path:ComputeAsync(e.Root.Position, goal)
						end)
						if
							ok
							and not e.Removed
							and e.Humanoid.Health > 0
							and e.Goal
							and (e.Goal - goal).Magnitude < 10
							and path.Status == Enum.PathStatus.Success
						then
							e.Path = path:GetWaypoints()
							e.Waypoint = 2
						end
						path:Destroy()
						computing = false
					end)
					break
				end
			end
		end
	end)
end
return City
