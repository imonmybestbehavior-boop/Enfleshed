--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Types = require(Shared.Types.CombatTypes)
local Magic = {}

local function aim(): (Vector3, Vector3)
	local camera = Workspace.CurrentCamera
	if not camera then
		return Vector3.zAxis, Vector3.zero
	end
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { Players.LocalPlayer.Character or workspace }
	local hit = Workspace:Raycast(origin, direction * 90, ray)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		origin = root.Position
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude > 0 then
			direction = direction.Unit
		end
	end
	return direction, if hit then hit.Position else camera.CFrame.Position + camera.CFrame.LookVector * 90
end

function Magic.start(send: (string, Types.ActionOptions?) -> number)
	local activeSpell: string? = nil
	local function cast(spellId: string)
		local direction, point = aim()
		activeSpell = spellId
		send(Protocol.MagicStart, { SpellId = spellId, AimDirection = direction, WorldPoint = point })
	end
	return {
		Cast = cast,
		Release = function()
			if activeSpell ~= "StoneShot" then
				return
			end
			local direction, point = aim()
			send(Protocol.MagicRelease, { SpellId = activeSpell, AimDirection = direction, WorldPoint = point })
			activeSpell = nil
		end,
		WeaponAction = function(action: string)
			local direction, point = aim()
			send(Protocol.EquipmentUse, { EquipmentAction = action, AimDirection = direction, WorldPoint = point })
		end,
		Reset = function()
			activeSpell = nil
		end,
	}
end

return Magic
