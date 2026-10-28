--!strict
-- Pure rules for the Dispel payload (on spells, TargetKind = "Spell").
--   Shorten: cut Seconds (1-30) off a timed spell's remaining time.
--   End: remove the spell if its estimated complexity is at most the dispel
--     spell's own; otherwise halve its remaining time, so a cheap dispel cannot
--     erase an expensive wall.
-- Untimed spells (toggles, persistent) can only be Ended. Persistent (saved)
-- Constructs can only be dispelled by their owner.
local Spec = {}

Spec.Modes = { "Shorten", "End" }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Returns "End", "Shorten" (with the new remaining time) or "None".
-- `remaining` is nil for untimed spells.
function Spec.resolve(
	mode: string,
	seconds: number?,
	remaining: number?,
	targetComplexity: number,
	dispelComplexity: number
): (string, number?)
	local timed = finite(remaining)
	if mode == "End" then
		if targetComplexity <= dispelComplexity then
			return "End", nil
		end
		if timed then
			return "Shorten", (remaining :: number) / 2
		end
		return "None", nil
	elseif mode == "Shorten" and timed and finite(seconds) then
		return "Shorten", math.max(0, (remaining :: number) - math.max(0, seconds :: number))
	end
	return "None", nil
end

-- Persistent (saved) Constructs: only their owner.
function Spec.persistentAllowed(casterUserId: number?, ownerUserId: number?): boolean
	return casterUserId ~= nil and casterUserId == ownerUserId
end

-- Bane when it targets Hostile spells, otherwise Neutral.
function Spec.polarity(spellRelationship: string?): string
	return if (spellRelationship or "Hostile") == "Hostile" then "Bane" else "Neutral"
end

return Spec
