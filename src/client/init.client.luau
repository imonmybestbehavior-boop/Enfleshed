--!strict

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local remotes = Shared:WaitForChild(Protocol.Folder)
local request = remotes:WaitForChild(Protocol.Request) :: RemoteEvent
local feedback = remotes:WaitForChild(Protocol.Feedback) :: RemoteEvent
local player = Players.LocalPlayer
local sequence = 0

local function send(action: string, extra: Types.ActionOptions?): number
	sequence += 1
	local character = player.Character
	if not character then
		return sequence
	end
	local payload: Types.ActionRequest = {
		Action = action,
		Sequence = sequence,
		Character = character,
		Sprinting = if extra then extra.Sprinting else nil,
		Direction = if extra then extra.Direction else nil,
		SpellId = if extra then extra.SpellId else nil,
		AimDirection = if extra then extra.AimDirection else nil,
		WorldPoint = if extra then extra.WorldPoint else nil,
		EquipmentSlot = if extra then extra.EquipmentSlot else nil,
		EquipmentAction = if extra then extra.EquipmentAction else nil,
	}
	request:FireServer(payload)
	return sequence
end

local debug = require(script.Controllers.DebugController).start()
local movement = require(script.Controllers.MovementController).start(send)
local combat = require(script.Controllers.CombatController).start(send, movement, debug)
local magic = require(script.Controllers.MagicController).start(send)
local equipment = require(script.Controllers.EquipmentController).start(send, combat.Attack, magic.WeaponAction)
require(script.Controllers.InputController).start(movement.Sprint, function()
	if combat.CanDash() then
		movement.Dash()
	end
end, magic.Cast, magic.Release, equipment.Use, equipment.Switch)

local function reset()
	movement.Reset()
	combat.Reset()
	magic.Reset()
	equipment.Reset()
end
player.CharacterRemoving:Connect(reset)
local deathConnection: RBXScriptConnection? = nil
local function characterAdded(character: Model)
	reset()
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") and player.Character == character then
		deathConnection = humanoid.Died:Connect(reset)
	end
end
player.CharacterAdded:Connect(characterAdded)
if player.Character then
	task.spawn(characterAdded, player.Character)
end
feedback.OnClientEvent:Connect(function(message)
	if message.Kind == "Equipment" then
		equipment.Feedback(message)
	elseif message.Kind == "Magic" then
		debug.Magic(message)
	elseif message.Kind == "Swing" or (player.Character ~= nil and message.Character == player.Character) then
		movement.Feedback(message)
		combat.Feedback(message)
	end
end)
