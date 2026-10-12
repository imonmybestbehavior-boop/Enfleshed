--!strict

-- Pure expiry rules for server-owned target status effects.
local Spec = {}

function Spec.isExpired(kind, expiresAt, remaining, now, casterAlive, viewerPresent)
	if not casterAlive or not viewerPresent then
		return true
	end

	if kind == "TimeDilation" then
		return type(expiresAt) ~= "number" or expiresAt ~= expiresAt or expiresAt <= now
	end

	return type(remaining) ~= "number" or remaining ~= remaining or remaining <= 0
end

return Spec
