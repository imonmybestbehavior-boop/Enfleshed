--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox")).Movement
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local Movement = {}

function Movement.sprint(state: Types.PlayerState, enabled: boolean)
	state.Sprinting = enabled
	state.Humanoid.WalkSpeed = if enabled then Config.SprintSpeed else Config.WalkSpeed
end

function Movement.dash(state: Types.PlayerState, now: number): boolean
	if now < state.DashReadyAt or now < state.ReadyAt or now < state.CorrectionUntil then
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
	local budget = Config.SprintSpeed * elapsed + state.DashAllowance + Config.PositionTolerance
	-- Check before every damage sample, not just when advancing the movement anchor.
	if horizontal ~= horizontal or horizontal > budget then
		-- This violation is horizontal: preserve current jumping/falling height.
		correct(
			state,
			Vector3.new(state.LastPosition.X, state.Root.Position.Y, state.LastPosition.Z),
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
			+ Config.SprintSpeed * (Config.ValidationInterval + Config.DashReplicationGrace)
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
