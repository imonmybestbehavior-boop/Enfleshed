--!strict

local applied = Instance.new("BindableEvent")
local Damage = { Applied = applied.Event }
local Status = require(script.Parent.MagicStatusEffectService)
local Defense = require(script.Parent.MeleeDefenseService)
local Players = game:GetService("Players")
local DamageRules = require(game:GetService("ReplicatedStorage").Shared.Modules.MagicDamageRules)
local CombatPolicy = require(game:GetService("ReplicatedStorage").Shared.Modules.CombatPolicy)
local StatCaps = require(game:GetService("ReplicatedStorage").Shared.Modules.SpellStatCaps)
local CapProfiles = require(game:GetService("ReplicatedStorage").Shared.Configuration.SpellStatCaps)

local function apply(
	attacker: Model,
	target: Humanoid,
	amount: number,
	eventContext: any?,
	melee: boolean
): (number, number, boolean)
	local targetModel = target.Parent
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)
	local attackerOwnerId = attackerPlayer and attackerPlayer.UserId or attacker:GetAttribute("MagicSummonOwnerUserId")
	if targetModel and targetModel:GetAttribute("MissionGateway") == true then
		if attackerOwnerId ~= nil or attacker:GetAttribute("MissionId") ~= targetModel:GetAttribute("MissionId") then
			return 0, 0, false
		end
	end
	local targetOwnerId = targetModel and targetModel:GetAttribute("MagicSummonOwnerUserId")
	if
		target.Parent == attacker
		or target.Health <= 0
		or not target:IsDescendantOf(workspace)
		or (attackerOwnerId ~= nil and attackerOwnerId == targetOwnerId)
		or not CombatPolicy.canDamage(attacker, targetModel, Players)
	then
		return 0, 0, false
	end
	local incoming = math.max(0, amount)
	if targetModel and targetModel:GetAttribute("MissionGateway") == true then
		local scales =
			require(game:GetService("ReplicatedStorage").Shared.Configuration.DefendTheWalls).GatewayDamageScale
		incoming *= scales[attacker:GetAttribute("MissionRole") or "Basic"] or scales.Basic
	end
	incoming = DamageRules.applyOutgoingStrength(incoming, attacker:GetAttribute("MagicStrengthBonus"))
	if eventContext then
		local regionMultiplier = eventContext.RegionMultiplier
		if type(regionMultiplier) == "number" and regionMultiplier == regionMultiplier then
			incoming *= math.clamp(regionMultiplier, 0, 4)
		end
		-- Spell hits: mitigation, then the target's DamageTaken modifier.
		incoming = DamageRules.applyChannel(incoming, targetModel, eventContext.DamageChannel, eventContext.Element)
	else
		-- Melee and other context-free hits still honour DamageTaken.
		incoming = DamageRules.applyDamageTaken(incoming, targetModel)
	end
	if targetModel and targetModel:IsA("Model") then
		incoming = Defense.resolve(attacker, targetModel, incoming, melee)
		local armor = targetModel:GetAttribute("ArmorReduction")
		if type(armor) == "number" and armor == armor then
			incoming *= 1 - math.clamp(armor, 0, 0.9)
		end
	end
	-- PvP stat caps limit the final hit between players who may fight.
	local capProfile =
		StatCaps.profileName(CombatPolicy.owner(attacker, Players), CombatPolicy.owner(targetModel, Players))
	incoming = StatCaps.damage(incoming, CapProfiles[capProfile])
	-- Per-hit cap carried by the hit (PvP damage-over-time ticks), applied last.
	if eventContext and type(eventContext.PerHitCap) == "number" then
		incoming = math.min(incoming, eventContext.PerHitCap)
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
		-- Last argument: IsMelee, true only for DamageService.applyMelee hits (OnMeleeHit).
		applied:Fire(attacker, target, dealt, killed, eventContext, melee)
	end
	for _, effect in brokenShields do
		if effect.OnBreak then
			effect.OnBreak(target)
		end
	end
	return dealt, absorbed, killed
end

function Damage.apply(attacker: Model, target: Humanoid, amount: number, eventContext: any?): (number, number, boolean)
	return apply(attacker, target, amount, eventContext, false)
end

-- Weapon and claw strikes. These are the only hits a guard's opening moment can parry.
function Damage.applyMelee(attacker: Model, target: Humanoid, amount: number): (number, number, boolean)
	return apply(attacker, target, amount, nil, true)
end

return Damage
