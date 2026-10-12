local spec = assert(loadfile("src/shared/Modules/MagicConstructGeometrySpec.luau"))()
assert(table.concat(spec.Order, ",") == "Box,Sphere,Cylinder,Wedge,Arch,Pillar,Stairs,Bridge,Custom")
for _, name in ipairs(spec.Order) do
	assert(spec.get(name), "listed Construct geometry should resolve: " .. name)
	if name ~= "Custom" then
		local components = spec.components(name, 8, 6, 4)
		assert(
			components and #components > 0 and #components <= 5,
			"Construct component count must stay bounded: " .. name
		)
		for _, component in ipairs(components) do
			assert(component.Size[1] > 0 and component.Size[2] > 0 and component.Size[3] > 0)
			local worldSize = component.Size
			if component.Shape == "Cylinder" then
				worldSize = { component.Size[2], component.Size[1], component.Size[3] }
			end
			for axis = 1, 3 do
				assert(math.abs(component.Offset[axis]) + worldSize[axis] / 2 <= ({ 4, 3, 2 })[axis] + 0.001)
			end
		end
	end
end
assert(spec.get("Mesh") == nil, "unregistered Construct geometry must be rejected")
assert(spec.dimensions("Box", 4, 6, 8) == 4)
local width, height, depth = spec.dimensions("Cylinder", 4, 6, 8)
assert(width == 6 and height == 4 and depth == 8, "Cylinder axis mapping should be explicit")
local x, y, z = spec.rotationDegrees("Cylinder")
assert(x == 0 and y == 0 and z == 90, "Cylinder should orient its local long axis vertically")
x, y, z = spec.rotationDegrees("Wedge")
assert(x == 0 and y == 0 and z == 0)
assert(#spec.components("Arch", 8, 6, 4) == 3, "Arch should be composed from structural legs and lintel")
assert(#spec.components("Pillar", 8, 6, 4) == 3, "Pillar should include foot, shaft, and capital")
assert(#spec.components("Stairs", 8, 6, 4) == 5, "Stairs should provide five connected risers")
assert(#spec.components("Bridge", 8, 6, 4) == 5, "Bridge should include a deck, rails, and edge beams")
local customDefinition = {
	{
		Shape = "Block",
		SizeX = 0.2,
		SizeY = 0.8,
		SizeZ = 0.8,
		OffsetX = -0.4,
		OffsetY = 0,
		OffsetZ = 0,
		RotationX = 0,
		RotationY = 0,
		RotationZ = 0,
		Duration = 4,
	},
	{
		Shape = "Cylinder",
		SizeX = 0.4,
		SizeY = 0.4,
		SizeZ = 0.8,
		OffsetX = 0.25,
		OffsetY = 0,
		OffsetZ = 0,
		RotationX = 0,
		RotationY = 0,
		RotationZ = 0,
	},
}
local custom = spec.components("Custom", 10, 8, 6, customDefinition)
assert(custom and #custom == 2, "Custom geometry should resolve authored primitive components")
assert(custom[1].Size[1] == 2 and custom[1].Offset[1] == -4, "Custom components should scale inside their envelope")
assert(custom[1].Duration == 4, "Custom component lifetime should pass through to runtime geometry")
local invalidCustom = spec.components("Custom", 10, 8, 6, {
	{
		Shape = "Block",
		SizeX = 1,
		SizeY = 1,
		SizeZ = 1,
		OffsetX = 0.1,
		OffsetY = 0,
		OffsetZ = 0,
		RotationX = 0,
		RotationY = 0,
		RotationZ = 0,
	},
})
assert(not invalidCustom, "Custom component bounds must fit inside the overall Construct envelope")
invalidCustom = spec.components("Custom", 8, 2, 6, {
	{
		Shape = "Block",
		SizeX = 0.8,
		SizeY = 0.05,
		SizeZ = 0.05,
		OffsetX = 0,
		OffsetY = 0,
		OffsetZ = 0,
		RotationX = 0,
		RotationY = 0,
		RotationZ = 45,
	},
})
assert(not invalidCustom, "Rotated custom bounds must fit the Construct envelope")
invalidCustom = spec.components("Custom", 10, 8, 6, {
	customDefinition[1],
	customDefinition[2],
	customDefinition[1],
	customDefinition[2],
	customDefinition[1],
	customDefinition[2],
})
assert(not invalidCustom, "Custom geometry should enforce its five-part limit")
local timedPart = {}
for key, value in pairs(customDefinition[1]) do
	timedPart[key] = value
end
timedPart.Duration = spec.MaxComponentLifetime + 0.1
assert(
	not spec.components("Custom", 10, 8, 6, { timedPart }),
	"Custom component lifetime should stay inside its maximum"
)
timedPart.Duration = 0
assert(
	not spec.components("Custom", 10, 8, 6, { timedPart }),
	"Custom component lifetime should require a positive bounded duration"
)
print("Magic Construct geometry spec: bounded registry, compositions, dimensions, and orientation passed")
