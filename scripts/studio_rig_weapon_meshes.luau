-- Turns the imported Blender weapon FBXs (assets/weapons/*.fbx, brought in with
-- Home > Import 3D) into rigged weapon models in ReplicatedStorage.Assets.WeaponModels.
-- Run in Studio's Edit DataModel after importing. Looks for a Model named after each
-- weapon anywhere in Workspace, holding MeshParts named by material (Blade, Fittings,
-- Grip, Wood, Thorn). Replaces the stand-in of the same name.
--
-- Values come from tools/weapons/gen_weapons.py, in studs along the blade axis,
-- measured from the grip point (the Blender origin).
local SPEC = {
	Sword = { Bottom = -0.47, Top = 3.16, BladeBase = 0.5, BladeTip = 3.0 },
	Greatsword = { Bottom = -1.15, Top = 4.25, BladeBase = 0.8, BladeTip = 4.05 },
	Dagger = { Bottom = -0.39, Top = 1.57, BladeBase = 0.38, BladeTip = 1.45 },
	Spear = { Bottom = -2.62, Top = 5.05, BladeBase = 4.05, BladeTip = 4.95 },
}
local GRIP_TILT = math.rad(60) -- Rest wrist angle the starter animations were authored with.
local LOOK = {
	Blade = { Enum.Material.Metal, Color3.fromRGB(104, 106, 110) },
	Fittings = { Enum.Material.Metal, Color3.fromRGB(52, 50, 48) },
	Grip = { Enum.Material.Leather, Color3.fromRGB(46, 34, 28) },
	Wood = { Enum.Material.Wood, Color3.fromRGB(86, 62, 40) },
	Thorn = { Enum.Material.Wood, Color3.fromRGB(96, 78, 58) },
}

local folder = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("WeaponModels")
local report = {}

for name, spec in pairs(SPEC) do
	local imported: Model? = nil
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name and d:FindFirstChildWhichIsA("MeshPart", true) then
			imported = d
			break
		end
	end
	if not imported then
		table.insert(report, name .. ": not imported yet")
		continue
	end
	local parts = {}
	for _, d in ipairs(imported:GetDescendants()) do
		if d:IsA("MeshPart") then
			-- The importer may suffix names; match on the material prefix.
			for key in pairs(LOOK) do
				if d.Name:sub(1, #key) == key then
					parts[key] = d
				end
			end
		end
	end
	local gripPart = parts.Grip
	if not gripPart then
		table.insert(report, name .. ": no Grip mesh found")
		continue
	end
	-- Blade axis: the longest bounding-box axis, pointing from the grip toward the head.
	local cf, size = imported:GetBoundingBox()
	local axes = { cf.RightVector * size.X, cf.UpVector * size.Y, cf.LookVector * size.Z }
	table.sort(axes, function(a, b) return a.Magnitude > b.Magnitude end)
	local axis = axes[1].Unit
	local head = parts.Blade or parts.Thorn
	if head and (head.Position - gripPart.Position):Dot(axis) < 0 then
		axis = -axis
	end
	-- Fix the import scale (meters vs studs) from the known overall length.
	local wanted = spec.Top - spec.Bottom
	local scale = wanted / axes[1].Magnitude
	if math.abs(scale - 1) > 0.02 then
		imported:ScaleTo(imported:GetScale() * scale)
		cf, size = imported:GetBoundingBox()
	end
	local bottom = cf.Position - axis * (wanted / 2)
	local origin = bottom + axis * (-spec.Bottom)

	local model = Instance.new("Model")
	model.Name = name
	-- Handle frame: origin at the grip point, +Y along the blade, +X along the edges
	-- (the second-longest axis: guard / blade width), matching the stand-in.
	local right = (axes[2] - axes[2]:Dot(axis) * axis).Unit
	local handleFrame = CFrame.fromMatrix(origin, right, axis)
	for key, part in pairs(parts) do
		part.Name = key
		part.Material = LOOK[key][1]
		part.Color = LOOK[key][2]
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = true
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("SurfaceAppearance") then child:Destroy() end
		end
		part.Parent = model
	end
	gripPart.Name = "Handle"
	for key, part in pairs(parts) do
		if part ~= gripPart then
			local weld = Instance.new("Weld")
			weld.Name = "HandleWeld"
			weld.Part0 = gripPart
			weld.Part1 = part
			weld.C0 = gripPart.CFrame:ToObjectSpace(part.CFrame)
			weld.Parent = part
		end
	end
	local function attach(attName: string, along: number, extra: CFrame?)
		local a = Instance.new("Attachment")
		a.Name = attName
		a.CFrame = gripPart.CFrame:ToObjectSpace(handleFrame * CFrame.new(0, along, 0)) * (extra or CFrame.identity)
		a.Parent = gripPart
		return a
	end
	-- Grip.CFrame is the Motor6D C1: Handle = Hand * RightGripAttachment * Grip^-1,
	-- so the tilt is stored inverted.
	attach("Grip", 0, CFrame.Angles(-GRIP_TILT, 0, 0):Inverse())
	attach("BladeBase", spec.BladeBase)
	attach("BladeTip", spec.BladeTip)
	model.PrimaryPart = gripPart
	model:SetAttribute("Archetype", name)
	model:SetAttribute("Source", "assets/weapons/" .. name .. ".fbx")

	local old = folder:FindFirstChild(name)
	if old then old:Destroy() end
	model.Parent = folder
	imported:Destroy()
	table.insert(report, ("%s: rigged (%d meshes, scale x%.2f)"):format(name, #model:GetChildren(), scale))
end

return table.concat(report, "\n")
