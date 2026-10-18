--!strict
-- Shared building blocks for the siege map: one palette, one part helper and a
-- few reusable pieces (torch, brazier, lantern, banner). Blockout stage: these
-- are well-materialled Parts; DefendTheWallsAssets lists the mesh kit that will
-- replace them piece by piece.
local Kit = {}

Kit.Color = {
	Slate = Color3.fromRGB(52, 56, 62),
	SlateWet = Color3.fromRGB(40, 44, 50),
	Cobble = Color3.fromRGB(70, 68, 64),
	Oak = Color3.fromRGB(52, 38, 28),
	OakPale = Color3.fromRGB(84, 64, 46),
	Iron = Color3.fromRGB(46, 46, 50),
	Moss = Color3.fromRGB(52, 64, 44),
	Mud = Color3.fromRGB(58, 48, 38),
	Plaster = Color3.fromRGB(122, 112, 96),
	Bone = Color3.fromRGB(176, 166, 140),
	Flame = Color3.fromRGB(255, 160, 80),
	Banner = Color3.fromRGB(96, 22, 26),
}

Kit.Material = {
	Wall = Enum.Material.Slate,
	Cobble = Enum.Material.Cobblestone,
	Wood = Enum.Material.WoodPlanks,
	Timber = Enum.Material.Wood,
	Iron = Enum.Material.DiamondPlate,
	Rock = Enum.Material.Rock,
	Plaster = Enum.Material.Plaster,
	Moss = Enum.Material.Grass,
}

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name, f.Parent = name, parent
	return f
end

function Kit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored = true
	p.Material, p.Color = material, color
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide = collide ~= false
	if collide == false then
		p.CanQuery, p.CanTouch = false, false
	end
	p.Parent = parent
	return p
end

function Kit.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3
): WedgePart
	local w = Instance.new("WedgePart")
	w.Name, w.Size, w.CFrame = name, size, cf
	w.Anchored, w.Material, w.Color = true, material, color
	w.Parent = parent
	return w
end

-- Decorative only: no collision, query or touch, and no shadow for tiny bits.
function Kit.detail(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	material: Enum.Material,
	color: Color3
): Part
	local p = Kit.part(parent, name, size, cf, material, color, false)
	if size.Magnitude < 4 then
		p.CastShadow = false
	end
	return p
end

function Kit.light(parent: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = color, range, brightness
	light.Shadows = shadows == true
	light.Parent = parent
	return light
end

local function flame(parent: Instance, cf: CFrame, size: number, color: Color3): Part
	local f = Kit.detail(parent, "Flame", Vector3.new(size, size * 1.4, size), cf, Enum.Material.Neon, color)
	f.Shape = Enum.PartType.Ball
	return f
end

-- Wall-mounted or free-standing torch. Warm light pool; shadows only when asked
-- (shadowed lights are expensive on console, so only hero lights cast them).
function Kit.torch(parent: Instance, base: Vector3, color: Color3?, shadows: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "Torch"
	Kit.detail(
		model,
		"Post",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(base + Vector3.new(0, 3.5, 0)),
		Kit.Material.Timber,
		Kit.Color.Oak
	)
	Kit.detail(
		model,
		"Cup",
		Vector3.new(1.2, 0.8, 1.2),
		CFrame.new(base + Vector3.new(0, 7.2, 0)),
		Kit.Material.Iron,
		Kit.Color.Iron
	)
	local f = flame(model, CFrame.new(base + Vector3.new(0, 8.1, 0)), 1, color or Kit.Color.Flame)
	Kit.light(f, color or Kit.Color.Flame, 22, 1.6, shadows)
	model.Parent = parent
	return model
end

function Kit.brazier(parent: Instance, base: Vector3, shadows: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "Brazier"
	Kit.detail(
		model,
		"Stand",
		Vector3.new(1, 3, 1),
		CFrame.new(base + Vector3.new(0, 1.5, 0)),
		Kit.Material.Iron,
		Kit.Color.Iron
	)
	local bowl = Kit.detail(
		model,
		"Bowl",
		Vector3.new(1.4, 3.6, 3.6),
		CFrame.new(base + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Kit.Material.Iron,
		Kit.Color.Iron
	)
	bowl.Shape = Enum.PartType.Cylinder
	local f = flame(model, CFrame.new(base + Vector3.new(0, 4.6, 0)), 2.4, Kit.Color.Flame)
	Kit.light(f, Kit.Color.Flame, 30, 2.2, shadows)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 4, 6, Kit.Color.Flame, Color3.fromRGB(120, 30, 10)
	fire.Parent = f
	model.Parent = parent
	return model
end

function Kit.lantern(parent: Instance, at: Vector3, color: Color3?): Part
	local hook = Kit.detail(
		parent,
		"LanternChain",
		Vector3.new(0.2, 2, 0.2),
		CFrame.new(at + Vector3.new(0, 1.5, 0)),
		Kit.Material.Iron,
		Kit.Color.Iron
	)
	local glass = Kit.detail(
		parent,
		"Lantern",
		Vector3.new(0.9, 1.2, 0.9),
		CFrame.new(at),
		Enum.Material.Neon,
		color or Kit.Color.Flame
	)
	Kit.light(glass, color or Kit.Color.Flame, 14, 1.2)
	return hook
end

function Kit.banner(parent: Instance, top: CFrame, height: number)
	Kit.detail(parent, "BannerPole", Vector3.new(5, 0.4, 0.4), top, Kit.Material.Timber, Kit.Color.Oak)
	Kit.detail(
		parent,
		"Banner",
		Vector3.new(4, height, 0.15),
		top * CFrame.new(0, -height / 2 - 0.2, 0),
		Enum.Material.Fabric,
		Kit.Color.Banner
	)
end

-- Emissive lane edge strip: keeps lane borders readable in the dark.
function Kit.strip(parent: Instance, a: Vector3, b: Vector3, color: Color3)
	local length = (b - a).Magnitude
	if length < 0.5 then
		return
	end
	local strip = Kit.detail(
		parent,
		"LaneGlow",
		Vector3.new(0.5, 0.2, length),
		CFrame.lookAt((a + b) / 2, b),
		Enum.Material.Neon,
		color
	)
	strip.Transparency = 0.35
end

-- World label: near-only and never drawn through geometry, so labels can't stack.
function Kit.label(parent: BasePart, text: string, color: Color3, maxDistance: number)
	local sign = Instance.new("BillboardGui")
	sign.Size, sign.StudsOffset = UDim2.fromOffset(170, 30), Vector3.new(0, parent.Size.Y / 2 + 3, 0)
	sign.AlwaysOnTop, sign.MaxDistance, sign.LightInfluence = false, maxDistance, 0
	sign.Parent = parent
	local caption = Instance.new("TextLabel")
	caption.Size, caption.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	caption.Text, caption.TextColor3, caption.TextScaled, caption.Font = text, color, true, Enum.Font.GothamBold
	caption.TextStrokeTransparency = 0.4
	caption.Parent = sign
end

function Kit.v(p: { X: number, Z: number }, y: number?): Vector3
	return Vector3.new(p.X, y or 0, p.Z)
end

function Kit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

return Kit
