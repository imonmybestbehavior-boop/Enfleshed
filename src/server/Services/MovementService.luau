--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox")).Movement
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local Speed = require(Shared.Modules.MovementSpeed)
local MagicLab = require(Shared.Configuration.MagicLab)
local AerialSpec = require(Shared.Modules.MagicAerialMovementSpec)
local Movement = {}
type NpcSlowRecord = {
	BaseSpeed: number,
	BaseJumpPower: number,
	BaseJumpHeight: number,
	Multiplier: number,
	AppliedSpeed: number,
	Writing: boolean,
	Connection: RBXScriptConnection?,
}
local impulses = setmetatable({}, { __mode = "k" })
local playerStates = setmetatable({}, { __mode = "k" })
local npcSlowRecords: { [Humanoid]: NpcSlowRecord } = setmetatable({}, { __mode = "k" }) :: any

-- Ground speed for the current sprint and guard state, before magic slows and casting.
local function groundSpeed(state: Types.PlayerState): number
	return Speed.calculate(
		Config.WalkSpeed,
		Config.SprintSpeed,
		state.Sprinting and not state.Blocking,
		state.MagicWalkSpeedBonus,
		state.MagicSpeedMultiplier
	) * (if state.Blocking then Config.BlockWalkMultiplier else 1)
end

local function clearAerial(state: Types.PlayerState)
	if state.MagicAerialVelocity then
		if state.Root:IsDescendantOf(workspace) then
			state.Root.AssemblyLinearVelocity = Vector3.zero
		end
		state.MagicAerialVelocity:Destroy()
		state.MagicAerialVelocity = nil
	end
	if state.MagicAerialAttachment then
		state.MagicAerialAttachment:Destroy()
		state.MagicAerialAttachment = nil
	end
	state.MagicAerialSpeed = 0
	state.MagicAerialInput = Vector3.zero
	state.MagicAerialInputExpiresAt = 0
	state.Character:SetAttribute("MagicAerialSpeed", 0)
end

local function applyAerialInput(state: Types.PlayerState, now: number)
	local velocity = state.MagicAerialVelocity
	if not velocity then
		return
	end
	if now < state.DashUntil then
		if velocity.Enabled then
			velocity.Enabled = false
		end
		return
	end
	if not velocity.Enabled then
		velocity.Enabled = true
	end
	local input = if now <= state.MagicAerialInputExpiresAt then state.MagicAerialInput else Vector3.zero
	local speedScale = if Config.WalkSpeed > 0
		then Speed.calculate(
			Config.WalkSpeed,
			Config.SprintSpeed,
			state.Sprinting,
			state.MagicWalkSpeedBonus,
			state.MagicSpeedMultiplier
		) / Config.WalkSpeed
		else 1
	local speed = math.clamp(
		state.MagicAerialSpeed * speedScale * (state.MagicSlowMultiplier or 1) * (state.MagicCastingMultiplier or 1),
		0,
		MagicLab.MaxAerialSpeed
	)
	local targetVelocity = input * speed
	if velocity.VectorVelocity ~= targetVelocity then
		velocity.VectorVelocity = targetVelocity
	end
end

local function aerialMaximumSpeed(state: Types.PlayerState): number
	if state.MagicAerialSpeed <= 0 then
		return 0
	end
	local speedScale = if Config.WalkSpeed > 0
		then Speed.calculate(
			Config.WalkSpeed,
			Config.SprintSpeed,
			state.Sprinting,
			state.MagicWalkSpeedBonus,
			state.MagicSpeedMultiplier
		) / Config.WalkSpeed
		else 1
	return math.clamp(
		state.MagicAerialSpeed * speedScale * (state.MagicSlowMultiplier or 1) * (state.MagicCastingMultiplier or 1),
		0,
		MagicLab.MaxAerialSpeed
	)
end

