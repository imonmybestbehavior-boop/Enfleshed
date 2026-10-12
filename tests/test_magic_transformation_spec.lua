local configuration = {
	MagicLab = {
		MinTransformScale = 0.7,
		MaxTransformScale = 1.35,
		MaxCombinedTransformScale = 1.75,
	},
}
local environment = setmetatable({
	script = { Parent = { Parent = { Configuration = configuration } } },
}, { __index = _G })
environment.require = function(_)
	return configuration.MagicLab
end
local spec = assert(loadfile("src/shared/Modules/MagicTransformationSpec.luau", "t", environment))()

assert(spec.clampScale(1.1) == 1.1)
assert(spec.clampScale(3) == 1.35)
assert(spec.clampScale(0.1) == 0.7)
assert(spec.clampScale(math.huge) == nil)
assert(spec.clampScale(0 / 0) == nil)
assert(spec.aggregate({
	{ Kind = "Transformation", Multiplier = 1.2 },
	{ Kind = "Transformation", Multiplier = 1.2 },
}) == 1.44, "Concurrent transforms should combine multiplicatively")
assert(spec.aggregate({
	{ Kind = "Transformation", Multiplier = 1.35 },
	{ Kind = "Transformation", Multiplier = 1.35 },
	{ Kind = "Transformation", Multiplier = 1.35 },
}) == 1.75, "Combined scale must remain bounded")
assert(spec.aggregate({
	{ Kind = "Transformation", Multiplier = 0.7 },
	{ Kind = "Transformation", Multiplier = 0.7 },
}) >= 1 / 1.75, "Shrink stacking must have a lower bound")
assert(spec.aggregate({ { Kind = "Transformation", Multiplier = 1.3, ExpiresAt = 4 } }, 5) == 1)
print("Magic transformation spec: scale bounds, aggregation and expiry filtering passed")
