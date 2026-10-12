local Consent = assert(loadfile("src/shared/Modules/MagicTargetConsentSpec.luau"))()

local function playerWithConsent(value)
	return {
		GetAttribute = function(_, name)
			assert(name == Consent.Attribute)
			return value
		end,
	}
end

local targetModel = {}
local player
local players = {
	GetPlayerFromCharacter = function(_, model)
		if model == targetModel then
			return player
		end
		return nil
	end,
}

assert(Consent.valid(true) and Consent.valid(false))
assert(not Consent.valid("true"), "Consent requests must use a boolean")
assert(Consent.allows(false, targetModel, players), "Consent-free definitions keep legacy behavior")
assert(Consent.allows(true, nil, players), "A missing model is not a player target")

player = nil
assert(Consent.allows(true, {}, players), "NPCs and training targets are not gated")
player = playerWithConsent(false)
assert(not Consent.allows(true, targetModel, players), "Player targets are excluded until opted in")
player = playerWithConsent(true)
assert(Consent.allows(true, targetModel, players), "Opted-in players can receive consent-gated spells")

print("Magic target consent: opt-in, NPC compatibility, and legacy behavior passed")
