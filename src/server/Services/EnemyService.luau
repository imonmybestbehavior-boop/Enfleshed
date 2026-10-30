--!strict

local Collection = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sandbox = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local EnemyVisuals = require(Shared:WaitForChild("Configuration"):WaitForChild("EnemyVisuals"))
local Navigation = require(Shared:WaitForChild("Modules"):WaitForChild("EnemyNavigation"))
local AnimationCorpse = require(script.Parent.EnemyAnimationCorpse)
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

local visualNames = { "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function importedParts(kind: string): { [string]: MeshPart }?
	local library = ServerStorage:FindFirstChild("EnfleshedModels")
	local template = if library then library:FindFirstChild(kind) else nil
	if not template or not template:IsA("Model") then
		return nil
	end
	local found: { [string]: MeshPart } = {}
	for _, name in visualNames do
		local mesh = template:FindFirstChild(name, true)
		if not mesh or not mesh:IsA("MeshPart") then
			warn("Enfleshed model " .. kind .. " is missing MeshPart " .. name)
			return nil
		end
		found[name] = mesh
	end
	return found
end

local function createRig(
	position: Vector3,
	container: Folder,
	collisionGroup: string,
	kind: string?
): (Model, Humanoid, BasePart, TextLabel)
	local visualKind = kind or "Basic"
	local layout = EnemyVisuals[visualKind]
	local meshes = if layout then importedParts(visualKind) else nil
	local model = Instance.new("Model")
	model.Name = "Stage1Enfleshed"
	Collection:AddTag(model, "Enfleshed")
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
	-- The root stays non-colliding, but Humanoid ground queries use its group.
	-- Visuals ignore Default geometry; putting the root there leaves the rig in
	-- Freefall even when its separate hull is standing on the floor.
	root.CollisionGroup = "Default"
	local function visual(name: string, size: Vector3, offset: Vector3, color: Color3): BasePart
		if meshes then
			local mesh = meshes[name]:Clone()
			local placement = layout.Parts[name]
			mesh.Size = placement.Size
			mesh.CFrame = CFrame.new(position + placement.Center)
			mesh.Anchored = false
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.Massless = true
			mesh.RenderFidelity = Enum.RenderFidelity.Performance
			mesh.CollisionGroup = Config.VisualCollisionGroup
			mesh.Parent = model
			return mesh
		end
		return part(name, size, offset, color)
	end
	local torso = visual("Torso", Vector3.new(3.2, 3.7, 1.75), Vector3.new(0, 0.3, 0), Color3.fromRGB(94, 42, 52))
	local head =
		visual("Head", Vector3.new(1.9, 2.15, 1.8), Vector3.new(-0.18, 2.75, -0.35), Color3.fromRGB(145, 72, 76))
	if head:IsA("Part") then
		head.Shape = Enum.PartType.Ball
	end
	local function joint(name: string, parent: BasePart, limb: BasePart): Motor6D
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0 = parent
		motor.Part1 = limb
		if name ~= "RootJoint" then
			local fallbackPivots = {
				Neck = Vector3.new(0, 2.1, 0),
				["Left Shoulder"] = Vector3.new(-1.6, 1.55, 0),
				["Right Shoulder"] = Vector3.new(1.6, 1.55, 0),
				["Left Hip"] = Vector3.new(-0.65, -1.2, 0),
				["Right Hip"] = Vector3.new(0.65, -1.2, 0),
			}
			local pivot = CFrame.new(position + (if meshes then layout.Pivots[name] else fallbackPivots[name]))
			motor.C0 = parent.CFrame:ToObjectSpace(pivot)
			motor.C1 = limb.CFrame:ToObjectSpace(pivot)
		else
			motor.C0 = parent.CFrame:ToObjectSpace(limb.CFrame)
		end
		motor.Parent = parent
		return motor
	end
	local rootJoint = joint("RootJoint", root, torso)
	local neck = joint("Neck", torso, head)
	local leftShoulder = joint(
		"Left Shoulder",
		torso,
		visual("Left Arm", Vector3.new(1.45, 3.7, 1.3), Vector3.new(-2.25, 0.05, -0.15), Color3.fromRGB(121, 55, 71))
	)
	local rightShoulder = joint(
		"Right Shoulder",
		torso,
		visual("Right Arm", Vector3.new(1.8, 4.5, 1.55), Vector3.new(2.4, -0.25, -0.5), Color3.fromRGB(151, 61, 67))
	)
	local leftHip = joint(
		"Left Hip",
		torso,
		visual("Left Leg", Vector3.new(1.2, 3, 1.2), Vector3.new(-0.65, -2.9, 0), Color3.fromRGB(90, 42, 55))
	)
	local rightHip = joint(
		"Right Hip",
		torso,
		visual("Right Leg", Vector3.new(1.2, 3, 1.2), Vector3.new(0.65, -2.9, 0), Color3.fromRGB(90, 42, 55))
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
	if not meshes then
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
	end
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
	gui.Name = "LegacyTargetNameplate"
	gui.Enabled = false
	gui.Size = UDim2.fromOffset(240, 48)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 55
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.fromScale(1, 0.5)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextSize = 16
	label.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "HealthBack"
	bar.Size = UDim2.fromScale(0.7, 0.14)
	bar.Position = UDim2.fromScale(0.15, 0.62)
	bar.BorderSizePixel, bar.BackgroundColor3 = 0, Color3.fromRGB(20, 20, 20)
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "HealthFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel, fill.BackgroundColor3 = 0, Color3.fromRGB(155, 58, 68)
	fill.Parent = bar
	model:SetAttribute("SandboxAlignment", "Enemy")
	model:SetAttribute("SandboxLabel", "Nascent")
	model:SetAttribute("VisualKind", visualKind)
	model:SetAttribute("ImportedVisual", meshes ~= nil)
	Collection:AddTag(model, "MagicHostileTarget")
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
	GetNavigationDiagnostics: () -> { [string]: any },
}

function Enemy.create(
	position: Vector3,
	container: Folder,
	collisionGroup: string,
	thinkOffset: number,
	hitInterval: number,
	kind: string?
): Handle
	local model, humanoid, root, label = createRig(position, container, collisionGroup, kind)
	local state: State = "Idle"
	local target: Instance? = nil
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
	local hull = model:FindFirstChild("CollisionHull") :: BasePart
	local leg = model:FindFirstChild("Left Leg") :: BasePart
	local lastHullSize = hull.Size
	local path: Path? = nil
	local blockedConnection: RBXScriptConnection? = nil
	local waypoints: { PathWaypoint } = {}
	local waypointIndex = 1
	local issuedJumpIndex = 0
	local pathGoal: Vector3? = nil
	local generation = 0
	local computing = false
	local pendingPath: (() -> ())? = nil
	local nextPath = 0
	local progressPosition = root.Position
	local progressAt = 0
	local stuck = false
	local lastUpdateAt = os.clock()
	-- Read only on demand by the Studio fixture; no per-frame replication or
	-- extra path jobs are introduced for diagnostics.
	local navigationMode, lastPathStatus = "Idle", "NotRequested"
	local queuedAt, queueWait, computeSeconds = 0, 0, 0
	local pathRequests, pathFailures, blockedPaths, stuckRecoveries, jumpRequests = 0, 0, 0, 0, 0

	local function navigationBody(): (number, number, Vector3, CFrame, Vector3)
		-- The upright cylinder's local X is its height. Read the actual hull:
		-- mission ScaleTo happens after Enemy.create, not before it.
		local scale = hull.Size.X / Config.CollisionHull.Height
		local diameter = math.max(hull.Size.Y, hull.Size.Z)
		local rootToFloor = Navigation.r6GroundOffset(leg.Size.Y, root.Size.Y, humanoid.HipHeight)
		local floorToHullTop = rootToFloor + hull.Position.Y - root.Position.Y + hull.Size.X / 2
		local radius, height = Navigation.agentDimensions(
			nav.AgentRadius,
			nav.AgentHeight,
			scale,
			math.max(hull.Size.X, floorToHullTop),
			diameter
		)
		local sweep = nav.SweepSize * scale
		local frame = root.CFrame + (hull.Position - root.Position)
		local ground = root.Position - Vector3.new(0, rootToFloor, 0)
		return radius, height, sweep, frame, ground
	end

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
		issuedJumpIndex = 0
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

	local lastPose = ""
	local function pose(
		poseState: string,
		now: number,
		attack: string,
		step: number,
		desperate: boolean,
		major: boolean
	)
		local finish = if poseState == "Telegraph"
			then activeAt
			elseif poseState == "Attack" then activeUntil
			elseif poseState == "Recover" or poseState == "Vulnerable" then recoverUntil
			elseif poseState == "Flinch" then flinchUntil
			else 0
		local key = table.concat(
			{ poseState, attack, tostring(step), tostring(desperate), tostring(major), tostring(finish) },
			"|"
		)
		if key == lastPose then
			return
		end
		lastPose = key
		local stamp = workspace:GetServerTimeNow()
		model:SetAttribute(
			"EnemyPose",
			game:GetService("HttpService"):JSONEncode({
				State = poseState,
				Attack = attack,
				Step = step,
				Desperate = desperate,
				Major = major,
				Start = stamp,
				Finish = stamp + math.max(0, finish - now),
			})
		)
	end

	local function display()
		pose(
			state,
			os.clock(),
			attackName,
			attackStep,
			humanoid.Health / humanoid.MaxHealth <= Config.DesperateHealthFraction,
			flinchMajor
		)
		label.Text = if Config.DebugLabels
			then string.format(
				"%s  %d/%d\n%s",
				model:GetAttribute("SandboxLabel") or "Nascent",
				humanoid.Health,
				humanoid.MaxHealth,
				state
			)
			else "Nascent"
		local fill = label.Parent
			and label.Parent:FindFirstChild("HealthBack")
			and label.Parent.HealthBack:FindFirstChild("HealthFill")
		if fill and fill:IsA("Frame") then
			fill.Size = UDim2.fromScale(math.max(0, humanoid.Health / humanoid.MaxHealth), 1)
		end
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

	local function targetRoot(subject: Instance?): BasePart?
		local character = if subject and subject:IsA("Player")
			then subject.Character
			elseif subject and subject:IsA("Model") then subject
			else nil
		if subject and subject:IsA("Player") and not subject:GetAttribute("CharacterReady") then
			return nil
		end
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
		if humanoid.Health <= 0 and model:IsDescendantOf(workspace) then
			AnimationCorpse.show(model)
		end
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
			local requestedHullSize = hull.Size
			local radius, height = navigationBody()
			local destination = other.Position
			local requestedTarget = target
			nextPath = os.clock() + nav.RepathInterval
			queueWait = math.max(0, os.clock() - queuedAt)
			pathRequests += 1
			local candidate = PathfindingService:CreatePath({
				AgentRadius = radius,
				AgentHeight = height,
				AgentCanJump = nav.AgentCanJump,
				WaypointSpacing = nav.WaypointSpacing,
			})
			local computeStarted = os.clock()
			local ok = pcall(function()
				candidate:ComputeAsync(root.Position, destination)
			end)
			computeSeconds = os.clock() - computeStarted
			lastPathStatus = if ok then candidate.Status.Name else "ComputeError"
			if not ok or candidate.Status ~= Enum.PathStatus.Success then
				pathFailures += 1
			end
			computing = false
			local currentRoot = targetRoot(target)
			if
				not ok
				or candidate.Status ~= Enum.PathStatus.Success
				or state ~= "Chase"
				or token ~= generation
				or target ~= requestedTarget
				or hull.Size ~= requestedHullSize
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
					blockedPaths += 1
					clearPath()
					stopMoving()
				end
			end)
		end
		queuedAt = now
		model:SetAttribute("PathQueued", true)
	end

	local function chase(other: BasePart, now: number, frameDelta: number)
		if hull.Size ~= lastHullSize then
			lastHullSize = hull.Size
			clearPath() -- A previously computed route may no longer fit this body.
		end
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
			stuckRecoveries += 1
			clearPath()
			progressAt = now
		end
		local _, _, sweep, sweepFrame, ground = navigationBody()
		local travel = other.Position - root.Position
		local blocked = workspace:Blockcast(sweepFrame, sweep, travel, rayParams(other.Parent :: Instance)) ~= nil
		local nextWaypoint = waypoints[waypointIndex]
		local jumpPending = nextWaypoint ~= nil and nextWaypoint.Action == Enum.PathWaypointAction.Jump
		local direct = Navigation.canMoveDirectly(travel.Y, nav.WaypointTolerance, blocked, stuck, jumpPending)
		if direct then
			navigationMode = "Direct"
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
		navigationMode = "Path"
		if not pathGoal or (other.Position - pathGoal).Magnitude >= nav.TargetMoveThreshold then
			requestPath(other, now)
		end
		waypointIndex = Navigation.nextWaypoint(
			waypoints,
			waypointIndex,
			ground,
			nav.WaypointTolerance,
			Enum.PathWaypointAction.Jump,
			issuedJumpIndex,
			function(position)
				if humanoid.FloorMaterial == Enum.Material.Air then
					return nil
				end
				local tolerance = nav.WaypointTolerance
				-- Start above both references so an upper floor cannot be mistaken
				-- for the lower floor beneath it.
				local top = math.max(position.Y, ground.Y) + tolerance
				local origin = Vector3.new(position.X, top, position.Z)
				local hit = workspace:Raycast(
					origin,
					Vector3.new(0, ground.Y - tolerance - top, 0),
					rayParams(other.Parent :: Instance)
				)
				return if hit then hit.Position else nil
			end
		)
		local waypoint = waypoints[waypointIndex]
		if waypoint then
			local approach = waypoint.Position - ground
			local atTakeoff = Vector3.new(approach.X, 0, approach.Z).Magnitude
				<= math.max(nav.WaypointSpacing, nav.WaypointTolerance)
			if
				waypoint.Action == Enum.PathWaypointAction.Jump
				and issuedJumpIndex ~= waypointIndex
				and atTakeoff
				and humanoid.FloorMaterial ~= Enum.Material.Air
			then
				humanoid.Jump = true
				issuedJumpIndex = waypointIndex
				jumpRequests += 1
			end
			humanoid:MoveTo(waypoint.Position)
		else
			navigationMode = if pendingPath or computing then "WaitingForPath" else "NoPath"
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
								or Collection:HasTag(character, "CityHuman")
						end,
					})
				do
					if not hitTargets[victim] then
						hitTargets[victim] = true
						local damage = activeAttack.Damage
						Damage.applyMelee(
							model,
							victim,
							if typeof(damage) == "table" then damage[attackStep] else damage
						)
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
		local order = model:FindFirstChild("ObjectiveTarget")
		local objective = if order and order:IsA("ObjectValue") then order.Value else nil
		if
			not other or (target ~= objective and (other.Position - root.Position).Magnitude > Config.DisengageRange)
		then
			target = nil
			other = nil
			clearPath()
			stopMoving()
			setState("Idle")
			local nearest = Config.DetectionRange
			local candidates: { Instance } = {}
			for _, player in Players:GetPlayers() do
				table.insert(candidates, player)
			end
			for _, human in Collection:GetTagged("CityHuman") do
				table.insert(candidates, human)
			end
			for _, player in candidates do
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
			if not other and objective then
				target, other = objective, targetRoot(objective)
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
		GetNavigationDiagnostics = function(): { [string]: any }
			local radius, height, sweep, frame, ground = navigationBody()
			local waypoint = waypoints[waypointIndex]
			return {
				State = state,
				Mode = navigationMode,
				Root = root.Position,
				Ground = ground,
				HullBottom = hull.Position - Vector3.new(0, hull.Size.X / 2, 0),
				HullSize = hull.Size,
				SweepSize = sweep,
				SweepCenter = frame.Position,
				AgentRadius = radius,
				AgentHeight = height,
				FloorMaterial = humanoid.FloorMaterial.Name,
				HumanoidState = humanoid:GetState().Name,
				WaypointIndex = waypointIndex,
				WaypointCount = #waypoints,
				WaypointPosition = if waypoint then waypoint.Position else nil,
				WaypointAction = if waypoint then waypoint.Action.Name else nil,
				JumpIssuedIndex = issuedJumpIndex,
				PathQueued = pendingPath ~= nil,
				QueueAge = if pendingPath then math.max(0, os.clock() - queuedAt) else 0,
				Computing = computing,
				LastQueueWait = queueWait,
				LastComputeSeconds = computeSeconds,
				LastPathStatus = lastPathStatus,
				PathRequests = pathRequests,
				PathFailures = pathFailures,
				BlockedPaths = blockedPaths,
				Stuck = stuck,
				StuckRecoveries = stuckRecoveries,
				JumpRequests = jumpRequests,
			}
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
