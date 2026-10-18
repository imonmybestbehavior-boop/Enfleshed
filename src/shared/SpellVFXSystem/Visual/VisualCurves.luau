-- Bounded, nonlinear normalization shared by the visual feature extractor and plan builder.
-- Every function returns a value in [0, 1] for any finite or non-finite input.
local Curves = {}

local function finite(x)
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

function Curves.clamp01(x)
	if not finite(x) then
		return if x == math.huge then 1 else 0
	end
	return math.clamp(x, 0, 1)
end

-- log1p(x) / log1p(ref): strong response at small values, saturates at ref.
function Curves.log(x, ref)
	if not finite(x) then
		return Curves.clamp01(x)
	end
	if x <= 0 then
		return 0
	end
	return math.min(1, math.log(1 + x) / math.log(1 + ref))
end

function Curves.sqrt(x, ref)
	if not finite(x) or x <= 0 then
		return Curves.clamp01(x)
	end
	return math.min(1, math.sqrt(x / ref))
end

function Curves.linear(x, ref)
	if not finite(x) then
		return Curves.clamp01(x)
	end
	return math.clamp(x / ref, 0, 1)
end

-- 1 - e^(-x/k): saturating response for counts.
function Curves.saturate(x, k)
	if not finite(x) or x <= 0 then
		return Curves.clamp01(x)
	end
	return 1 - math.exp(-x / k)
end

function Curves.smoothstep(x, lo, hi)
	local t = Curves.clamp01((finite(x) and (x - lo) / (hi - lo)) or Curves.clamp01(x))
	return t * t * (3 - 2 * t)
end

-- Response shaping used by layer drivers on already-normalized features.
Curves.Shapes = {
	Linear = function(t)
		return t
	end,
	Ease = function(t)
		return t * t * (3 - 2 * t)
	end,
	Soft = function(t)
		return math.sqrt(t)
	end,
	Late = function(t)
		return t * t
	end,
}

function Curves.shape(name, t)
	local f = Curves.Shapes[name or "Linear"] or Curves.Shapes.Linear
	return f(Curves.clamp01(t))
end

function Curves.quantize(x, steps)
	steps = steps or 1000
	return math.floor(Curves.clamp01(x) * steps + 0.5) / steps
end

function Curves.int(x, maximum)
	if not finite(x) or x <= 0 then
		return 0
	end
	return math.min(maximum, math.floor(x + 0.5))
end

return Curves
