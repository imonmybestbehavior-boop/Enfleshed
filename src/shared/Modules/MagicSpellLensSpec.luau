--!strict
-- Pure rules for Field lenses (Field.AffectsSpells): a projectile crossing the
-- Field whose owner matches Who is changed at most once per field:
--   AddMark: on impact, the target gets an elemental mark of that element.
--   ScalePotency (0.5-1.5): multiplies the projectile's potency.
--   Slow (0.3-1.0): multiplies the projectile's speed.
-- A hostile player's projectile is never weakened below the PvP floors.
local Spec = {}

Spec.Who = { "Hostile", "Allied", "Any" }

-- The changes to apply to `projectile` (a table with Lensed = { [field] = true })
-- for `field`'s lens, or nil when this field already changed it.
-- `floors` = { Potency, Slow } when the projectile belongs to a hostile player.
function Spec.apply(projectile: any, field: any, lens: any, floors: any?): any?
	projectile.Lensed = projectile.Lensed or {}
	if projectile.Lensed[field] then
		return nil
	end
	projectile.Lensed[field] = true
	local potency = lens.ScalePotency or 1
	local speed = lens.Slow or 1
	if floors then
		potency = math.max(potency, floors.Potency or potency)
		speed = math.max(speed, floors.Slow or speed)
	end
	return { Potency = potency, Speed = speed, Mark = lens.AddMark }
end

-- Whether a lens has at least one modifier.
function Spec.hasModifier(lens: any): boolean
	return type(lens) == "table" and (lens.AddMark ~= nil or lens.ScalePotency ~= nil or lens.Slow ~= nil)
end

return Spec
