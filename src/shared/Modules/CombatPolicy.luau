--!strict
-- Who may damage whom. Player-owned combatants (characters and their summons)
-- never damage each other unless both owners stand in an open-PvP zone or have
-- an accepted duel with each other. NPCs, enemies and world targets are not gated.
-- Both attributes are server-owned and set on the Player instance.
local Policy = {}

Policy.ZoneAttribute = "PvPZone" -- "Open" or "Ranked" while inside a PvP area; nil elsewhere
Policy.DuelAttribute = "DuelOpponentUserId" -- UserId of the accepted duel opponent
Policy.OpenZone = "Open"
Policy.RankedZone = "Ranked"

export type Owner = {
	UserId: number,
	Zone: any,
	DuelOpponent: any,
}

-- attacker/target are nil when the combatant is not player-owned.
function Policy.allows(attacker: Owner?, target: Owner?): boolean
	if attacker == nil or target == nil then
		return true
	end
	if attacker.UserId == target.UserId then
		return false
	end
	-- Both players in the same PvP zone (open or ranked).
	if (attacker.Zone == Policy.OpenZone or attacker.Zone == Policy.RankedZone) and attacker.Zone == target.Zone then
		return true
	end
	return attacker.DuelOpponent == target.UserId and target.DuelOpponent == attacker.UserId
end

-- Resolves the owning player's policy state for a combatant model.
function Policy.owner(model: Instance?, players: any): Owner?
	if not model then
		return nil
	end
	local player = players:GetPlayerFromCharacter(model)
	if not player then
		local ownerId = model:GetAttribute("MagicSummonOwnerUserId")
		if type(ownerId) ~= "number" then
			return nil
		end
		player = players:GetPlayerByUserId(ownerId)
		if not player then
			-- Summon of a player who left: still player-owned, never PvP-eligible.
			return { UserId = ownerId, Zone = nil, DuelOpponent = nil }
		end
	end
	return {
		UserId = player.UserId,
		Zone = player:GetAttribute(Policy.ZoneAttribute),
		DuelOpponent = player:GetAttribute(Policy.DuelAttribute),
	}
end

-- Non-damage payloads that harm or impede the target. Damage itself is gated in
-- DamageService; helpful payloads (Heal, Shield, Restoration…) stay unrestricted.
local hostileKinds = {
	DamageOverTime = true,
	Slow = true,
	Bind = true,
	Control = true,
	Force = true,
	Displacement = true,
	Reveal = true,
	Transformation = true,
	ElementalMark = true,
	ConsumeElementalMark = true,
	Stun = true,
	Silence = true,
	Taunt = true,
	Fear = true,
	DrainResource = true,
}

function Policy.isHostilePayload(payload: any): boolean
	if type(payload) ~= "table" then
		return false
	end
	local kind = payload.Kind
	if hostileKinds[kind] then
		return true
	elseif kind == "ModifyAttribute" then
		return type(payload.Amount) ~= "number" or payload.Amount < 0
	elseif kind == "TimeDilation" then
		return type(payload.Rate) ~= "number" or payload.Rate < 1
	elseif kind == "Transformation" then
		-- Polymorph turns someone into a critter; Scale and Shapeshift do not harm.
		return payload.Mode == "Polymorph"
	elseif kind == "Cleanse" then
		-- Stripping Boons harms the target; removing Banes helps them.
		return payload.Remove ~= "Banes"
	end
	return false
end

function Policy.canDamage(attacker: Instance?, target: Instance?, players: any): boolean
	return Policy.allows(Policy.owner(attacker, players), Policy.owner(target, players))
end

return Policy
