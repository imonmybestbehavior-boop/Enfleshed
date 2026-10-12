-- Pure bounded time-rate math shared by status and periodic-effect runtimes.
local Rate = {}
Rate.Minimum = 0.25
Rate.Maximum = 2

function Rate.configure(minimum, maximum)
	if
		type(minimum) == "number"
		and type(maximum) == "number"
		and minimum > 0
		and minimum <= 1
		and maximum >= 1
		and maximum >= minimum
	then
		Rate.Minimum = minimum
		Rate.Maximum = maximum
	end
end

function Rate.clamp(value)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 1
	end
	return math.max(Rate.Minimum, math.min(Rate.Maximum, value))
end

function Rate.combine(effects, now)
	local value = 1
	for _, effect in ipairs(effects) do
		if effect.Kind == "TimeDilation" and effect.ExpiresAt > now then
			value = value * Rate.clamp(effect.Multiplier)
		end
	end
	return Rate.clamp(value)
end

function Rate.advance(remaining, elapsed, multiplier)
	return math.max(0, remaining - math.max(0, elapsed) * Rate.clamp(multiplier))
end

function Rate.worldDuration(localDuration, multiplier)
	return math.max(0, localDuration) / Rate.clamp(multiplier)
end

return Rate
