--!strict
-- Estimates include display-only upkeep, which belongs to Casting, not saved Cost.
-- Keep the established Cost schema and any authored special-resource costs.
local Cost = {}
function Cost.normalize(definition)
	if type(definition.Cost) == "table" then
		definition.Cost.ManaUpkeepPerSecond = nil
		definition.Cost.StrainPerSecond = nil
	end
end
function Cost.refresh(definition, estimate, clone)
	local previous = definition.Cost or {}
	local values = estimate(definition)
	-- Authored costs survive repricing: special resources and blood magic.
	definition.Cost = {
		ManaDemand = values.ManaDemand,
		Strain = values.Strain,
		Complexity = values.Complexity,
		SpecialResources = clone(previous.SpecialResources or {}),
		Health = if previous.Health then clone(previous.Health) else nil,
		HealthForMana = previous.HealthForMana,
		HealthPerSecond = previous.HealthPerSecond,
	}
end
return Cost
