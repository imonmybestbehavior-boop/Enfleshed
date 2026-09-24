--!strict

local Builders = {}

function Builders.street(ctx: any, name: string, position: Vector3, size: Vector3, color: Color3)
	ctx:floor("Human", name, position, size, color)
	for offset = -size.Z / 2 + 30, size.Z / 2 - 10, 60 do
		ctx:lamp(position + Vector3.new(-size.X / 2 + 4, 8, offset), 28)
	end
end

function Builders.partial(ctx: any, name: string, position: Vector3, size: Vector3)
	local c = ctx.Config.Colors
	ctx:floor("Human", name .. "Apron", position, Vector3.new(size.X, 0.3, size.Z), c.HumanDark)
	for floor = 0, 2 do
		local y = floor * 10 + 5
		ctx:part(
			"Human",
			name .. "Frontage",
			position + Vector3.new(0, y, -size.Z / 2 + 2),
			Vector3.new(size.X, 10, 4),
			if floor % 2 == 0 then c.HumanDark else c.Human
		)
		ctx:part(
			"Human",
			name .. "RearMass",
			position + Vector3.new(0, y, size.Z / 2 - 3),
			Vector3.new(size.X, 10, 6),
			c.HumanDark
		)
		ctx:part(
			"Human",
			name .. "SideWing",
			position + Vector3.new(size.X / 2 - 3, y, 0),
			Vector3.new(6, 10, size.Z - 8),
			c.Human
		)
		ctx:part(
			"Human",
			name .. "UpperSlab",
			position + Vector3.new(0, y + 5, 0),
			Vector3.new(size.X - 10, 1, size.Z - 12),
			c.HumanDark,
			false
		)
	end
	ctx:part(
		"Human",
		name .. "RoofAddition",
		position + Vector3.new(-size.X * 0.2, 36, size.Z * 0.15),
		Vector3.new(size.X * 0.55, 8, size.Z * 0.45),
		c.Human
	)
	ctx:part(
		"Human",
		name .. "Balcony",
		position + Vector3.new(-size.X * 0.25, 18, -size.Z / 2 - 2),
		Vector3.new(size.X * 0.35, 1, 8),
		c.Human,
		false
	)
end

function Builders.throughBuilding(
	ctx: any,
	name: string,
	position: Vector3,
	width: number,
	depth: number,
	upper: boolean
)
	local c = ctx.Config.Colors
	ctx:floor("Human", name .. "InteriorFloor", position, Vector3.new(width, 0.35, depth), c.Human)
	for _, x in { -width / 2 + 2, width / 2 - 2 } do
		ctx:part("Human", name .. "SideWall", position + Vector3.new(x, 8, 0), Vector3.new(4, 16, depth), c.HumanDark)
	end
	ctx:part(
		"Human",
		name .. "InteriorDivider",
		position + Vector3.new(0, 5, 0),
		Vector3.new(width - 10, 10, 2),
		c.HumanDark
	)
	ctx:part(
		"Human",
		name .. "FrontFrameLeft",
		position + Vector3.new(-width / 2 + 5, 7, -depth / 2),
		Vector3.new(4, 14, 3),
		c.HumanDark
	)
	ctx:part(
		"Human",
		name .. "FrontFrameRight",
		position + Vector3.new(width / 2 - 5, 7, -depth / 2),
		Vector3.new(4, 14, 3),
		c.HumanDark
	)
	if upper then
		local y = ctx.Config.Metrics.UpperRouteHeight
		ctx:floor(
			"Human",
			name .. "UpperFloor",
			position + Vector3.new(0, y, 0),
			Vector3.new(width - 8, 0.35, depth * 0.55),
			c.HumanDark
		)
		for step = 0, 32 do
			ctx:floor(
				"Human",
				name .. "Stair",
				position + Vector3.new(-width / 2 + 8, step * 2.25, -depth / 2 + 8 + step * 0.9),
				Vector3.new(10, 0.5, 8),
				c.Human
			)
		end
	end
end

function Builders.ancient(ctx: any, name: string, position: Vector3, size: Vector3)
	return ctx:part("Ancient", name, position, size, ctx.Config.Colors.Ancient)
end

return Builders