function Movement.bind(state: Types.PlayerState)
	playerStates[state.Humanoid] = state
	state.Character:SetAttribute("MagicAerialSpeed", state.MagicAerialSpeed)
end

function Movement.unbind(state: Types.PlayerState)
	clearAerial(state)
	playerStates[state.Humanoid] = nil
	state.MagicSlowMultiplier = 1
	state.MagicCastingMultiplier = 1
	state.Humanoid:SetAttribute("MagicSlowMultiplier", 1)
	state.Character:SetAttribute("MagicCastingMultiplier", 1)
	state.Character:SetAttribute("MagicCastingLocked", false)
	state.MagicRotationLocked = false
	state.MagicCastingDirection = nil
	state.Character:SetAttribute("MagicRotationLocked", false)
	state.Humanoid:SetAttribute("MagicMovementBound", false)
	state.Humanoid.JumpPower = 50 + state.MagicJumpPowerBonus
	state.Humanoid.JumpHeight = state.MagicBaseJumpHeight
end

function Movement.setMagicAerial(state: Types.PlayerState, speed: number)
	local safeSpeed = AerialSpec.clampSpeed(speed, MagicLab.MaxAerialSpeed) or 0
	if safeSpeed <= 0 then
		clearAerial(state)
		return
	end
	state.MagicAerialSpeed = safeSpeed
	state.MagicAerialInput = Vector3.zero
	state.MagicAerialInputExpiresAt = 0
	if not state.MagicAerialAttachment or state.MagicAerialAttachment.Parent ~= state.Root then
		if state.MagicAerialVelocity then
			state.MagicAerialVelocity:Destroy()
		end
		state.MagicAerialAttachment = Instance.new("Attachment")
		state.MagicAerialAttachment.Name = "MagicAerialAttachment"
		state.MagicAerialAttachment.Parent = state.Root
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "MagicAerialVelocity"
		velocity.Attachment0 = state.MagicAerialAttachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.ForceLimitsEnabled = false
		velocity.VectorVelocity = Vector3.zero
		velocity.Parent = state.Root
		state.MagicAerialVelocity = velocity
	end
	state.Character:SetAttribute("MagicAerialSpeed", safeSpeed)
	applyAerialInput(state, workspace:GetServerTimeNow())
end

function Movement.aerialInput(state: Types.PlayerState, direction: Vector3, now: number): boolean
	if state.MagicAerialSpeed <= 0 or not state.MagicAerialVelocity then
		return false
	end
	local x, y, z = AerialSpec.normalizeInput(direction.X, direction.Y, direction.Z, 1.1)
	if x == nil or y == nil or z == nil then
		return false
	end
	state.MagicAerialInput = Vector3.new(x, y, z)
	state.MagicAerialInputExpiresAt = now + 0.35
	applyAerialInput(state, now)
	return true
end

