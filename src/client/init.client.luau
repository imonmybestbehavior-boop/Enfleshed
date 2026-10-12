--!strict

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local remotes = Shared:WaitForChild(Protocol.Folder)
local request = remotes:WaitForChild(Protocol.Request) :: RemoteEvent
local feedback = remotes:WaitForChild(Protocol.Feedback) :: RemoteEvent
local aerialControl = remotes:WaitForChild(Protocol.AerialControl) :: RemoteEvent
local player = Players.LocalPlayer
local sequence = 0

local function send(action: string, extra: Types.ActionOptions?): number
	sequence += 1
	local character = player.Character
	if not character or not player:GetAttribute("OpeningComplete") then
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
		TargetModel = if extra then extra.TargetModel else nil,
		TargetInstance = if extra then extra.TargetInstance else nil,
		CastOrigin = if extra then extra.CastOrigin else nil,
		EquipmentSlot = if extra then extra.EquipmentSlot else nil,
		EquipmentAction = if extra then extra.EquipmentAction else nil,
		AwakeningProfileId = if extra then extra.AwakeningProfileId else nil,
		SummonMode = if extra then extra.SummonMode else nil,
		SummonId = if extra then extra.SummonId else nil,
	}
	request:FireServer(payload)
	return sequence
end

require(script.Controllers.OpeningController).start(remotes)
local practice = game:GetService("RunService"):IsStudio() and require(Shared.Configuration.DevelopmentSandbox).Enabled
if not practice then
	require(script.Controllers.WorldEventController).start()
end

local debug = require(script.Controllers.DebugController).start()
require(script.Controllers.MagicRevealController).start()
if not practice then
	require(script.Controllers.AssignmentController).start()
	require(script.Controllers.NavigationController).start()
end
require(script.Controllers.LanternController).start()
local aerial = require(script.Controllers.MagicAerialController).start(aerialControl)
local movement = require(script.Controllers.MovementController).start(send)
local combat = require(script.Controllers.CombatController).start(send, movement, debug)
local camera = require(script.Controllers.CameraController).start()
local magic = require(script.Controllers.MagicController).start(send, camera.GetAim)
local equipment = require(script.Controllers.EquipmentController).start(send, combat.Attack, magic.WeaponAction)
local awakening = require(script.Controllers.AwakeningController).start(send)
local generated = require(script.Controllers.GeneratedSpellController).start(magic, debug)
local selectedSummonId: number? = nil
local function cycleSummonSelection()
	local summons = workspace:FindFirstChild("MagicSummons")
	local owned = {}
	if summons then
		for _, model in summons:GetChildren() do
			local summonId = model:GetAttribute("MagicSummonId")
			if
				model:IsA("Model")
				and model:GetAttribute("MagicSummonOwnerUserId") == player.UserId
				and type(summonId) == "number"
			then
				table.insert(owned, { Model = model, Id = summonId })
			end
		end
	end
	table.sort(owned, function(first, second)
		return first.Id < second.Id
	end)
	if #owned == 0 then
		selectedSummonId = nil
	else
		local nextIndex = 1
		for index, summon in owned do
			if summon.Id == selectedSummonId then
				nextIndex = index % #owned + 1
				break
			end
		end
		selectedSummonId = owned[nextIndex].Id
	end
	player:SetAttribute("MagicSelectedSummonId", selectedSummonId)
end

local function summonCommand(mode: string)
	local _, point, target = camera.GetAim()
	send(Protocol.SummonCommand, {
		SummonMode = mode,
		TargetModel = if mode == "Attack" then target else nil,
		WorldPoint = if mode == "Move" or mode == "Patrol" then point else nil,
		SummonId = if mode == "Dismiss" then nil else selectedSummonId,
	})
end

local summonCommands = require(script.Controllers.SummonCommandController).start(summonCommand, cycleSummonSelection)
require(script.Controllers.InputController).start(
	movement.Sprint,
	function()
		if combat.CanDash() then
			movement.Dash()
		end
	end,
	magic.Cast,
	magic.Release,
	equipment.Use,
	equipment.Switch,
	generated.Cycle,
	generated.Begin,
	generated.Release,
	cycleSummonSelection,
	summonCommand
)

local function reset()
	selectedSummonId = nil
	player:SetAttribute("MagicSelectedSummonId", nil)
	movement.Reset()
	aerial.Reset()
	combat.Reset()
	magic.Reset()
	equipment.Reset()
	awakening.Reset()
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
	elseif message.Kind == "MagicAwakening" then
		awakening.Feedback(message)
	elseif message.Kind == "ImpactNumber" then
		local target = if typeof(message.Target) == "Instance" and message.Target:IsA("Model")
			then message.Target
			else nil
		if typeof(message.Amount) == "number" and typeof(message.Effect) == "string" then
			debug.Number(message.Effect, message.Amount, target)
		end
	elseif message.Kind == "Magic" then
		debug.Magic(message)
	elseif message.Kind == "SummonCommand" then
		debug.SummonCommand(message)
		summonCommands.Feedback(message)
	elseif message.Kind == "Swing" or (player.Character ~= nil and message.Character == player.Character) then
		movement.Feedback(message)
		combat.Feedback(message)
	end
end)
