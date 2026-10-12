-- Paste into Roblox Studio's Command Bar after ConfigureImportedStreet.luau.

local root = workspace:FindFirstChild("StorefrontStreetPilot")
assert(root and root:IsA("Model"), "Workspace.StorefrontStreetPilot is missing")

local visuals = {}
local colliders = {}
local failures = {}

local function fail(message: string)
	table.insert(failures, message)
	warn("STREET PILOT: " .. message)
end

for _, descendant in root:GetDescendants() do
	if not descendant:IsA("BasePart") then
		continue
	end
	if string.sub(descendant.Name, 1, 4) == "VIS_" then
		table.insert(visuals, descendant)
		if not descendant.Anchored then
			fail(descendant.Name .. " is not anchored")
		end
		if descendant.CanCollide then
			fail(descendant.Name .. " still has collision enabled")
		end
	elseif string.sub(descendant.Name, 1, 4) == "COL_" then
		table.insert(colliders, descendant)
		if not descendant.Anchored then
			fail(descendant.Name .. " is not anchored")
		end
		if not descendant.CanCollide then
			fail(descendant.Name .. " is not collidable")
		end
		if descendant.Transparency < 0.99 then
			fail(descendant.Name .. " is still visible")
		end
	end
end

if #visuals ~= 11 then
	fail(string.format("expected 11 visual meshes, found %d", #visuals))
end
if #colliders ~= 53 then
	fail(string.format("expected 53 collision meshes, found %d", #colliders))
end

for _, requiredName in
	{
		"COL_StreetFloor",
		"COL_Shop06_Floor",
		"COL_Court17_BackLeft",
		"COL_Court17_BackRight",
		"COL_CourtStairRamp",
		"COL_CatwalkFloor",
		"COL_AlleyStairRamp",
	}
do
	if not root:FindFirstChild(requiredName, true) then
		fail("missing route collider " .. requiredName)
	end
end

local _, size = root:GetBoundingBox()
local dimensions = { size.X, size.Y, size.Z }
table.sort(dimensions)
if dimensions[1] < 35 or dimensions[1] > 50 then
	fail(string.format("smallest model dimension %.1f studs is outside 35–50", dimensions[1]))
end
if dimensions[2] < 60 or dimensions[2] > 82 then
	fail(string.format("middle model dimension %.1f studs is outside 60–82", dimensions[2]))
end
if dimensions[3] < 100 or dimensions[3] > 120 then
	fail(string.format("largest model dimension %.1f studs is outside 100–120", dimensions[3]))
end

local street = root:FindFirstChild("COL_StreetFloor", true)
if street and street:IsA("BasePart") then
	local streetDimensions = { street.Size.X, street.Size.Y, street.Size.Z }
	table.sort(streetDimensions)
	if streetDimensions[2] < 22 or streetDimensions[2] > 28 then
		fail(string.format("street width %.1f studs is outside 22–28", streetDimensions[2]))
	end
end

if #failures > 0 then
	root:SetAttribute("PilotCheckPassed", false)
	error(string.format("Street pilot failed %d checks; review Output warnings", #failures))
end

root:SetAttribute("PilotCheckPassed", true)
root:SetAttribute("PilotBounds", string.format("%.1f x %.1f x %.1f", size.X, size.Y, size.Z))
print(
	string.format(
		"STREET PILOT READY: %d visuals, %d colliders, bounds %.1f x %.1f x %.1f studs. Press Play and follow the green markers through Court 17.",
		#visuals,
		#colliders,
		size.X,
		size.Y,
		size.Z
	)
)
