-- Aggregates explicit movement statuses without owning Humanoid properties.
local Effects = {}

function Effects.multiplier(active, now)
	local multiplier = 1
	for _, effect in ipairs(active) do
		if effect.ExpiresAt > now then
			if effect.Kind == "Bind" then
				return 0
			elseif effect.Kind == "Slow" then
				multiplier = math.min(multiplier, effect.Multiplier or 1)
			end
		end
	end
	return multiplier
end

return Effects
