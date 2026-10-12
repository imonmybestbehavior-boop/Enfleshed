-- Optional minimum Locus metrics required to execute an authored spell.
local Spec = {}

Spec.Order = { "Capacity", "Efficiency", "Potency", "StrainTolerance", "ComplexityCapacity" }
Spec.Metrics = {
	Capacity = { Label = "Capacity", Maximum = 100000 },
	Efficiency = { Label = "Efficiency", Maximum = 100 },
	Potency = { Label = "Potency", Maximum = 100 },
	StrainTolerance = { Label = "Strain tolerance", Maximum = 100000 },
	ComplexityCapacity = { Label = "Complexity capacity", Maximum = 100000 },
}

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Spec.validate(requirements)
	if requirements == nil then
		return true
	end
	if type(requirements) ~= "table" then
		return false, "Locus requirements must be a table"
	end
	for key, value in pairs(requirements) do
		local metric = Spec.Metrics[key]
		if not metric then
			return false, "Unsupported Locus requirement: " .. tostring(key)
		end
		if not finite(value) or value < 0 or value > metric.Maximum then
			return false, "Minimum " .. metric.Label .. " is outside its supported range"
		end
	end
	return true
end

function Spec.check(requirements, resources)
	local valid, reason = Spec.validate(requirements)
	if not valid then
		return false, reason
	end
	if type(resources) ~= "table" then
		return false, "Locus state unavailable"
	end
	for _, key in ipairs(Spec.Order) do
		local minimum = requirements and requirements[key] or 0
		if minimum > 0 and (not finite(resources[key]) or resources[key] < minimum) then
			return false, string.format("Requires Locus %s ≥ %g", Spec.Metrics[key].Label, minimum)
		end
	end
	return true
end

return Spec
