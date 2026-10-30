--!strict

-- Lightweight health table for Constructs with Construct.Health, keyed by the
-- construct record (persistent Constructs get a small record of their own).
-- Rules live in MagicConstructHealthSpec; this module finds the Construct a
-- part belongs to, applies PvP caps and mirrors health onto the model.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local HealthSpec = require(Shared.Modules.MagicConstructHealthSpec)
local CombatPolicy = require(Shared.Modules.CombatPolicy)
local StatCaps = require(Shared.Modules.SpellStatCaps)
local CapProfiles = require(Shared.Configuration.SpellStatCaps)

local Health = {}

export type Entry = {
	Record: any,
	Model: Model,
	OwnerUserId: number?,
	Health: number,
	MaxHealth: number,
	OnChanged: ((Entry) -> ())?,
	OnDestroyed: ((Entry, Model?) -> ())?,
}

local byRecord: { [any]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local byModel: { [Model]: any } = setmetatable({}, { __mode = "k" }) :: any

local function mirror(entry: Entry)
	entry.Model:SetAttribute("MagicConstructHealth", entry.Health)
	entry.Model:SetAttribute("MagicConstructMaxHealth", entry.MaxHealth)
end

function Health.register(
	record: any,
	model: Model,
	ownerUserId: number?,
	maxHealth: number,
	current: number?,
	callbacks: { OnChanged: ((Entry) -> ())?, OnDestroyed: ((Entry, Model?) -> ())? }?
): Entry
	local entry: Entry = {
		Record = record,
		Model = model,
		OwnerUserId = ownerUserId,
		Health = HealthSpec.restore(current, maxHealth),
		MaxHealth = maxHealth,
		OnChanged = callbacks and callbacks.OnChanged,
		OnDestroyed = callbacks and callbacks.OnDestroyed,
	}
	byRecord[record] = entry
	byModel[model] = record
	mirror(entry)
	return entry
end

function Health.unregister(record: any)
	local entry = byRecord[record]
	if entry then
		byRecord[record] = nil
		byModel[entry.Model] = nil
	end
end

function Health.entryForPart(part: Instance): Entry?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local record = byModel[model]
		if record then
			return byRecord[record]
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function ownerOf(userId: number?): any
	if userId == nil then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		-- Offline owner: no zone or duel, so no player can fight it.
		return { UserId = userId, Zone = nil, DuelOpponent = nil }
	end
	return {
		UserId = userId,
		Zone = player:GetAttribute(CombatPolicy.ZoneAttribute),
		DuelOpponent = player:GetAttribute(CombatPolicy.DuelAttribute),
	}
end

-- Applies `amount` from `attacker` (a character, or nil for the world) to the
-- Construct that owns `part`. Returns the damage taken.
function Health.damage(part: Instance, amount: number, attacker: Model?): number
	local entry = Health.entryForPart(part)
	if not entry or entry.Health <= 0 then
		return 0
	end
	local attackerOwner = if attacker then CombatPolicy.owner(attacker, Players) else nil
	local owner = ownerOf(entry.OwnerUserId)
	local allows = attackerOwner ~= nil and CombatPolicy.allows(attackerOwner, owner)
	if not HealthSpec.canDamage(attackerOwner and attackerOwner.UserId, entry.OwnerUserId, allows) then
		return 0
	end
	local profile = CapProfiles[StatCaps.profileName(attackerOwner, owner)]
	local capped = StatCaps.damage(amount, profile)
	local remaining, taken, destroyed = HealthSpec.apply(entry.Health, capped)
	if taken <= 0 then
		return 0
	end
	entry.Health = remaining
	mirror(entry)
	if entry.OnChanged then
		entry.OnChanged(entry)
	end
	if destroyed then
		Health.unregister(entry.Record)
		if entry.OnDestroyed then
			entry.OnDestroyed(entry, attacker)
		end
	end
	return taken
end

return Health
