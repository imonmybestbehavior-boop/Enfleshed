--!strict

local applied = Instance.new("BindableEvent")
local Damage = { Applied = applied.Event }
local Status = require(script.Parent.MagicStatusEffectService)
local Players = game:GetService("Players")
local DamageRules = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicDamageRules)

function Damage.apply(attacker: Model, target: Humanoid, amount: number, eventContext: any?): (number, number, boolean)
	local targetModel = target.Parent
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	local attackerOwnerId = attackerPlayer and attackerPlayer.UserId or attacker:GetAttribute("MagicSummonOwnerUserId")
	local targetOwnerId = targetModel and targetModel:GetAttribute("MagicSummonOwnerUserId")
	if
		target.Parent == attacker
		or target.Health <= 0
		or not target:IsDescendantOf(workspace)
		or (attackerOwnerId ~= nil and attackerOwnerId == targetOwnerId)
	then
		return 0, 0, false
	end
	local incoming = math.max(0, amount)
	incoming = DamageRules.applyOutgoingStrength(incoming, attacker:GetAttribute("MagicStrengthBonus"))
	if eventContext then
		local regionMultiplier = eventContext.RegionMultiplier
		if type(regionMultiplier) == "number" and regionMultiplier == regionMultiplier then
			incoming *= math.clamp(regionMultiplier, 0, 4)
		end
		incoming = DamageRules.applyChannel(incoming, targetModel, eventContext.DamageChannel, eventContext.Element)
	end
	local remaining, absorbed, brokenShields = Status.absorb(target, incoming)
	local dealt = 0
	local killed = false
	if remaining > 0 then
		local before = target.Health
		target:TakeDamage(remaining)
		dealt = math.max(0, before - target.Health)
		killed = before > 0 and target.Health <= 0
	end
	if dealt > 0 then
		applied:Fire(attacker, target, dealt, killed, eventContext)
	end
	for _, effect in brokenShields do
		if effect.OnBreak then
			effect.OnBreak(target)
		end
	end
	return dealt, absorbed, killed
end

return Damage
