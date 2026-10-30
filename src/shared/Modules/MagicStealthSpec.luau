--!strict
-- Pure rules for Stealth.
--
-- A stealthed character carries the replicated MagicStealthed attribute.
-- Monsters always skip stealthed characters when choosing a target.
-- Players: hidden from another player only when the PvP profile setting
-- StealthHidesFromPlayers is on (false for now), the two players may fight,
-- and the viewer has not Revealed them (MagicRevealSpec attribute for that
-- viewer). Turning the setting on needs no new code.
local RevealSpec = require(script.Parent.MagicRevealSpec)
local Spec = {}

-- Whether a monster's target scan should skip this character.
function Spec.hiddenFromMonsters(stealthed: any): boolean
	return stealthed == true
end

-- Whether `viewerUserId` should not see the target. `read(name)` returns the
-- target's attribute (so the Reveal attribute name comes from MagicRevealSpec).
function Spec.hiddenFrom(
	viewerUserId: number,
	read: (string) -> any,
	isSelf: boolean,
	canFight: boolean,
	setting: boolean,
	now: number
): boolean
	if not setting or isSelf or not canFight or read("MagicStealthed") ~= true then
		return false
	end
	local revealUntil = read((RevealSpec.attributeNames(viewerUserId)))
	if type(revealUntil) == "number" and revealUntil > now then
		return false -- revealed to this viewer
	end
	return true
end

-- The setting from the PvP profiles: hiding applies if any PvP profile enables it.
function Spec.hidesFromPlayers(profiles: any): boolean
	for _, profile in pairs(profiles or {}) do
		if type(profile) == "table" and profile.StealthHidesFromPlayers == true then
			return true
		end
	end
	return false
end

return Spec
