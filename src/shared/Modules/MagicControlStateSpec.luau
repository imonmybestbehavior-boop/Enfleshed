--!strict
-- Pure rules for Taunt and Fear on NPCs (never players).
--
-- The status service writes these on the NPC model while the effect lasts:
--   MagicForcedTarget (ObjectValue, Value = the taunting caster's model)
--   MagicForcedTargetUntil (server time)
--   MagicFearSource (Vector3, where the fear came from)
--   MagicFearUntil (server time)
-- EnemyService asks `decide` each think, before its player target scan.
local Spec = {}

export type Decision = "Fear" | "Forced" | "Scan"

local function active(untilTime: any, now: number): boolean
	return type(untilTime) == "number" and untilTime > now
end

-- Fear wins over Taunt: a frightened monster disengages even if taunted.
-- A taunt only holds while its caster is still a valid target.
function Spec.decide(now: number, forcedUntil: any, forcedValid: boolean, fearUntil: any): Decision
	if active(fearUntil, now) then
		return "Fear"
	end
	if forcedValid and active(forcedUntil, now) then
		return "Forced"
	end
	return "Scan"
end

-- Of several active effects of one kind, the one that lasts longest decides
-- the target (Taunt) or the source (Fear). Effects: { ExpiresAt, ... }.
function Spec.strongest(effects: { any }, now: number): any?
	local best = nil
	for _, effect in ipairs(effects) do
		if effect.ExpiresAt > now and (best == nil or effect.ExpiresAt > best.ExpiresAt) then
			best = effect
		end
	end
	return best
end

return Spec