function Movement.setMagicSlow(humanoid: Humanoid, multiplier: number)
	local state = playerStates[humanoid]
	if state then
		state.MagicSlowMultiplier = multiplier
		state.Character:SetAttribute("MagicSlowMultiplier", multiplier)
		humanoid:SetAttribute("MagicSlowMultiplier", multiplier)
		local base = groundSpeed(state)
		humanoid.WalkSpeed = base * multiplier * (state.MagicCastingMultiplier or 1)
		if multiplier <= 0 or (state.MagicCastingMultiplier or 1) <= 0 then
			if humanoid.UseJumpPower then
				humanoid.JumpPower = 0
			else
				humanoid.JumpHeight = 0
			end
		else
			humanoid.JumpPower = 50 + state.MagicJumpPowerBonus
			humanoid.JumpHeight = state.MagicBaseJumpHeight
		end
		return
	end

	local record = npcSlowRecords[humanoid]
	if multiplier == 1 then
		if record then
			record.Writing = true
			record.AppliedSpeed = record.BaseSpeed
			humanoid.WalkSpeed = record.BaseSpeed
			humanoid.JumpPower = record.BaseJumpPower
			humanoid.JumpHeight = record.BaseJumpHeight
			if record.Connection then
				record.Connection:Disconnect()
			end
			npcSlowRecords[humanoid] = nil
		end
		humanoid:SetAttribute("MagicSlowMultiplier", 1)
		return
	end
	if not record then
		record = {
			BaseSpeed = humanoid.WalkSpeed,
			BaseJumpPower = humanoid.JumpPower,
			BaseJumpHeight = humanoid.JumpHeight,
			Multiplier = multiplier,
			AppliedSpeed = humanoid.WalkSpeed * multiplier,
			Writing = false,
			Connection = nil,
		}
		record.Connection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			local currentSpeed = humanoid.WalkSpeed
			if record.Writing or currentSpeed == record.AppliedSpeed or not humanoid:IsDescendantOf(workspace) then
				return
			end
			record.BaseSpeed = currentSpeed
			record.Writing = true
			record.AppliedSpeed = record.BaseSpeed * record.Multiplier
			humanoid.WalkSpeed = record.AppliedSpeed
			if record.Multiplier <= 0 then
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
			else
				humanoid.JumpPower = record.BaseJumpPower
				humanoid.JumpHeight = record.BaseJumpHeight
			end
			record.Writing = false
		end)
		npcSlowRecords[humanoid] = record
	else
		record.Multiplier = multiplier
	end
	record.Writing = true
	record.AppliedSpeed = record.BaseSpeed * multiplier
	humanoid.WalkSpeed = record.AppliedSpeed
	if multiplier <= 0 then
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.JumpPower = record.BaseJumpPower
		humanoid.JumpHeight = record.BaseJumpHeight
	end
	record.Writing = false
	humanoid:SetAttribute("MagicSlowMultiplier", multiplier)
end
function Movement.allowMagicImpulse(root: BasePart, velocity: Vector3)
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local old = impulses[root]
	if old and workspace:GetServerTimeNow() >= old.Until then
		old = nil
	end
	impulses[root] =
		{ Speed = math.min(120, horizontal + (old and old.Speed or 0)), Until = workspace:GetServerTimeNow() + 1 }
end

local function maximumSpeed(state: Types.PlayerState): number
	local multiplier = state.MagicSpeedMultiplier
	if workspace:GetServerTimeNow() < (state.MagicSpeedGraceUntil or 0) then
		multiplier = math.max(multiplier, state.MagicPreviousMultiplier or 1)
	end
	return Speed.calculate(Config.WalkSpeed, Config.SprintSpeed, true, state.MagicWalkSpeedBonus, multiplier)
		* (state.MagicSlowMultiplier or 1)
		* (state.MagicCastingMultiplier or 1)
end

local function applySpeed(state: Types.PlayerState)
	state.Humanoid.WalkSpeed = groundSpeed(state)
		* (state.MagicSlowMultiplier or 1)
		* (state.MagicCastingMultiplier or 1)
	if state.MagicSlowMultiplier <= 0 or (state.MagicCastingMultiplier or 1) <= 0 then
		if state.Humanoid.UseJumpPower then
			state.Humanoid.JumpPower = 0
		else
			state.Humanoid.JumpHeight = 0
		end
	else
		state.Humanoid.JumpPower = 50 + state.MagicJumpPowerBonus
		state.Humanoid.JumpHeight = state.MagicBaseJumpHeight
	end
end

function Movement.setMagicCasting(state: Types.PlayerState, multiplier: number)
	state.MagicCastingMultiplier = math.clamp(multiplier, 0, 1)
	state.Character:SetAttribute("MagicCastingMultiplier", state.MagicCastingMultiplier)
	state.Character:SetAttribute("MagicCastingLocked", state.MagicCastingMultiplier <= 0)
	applySpeed(state)
end

