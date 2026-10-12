-- Shared Construct primitive and bounded composition registry. Geometry is
-- server-authored from these descriptors; clients can choose only a registry key.
local Spec = {}

Spec.Order = { "Box", "Sphere", "Cylinder", "Wedge", "Arch", "Pillar", "Stairs", "Bridge", "Custom" }
Spec.PrimitiveOrder = { "Block", "Ball", "Cylinder", "Wedge" }
Spec.MaxCustomComponents = 5
Spec.MaxComponentLifetime = 15
Spec.DefaultCustomComponent = {
	Shape = "Block",
	SizeX = 0.7,
	SizeY = 0.7,
	SizeZ = 0.7,
	OffsetX = 0,
	OffsetY = 0,
	OffsetZ = 0,
	RotationX = 0,
	RotationY = 0,
	RotationZ = 0,
	Duration = nil,
}

local function piece(shape, sizeScale, offsetScale, rotationDegrees)
	return {
		Shape = shape,
		SizeScale = sizeScale,
		OffsetScale = offsetScale,
		RotationDegrees = rotationDegrees or { 0, 0, 0 },
	}
end

Spec.Definitions = {
	Box = {
		Parts = { piece("Block", { 1, 1, 1 }, { 0, 0, 0 }) },
	},
	Sphere = {
		Parts = { piece("Ball", { 1, 1, 1 }, { 0, 0, 0 }) },
	},
	Cylinder = {
		Parts = { piece("Cylinder", { 1, 1, 1 }, { 0, 0, 0 }, { 0, 0, 90 }) },
	},
	Wedge = {
		Parts = { piece("Wedge", { 1, 1, 1 }, { 0, 0, 0 }) },
	},
	Arch = {
		Parts = {
			piece("Block", { 0.18, 0.82, 1 }, { -0.41, -0.09, 0 }),
			piece("Block", { 0.18, 0.82, 1 }, { 0.41, -0.09, 0 }),
			piece("Block", { 0.82, 0.18, 1 }, { 0, 0.41, 0 }),
		},
	},
	Pillar = {
		Parts = {
			piece("Block", { 0.82, 0.14, 0.82 }, { 0, -0.43, 0 }),
			piece("Block", { 0.62, 0.72, 0.62 }, { 0, 0, 0 }),
			piece("Block", { 0.92, 0.14, 0.92 }, { 0, 0.43, 0 }),
		},
	},
	Stairs = {
		Parts = {},
	},
	Bridge = {
		Parts = {
			piece("Block", { 1, 0.16, 1 }, { 0, -0.34, 0 }),
			piece("Block", { 0.12, 0.18, 1 }, { -0.44, -0.17, 0 }),
			piece("Block", { 0.12, 0.18, 1 }, { 0.44, -0.17, 0 }),
			piece("Block", { 1, 0.14, 0.1 }, { 0, 0.14, -0.45 }),
			piece("Block", { 1, 0.14, 0.1 }, { 0, 0.14, 0.45 }),
		},
	},
	Custom = { Parts = {}, IsCustom = true },
}

for index = 1, 5 do
	local stepCount = 5
	local height = index / stepCount
	table.insert(
		Spec.Definitions.Stairs.Parts,
		piece("Block", { 1, height, 1 / stepCount }, { 0, -0.5 + height / 2, -0.5 + (index - 0.5) / stepCount })
	)
end

function Spec.get(name)
	return Spec.Definitions[name]
end

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function denseCustomArray(components)
	if type(components) ~= "table" or #components < 1 or #components > Spec.MaxCustomComponents then
		return false
	end
	local count = 0
	for key in pairs(components) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > Spec.MaxCustomComponents then
			return false
		end
		count = count + 1
	end
	return count == #components
end

local function rotatedExtents(size, rotationDegrees)
	local x, y, z = math.rad(rotationDegrees[1]), math.rad(rotationDegrees[2]), math.rad(rotationDegrees[3])
	local sx, cx, sy, cy, sz, cz = math.sin(x), math.cos(x), math.sin(y), math.cos(y), math.sin(z), math.cos(z)
	local matrix = {
		{ cy * cz, -cy * sz, sy },
		{ cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy },
		{ sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy },
	}
	return {
		math.abs(matrix[1][1]) * size[1] / 2
			+ math.abs(matrix[1][2]) * size[2] / 2
			+ math.abs(matrix[1][3]) * size[3] / 2,
		math.abs(matrix[2][1]) * size[1] / 2
			+ math.abs(matrix[2][2]) * size[2] / 2
			+ math.abs(matrix[2][3]) * size[3] / 2,
		math.abs(matrix[3][1]) * size[1] / 2
			+ math.abs(matrix[3][2]) * size[2] / 2
			+ math.abs(matrix[3][3]) * size[3] / 2,
	}
