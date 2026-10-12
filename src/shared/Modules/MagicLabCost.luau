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
	local special = definition.Cost and definition.Cost.SpecialResources
	local values = estimate(definition)
	definition.Cost = {
		ManaDemand = values.ManaDemand,
		Strain = values.Strain,
		Complexity = values.Complexity,
		SpecialResources = clone(special or {}),
	}
end
return Cost
