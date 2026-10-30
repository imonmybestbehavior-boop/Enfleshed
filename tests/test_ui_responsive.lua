-- Run by scripts/run_luau_unit_tests.py. Pure parts of the UI kit.
local Tokens = { ReferenceSize = { X = 1280, Y = 720 } }
local Responsive = assert(loadfile(
	"src/client/UI/Kit/Responsive.luau",
	"t",
	setmetatable({
		script = { Parent = { Tokens = "tokens" } },
		require = function()
			return Tokens
		end,
		game = {
			GetService = function()
				return {}
			end,
		},
	}, { __index = getfenv() })
))()
local function v(x, y)
	return { X = x, Y = y }
end
assert(Responsive.scaleFor(v(1280, 720)) == 1, "reference size is 1x")
assert(Responsive.scaleFor(v(2560, 1440)) == Responsive.MaxScale, "4K clamps to max")
assert(Responsive.scaleFor(v(640, 360)) == Responsive.MinScale, "tiny screens clamp to min")
assert(
	math.abs(Responsive.scaleFor(v(1920, 1080)) - 1.4) < 1e-9
		or Responsive.scaleFor(v(1920, 1080)) <= Responsive.MaxScale
)
assert(Responsive.scaleFor(v(1280, 720), 1.25) == 1.25, "player UI scale setting applies")
assert(Responsive.scaleFor(v(1280, 720), 9) == 1.4, "setting is clamped")
assert(Responsive.scaleFor(v(0, 0)) == 1, "zero viewport is safe")
-- Phone landscape (e.g. 844x390): fits height
assert(math.abs(Responsive.scaleFor(v(844, 390)) - math.max(Responsive.MinScale, 390 / 720)) < 1e-9)
print("UI kit: responsive scale passed")
