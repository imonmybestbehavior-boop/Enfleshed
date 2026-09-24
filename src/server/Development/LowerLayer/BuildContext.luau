--!strict

local Lighting = game:GetService("Lighting")
local BuildContext = {}
BuildContext.__index = BuildContext

function BuildContext.new(config: any): any
	local root = Instance.new("Folder")
	root.Name = "LowerLayerGraybox"
	root.Parent = workspace
	local groups: { [string]: Instance } = {}
	for _, name in
		{ "Ancient", "Human", "Military", "Frontline", "Contamination", "Navigation", "SpawnPoints", "Debug" }
	do
		local group = Instance.new("Folder")
		group.Name = name
		group.Parent = root
		groups[name] = group
	end
	-- Only the six distant enclosure surfaces must survive streaming. Detailed
	-- buildings, streets and ancient ribs continue to stream normally.
	local enclosure = Instance.new("Model")
	enclosure.Name = "Enclosure"
	enclosure.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	enclosure.Parent = root
	groups.Enclosure = enclosure
	return setmetatable({ Config = config, Root = root, Groups = groups, PartCount = 0 }, BuildContext)
end

function BuildContext:part(
	group: string,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	collide: boolean?
): Part
	self.PartCount += 1
	local result = Instance.new("Part")
	result.Name, result.Anchored, result.Position, result.Size = name, true, position, size
	result.Color, result.Material = color, Enum.Material.Concrete
	result.CanCollide, result.CanTouch = collide ~= false, false
	result.Parent = self.Groups[group]
	return result
end

function BuildContext:floor(group: string, name: string, position: Vector3, size: Vector3, color: Color3): Part
	local support = self:part(
		"Navigation",
		name .. "Support",
		position - Vector3.new(0, 0.65, 0),
		size + Vector3.new(1, 0.8, 1),
		self.Config.Colors.AncientDark
	)
	support.Transparency = 0.97
	return self:part(group, name, position, size, color, false)
end

function BuildContext:marker(name: string, position: Vector3)
	local result = self:part("SpawnPoints", name, position, Vector3.new(4, 0.2, 4), self.Config.Colors.Light, false)
	result.Material, result.Transparency = Enum.Material.Neon, 0.4
	result:SetAttribute("GrayboxMarker", true)
end

function BuildContext:lamp(position: Vector3, range: number, brightness: number?, shadows: boolean?)
	local fixture =
		self:part("Human", "PracticalLamp", position, Vector3.new(0.6, 1, 0.6), self.Config.Colors.Light, false)
	fixture.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = self.Config.Colors.Light, range, brightness or 1.2
	light.Shadows = shadows == true
	light.Parent = fixture
end

function BuildContext:finish()
	self.Root:SetAttribute("PartCount", self.PartCount)
	self.Root:SetAttribute("Phase", "A")
	Lighting.Ambient, Lighting.OutdoorAmbient = Color3.fromRGB(12, 13, 18), Color3.fromRGB(20, 20, 28)
	Lighting.FogColor = Color3.fromRGB(22, 24, 30)
	Lighting.FogStart, Lighting.FogEnd = 220, 900
end

return BuildContext
