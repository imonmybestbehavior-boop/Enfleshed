--!strict
-- Preserve tick phase despite frame jitter; skip missed ticks instead of bursting.
local Clock = {}
function Clock.advance(nextTick, interval, expires, now)
	if nextTick > expires or now > expires + interval then
		return false, nil
	end
	if now < nextTick then
		return false, nextTick
	end
	local following = nextTick + interval * (math.floor((now - nextTick) / interval) + 1)
	return true, following <= expires and following or nil
end
return Clock
