local config = assert(loadfile("src/shared/Configuration/LowerLayerGraybox.luau", "t", {
	Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	},
	Color3 = {
		fromRGB = function(r, g, b)
			return { R = r, G = g, B = b }
		end,
	},
}))()
assert(config.PhaseA.Maximum.X - config.PhaseA.Minimum.X == 1400)
assert(config.PhaseA.Maximum.Z - config.PhaseA.Minimum.Z == 1400)
assert(config.Metrics.PrimaryAvenueWidth == 52 and config.Metrics.MarketCrossAvenueWidth == 42)
assert(config.Metrics.LocalStreetWidth >= 24 and config.Metrics.AlleyWidth >= 12)
assert(config.Boundary.Height >= 800)
local shell = config.Enclosure
for _, axis in ipairs({ "X", "Y", "Z" }) do
	assert(shell.Minimum[axis] < config.PhaseA.Minimum[axis], "Enclosure intersects playable bounds")
	assert(shell.Maximum[axis] > config.PhaseA.Maximum[axis], "Enclosure misses playable bounds")
	assert(shell.Maximum[axis] - shell.Minimum[axis] + shell.Thickness <= 2048, "Enclosure exceeds Part size limit")
end
assert(shell.Minimum.Y + shell.Thickness / 2 < config.Metrics.CatchSurfaceY, "Enclosure blocks catch surface")
local source = assert(io.open("src/server/Development/LowerLayer/PhaseA.luau")):read("*a")
for _, name in ipairs({ "Geometry.build", "AccretedHabitation", "AncientOverheadRib", "PhaseBConstructionGate" }) do
	assert(source:find(name, 1, true), "Missing Phase A feature " .. name)
end
print("PASS: Phase A scale, routes, interiors, and ancient structure contract")