end

local function customComponents(components, width, height, depth)
	if not denseCustomArray(components) then
		return nil
	end
	local envelope = { width, height, depth }
	local result = {}
	local allowed = {
		Shape = true,
		SizeX = true,
		SizeY = true,
		SizeZ = true,
		OffsetX = true,
		OffsetY = true,
		OffsetZ = true,
		RotationX = true,
		RotationY = true,
		RotationZ = true,
		Duration = true,
	}
	for _, component in ipairs(components) do
		if type(component) ~= "table" then
			return nil
		end
		for key in pairs(component) do
			if not allowed[key] then
				return nil
			end
		end
		local validShape = false
		for _, shape in ipairs(Spec.PrimitiveOrder) do
			if shape == component.Shape then
				validShape = true
				break
			end
		end
		if not validShape then
			return nil
		end
		local normalizedSize = { component.SizeX, component.SizeY, component.SizeZ }
		local normalizedOffset = { component.OffsetX, component.OffsetY, component.OffsetZ }
		local rotation = { component.RotationX, component.RotationY, component.RotationZ }
		for axis = 1, 3 do
			if not finite(normalizedSize[axis]) or normalizedSize[axis] < 0.05 or normalizedSize[axis] > 1 then
				return nil
			end
			if not finite(normalizedOffset[axis]) or math.abs(normalizedOffset[axis]) > 0.5 then
				return nil
			end
			if not finite(rotation[axis]) or math.abs(rotation[axis]) > 180 then
				return nil
			end
		end
		if
			component.Duration ~= nil
			and (
				not finite(component.Duration)
				or component.Duration < 0.1
				or component.Duration > Spec.MaxComponentLifetime
			)
		then
			return nil
		end
		local size = {
			envelope[1] * normalizedSize[1],
			envelope[2] * normalizedSize[2],
			envelope[3] * normalizedSize[3],
		}
		local offset = {
			envelope[1] * normalizedOffset[1],
			envelope[2] * normalizedOffset[2],
			envelope[3] * normalizedOffset[3],
		}
		local extents = rotatedExtents(size, rotation)
		for axis = 1, 3 do
			if math.abs(offset[axis]) + extents[axis] > envelope[axis] / 2 + 0.001 then
				return nil
			end
		end
		table.insert(result, {
			Shape = component.Shape,
			Size = size,
			Offset = offset,
			RotationDegrees = rotation,
			Duration = component.Duration,
		})
	end
	return result
end

function Spec.components(name, width, height, depth, customParts)
	if name == "Custom" then
		return customComponents(customParts, width, height, depth)
	end
	local definition = Spec.Definitions[name]
	if not definition then
		return nil
	end
	local result = {}
	for _, descriptor in ipairs(definition.Parts) do
		local sizeX = width * descriptor.SizeScale[1]
		local sizeY = height * descriptor.SizeScale[2]
		if descriptor.Shape == "Cylinder" then
			sizeX, sizeY = sizeY, sizeX
		end
		table.insert(result, {
			Shape = descriptor.Shape,
			Size = {
				sizeX,
				sizeY,
				depth * descriptor.SizeScale[3],
			},
			Offset = {
				width * descriptor.OffsetScale[1],
				height * descriptor.OffsetScale[2],
				depth * descriptor.OffsetScale[3],
			},
			RotationDegrees = descriptor.RotationDegrees,
		})
	end
	return result
end

function Spec.dimensions(name, width, height, depth)
	local components = Spec.components(name, width, height, depth)
	local first = components and components[1]
	if not first then
		return width, height, depth
	end
	return first.Size[1], first.Size[2], first.Size[3]
end

function Spec.rotationDegrees(name)
	local definition = Spec.Definitions[name]
	local first = definition and definition.Parts[1]
	local rotation = first and first.RotationDegrees or { 0, 0, 0 }
	return rotation[1], rotation[2], rotation[3]
end

return Spec
