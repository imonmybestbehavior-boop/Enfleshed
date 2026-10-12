--!strict

-- Consent is a server-owned player preference. Non-player Humanoids are not
-- gated; spells can require opt-in for multiplayer targets without changing
-- NPC or training-dummy behavior.
local Spec = {}
Spec.Attribute = "MagicAcceptsTargetedSpells"

function Spec.valid(value)
	return type(value) == "boolean"
end

function Spec.allows(required, model, players)
	if required ~= true or not model then
		return true
	end
	local player = players:GetPlayerFromCharacter(model)
	return player == nil or player:GetAttribute(Spec.Attribute) == true
end

return Spec
