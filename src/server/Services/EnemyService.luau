--!strict

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox")).Enemy
local Damage = require(script.Parent.DamageService)
local HitDetection = require(script.Parent.HitDetectionService)
local Enemy = {}

type State = "Idle" | "Chase" | "Telegraph" | "Attack" | "Recover" | "Dead"

-- One local placeholder rig, with no asset request, animation package, or spawn manager.
local function createRig(): (Model, Humanoid, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "Stage1Enfleshed"
	local function part(name: string, size: Vector3, offset: Vector3): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Size = size
		result.Position = Config.Position + offset
		result.Color = Color3.fromRGB(130, 65, 70)
		result.CanCollide = name == "Torso"
		result.Massless = name ~= "HumanoidRootPart"
		result.Parent = model
		return result
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.zero)
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 1.5, 0))
	local function joint(name: string, parent: BasePart, limb: BasePart)
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = parent
		motor.Part1 = limb
		motor.C0 = parent.CFrame:ToObjectSpace(limb.CFrame)
		motor.Parent = parent
	end
	joint("RootJoint", root, torso)
	joint("Neck", torso, head)
	joint("Left Shoulder", torso, part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0)))
	joint("Right Shoulder", torso, part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0)))
	joint("Left Hip", torso, part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0)))
	joint("Right Hip", torso, part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0)))
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = 0
	humanoid.MaxHealth = Config.Health
	humanoid.Health = Config.Health
	humanoid.WalkSpeed = Config.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 48)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextSize = 16
	label.Parent = gui
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	return model, humanoid, root, label
end

