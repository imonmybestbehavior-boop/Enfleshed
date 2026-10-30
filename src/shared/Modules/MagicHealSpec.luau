--!strict
-- Pure rules for ratio heals and shields (Heal and Shield payloads).
--
--   Mode = "Flat" (default): Amount is the heal/shield value.
--   Mode = "PercentMaxHealth": Amount is a percent (0-100) of the target's max health.
--   Mode = "PercentDamageDealt": Amount is a percent (0-100) of the damage the
--     triggering hit dealt (OnDamageDealt steps only, e.g. lifesteal).
--   Overflow = "Shield" (Heal only): healing beyond max health becomes a shield.
--
-- Order (Phase 5): authored Amount -> ScaleBy -> Mode -> potency -> caps.
local Spec = {}

Spec.Modes = { "Flat", "PercentMaxHealth", "PercentDamageDealt" }

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The heal/shield value for one target before potency.
function Spec.base(mode: string?, amount: number, maxHealth: number?, damageDealt: number?): number
	local safe = if finite(amount) then math.max(0, amount) else 0
	if mode == "PercentMaxHealth" then
		return (if finite(maxHealth) then math.max(0, maxHealth :: number) else 0) * safe / 100
	elseif mode == "PercentDamageDealt" then
		return (if finite(damageDealt) then math.max(0, damageDealt :: number) else 0) * safe / 100
	end
	return safe
end

-- How much of `requested` healing spills over into a shield, given what the
-- heal actually restored and the per-hit limit it was clamped to.
function Spec.overflow(requested: number, restored: number, limit: number?): number
	local capped = if finite(limit) then math.min(requested, limit :: number) else requested
	return math.max(0, capped - math.max(0, restored))
end

return Spec
