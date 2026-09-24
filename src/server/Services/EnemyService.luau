--!strict

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Config = Sandbox.Enemy
local Damage = require(script.Parent.DamageService)
local HitDetection = require(script.Parent.HitDetectionService)
local AttackSelector = require(script.Parent.NascentAttackSelector)
local Enemy = {}
local hitReactions: { [Humanoid]: (string) -> () } = {}

-- One synchronous reaction for this basic enemy; no status-effect bus or registry of effects.
function Enemy.onLightHit(humanoid: Humanoid)
	local react = hitReactions[humanoid]
	if react then
		react("Minor")
	end
end

function Enemy.onHit(humanoid: Humanoid, strength: string)
	local react = hitReactions[humanoid]
	if react then
		react(strength)
	end
end

type State = "Idle" | "Chase" | "Telegraph" | "Attack" | "Recover" | "Vulnerable" | "Flinch" | "Dead"

-- One local placeholder rig, with no asset request, animation package, or spawn manager.
local function createRig(
	position: Vector3,
	container: Folder,
	collisionGroup: string
): (Model, Humanoid, BasePart, TextLabel, (string, number) -> ())
	local model = Instance.new("Model")
	model.Name = "Stage1Enfleshed"
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3?): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Size = size
		result.Position = position + offset
		result.Color = color or Color3.fromRGB(130, 65, 70)
		result.Material = Enum.Material.SmoothPlastic
		result.CanCollide = false
		result.CanTouch = false
		result.Massless = name ~= "HumanoidRootPart"
		result.CollisionGroup = Config.VisualCollisionGroup
		result.Parent = model
		return result
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero)
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(3.2, 3.7, 1.75), Vector3.new(0, 0.3, 0), Color3.fromRGB(94, 42, 52))
	local head = part("Head", Vector3.new(1.9, 2.15, 1.8), Vector3.new(-0.18, 2.75, -0.35), Color3.fromRGB(145, 72, 76))
	head.Shape = Enum.PartType.Ball
	local function joint(name: string, parent: BasePart, limb: BasePart): Motor6D
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = parent
		motor.Part1 = limb
		motor.C0 = parent.CFrame:ToObjectSpace(limb.CFrame)
		motor.Parent = parent
		return motor
	end
	local rootJoint = joint("RootJoint", root, torso)
	local neck = joint("Neck", torso, head)
	local leftShoulder = joint(
		"Left Shoulder",
		torso,
		part("Left Arm", Vector3.new(1.45, 3.7, 1.3), Vector3.new(-2.25, 0.05, -0.15), Color3.fromRGB(121, 55, 71))
	)
	local rightShoulder = joint(
		"Right Shoulder",
		torso,
		part("Right Arm", Vector3.new(1.8, 4.5, 1.55), Vector3.new(2.4, -0.25, -0.5), Color3.fromRGB(151, 61, 67))
	)
	local leftHip = joint(
		"Left Hip",
		torso,
		part("Left Leg", Vector3.new(1.2, 3, 1.2), Vector3.new(-0.65, -2.9, 0), Color3.fromRGB(90, 42, 55))
	)
	local rightHip = joint(
		"Right Hip",
		torso,
		part("Right Leg", Vector3.new(1.2, 3, 1.2), Vector3.new(0.65, -2.9, 0), Color3.fromRGB(90, 42, 55))
	)
	-- The humanoid joints remain the animatable foundation. These welded growths
	-- only distort the silhouette into an asymmetrical, once-human Nascent.
	local function growth(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
		local piece = part(name, size, Vector3.zero, color)
		piece.Shape = shape or Enum.PartType.Block
		piece.CFrame = torso.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = piece
		weld.Parent = piece
	end
	growth(
		"ShoulderGrowth",
		Vector3.new(2.25, 1.45, 2.1),
		CFrame.new(-1.35, 1.05, 0.15),
		Color3.fromRGB(112, 49, 62),
		Enum.PartType.Ball
	)
	growth(
		"RibGrowth",
		Vector3.new(1.15, 2.4, 0.75),
		CFrame.new(1.5, -0.2, -0.6) * CFrame.Angles(0, 0, -0.35),
		Color3.fromRGB(128, 57, 62)
	)
	growth(
		"BackMass",
		Vector3.new(2.4, 2.7, 1.25),
		CFrame.new(0.5, 0.1, 1.1) * CFrame.Angles(0.2, 0.25, 0),
		Color3.fromRGB(69, 31, 42),
		Enum.PartType.Ball
	)
	growth(
		"JawGrowth",
		Vector3.new(1.4, 0.65, 1.1),
		CFrame.new(-0.1, 1.45, -0.85),
		Color3.fromRGB(173, 83, 83),
		Enum.PartType.Ball
	)
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
	local function pose(
		state: string,
		now: number,
		attack: string,
		step: number,
		desperate: boolean,
		majorFlinch: boolean
	)
		local breath = math.sin(now * (if desperate then 6 else 3))
		rootJoint.Transform = CFrame.new(0, breath * 0.055, 0.12) * CFrame.Angles(-0.16, 0, 0)
		neck.Transform = CFrame.Angles(0.18, breath * 0.1, -0.08)
		leftShoulder.Transform = CFrame.Angles(0.15, 0, 0.28)
		rightShoulder.Transform = CFrame.Angles(0.32, 0, -0.34)
		leftHip.Transform = CFrame.new()
		rightHip.Transform = CFrame.new()
		if state == "Chase" then
			local stride = math.sin(now * (if desperate then 13 else 10)) * 0.72
			rootJoint.Transform *= CFrame.Angles(-0.22, 0, 0)
			leftShoulder.Transform = CFrame.Angles(stride + 0.35, 0, 0.35)
			rightShoulder.Transform = CFrame.Angles(-stride - 0.6, 0, -0.52)
			leftHip.Transform = CFrame.Angles(-stride, 0, 0)
			rightHip.Transform = CFrame.Angles(stride, 0, 0)
		elseif state == "Telegraph" then
			if attack == "PredatoryLunge" then
				rootJoint.Transform = CFrame.new(0, -0.25, 0.45) * CFrame.Angles(0.52, 0, 0)
				leftShoulder.Transform = CFrame.Angles(-1.4, 0, 0.6)
				rightShoulder.Transform = CFrame.Angles(-1.6, 0, -0.7)
			elseif attack == "FrenziedChain" then
				rootJoint.Transform = CFrame.Angles(-0.38, 0, if step % 2 == 0 then -0.2 else 0.2)
				leftShoulder.Transform = CFrame.Angles(-1.05, 0, 0.7)
				rightShoulder.Transform = CFrame.Angles(-0.55, 0, -0.75)
			elseif attack == "MaulingCombination" then
				rootJoint.Transform = CFrame.Angles(-0.34, 0, if step == 3 then 0.25 else -0.16)
				leftShoulder.Transform = CFrame.Angles(-0.75, 0, 0.55)
				rightShoulder.Transform = CFrame.Angles(-1.1, 0, -0.55)
			else
				rootJoint.Transform = CFrame.Angles(-0.28, 0, 0)
				leftShoulder.Transform = CFrame.Angles(-0.65, 0, 0.45)
				rightShoulder.Transform = CFrame.Angles(-1.3, 0, -0.5)
			end
		elseif state == "Attack" then
			rootJoint.Transform = CFrame.new(0, 0, -0.25) * CFrame.Angles(-0.28, 0, 0)
			if attack == "FrenziedChain" then
				if step == 1 then
					rightShoulder.Transform = CFrame.Angles(1.5, 0, -0.6)
				elseif step == 2 then
					leftShoulder.Transform = CFrame.Angles(1.35, 0, 0.75)
				elseif step == 3 then
					rightShoulder.Transform = CFrame.Angles(1.1, 0, 0.8)
				else
					rootJoint.Transform *= CFrame.Angles(-0.28, 0, 0.35)
					leftShoulder.Transform = CFrame.Angles(1.5, 0, 1)
					rightShoulder.Transform = CFrame.Angles(1.55, 0, -0.8)
				end
			elseif attack == "PredatoryLunge" then
				rootJoint.Transform = CFrame.new(0, 0.15, -0.5) * CFrame.Angles(-0.55, 0, 0)
				leftShoulder.Transform = CFrame.Angles(1.2, 0, 0.6)
				rightShoulder.Transform = CFrame.Angles(1.35, 0, -0.7)
			elseif attack == "MaulingCombination" then
				leftShoulder.Transform = CFrame.Angles(if step == 2 then 0.55 else 1.15, 0, 0.8)
				rightShoulder.Transform = CFrame.Angles(if step == 3 then 1.65 else 0.85, 0, -0.8)
			else
				rightShoulder.Transform = CFrame.Angles(1.35, 0, -0.35)
				leftShoulder.Transform = CFrame.Angles(0.75, 0, 0.42)
			end
		elseif state == "Vulnerable" then
			rootJoint.Transform = CFrame.new(0, -0.3, 0.38) * CFrame.Angles(0.48, 0, 0.35)
			leftShoulder.Transform = CFrame.Angles(0.9, 0, 1.1)
			rightShoulder.Transform = CFrame.Angles(0.75, 0, -1.15)
		elseif state == "Flinch" then
			rootJoint.Transform =
				CFrame.Angles(if majorFlinch then 0.45 else 0.16, 0, if majorFlinch then -0.45 else -0.16)
			leftShoulder.Transform = CFrame.Angles(0.65, 0, 0.8)
			rightShoulder.Transform = CFrame.Angles(0.65, 0, -0.8)
		elseif state == "Dead" then
			rootJoint.Transform = CFrame.new(0, -1.1, 0.55) * CFrame.Angles(1.25, 0, -0.5)
		end
	end
	return model, humanoid, root, label, pose
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
	local model, humanoid, root, label, pose = createRig(position, container, collisionGroup)
	local state: State = "Idle"
	local target: Player? = nil
	local nextThink = os.clock() + thinkOffset
	local nextHit = 0
	local activeAt, activeUntil, recoverUntil = 0, 0, 0
	local activeAttack: any? = nil
	local attackName = ""
	local attackStep, attackCount = 0, 0
	local attackHit = false
	local attackSerial = 0
	local lastAttack = ""
	local flinchUntil = 0
	local flinchMajor = false
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
	local lastUpdateAt = os.clock()

	local function turnToward(other: BasePart, maxRadians: number, pivotRadians: number?): boolean
		local flatTarget = Vector3.new(other.Position.X, root.Position.Y, other.Position.Z) - root.Position
		if flatTarget.Magnitude < 0.01 then
			return false
		end
		local current = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if current.Magnitude < 0.01 then
			return false
		end
		current = current.Unit
		local desired = flatTarget.Unit
		local signed = math.atan2(current:Cross(desired).Y, math.clamp(current:Dot(desired), -1, 1))
		if pivotRadians and math.abs(signed) >= Config.Turning.PivotAngle then
			maxRadians = math.max(maxRadians, pivotRadians)
		end
		local turn = math.clamp(signed, -maxRadians, maxRadians)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + current) * CFrame.Angles(0, turn, 0)
		return true
	end

	local function combatTurnRate(other: BasePart): number
		local distance = (other.Position - root.Position).Magnitude
		local turning = Config.Turning
		if distance <= turning.VeryCloseDistance then
			return turning.VeryCloseTurnRate
		elseif distance <= turning.CloseCombatDistance then
			return turning.CloseCombatTurnRate
		elseif distance <= turning.MidRangeDistance then
			return turning.MidRangeTurnRate
		end
		return turning.ChaseTurnRate
	end

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
		model:SetAttribute("NascentAttack", attackName)
		model:SetAttribute("NascentVulnerable", state == "Vulnerable")
		model:SetAttribute("NascentDesperate", humanoid.Health / humanoid.MaxHealth <= Config.DesperateHealthFraction)
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
		pose("Dead", os.clock(), attackName, attackStep, false, false)
		hitReactions[humanoid] = nil
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

	local function beginFlinch(now: number, keepRecovery: boolean, duration: number?, major: boolean?)
		clearPath()
		clearDebug()
		stopMoving()
		humanoid.AutoRotate = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
		activeAt, activeUntil = 0, 0
		activeAttack = nil
		hitTargets = {}
		flinchAfterAttack = false
		flinchMajor = major == true
		resumeRecovery = keepRecovery
		if not keepRecovery then
			recoverUntil = 0
		end
		flinchUntil = now + (duration or Config.Reactions.Significant.Flinch)
		setState("Flinch")
	end

	hitReactions[humanoid] = function(strength: string)
		if state == "Dead" or humanoid.Health <= 0 then
			return
		end
		local reaction = Config.Reactions[strength] or Config.Reactions.Minor
		local now = os.clock()
		if state == "Vulnerable" then
			reaction = Config.Reactions.Major
		end
		if reaction.Flinch <= 0 then
			return
		end
		local committed = (state == "Telegraph" or state == "Attack") and now >= activeAt
		if committed and now < activeUntil and strength ~= "Major" then
			-- An already active strike finishes; it cannot be retroactively dodged by hitting.
			flinchAfterAttack = true
			return
		end
		beginFlinch(
			now,
			state == "Recover" or committed or (state == "Flinch" and resumeRecovery),
			reaction.Flinch,
			strength == "Major" or state == "Vulnerable"
		)
	end

	local function beginAttack(other: BasePart, name: string, now: number)
		local attacks = Config.Nascent
		activeAttack = attacks[name]
		if not activeAttack then
			return
		end
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
		attackName = name
		attackStep = 1
		attackCount = activeAttack.Count or 1
		attackHit = false
		attackSerial += 1
		committedOrigin = root.CFrame
		committedBox = committedOrigin * CFrame.new(0, 0, -activeAttack.Offset)
		activeAt = now + activeAttack.Telegraph
		activeUntil = activeAt + activeAttack.Active
		local desperate = humanoid.Health / humanoid.MaxHealth <= Config.DesperateHealthFraction
		recoverUntil = activeUntil
			+ activeAttack.Recovery * (if desperate then Config.Nascent.DesperateRecoveryMultiplier else 1)
		hitTargets = {}
		nextHit = activeAt
		setState("Telegraph")
		if Config.DebugTelegraph and Config.DebugNascent then
			local box = Instance.new("Part")
			box.Name = "TemporaryEnemyAttackDebug"
			box.Size = activeAttack.Size
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

	local function chooseAttack(distance: number): string?
		local desperate = humanoid.Health / humanoid.MaxHealth <= Config.DesperateHealthFraction
		return AttackSelector.choose(Config.Nascent, distance, lastAttack, attackSerial, desperate)
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

	local function chase(other: BasePart, now: number, frameDelta: number)
		local targetDistance = (other.Position - root.Position).Magnitude
		local closeCombat = targetDistance <= Config.Turning.CloseCombatDistance
		humanoid.AutoRotate = not closeCombat
		if closeCombat then
			turnToward(other, combatTurnRate(other) * frameDelta, Config.Turning.PivotTurnRate * frameDelta)
		end
		if targetDistance <= Config.Turning.CloseStandoffDistance + nav.WaypointTolerance then
			-- Holding the intended melee standoff is progress, not a navigation stall.
			progressPosition = root.Position
			progressAt = now
			stuck = false
		elseif (root.Position - progressPosition).Magnitude >= nav.ProgressDistance then
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
			local horizontal = Vector3.new(other.Position.X - root.Position.X, 0, other.Position.Z - root.Position.Z)
			if horizontal.Magnitude <= Config.Turning.CloseStandoffDistance then
				-- At melee range, face and pressure instead of running through prey.
				stopMoving()
			else
				local destination = other.Position - horizontal.Unit * Config.Turning.CloseStandoffDistance
				humanoid:MoveTo(destination)
			end
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
		local frameDelta = math.min(0.1, math.max(0, now - lastUpdateAt))
		lastUpdateAt = now
		pose(
			state,
			now,
			attackName,
			attackStep,
			humanoid.Health / humanoid.MaxHealth <= Config.DesperateHealthFraction,
			flinchMajor
		)
		-- Timers are cheap; hit queries are capped separately from staggered navigation.
		if state == "Telegraph" or state == "Attack" then
			local other = targetRoot(target)
			if state == "Telegraph" and other and activeAttack then
				if activeAttack.TrackingByStrike then
					local tracking = activeAttack.TrackingByStrike[attackStep] or 0
					if
						(other.Position - root.Position).Magnitude <= activeAttack.TrackingEscapeRange
						and tracking > 0
					then
						turnToward(other, activeAttack.TrackingTurnRate * tracking * frameDelta)
					end
				elseif activeAttack.TelegraphTurnRate then
					local windupProgress =
						math.clamp((now - (activeAt - activeAttack.Telegraph)) / activeAttack.Telegraph, 0, 1)
					local rate = if windupProgress < (activeAttack.CommitFraction or 1)
						then activeAttack.TelegraphTurnRate
						else activeAttack.CommitTurnRate or 0
					turnToward(other, rate * frameDelta)
				end
			end
			if now >= activeUntil then
				if flinchAfterAttack then
					clearDebug()
					beginFlinch(now, true)
				elseif attackStep < attackCount then
					attackStep += 1
					hitTargets = {}
					activeAt = now + (activeAttack.StepGap or 0)
					activeUntil = activeAt + activeAttack.Active
					setState("Telegraph")
				elseif attackName == "FrenziedChain" then
					clearDebug()
					recoverUntil = now + activeAttack.Recovery
					setState("Vulnerable")
				elseif attackName == "PredatoryLunge" and not attackHit then
					clearDebug()
					recoverUntil = now + activeAttack.MissRecovery
					setState("Vulnerable")
				elseif attackName == "RushingStrike" and not attackHit and attackSerial % 2 == 0 then
					clearDebug()
					beginAttack(other or root, "ReversalSwipe", now)
				else
					clearDebug()
					lastAttack = attackName
					activeAttack = nil
					setState("Recover")
				end
			elseif now >= activeAt then
				if state ~= "Attack" then
					setState("Attack")
					-- Contact begins with the visible strike pose, before the first
					-- server hit query runs on this active window.
					pose(
						"Attack",
						now,
						attackName,
						attackStep,
						humanoid.Health / humanoid.MaxHealth <= Config.DesperateHealthFraction,
						flinchMajor
					)
					committedOrigin = root.CFrame
					committedBox = committedOrigin * CFrame.new(0, 0, -(activeAttack and activeAttack.Offset or 0))
					if debugBox then
						debugBox.Color = Color3.fromRGB(255, 55, 55)
					end
					if debugHighlight then
						debugHighlight.FillColor = Color3.fromRGB(255, 55, 55)
					end
				end
				if other and activeAttack then
					if activeAttack.TrackingByStrike then
						local tracking = activeAttack.TrackingByStrike[attackStep] or 0
						if
							(other.Position - root.Position).Magnitude <= activeAttack.TrackingEscapeRange
							and tracking > 0
						then
							turnToward(other, activeAttack.TrackingTurnRate * tracking * frameDelta)
						end
					elseif activeAttack.CommitTurnRate then
						turnToward(other, activeAttack.CommitTurnRate * frameDelta)
					end
				end
				if activeAttack and activeAttack.Travel > 0 then
					local travel = root.CFrame.LookVector
						* (activeAttack.Travel * math.min(1, hitInterval / activeAttack.Active))
					local obstacle = workspace:Blockcast(
						root.CFrame,
						Config.CollisionHull.Diameter * Vector3.new(1, 1, 1),
						travel,
						rayParams(model)
					)
					if obstacle then
						travel = travel.Unit * math.max(0, obstacle.Distance - 0.2)
					end
					root.CFrame += travel
					committedOrigin = root.CFrame
					committedBox = committedOrigin * CFrame.new(0, 0, -activeAttack.Offset)
					if debugBox then
						debugBox.CFrame = committedBox
					end
				end
				if now < nextHit or not activeAttack then
					return
				end
				nextHit = now + hitInterval
				for _, victim in
					HitDetection.find(model, committedOrigin, committedBox, activeAttack.Size, {
						OverlapCollisionGroup = Sandbox.Combat.OverlapCollisionGroup,
						RequireLineOfSight = true,
						CanTarget = function(character)
							return Players:GetPlayerFromCharacter(character) ~= nil
						end,
					})
				do
					if not hitTargets[victim] then
						hitTargets[victim] = true
						local damage = activeAttack.Damage
						Damage.apply(model, victim, if typeof(damage) == "table" then damage[attackStep] else damage)
						attackHit = true
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
		if state == "Vulnerable" then
			if now < recoverUntil then
				return
			end
			activeAttack = nil
			lastAttack = attackName
			root.Anchored = false
			root:SetNetworkOwner(nil)
			humanoid.AutoRotate = true
			setState("Chase")
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
		if state == "Chase" then
			local chaseTarget = targetRoot(target)
			if
				chaseTarget
				and (chaseTarget.Position - root.Position).Magnitude <= Config.Turning.CloseCombatDistance
			then
				humanoid.AutoRotate = false
				turnToward(
					chaseTarget,
					combatTurnRate(chaseTarget) * frameDelta,
					Config.Turning.PivotTurnRate * frameDelta
				)
			elseif chaseTarget then
				humanoid.AutoRotate = true
			end
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
			local choice = if visible(other) then chooseAttack((other.Position - root.Position).Magnitude) else nil
			if choice then
				beginAttack(other, choice, now)
			else
				chase(other, now, frameDelta)
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
