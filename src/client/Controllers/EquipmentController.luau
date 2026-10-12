--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Types = require(Shared.Types.CombatTypes)
local Equipment = {}

function Equipment.start(
	send: (string, Types.ActionOptions?) -> number,
	meleeAttack: () -> (),
	magicAction: (string) -> ()
)
	local player = game:GetService("Players").LocalPlayer
	local activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
	player:GetAttributeChangedSignal("ActiveEquipmentSlot"):Connect(function()
		activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
	end)
	return {
		Use = function(action: string)
			if activeSlot == "SecondaryWeapon" and action == "Primary" then
				meleeAttack()
			elseif activeSlot == "PrimaryWeapon" then
				magicAction(action)
			end
		end,
		Switch = function()
			local slot = if activeSlot == "PrimaryWeapon" then "SecondaryWeapon" else "PrimaryWeapon"
			send(Protocol.EquipmentSwitch, { EquipmentSlot = slot })
		end,
		Feedback = function(message: any)
			if
				message.Kind == "Equipment"
				and (message.ActiveSlot == "PrimaryWeapon" or message.ActiveSlot == "SecondaryWeapon")
			then
				activeSlot = message.ActiveSlot
			end
		end,
		Reset = function()
			activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
		end,
	}
end

return Equipment
