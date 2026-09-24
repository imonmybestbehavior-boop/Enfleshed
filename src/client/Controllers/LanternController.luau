--!strict

local Players = game:GetService("Players")
local Lantern = {}

function Lantern.start()
	local player = Players.LocalPlayer
	local attachment: Attachment? = nil
	local function clear()
		if attachment then
			attachment:Destroy()
			attachment = nil
		end
	end
	local function bind(character: Model)
		clear()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if player.Character ~= character or not root or not root:IsA("BasePart") then
			return
		end
		local anchor = Instance.new("Attachment")
		anchor.Name = "LocalFieldLantern"
		anchor.Position = Vector3.new(0, 2.2, -1.4)
		anchor.Parent = root
		attachment = anchor
		local light = Instance.new("PointLight")
		light.Name = "FieldLantern"
		light.Color = Color3.fromRGB(255, 203, 146)
		light.Range, light.Brightness, light.Shadows = 36, 3.25, true
		light.Parent = anchor
	end
	player.CharacterRemoving:Connect(clear)
	player.CharacterAdded:Connect(bind)
	if player.Character then
		task.spawn(bind, player.Character)
	end
end

return Lantern
