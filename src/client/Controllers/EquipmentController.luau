--!strict

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Types = require(Shared.Types.CombatTypes)
local Equipment = {}

-- Melee: primary fires a light attack on press (the chain length depends on the weapon),
-- the heavy key fires a heavy, and holding secondary blocks (its opening is the parry window).
function Equipment.start(send: (string, Types.ActionOptions?) -> number, combat: any, magicAction: (string) -> ())
	local player = game:GetService("Players").LocalPlayer
	local activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
	player:GetAttributeChangedSignal("ActiveEquipmentSlot"):Connect(function()
		activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
	end)

	local function releaseAll()
		combat.Block(false)
	end

	return {
		Use = function(action: string, phase: string?)
			local began = phase ~= "End"
			if activeSlot == "SecondaryWeapon" then
				if action == "Primary" and began then
					combat.Attack()
				elseif action == "Heavy" and began then
					combat.Heavy()
				elseif action == "Area" then
					combat.Block(began)
				end
			elseif activeSlot == "PrimaryWeapon" and began and action ~= "Heavy" then
				magicAction(action)
			end
		end,
		Switch = function()
			releaseAll()
			local slot = if activeSlot == "PrimaryWeapon" then "SecondaryWeapon" else "PrimaryWeapon"
			send(Protocol.EquipmentSwitch, { EquipmentSlot = slot })
		end,
		Feedback = function(message: any)
			if
				message.Kind == "Equipment"
				and (message.ActiveSlot == "PrimaryWeapon" or message.ActiveSlot == "SecondaryWeapon")
			then
				if message.ActiveSlot ~= activeSlot then
					releaseAll()
				end
				activeSlot = message.ActiveSlot
			end
		end,
		Reset = function()
			activeSlot = player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon"
		end,
	}
end

return Equipment
