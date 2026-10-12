local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local ROOT_NAME = "StorefrontStreetPilot"
local root = Workspace:FindFirstChild(ROOT_NAME)
if not root then
	root = Instance.new("Model")
	root.Name = ROOT_NAME
	root.Parent = Workspace
end

local visuals = root:FindFirstChild("Visuals")
if not visuals then
	visuals = Instance.new("Model")
	visuals.Name = "Visuals"
	visuals.Parent = root
end

local collisions = root:FindFirstChild("Collision")
if not collisions then
	collisions = Instance.new("Model")
	collisions.Name = "Collision"
	collisions.Parent = root
end

local function isImportedContainer(instance)
	local name = string.lower(instance.Name)
	return string.find(name, "lower_layer_storefront_street", 1, true) ~= nil
		or string.find(name, "storefront_street", 1, true) ~= nil
end

local function importedKind(part)
	if string.sub(part.Name, 1, 4) == "VIS_" then
		return "visual"
	end
	if string.sub(part.Name, 1, 4) == "COL_" then
		return "collision"
	end

	local ancestor = part.Parent
	while ancestor and ancestor ~= Workspace do
		if string.sub(ancestor.Name, 1, 4) == "VIS_" then
			return "visual"
		end
		if string.sub(ancestor.Name, 1, 4) == "COL_" then
			return "collision"
		end
		if isImportedContainer(ancestor) then
			local name = string.lower(ancestor.Name)
			if string.find(name, "collision", 1, true) then
				return "collision"
			end
			if string.find(name, "visual", 1, true) then
				return "visual"
			end
		end
		ancestor = ancestor.Parent
	end
	return nil
end

local visualParts = {}
local collisionParts = {}
for _, instance in ipairs(Workspace:GetDescendants()) do
	if
		instance:IsA("BasePart")
		and not instance:IsDescendantOf(visuals)
		and not instance:IsDescendantOf(collisions)
	then
		local kind = importedKind(instance)
		if kind == "visual" then
			table.insert(visualParts, instance)
		elseif kind == "collision" then
			table.insert(collisionParts, instance)
		end
	end
end

assert(#visualParts > 0, "No storefront visual parts were found. The visual GLB must be imported first.")
assert(#collisionParts > 0, "No storefront collision parts were found. The collision GLB must be imported first.")

for _, part in ipairs(visualParts) do
	local sourceGroup = part.Parent
	if sourceGroup and string.sub(sourceGroup.Name, 1, 4) == "VIS_" then
		part.Name = sourceGroup.Name .. "_" .. part.Name
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if part:IsA("MeshPart") then
		part.RenderFidelity = Enum.RenderFidelity.Automatic
	end
	part.Parent = visuals
end

for _, part in ipairs(collisionParts) do
	local sourceGroup = part.Parent
	if sourceGroup and string.sub(sourceGroup.Name, 1, 4) == "COL_" then
		part.Name = sourceGroup.Name .. "_" .. part.Name
	end
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = true
	part.CanQuery = true
	part.CanTouch = true
	if part:IsA("MeshPart") then
		part.RenderFidelity = Enum.RenderFidelity.Performance
		part.CollisionFidelity = Enum.CollisionFidelity.Box
	end
	part.Parent = collisions
end

local oldMarkers = root:FindFirstChild("PilotMarkers")
if oldMarkers then
	oldMarkers:Destroy()
end

local markers = Instance.new("Folder")
markers.Name = "PilotMarkers"
markers.Parent = root

local boundsCFrame, boundsSize = root:GetBoundingBox()
local routeFractions = {
	Vector3.new(-0.42, 0.05, -0.34),
	Vector3.new(-0.18, 0.05, -0.10),
	Vector3.new(0.02, 0.13, 0.08),
	Vector3.new(0.20, 0.32, 0.20),
	Vector3.new(0.40, 0.08, 0.36),
}

for index, fraction in ipairs(routeFractions) do
	local marker = Instance.new("Part")
	marker.Name = string.format("Route_%02d", index)
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(1.2, 1.2, 1.2)
	marker.Color = Color3.fromRGB(72, 255, 133)
	marker.Material = Enum.Material.Neon
	marker.Anchored = true
	marker.CanCollide = false
	marker.Position = boundsCFrame:PointToWorldSpace(Vector3.new(
		boundsSize.X * fraction.X,
		boundsSize.Y * fraction.Y,
		boundsSize.Z * fraction.Z
	))
	marker.Parent = markers
end

local spawn = root:FindFirstChild("PilotSpawn")
if not spawn then
	spawn = Instance.new("SpawnLocation")
	spawn.Name = "PilotSpawn"
	spawn.Parent = root
end
spawn.Anchored = true
spawn.Neutral = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.Transparency = 0.35
spawn.Position = boundsCFrame:PointToWorldSpace(Vector3.new(-boundsSize.X * 0.46, 1, -boundsSize.Z * 0.42))

root:SetAttribute("Configured", true)
root:SetAttribute("VisualPartCount", #visualParts)
root:SetAttribute("CollisionPartCount", #collisionParts)
root:SetAttribute("PilotRoute", "Street > Court17 > Courtyard > Stairs > Catwalk > Alley")

Selection:Set({ root })
ChangeHistoryService:SetWaypoint("Configured Storefront Street Pilot")
print(string.format("STOREFRONT PILOT READY: %d visual parts, %d collision parts", #visualParts, #collisionParts))
