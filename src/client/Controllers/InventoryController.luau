--!strict

-- Client mirror of the server inventory. It never mutates items locally: every
-- change is a request, and the server answers with a full snapshot.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Rules = require(Shared.Modules.ItemRules)
local Model = require(Shared.Modules.InventoryModel)
local InventoryController = {}

local Keys = {
	Toggle = Enum.KeyCode.I,
	Quick = { Enum.KeyCode.Y, Enum.KeyCode.U },
}
InventoryController.Keys = Keys

function InventoryController.start()
	local player = Players.LocalPlayer
	local remote = Shared:WaitForChild(Protocol.Folder):WaitForChild(Protocol.Inventory) :: RemoteEvent
	local changed = Instance.new("BindableEvent")
	local noticed = Instance.new("BindableEvent")
	local inventory = Model.blank()
	local loaded = false

	local controller = {}
	controller.Changed = changed.Event
	controller.Notice = noticed.Event
	controller.Keys = Keys

	function controller.Get(): Model.Inventory
		return inventory
	end

	function controller.Loaded(): boolean
		return loaded
	end

	function controller.Request(message: { [string]: any })
		remote:FireServer(message)
	end

	-- Predicted melee loadout for the active weapon; the server re-resolves it authoritatively.
	function controller.MeleeLoadout(): any?
		if (player:GetAttribute("ActiveEquipmentSlot") or "SecondaryWeapon") ~= "SecondaryWeapon" then
			return nil
		end
		return Rules.meleeLoadout(inventory.Equip.MainHand)
	end

	remote.OnClientEvent:Connect(function(message)
		if type(message) ~= "table" then
			return
		end
		if message.Kind == "Snapshot" then
			inventory = Model.deserialize(message.Items)
			loaded = true
			changed:Fire()
		elseif message.Kind == "Notice" and type(message.Text) == "string" then
			noticed:Fire(message.Text)
		elseif message.Kind == "Rejected" then
			local reasons = {
				Rejected = "That item does not fit there",
				SwapRejected = "Those items cannot swap places",
				Full = "Inventory full",
				CannotDrop = "That item cannot be dropped",
			}
			local text = reasons[message.Reason]
			if text then
				noticed:Fire(text)
			end
		end
	end)

	local view = require(script.Parent.Parent.UI.InventoryView).new(controller)
	controller.View = view

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Keys.Toggle then
			if player:GetAttribute("MagicLabOpen") ~= true then
				view.SetOpen(not view.IsOpen())
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and view.IsOpen() then
			view.SetOpen(false)
		else
			for index, key in Keys.Quick do
				if input.KeyCode == key and player:GetAttribute("MagicLabOpen") ~= true then
					if inventory.Quick[index] then
						controller.Request({ Op = "Use", From = "Quick:" .. index })
					end
				end
			end
		end
	end)
	-- Gamepad: D-pad down toggles the inventory (outside the Grimoire).
	game:GetService("ContextActionService"):BindAction("InventoryToggleGamepad", function(_, state)
		if state ~= Enum.UserInputState.Begin or player:GetAttribute("MagicLabOpen") == true then
			return Enum.ContextActionResult.Pass
		end
		view.SetOpen(not view.IsOpen())
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.DPadDown)
	player:GetAttributeChangedSignal("MagicLabOpen"):Connect(function()
		if player:GetAttribute("MagicLabOpen") == true then
			view.SetOpen(false)
		end
	end)
	player:GetAttributeChangedSignal("ActiveEquipmentSlot"):Connect(function()
		changed:Fire()
	end)

	controller.Request({ Op = "Refresh" })
	return controller
end

return InventoryController
