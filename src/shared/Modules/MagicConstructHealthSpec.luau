--!strict
-- Pure rules for Construct health (Construct.Health). Hits on a Construct's
-- parts lower its health; at zero it is destroyed (OnDestroyed). Persistent
-- Constructs keep their remaining health in their saved record.
local Spec = {}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Starting maximum: authored value within the hard limit and, while the
-- caster can fight players, the PvP MaxConstructHealth of their zone.
function Spec.maxHealth(authored: number?, cap: number?, limit: number): number?
	if not finite(authored) or (authored :: number) <= 0 then
		return nil
	end
	local ceiling = if finite(cap) then math.min(cap :: number, limit) else limit
	return math.clamp(authored :: number, 1, math.max(1, ceiling))
end

-- Who may damage it: NPCs/world (no owner) always; never its own owner;
-- another player only when the combat policy lets them fight the owner.
function Spec.canDamage(attackerUserId: number?, ownerUserId: number?, policyAllows: boolean): boolean
	if attackerUserId == nil then
		return true
	end
	if attackerUserId == ownerUserId then
		return false
	end
	return policyAllows
end

-- Returns (new health, damage taken, destroyed).
function Spec.apply(health: number, amount: number): (number, number, boolean)
	if not finite(amount) or amount <= 0 or health <= 0 then
		return health, 0, health <= 0
	end
	local taken = math.min(health, amount)
	local remaining = health - taken
	return remaining, taken, remaining <= 0
end

-- Saved health back into a live value: missing → full, clamped to (0, max].
function Spec.restore(saved: number?, maxHealth: number): number
	if not finite(saved) then
		return maxHealth
	end
	return math.clamp(saved :: number, 1, maxHealth)
end

return Spec
