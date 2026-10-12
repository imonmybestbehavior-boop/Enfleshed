-- Paste into Roblox Studio's Command Bar after importing both GLB files.
-- Parent both imported models beneath one Model named StorefrontStreetPilot first.

local root = workspace:FindFirstChild("StorefrontStreetPilot")
assert(root and root:IsA("Model"), "Create Workspace.StorefrontStreetPilot and place both imported models inside it")

local visualCount = 0
local collisionCount = 0

for _, descendant in root:GetDescendants() do
	if not descendant:IsA("BasePart") then
		continue
	end

	descendant.Anchored = true
	descendant.CanTouch = false

	if string.sub(descendant.Name, 1, 4) == "VIS_" then
		visualCount += 1
		descendant.CanCollide = false
		descendant.CanQuery = true
		if descendant:IsA("MeshPart") then
			descendant.RenderFidelity = Enum.RenderFidelity.Automatic
			descendant.CollisionFidelity = Enum.CollisionFidelity.Box
		end
	elseif string.sub(descendant.Name, 1, 4) == "COL_" then
		collisionCount += 1
		descendant.Transparency = 1
		descendant.CastShadow = false
		descendant.CanCollide = true
		descendant.CanQuery = true
		if descendant:IsA("MeshPart") then
			descendant.RenderFidelity = Enum.RenderFidelity.Performance
			descendant.CollisionFidelity = Enum.CollisionFidelity.Box
		end
	end
end

local function findPart(name: string): BasePart?
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

local markers = root:FindFirstChild("PilotMarkers")
if not markers then
	markers = Instance.new("Folder")
	markers.Name = "PilotMarkers"
	markers.Parent = root
end
markers:ClearAllChildren()

local function addMarker(partName: string, markerName: string, color: Color3)
	local source = findPart(partName)
	assert(source, string.format("Missing imported collision part %s", partName))
	local marker = Instance.new("Part")
	marker.Name = markerName
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(2.5, 2.5, 2.5)
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.2
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CFrame = source.CFrame + Vector3.new(0, source.Size.Y / 2 + 2, 0)
	marker.Parent = markers
end

addMarker("COL_Shop06_Floor", "01 Court 17 entrance", Color3.fromRGB(71, 255, 169))
addMarker("COL_CourtyardFloor", "02 Rear courtyard", Color3.fromRGB(71, 255, 169))
addMarker("COL_CourtyardLanding", "03 Upper landing", Color3.fromRGB(71, 255, 169))
addMarker("COL_CatwalkFloor", "04 Catwalk", Color3.fromRGB(71, 255, 169))
addMarker("COL_AlleyWestWall", "05 Exit alley", Color3.fromRGB(71, 255, 169))

local streetFloor = findPart("COL_StreetFloor")
assert(streetFloor, "Missing COL_StreetFloor")
local spawn = root:FindFirstChild("PilotSpawn")
if not (spawn and spawn:IsA("SpawnLocation")) then
	if spawn then
		spawn:Destroy()
	end
	spawn = Instance.new("SpawnLocation")
	spawn.Name = "PilotSpawn"
	spawn.Parent = root
end
spawn.Size = Vector3.new(6, 1, 6)
spawn.Anchored = true
spawn.Neutral = true
spawn.Transparency = 0.35
spawn.Color = Color3.fromRGB(66, 135, 245)
spawn.CFrame = streetFloor.CFrame * CFrame.new(-streetFloor.Size.X / 2 + 8, streetFloor.Size.Y / 2 + 3, 0)

root:SetAttribute("ArtPilot", "LowerLayerStorefrontStreetV1")
root:SetAttribute("VisualMeshCount", visualCount)
root:SetAttribute("CollisionMeshCount", collisionCount)
root:SetAttribute("PilotMarkersCreated", 5)
print(
	string.format(
		"Configured StorefrontStreetPilot: %d visual meshes, %d collision meshes",
		visualCount,
		collisionCount
	)
)
