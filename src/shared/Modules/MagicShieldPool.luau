--!strict

-- Consumes the already-ordered shield effects on a target.
local Pool = {}

function Pool.consume(effects, amount)
	local remaining = math.max(0, amount)
	local broken = {}

	for _, effect in ipairs(effects) do
		if effect.Kind == "Shield" and remaining > 0 then
			local pool = math.max(0, effect.Amount or 0)
			local used = math.min(pool, remaining)
			effect.Amount = pool - used
			remaining = remaining - used
			if pool > 0 and effect.Amount <= 0 then
				table.insert(broken, effect)
			end
		end
	end

	return remaining, amount - remaining, broken
end

return Pool
