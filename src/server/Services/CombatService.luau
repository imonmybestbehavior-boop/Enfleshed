--!strict

-- Server-owned melee timing. Attack numbers come from the equipped weapon's
-- resolved loadout (ItemRules.meleeLoadout); the client only predicts them.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local MeleeConfig = require(Shared.Configuration.MeleeProfiles)
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local HitDetection = require(script.Parent.HitDetectionService)
local Damage = require(script.Parent.DamageService)
local Enemy = require(script.Parent.EnemyService)
local Defense = require(script.Parent.MeleeDefenseService)
local Movement = require(script.Parent.MovementService)
local Combat = {}

-- The client sends the flat direction it swung toward, because the server sees the
-- character's rotation late. Accept it only near the server's own facing.
local function attackFacing(state: Types.PlayerState, direction: any): Vector3?
	if
		typeof(direction) ~= "Vector3"
		or direction.X ~= direction.X
		or direction.Z ~= direction.Z
		or math.abs(direction.Y) >= Config.Movement.DirectionEpsilon
		or direction.Magnitude < 0.9
		or direction.Magnitude > 1.1
	then
		return nil
	end
	local look = state.Root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 or flat.Unit:Dot(direction.Unit) < Config.Combat.MaxFacingCorrectionDot then
		return nil
	end
	return direction.Unit
end

local function begin(state: Types.PlayerState, attack: Types.Attack, now: number, direction: any)
	state.Attack = attack
	state.ActiveAt = now + attack.Startup
	state.ActiveUntil = state.ActiveAt + attack.Active
	state.ReadyAt = state.ActiveUntil + attack.Recovery
	state.ComboExpires = state.ReadyAt + Config.Combat.ComboReset
	state.HitTargets = {}
	state.AttackFacing = attackFacing(state, direction)
	-- A parry bonus is spent on the first swing that starts inside its window.
	if now <= state.ParryBonusUntil then
		state.DamageScale = MeleeConfig.ParryBonus.Multiplier
		state.ParryBonusUntil = 0
	else
		state.DamageScale = 1
	end
end

local function busy(state: Types.PlayerState, now: number): boolean
	return now < state.ReadyAt or now < state.DashUntil or now < state.CorrectionUntil or state.Blocking
end

function Combat.request(state: Types.PlayerState, now: number, loadout: any, direction: any): boolean
	if not loadout or busy(state, now) then
		return false
	end
	local lights = loadout.Lights
	state.Combo = if now > state.ComboExpires or state.Combo < 1 then 1 else state.Combo % #lights + 1
	state.Heavy = false
	begin(state, lights[state.Combo], now, direction)
	return true
end

function Combat.heavy(state: Types.PlayerState, now: number, loadout: any, direction: any): boolean
	if not loadout or busy(state, now) then
		return false
	end
	state.Combo = 0 -- A heavy ends the light chain.
	state.Heavy = true
	begin(state, loadout.Heavy, now, direction)
	state.ComboExpires = 0
	return true
end

function Combat.blockStart(
	player: Player,
	state: Types.PlayerState,
	now: number,
	loadout: any,
	feedback: RemoteEvent
): boolean
	-- A guard can't interrupt a swing's wind-up or hit, but it cancels the recovery after it.
	if not loadout or state.Blocking or now < state.ActiveUntil or now < state.DashUntil then
		return false
	end
	state.Attack = nil
	state.ReadyAt = math.min(state.ReadyAt, now)
	state.Blocking = true
	state.Combo = 0
	local character = state.Character
	Defense.raise(character, {
		StartedAt = now,
		Reduction = loadout.Block.Reduction,
		ParryWindow = loadout.Block.ParryWindow,
		FacingDot = loadout.Block.FacingDot,
		OnParry = function(attacker: Model)
			local humanoid = attacker:FindFirstChildOfClass("Humanoid")
			if humanoid then
				Enemy.onHit(humanoid, "Major")
			end
			if state.Character == character then
				state.ParryBonusUntil = workspace:GetServerTimeNow() + MeleeConfig.ParryBonus.Window
			end
			feedback:FireAllClients({ Kind = "Guard", Result = "Parry", Character = character, Attacker = attacker })
		end,
		OnBlock = function(attacker: Model, prevented: number)
			feedback:FireAllClients({
				Kind = "Guard",
				Result = "Block",
				Character = character,
				Attacker = attacker,
				Prevented = prevented,
			})
		end,
	})
	Movement.refreshSpeed(state)
	return true
end

function Combat.blockEnd(state: Types.PlayerState, now: number): boolean
	if not state.Blocking then
		return false
	end
	state.Blocking = false
	Defense.lower(state.Character)
	Movement.refreshSpeed(state)
	-- A short recovery stops block-cancelling straight into an attack. The client mirrors it.
	state.ReadyAt = math.max(state.ReadyAt, now + Config.Combat.BlockReleaseRecovery)
	return true
end

function Combat.reset(state: Types.PlayerState)
	if state.Blocking then
		state.Blocking = false
		Defense.lower(state.Character)
	end
end

function Combat.update(player: Player, state: Types.PlayerState, now: number, feedback: RemoteEvent)
	local attack = state.Attack
	if not attack then
		return
	end
	if now > state.ActiveUntil then
		state.Attack = nil
		return
	end
	if now < state.ActiveAt then
		return
	end
	local position = state.Root.Position
	local origin = if state.AttackFacing
		then CFrame.lookAt(position, position + state.AttackFacing)
		else state.Root.CFrame
	for _, target in
		HitDetection.find(state.Character, origin, origin * CFrame.new(0, 0, -attack.Offset), attack.Size, {
			OverlapCollisionGroup = Config.Combat.OverlapCollisionGroup,
			MaxDistance = attack.Reach,
			MinimumFacingDot = Config.Combat.MinimumFacingDot,
			RequireLineOfSight = true,
			-- Swings cleave: other bodies in the way don't shield the enemies behind them.
			LineOfSightIgnoresCharacters = true,
		})
	do
		if state.HitTargets[target] then
			continue
		end
		state.HitTargets[target] = true
		local amount = Damage.applyMelee(state.Character, target, attack.Damage * state.DamageScale)
		if amount > 0 then
			-- Ordinary lights damage a Nascent without stopping its committed
			-- pressure; finishers and heavies carry stronger reactions.
			Enemy.onHit(target, attack.Reaction or "Minor")
			local hit: Types.HitResult = { Target = target.Parent :: Model, Damage = amount, Health = target.Health }
			feedback:FireClient(player, {
				Kind = "Hit",
				Character = state.Character,
				Target = hit.Target,
				Damage = hit.Damage,
				Health = hit.Health,
				Heavy = state.Heavy,
			})
		end
	end
end

return Combat