function Movement.setMagicRotation(state: Types.PlayerState, locked: boolean, direction: Vector3?)
	state.MagicRotationLocked = locked
	state.MagicCastingDirection = if locked then direction else nil
	state.Character:SetAttribute("MagicRotationLocked", locked)
end

function Movement.sprint(state: Types.PlayerState, enabled: boolean)
	state.Sprinting = enabled
	applySpeed(state)
end

-- Re-applies walk speed after something outside movement changed it (raising or lowering a guard).
function Movement.refreshSpeed(state: Types.PlayerState)
	applySpeed(state)
end

-- This deliberately composes with sprinting instead of owning a separate stat
-- system. MagicService provides only validated temporary bonuses.
function Movement.setMagicEnhancement(
	state: Types.PlayerState,
	walkSpeedBonus: number,
	jumpPowerBonus: number,
	multiplier: number?
)
	-- Account for enhanced motion already observed in this validation window
	-- when the player turns the spell off while sprinting or dashing.
	state.MagicPreviousMultiplier = state.MagicSpeedMultiplier
	state.MagicSpeedGraceUntil = workspace:GetServerTimeNow() + Config.ValidationInterval + Config.DashReplicationGrace
	state.MagicSpeedMultiplier = multiplier or 1
	state.Character:SetAttribute("MagicSpeedMultiplier", state.MagicSpeedMultiplier)
	state.MagicWalkSpeedBonus = walkSpeedBonus
	state.MagicJumpPowerBonus = jumpPowerBonus
	state.Character:SetAttribute("MagicWalkSpeedBonus", walkSpeedBonus)
	state.Character:SetAttribute("MagicJumpPowerBonus", jumpPowerBonus)
	applySpeed(state)
end

function Movement.dash(state: Types.PlayerState, now: number): boolean
	if
		state.MagicSlowMultiplier <= 0
		or (state.MagicCastingMultiplier or 1) <= 0
		or now < state.DashReadyAt
		or now < state.ReadyAt
		or now < state.CorrectionUntil
		or now < (state.MagicRushUntil or 0)
	then
		return false
	end
	state.DashUntil = now + Config.DashDuration
	state.DashReadyAt = now + Config.DashCooldown
	-- Use the previous observed position: prediction can arrive before the request.
	state.DashOrigin = state.LastPosition
	state.DashCheckUntil = state.DashUntil + Config.DashReplicationGrace
	state.DashAllowance += Config.DashDistance
	return true
end

-- Whether a magic Rush may start now (not during a correction or another rush).
function Movement.canMagicRush(state: Types.PlayerState, now: number): boolean
	return now >= state.CorrectionUntil and now >= (state.MagicRushUntil or 0) and now >= state.SpawnGraceUntil
end

-- A magic Rush (Dash or Blink) is moved by the server, which owns the root
-- meanwhile: the speed and dash checks stand down until it ends plus the
-- replication grace, and any predicted dash is dropped. The character
-- attribute tells the client to stop predicting (MovementController).
function Movement.magicRush(state: Types.PlayerState, untilTime: number)
	state.MagicRushUntil = untilTime + Config.DashReplicationGrace
	state.DashOrigin = nil
	state.DashUntil = 0
	state.DashAllowance = 0
	state.Character:SetAttribute("MagicRushUntil", untilTime)
end

local function correct(state: Types.PlayerState, position: Vector3, now: number, player: Player, feedback: RemoteEvent)
	state.Root:SetNetworkOwner(nil)
	state.Root.CFrame = CFrame.new(position) * state.Root.CFrame.Rotation
	state.Root.AssemblyLinearVelocity = Vector3.zero
	state.CorrectionUntil = now + Config.CorrectionOwnershipTime
	state.Attack = nil
	state.DashOrigin = nil
	state.DashUntil = 0
	state.DashAllowance = 0
	state.LastPosition = position
	state.LastFramePosition = position
	state.LastCheck = now
	feedback:FireClient(player, { Kind = "Correction", Character = state.Character })
