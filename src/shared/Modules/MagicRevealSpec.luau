-- Aggregates owner-scoped reveal expiries for one target.
local Reveal = {}

function Reveal.attributeNames(userId)
	local suffix = tostring(userId)
	return "MagicRevealUntil_" .. suffix, "MagicRevealColor_" .. suffix
end

function Reveal.aggregate(effects, now)
	local result = {}
	for _, effect in ipairs(effects) do
		local userId = effect.ViewerUserId
		if effect.Kind == "Reveal" and userId and effect.ExpiresAt > now then
			local previous = result[userId]
			if not previous or effect.ExpiresAt >= previous.ExpiresAt then
				result[userId] = { ExpiresAt = effect.ExpiresAt, Color = effect.Color }
			end
		end
	end
	return result
end

return Reveal
