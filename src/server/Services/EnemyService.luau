--!strict

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Config = Sandbox.Enemy
local Damage = require(script.Parent.DamageService)
local HitDetection = require(script.Parent.HitDetectionService)
local Enemy = {}
local lightHitReactions: { [Humanoid]: () -> () } = {}

-- One synchronous reaction for this basic enemy; no status-effect bus or registry of effects.
function Enemy.onLightHit(humanoid: Humanoid)
	local react = lightHitReactions[humanoid]
	if react then
		react()
	end
end

type State = "Idle" | "Chase" | "Telegraph" | "Attack" | "Recover" | "Flinch" | "Dead"

-- One local placeholder rig, with no asset request, animation package, or spawn manager.
local function createRig(
	position: Vector3,
	container: Folder,
	collisionGroup: string
): (Model, Humanoid, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "Stage1Enfleshed"
	local function part(name: string, size: Vector3, offset: Vector3): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Size = size
		result.Position = position + offset
		result.Color = Color3.fromRGB(130, 65, 70)
		result.CanCollide = false
		result.CanTouch = false
		result.Massless = name ~= "HumanoidRootPart"
		result.CollisionGroup = Config.VisualCollisionGroup
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
	local hull = Instance.new("Part")
	hull.Name = "CollisionHull"
	hull.Shape = Enum.PartType.Cylinder
	-- Cylinders run along local X; rotate upright. The flat cap is above normal jump height.
	hull.Size = Vector3.new(Config.CollisionHull.Height, Config.CollisionHull.Diameter, Config.CollisionHull.Diameter)
	hull.CFrame = root.CFrame * CFrame.new(0, Config.CollisionHull.CenterOffsetY, 0) * CFrame.Angles(0, 0, math.pi / 2)
	hull.Transparency = 1
	hull.Massless = true
	hull.CanCollide = true
	hull.CanTouch = false
	hull.CollisionGroup = collisionGroup
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.7, Config.CollisionHull.Friction, 0, 100, 100)
	hull.Parent = model
	local hullWeld = Instance.new("WeldConstraint")
	hullWeld.Part0 = root
	hullWeld.Part1 = hull
	hullWeld.Parent = hull
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
	model.Parent = container
	root:SetNetworkOwner(nil)
	return model, humanoid, root, label
end

export type Handle = {
	Model: Model,
	Update: (number) -> (),
	IsAlive: () -> boolean,
	Destroy: () -> (),
	TakePathJob: () -> (() -> ())?,
	HasPendingPath: () -> boolean,
}

