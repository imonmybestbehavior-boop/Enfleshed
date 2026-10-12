local Growth = assert(loadfile("src/shared/Modules/MagicAreaGrowth.luau"))()

local static = { Radius = 8 }
assert(Growth.scale(static, 4) == 1, "Areas without growth must retain their authored size")
assert(Growth.area(static, 1) == static, "Static scale should preserve the original table")

local growing = {
	Radius = 8,
	Height = 6,
	GrowthStartScale = 0.5,
	GrowthEndScale = 1.5,
	GrowthDuration = 4,
}
assert(Growth.scale(growing, -1) == 0.5, "Expansion starts at the authored start scale")
assert(Growth.scale(growing, 2) == 1, "Expansion interpolates linearly over its duration")
assert(Growth.scale(growing, 8) == 1.5, "Expansion holds its final scale after the duration")

local scaled = Growth.area(growing, Growth.scale(growing, 1))
assert(scaled ~= growing and scaled.Radius == 6 and scaled.Height == 4.5, "All spatial dimensions scale together")
assert(scaled.GrowthDuration == growing.GrowthDuration, "Runtime scaling must preserve authored settings")
assert(growing.Radius == 8, "Scaling must not mutate the registered spell definition")

local ring = Growth.area({ InnerRadius = 2, OuterRadius = 8, Height = 4 }, 1.5)
assert(ring.InnerRadius == 3 and ring.OuterRadius == 12 and ring.Height == 6, "Ring hole and outer edge scale together")

local wave = { Range = 10, Dot = 0.25, GrowthStartScale = 0.5, GrowthEndScale = 1.5, GrowthDuration = 2 }
local expandingWave = Growth.area(wave, Growth.scale(wave, 2))
assert(expandingWave.Range == 15 and expandingWave.Dot == wave.Dot, "Wave reach scales without changing cone spread")
assert(wave.Range == 10, "Wave scaling must not mutate its registered hit range")

local beam = { Range = 40, Width = 2, GrowthStartScale = 0.5, GrowthEndScale = 1.5, GrowthDuration = 2 }
local expandingBeam = Growth.area(beam, Growth.scale(beam, 2))
assert(expandingBeam.Range == 60 and expandingBeam.Width == 3, "Beam range and hit width must scale together")
assert(beam.Range == 40 and beam.Width == 2, "Beam scaling must not mutate its registered geometry")

local construct = {
	Width = 4,
	Height = 6,
	Depth = 2,
	GrowthStartScale = 0.25,
	GrowthEndScale = 1.5,
	GrowthDuration = 3,
}
assert(Growth.scale(construct, 0) == 0.25, "Construct should begin at its configured scale")
assert(Growth.scale(construct, 1.5) == 0.875, "Construct expansion should interpolate over active age")
assert(Growth.scale(construct, 4) == 1.5, "Construct should hold its final scale")
local scaledConstruct = Growth.area(construct, Growth.scale(construct, 1.5))
assert(
	scaledConstruct.Width == 3.5 and scaledConstruct.Height == 5.25 and scaledConstruct.Depth == 1.75,
	"Construct dimensions should expand together"
)
assert(construct.Width == 4, "Construct expansion math must not mutate its definition")

print("Magic growth: areas, Waves, Beams, and Constructs interpolate without mutating definitions")
