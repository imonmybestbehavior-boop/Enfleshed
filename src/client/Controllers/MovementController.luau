--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox")).Movement
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local Speed = require(Shared.Modules.MovementSpeed)
local Movement = {}

function Movement.start(send: (string, Types.ActionOptions?) -> number)
	local player = Players.LocalPlayer
	local readyAt = 0
	local sprinting = false
	local dashSequence = 0
	local sprintSequence = 0
	local stopDash: (() -> ())? = nil
	local speedConnection: RBXScriptConnection? = nil
	local multiplierConnection: RBXScriptConnection? = nil

	local function applyPredictedSpeed()
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 then
			local bonus = character:GetAttribute("MagicWalkSpeedBonus")
			local multiplier = character:GetAttribute("MagicSpeedMultiplier")
			humanoid.WalkSpeed = Speed.calculate(
				Config.WalkSpeed,
				Config.SprintSpeed,
				sprinting,
				if typeof(bonus) == "number" then bonus else 0,
				if typeof(multiplier) == "number" then multiplier else 1
			)
		end
	end

	local function bindCharacter(character: Model)
		if multiplierConnection then
			multiplierConnection:Disconnect()
		end
		if speedConnection then
			speedConnection:Disconnect()
		end
		speedConnection = character:GetAttributeChangedSignal("MagicWalkSpeedBonus"):Connect(applyPredictedSpeed)
		multiplierConnection = character:GetAttributeChangedSignal("MagicSpeedMultiplier"):Connect(applyPredictedSpeed)
		applyPredictedSpeed()
	end
	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end

	local function cancel()
		if stopDash then
			stopDash()
		end
	end

	local function sprint(enabled: boolean)
		if sprinting == enabled then
			return
		end
		sprinting = enabled
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid and humanoid.Health > 0 then
			applyPredictedSpeed()
			sprintSequence = send(Protocol.Sprint, { Sprinting = enabled })
		end
	end

	local function dash(): boolean
		local now = workspace:GetServerTimeNow()
		if now < readyAt or stopDash then
			return false
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			return false
		end
		local move = humanoid.MoveDirection
		local direction = Vector3.new(move.X, 0, move.Z)
		if direction.Magnitude < Config.DirectionEpsilon then
			local facing = root.CFrame.LookVector
			direction = Vector3.new(facing.X, 0, facing.Z)
		end
		if direction.Magnitude < Config.DirectionEpsilon then
			return false
		end
		direction = direction.Unit
		readyAt = now + Config.DashCooldown
		local attachment = Instance.new("Attachment")
		attachment.Name = "PredictedDashAttachment"
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "PredictedDashVelocity"
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.xAxis
		velocity.SecondaryTangentAxis = Vector3.zAxis
		velocity.ForceLimitsEnabled = false
		local speed = Config.DashDistance / Config.DashDuration
		velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * speed
		velocity.Parent = root
		local rotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local connection: RBXScriptConnection? = nil
		stopDash = function()
			if connection then
				connection:Disconnect()
			end
			velocity:Destroy()
			attachment:Destroy()
			humanoid.AutoRotate = rotate
			stopDash = nil
		end
		connection = RunService.PreSimulation:Connect(function(dt)
			if player.Character ~= character or humanoid.Health <= 0 or not root.Parent then
				cancel()
				return
			end
			if workspace:GetServerTimeNow() >= now + Config.DashDuration then
				cancel()
				local normal = humanoid.MoveDirection * humanoid.WalkSpeed
				root.AssemblyLinearVelocity = Vector3.new(normal.X, root.AssemblyLinearVelocity.Y, normal.Z)
				return
			end
			local result = workspace:Blockcast(
				root.CFrame,
				Config.DashCollisionSize,
				direction * (speed * dt + Config.WallPadding),
				params
			)
			if result then
				cancel()
				root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			end
		end)
		-- Prediction is already active before the request leaves the client.
		dashSequence = send(Protocol.Dash, { Direction = direction })
		return true
	end

	return {
		Sprint = sprint,
		Dash = dash,
		Cancel = cancel,
		IsDashing = function(): boolean
			return stopDash ~= nil
		end,
		GetCooldown = function(): number
			return math.max(0, readyAt - workspace:GetServerTimeNow())
		end,
		Reset = function()
			cancel()
			readyAt = 0
			sprinting = false
			dashSequence = 0
			sprintSequence = 0
		end,
		Feedback = function(message: any)
			if message.Kind == "Correction" then
				cancel()
			end
			if message.Kind ~= "Action" then
				return
			end
			if message.Action == Protocol.Dash and message.Sequence == dashSequence then
				readyAt = message.DashReadyAt
				if not message.Accepted then
					local wasDashing = stopDash ~= nil
					cancel()
					local character = player.Character
					local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
					if wasDashing and root and root:IsA("BasePart") then
						root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
					end
				end
			elseif message.Action == Protocol.Sprint and message.Sequence == sprintSequence then
				-- Apply only the latest sprint acknowledgement.
				sprinting = message.Sprinting
				applyPredictedSpeed()
			end
		end,
	}
end

export type Controller = typeof(Movement.start(function()
	return 0
end))
return Movement