function Enemy.create(
	position: Vector3,
	container: Folder,
	collisionGroup: string,
	thinkOffset: number,
	hitInterval: number
): Handle
	local model, humanoid, root, label = createRig(position, container, collisionGroup)
	local state: State = "Idle"
	local target: Player? = nil
	local nextThink = os.clock() + thinkOffset
	local nextHit = 0
	local activeAt, activeUntil, recoverUntil = 0, 0, 0
	local flinchUntil = 0
	local flinchAfterAttack = false
	local resumeRecovery = false
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
	local pendingPath: (() -> ())? = nil
	local nextPath = 0
	local progressPosition = root.Position
	local progressAt = 0
	local stuck = false

	local function clearPath()
		pendingPath = nil
		model:SetAttribute("PathQueued", false)
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
		label.Text = string.format(
			"%s  %d/%d\n%s",
			model:GetAttribute("SandboxLabel") or "Stage 1 Enfleshed",
			humanoid.Health,
			humanoid.MaxHealth,
			state
		)
		model:SetAttribute("SandboxState", state)
	end

	local function setState(value: State)
		if state ~= value then
			state = value
			display()
		end
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
		params.FilterDescendantsInstances = { container, character }
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
		lightHitReactions[humanoid] = nil
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
		-- The temporary coordinator retires this handle and removes the corpse.
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanCollide = false
				item.CanQuery = false
			end
		end
	end

	local function beginFlinch(now: number, keepRecovery: boolean)
		clearPath()
		clearDebug()
		stopMoving()
		humanoid.AutoRotate = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		activeAt, activeUntil = 0, 0
		hitTargets = {}
		flinchAfterAttack = false
		resumeRecovery = keepRecovery
		if not keepRecovery then
			recoverUntil = 0
		end
		flinchUntil = now + Config.LightHitFlinch
		setState("Flinch")
	end

	lightHitReactions[humanoid] = function()
		if state == "Dead" or humanoid.Health <= 0 or Config.LightHitFlinch <= 0 then
			return
		end
		local now = os.clock()
		local committed = (state == "Telegraph" or state == "Attack") and now >= activeAt
		if committed and now < activeUntil then
			-- An already active strike finishes; it cannot be retroactively dodged by hitting.
			flinchAfterAttack = true
			return
		end
		beginFlinch(now, state == "Recover" or committed or (state == "Flinch" and resumeRecovery))
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
		nextHit = activeAt
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

	local function requestPath(_other: BasePart, now: number)
		if computing or pendingPath or now < nextPath then
			return
		end
		-- Keep a usable old route while waiting for the shared round-robin budget.
		pendingPath = function()
			local other = targetRoot(target)
			if state ~= "Chase" or not other then
				computing = false
				return
			end
			local token = generation
			local destination = other.Position
			local requestedTarget = target
			nextPath = os.clock() + nav.RepathInterval
			local candidate = PathfindingService:CreatePath({
				AgentRadius = nav.AgentRadius,
				AgentHeight = nav.AgentHeight,
				AgentCanJump = nav.AgentCanJump,
				WaypointSpacing = nav.WaypointSpacing,
			})
			local ok = pcall(function()
				candidate:ComputeAsync(root.Position, destination)
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
			clearPath()
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
		end
		model:SetAttribute("PathQueued", true)
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
		local direct = workspace:Blockcast(
			root.CFrame * CFrame.new(0, Config.CollisionHull.CenterOffsetY, 0),
			nav.SweepSize,
			travel,
			rayParams(other.Parent :: Instance)
		) == nil
		if direct and not stuck then
			if path or computing or pendingPath then
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

	table.insert(connections, model:GetAttributeChangedSignal("SandboxLabel"):Connect(display))
	table.insert(connections, humanoid.HealthChanged:Connect(display))
	table.insert(connections, humanoid.Died:Connect(die))
	table.insert(connections, model.Destroying:Connect(die))
	local function update(now: number)
		if humanoid.Health <= 0 or not model:IsDescendantOf(workspace) then
			die()
			return
		end
		-- Timers are cheap; hit queries are capped separately from staggered navigation.
		if state == "Telegraph" or state == "Attack" then
			if now >= activeUntil then
				clearDebug()
				if flinchAfterAttack then
					beginFlinch(now, true)
				else
					setState("Recover")
				end
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
				if now < nextHit then
					return
				end
				nextHit = now + hitInterval
				for _, victim in
					HitDetection.find(model, committedOrigin, committedBox, Config.HitboxSize, {
						OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
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
		if state == "Flinch" then
			if now < flinchUntil then
				return
			end
			-- Reuse release logic below; preserve an existing recovery instead of shortening it.
			if not resumeRecovery then
				recoverUntil = 0
			end
			setState("Recover")
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
	end
	display()
	return {
		Model = model,
		Update = update,
		IsAlive = function(): boolean
			return state ~= "Dead"
		end,
		HasPendingPath = function(): boolean
			return pendingPath ~= nil
		end,
		TakePathJob = function(): (() -> ())?
			local job = pendingPath
			if not job or state == "Dead" then
				return nil
			end
			pendingPath = nil
			model:SetAttribute("PathQueued", false)
			computing = true
			return function()
				local ok, err = pcall(job)
				computing = false -- Release even if creating or processing a path raises an error.
				if not ok then
					error(tostring(err))
				end
			end
		end,
		Destroy = function()
			die()
			model:Destroy()
		end,
	}
end

return Enemy