function Enemy.start()
	local model, humanoid, root, label = createRig()
	local state: State = "Idle"
	local target: Player? = nil
	local nextThink = 0
	local activeAt, activeUntil, recoverUntil = 0, 0, 0
	local committedOrigin = root.CFrame
	local committedBox = root.CFrame
	local hitTargets: { [Humanoid]: boolean } = {}
	local debugBox: Part? = nil
	local debugHighlight: Highlight? = nil
	local connections: { RBXScriptConnection } = {}
	local nav = Config.Navigation
	local path: Path? = nil
	local blockedConnection: RBXScriptConnection? = nil
	local waypoints: { PathWaypoint } = {}
	local waypointIndex = 1
	local pathGoal: Vector3? = nil
	local generation = 0
	local computing = false
	local nextPath = 0
	local progressPosition = root.Position
	local progressAt = 0
	local stuck = false

	local function clearPath()
		generation += 1 -- Any yielding ComputeAsync result from an earlier state is obsolete.
		if blockedConnection then
			blockedConnection:Disconnect()
			blockedConnection = nil
		end
		if path then
			path:Destroy()
			path = nil
		end
		waypoints = {}
		pathGoal = nil
		waypointIndex = 1
	end

	local function clearDebug()
		if debugBox then
			debugBox:Destroy()
			debugBox = nil
		end
		if debugHighlight then
			debugHighlight:Destroy()
			debugHighlight = nil
		end
	end

	local function display()
		label.Text = string.format("Stage 1 Enfleshed  %d/%d\n%s", humanoid.Health, humanoid.MaxHealth, state)
		model:SetAttribute("SandboxState", state)
	end

	local function setState(value: State)
		state = value
		display()
	end

	local function stopMoving()
		humanoid:MoveTo(root.Position)
		humanoid:Move(Vector3.zero)
	end

	local function targetRoot(player: Player?): BasePart?
		local character = if player and player.Parent == Players then player.Character else nil
		local health = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local result = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if health and health.Health > 0 and result and result:IsA("BasePart") and result:IsDescendantOf(workspace) then
			return result
		end
		return nil
	end

	local function rayParams(character: Instance): RaycastParams
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { model, character }
		params.RespectCanCollide = true
		return params
	end

	local function visible(other: BasePart): boolean
		return workspace:Raycast(root.Position, other.Position - root.Position, rayParams(other.Parent :: Instance))
			== nil
	end

	local function die()
		if state == "Dead" then
			return
		end
		setState("Dead")
		clearPath()
		clearDebug()
		target = nil
		hitTargets = {}
		stopMoving()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		for _, connection in connections do
			connection:Disconnect()
		end
		-- The inert corpse stays for inspection. Restart Play to create a new enemy.
	end

	local function beginAttack(other: BasePart, now: number)
		clearPath()
		stopMoving()
		humanoid.AutoRotate = false
		local facing = Vector3.new(other.Position.X, root.Position.Y, other.Position.Z)
		if (facing - root.Position).Magnitude > 0 then
			root.CFrame = CFrame.lookAt(root.Position, facing)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true -- Prevent contact physics from moving the committed strike.
		committedOrigin = root.CFrame
		committedBox = committedOrigin * CFrame.new(0, 0, -Config.HitboxOffset)
		activeAt = now + Config.Telegraph
		activeUntil = activeAt + Config.Active
		recoverUntil = activeUntil + Config.Recovery
		hitTargets = {}
		setState("Telegraph")
		if Config.DebugTelegraph then
			local box = Instance.new("Part")
			box.Name = "TemporaryEnemyAttackDebug"
			box.Size = Config.HitboxSize
			box.CFrame = committedBox
			box.Anchored = true
			box.CanCollide = false
			box.CanTouch = false
			box.CanQuery = false
			box.Material = Enum.Material.Neon
			box.Color = Color3.fromRGB(255, 170, 40)
			box.Transparency = 0.7
			box.Parent = workspace
			debugBox = box
			local highlight = Instance.new("Highlight")
			highlight.Name = "TemporaryTelegraphDebug"
			highlight.Adornee = model
			highlight.FillColor = box.Color
			highlight.FillTransparency = 0.5
			highlight.Parent = model
			debugHighlight = highlight
		end
	end

	local function requestPath(other: BasePart, now: number)
		if computing or now < nextPath then
			return
		end
		clearPath()
		computing = true
		nextPath = now + nav.RepathInterval
		local token = generation
		local destination = other.Position
		local start = root.Position
		local requestedTarget = target
		task.spawn(function()
			local candidate = PathfindingService:CreatePath({
				AgentRadius = nav.AgentRadius,
				AgentHeight = nav.AgentHeight,
				AgentCanJump = nav.AgentCanJump,
				WaypointSpacing = nav.WaypointSpacing,
			})
			local ok = pcall(function()
				candidate:ComputeAsync(start, destination)
			end)
			computing = false
			local currentRoot = targetRoot(target)
			if
				not ok
				or candidate.Status ~= Enum.PathStatus.Success
				or state ~= "Chase"
				or token ~= generation
				or target ~= requestedTarget
				or not currentRoot
				or (currentRoot.Position - destination).Magnitude > nav.TargetMoveThreshold
			then
				candidate:Destroy()
				return
			end
			path = candidate
			pathGoal = destination
			waypoints = candidate:GetWaypoints()
			waypointIndex = 2
			blockedConnection = candidate.Blocked:Connect(function(index)
				if index >= waypointIndex then
					clearPath()
					stopMoving()
				end
			end)
		end)
	end

	local function chase(other: BasePart, now: number)
		if (root.Position - progressPosition).Magnitude >= nav.ProgressDistance then
			progressPosition = root.Position
			progressAt = now
			stuck = false
		elseif now - progressAt >= nav.StuckTime then
			stuck = true
			clearPath()
			progressAt = now
		end
		local travel = other.Position - root.Position
		local direct = workspace:Blockcast(root.CFrame, nav.SweepSize, travel, rayParams(other.Parent :: Instance))
			== nil
		if direct and not stuck then
			if path or computing then
				clearPath()
			end
			humanoid:MoveTo(other.Position)
			return
		end
		if not pathGoal or (other.Position - pathGoal).Magnitude >= nav.TargetMoveThreshold then
			requestPath(other, now)
		end
		local waypoint = waypoints[waypointIndex]
		while waypoint do
			local delta = waypoint.Position - root.Position
			if Vector3.new(delta.X, 0, delta.Z).Magnitude > nav.WaypointTolerance then
				break
			end
			waypointIndex += 1
			waypoint = waypoints[waypointIndex]
		end
		if waypoint then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)
		else
			stopMoving()
			if path then
				clearPath()
			end
			requestPath(other, now)
		end
	end

	table.insert(connections, humanoid.HealthChanged:Connect(display))
	table.insert(connections, humanoid.Died:Connect(die))
	table.insert(connections, model.Destroying:Connect(die))
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function()
			if humanoid.Health <= 0 or not model:IsDescendantOf(workspace) then
				die()
				return
			end
			local now = os.clock()
			-- Attack sampling runs every server heartbeat; navigation uses the slower think rate.
			if state == "Telegraph" or state == "Attack" then
				if now >= activeUntil then
					clearDebug()
					setState("Recover")
				elseif now >= activeAt then
					if state ~= "Attack" then
						setState("Attack")
						if debugBox then
							debugBox.Color = Color3.fromRGB(255, 55, 55)
						end
						if debugHighlight then
							debugHighlight.FillColor = Color3.fromRGB(255, 55, 55)
						end
					end
					for _, victim in
						HitDetection.find(model, committedOrigin, committedBox, Config.HitboxSize, {
							RequireLineOfSight = true,
							CanTarget = function(character)
								return Players:GetPlayerFromCharacter(character) ~= nil
							end,
						})
					do
						if not hitTargets[victim] then
							hitTargets[victim] = true
							Damage.apply(model, victim, Config.Damage)
						end
					end
				end
				return
			end
			if state == "Recover" then
				if now < recoverUntil then
					return
				end
				root.Anchored = false
				root:SetNetworkOwner(nil)
				humanoid.AutoRotate = true
				progressPosition = root.Position
				progressAt = now
				setState("Chase")
			end
			if now < nextThink then
				return
			end
			nextThink = now + Config.ThinkInterval
			local other = targetRoot(target)
			if not other or (other.Position - root.Position).Magnitude > Config.DisengageRange then
				target = nil
				other = nil
				clearPath()
				stopMoving()
				setState("Idle")
				local nearest = Config.DetectionRange
				for _, player in Players:GetPlayers() do
					local candidate = targetRoot(player)
					if candidate then
						local distance = (candidate.Position - root.Position).Magnitude
						if distance <= nearest and visible(candidate) then
							nearest = distance
							target = player
							other = candidate
						end
					end
				end
				if other then
					progressAt = now
					progressPosition = root.Position
					stuck = false
					setState("Chase")
				end
			end
			if other then
				if (other.Position - root.Position).Magnitude <= Config.AttackRange and visible(other) then
					beginAttack(other, now)
				else
					chase(other, now)
				end
			end
		end)
	)
	display()
end

return Enemy
