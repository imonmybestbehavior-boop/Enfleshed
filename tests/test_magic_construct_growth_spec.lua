local Spec = assert(loadfile("src/shared/Modules/MagicConstructGrowthSpec.luau"))()

local static = { Width = 8, Height = 8, Depth = 1 }
assert(Spec.validate(static), "Constructs without growth values should remain static")
assert(
	Spec.validate({
		Width = 4,
		Height = 6,
		Depth = 2,
		GrowthStartScale = 0.25,
		GrowthEndScale = 1.5,
		GrowthDuration = 3,
	}),
	"bounded Construct growth should validate"
)

local incomplete = {
	Width = 4,
	Height = 6,
	Depth = 2,
	GrowthStartScale = 0.5,
	GrowthEndScale = 1.5,
}
assert(not Spec.validate(incomplete), "growth must specify start, end, and duration together")

local oversized = {
	Width = 12,
	Height = 6,
	Depth = 2,
	GrowthStartScale = 0.5,
	GrowthEndScale = 2,
	GrowthDuration = 3,
}
assert(not Spec.validate(oversized), "expanded width must respect the 20-stud cap")

local overVolume = {
	Width = 10,
	Height = 12,
	Depth = 6,
	GrowthStartScale = 0.5,
	GrowthEndScale = 1.5,
	GrowthDuration = 3,
}
assert(not Spec.validate(overVolume), "expanded volume must respect the 2,000-stud cap")
assert(not Spec.validate({
	Width = 4,
	Height = 6,
	Depth = 2,
	GrowthStartScale = 2.1,
	GrowthEndScale = 1,
	GrowthDuration = 3,
}), "scale must be bounded")

print("Magic Construct growth spec: static compatibility, complete settings, and expanded limits passed")
