--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Configuration"):WaitForChild("Sandbox"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local HitDetection = require(script.Parent.HitDetectionService)
local Damage = require(script.Parent.DamageService)
local Combat = {}

function Combat.request(state: Types.PlayerState, now: number): boolean
	if now < state.ReadyAt or now < state.DashUntil or now < state.CorrectionUntil then
		return false
	end
	state.Combo = if now > state.ComboExpires then 1 else state.Combo % #Config.Combat.Attacks + 1
	local attack = Config.Combat.Attacks[state.Combo]
	state.Attack = attack
	state.ActiveAt = now + attack.Startup
	state.ActiveUntil = state.ActiveAt + attack.Active
	state.ReadyAt = state.ActiveUntil + attack.Recovery
	state.ComboExpires = state.ReadyAt + Config.Combat.ComboReset
	state.HitTargets = {}
	return true
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
	for _, target in HitDetection.find(state, attack) do
		if state.HitTargets[target] then
			continue
		end
		state.HitTargets[target] = true
		local amount = Damage.apply(state.Character, target, attack.Damage)
		if amount > 0 then
			local hit: Types.HitResult = { Target = target.Parent :: Model, Damage = amount, Health = target.Health }
			feedback:FireClient(player, {
				Kind = "Hit",
				Character = state.Character,
				Target = hit.Target,
				Damage = hit.Damage,
				Health = hit.Health,
			})
		end
	end
end

return Combat