end

function Movement.update(player: Player, state: Types.PlayerState, now: number, feedback: RemoteEvent): boolean
	applyAerialInput(state, now)
	if now < state.SpawnGraceUntil then
		-- Roblox may still place/scale the rig after it first enters Workspace.
		-- Track the actual spawn position without fighting that engine movement.
		state.LastPosition = state.Root.Position
		state.LastFramePosition = state.Root.Position
		state.LastCheck = now
		if state.DashOrigin then
			state.DashOrigin = state.Root.Position
		end
		return true
	end
	if now < (state.MagicRushUntil or 0) then
		-- The server is moving this root (magic Rush): follow it, check nothing.
		state.LastPosition = state.Root.Position
		state.LastFramePosition = state.Root.Position
		state.LastCheck = now
		return true
	end
	if state.CorrectionUntil > 0 then
		if now < state.CorrectionUntil then
			return false
		end
		state.CorrectionUntil = 0
		state.Root:SetNetworkOwnershipAuto()
	end
	local elapsed = now - state.LastCheck
	local delta = state.Root.Position - state.LastPosition
	local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
	-- Horizontal checks leave jumping and falling alone. This is a sandbox guard,
	-- not a complete anti-cheat for client-owned Roblox character physics.
	local impulse = impulses[state.Root]
	local extraSpeed = 0
	if impulse then
		if now < impulse.Until then
			extraSpeed = impulse.Speed
		else
			impulses[state.Root] = nil
		end
	end
	local movementSpeed = math.max(maximumSpeed(state), aerialMaximumSpeed(state))
	local travel = if state.MagicAerialSpeed > 0 then delta.Magnitude else horizontal
	local budget = (movementSpeed + extraSpeed) * elapsed + state.DashAllowance + Config.PositionTolerance
	-- Check before every damage sample, not just when advancing the movement anchor.
	if travel ~= travel or travel > budget then
		-- Normal movement leaves vertical jumps/falls alone; aerial movement also
		-- caps height changes, using the same bounded validation window.
		correct(
			state,
			if state.MagicAerialSpeed > 0
				then state.LastPosition
				else Vector3.new(state.LastPosition.X, state.Root.Position.Y, state.LastPosition.Z),
			now,
			player,
			feedback
		)
		return false
	end
	if state.DashOrigin then
		local travel = state.Root.Position - state.LastFramePosition
		if travel.Magnitude > Config.DirectionEpsilon then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { state.Character }
			params.RespectCanCollide = true
			local start = CFrame.new(state.LastFramePosition) * state.Root.CFrame.Rotation
			local obstacle = workspace:Blockcast(start, Config.DashCollisionSize, travel, params)
			if obstacle then
				local safe = state.LastFramePosition + travel.Unit * math.max(0, obstacle.Distance - Config.WallPadding)
				correct(state, safe, now, player, feedback)
				return false
			end
		end
	end
	state.LastFramePosition = state.Root.Position
	if elapsed >= Config.ValidationInterval then
		state.LastCheck = now
		state.LastPosition = state.Root.Position
		-- Keep the allowance while delayed predicted physics can still arrive.
		if now >= state.DashCheckUntil then
			state.DashAllowance = 0
		end
	end
	if state.DashOrigin then
		local displacement = state.Root.Position - state.DashOrigin
		local limit = Config.DashDistance
			+ Config.PositionTolerance
			+ maximumSpeed(state) * (Config.ValidationInterval + Config.DashReplicationGrace)
		if Vector3.new(displacement.X, 0, displacement.Z).Magnitude > limit then
			correct(
				state,
				Vector3.new(state.DashOrigin.X, state.Root.Position.Y, state.DashOrigin.Z),
				now,
				player,
				feedback
			)
			return false
		end
		if now >= state.DashCheckUntil then
			state.DashOrigin = nil
		end
	end
	return true
end

return Movement
