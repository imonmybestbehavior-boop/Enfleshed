--!strict

-- Polymorph visual swap: hide the character's own parts and weld a small
-- part-built critter to its root. The rig, Humanoid, hitbox, camera and
-- network ownership are untouched. Restoring only touches parts that still
-- belong to the same model, so it is safe after respawn or replacement.
local Visual = {}

export type Handle = { Model: Model, Hidden: { [Instance]: number }, Critter: Model? }

local function buildCritter(root: BasePart, color: Color3): Model
	local critter = Instance.new("Model")
	critter.Name = "MagicPolymorphCritter"
	local function piece(name: string, size: Vector3, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
		part.Parent = critter
	end
	piece("Body", Vector3.new(1.8, 1.4, 2), CFrame.new(0, -1.9, 0))
	piece("Head", Vector3.one * 1.1, CFrame.new(0, -1.3, -1))
	piece("EarLeft", Vector3.new(0.3, 0.7, 0.3), CFrame.new(-0.3, -0.6, -1))
	piece("EarRight", Vector3.new(0.3, 0.7, 0.3), CFrame.new(0.3, -0.6, -1))
	return critter
end

function Visual.apply(model: Model, color: Color3?): Handle?
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local handle: Handle = { Model = model, Hidden = {}, Critter = nil }
	for _, item in model:GetDescendants() do
		if (item:IsA("BasePart") and item ~= root) or item:IsA("Decal") then
			handle.Hidden[item] = (item :: any).Transparency;
			(item :: any).Transparency = 1
		end
	end
	local critter = buildCritter(root, color or Color3.fromRGB(235, 225, 210))
	critter.Parent = model
	handle.Critter = critter
	return handle
end

function Visual.restore(handle: Handle?)
	if not handle then
		return
	end
	if handle.Critter then
		handle.Critter:Destroy()
	end
	for item, transparency in handle.Hidden do
		if item.Parent and item:IsDescendantOf(handle.Model) then
			(item :: any).Transparency = transparency
		end
	end
	table.clear(handle.Hidden)
end

return Visual
