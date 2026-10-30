--!strict

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local launcher = require(script.Controllers.GrimoireLauncher).start()
local camera = require(script.Controllers.CameraController).start()
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared:WaitForChild("Networking"):WaitForChild("Protocol"))
local Types = require(Shared:WaitForChild("Types"):WaitForChild("CombatTypes"))
local remotes = Shared:WaitForChild(Protocol.Folder)
local request = remotes:WaitForChild(Protocol.Request) :: RemoteEvent
local feedback = remotes:WaitForChild(Protocol.Feedback) :: RemoteEvent
local aerialControl = remotes:WaitForChild(Protocol.AerialControl) :: RemoteEvent
local studioSandbox = game:GetService("RunService"):IsStudio()
	and require(Shared.Configuration.DevelopmentSandbox).Enabled
local sequence = 0

local function send(action: string, extra: Types.ActionOptions?): number
	sequence += 1
	local character = player.Character
	if not character or (not studioSandbox and not player:GetAttribute("CharacterReady")) then
		return 0 -- Nothing was sent, so callers must not wait for a reply.
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
		SummonMode = if extra then extra.SummonMode else nil,
		SummonId = if extra then extra.SummonId else nil,
	}
	request:FireServer(payload)
	return sequence
end

local function startController(name: string, ...: any): ...any
	local ok, result = pcall(function(...)
		local controller = require(script.Controllers:WaitForChild(name))
		return controller.start(...)
	end, ...)
	if not ok then
		warn(string.format("Enfleshed client controller %s failed to start: %s", name, tostring(result)))
		if name == "MagicController" then
			launcher:SetError(tostring(result))
		end
		return nil
	end
	return result
end

local hud = startController("UIController", launcher)
local debug = startController("DebugController")
startController("MagicRevealController")
startController("MagicEnchantmentController")
startController("MagicStealthController")
startController("MagicHiddenMarkerController")
startController("SpellVFXController", remotes)
startController("SpellVFXShowcase")
startController("LanternController")
local aerial = startController("MagicAerialController", aerialControl)
local movement = startController("MovementController", send)
local inventory = startController("InventoryController")
if hud and inventory then
	hud.BindInventory(inventory)
end
local combat =
	startController("CombatController", send, movement, debug, hud, if inventory then inventory.MeleeLoadout else nil)
local magic = startController(
	"MagicController",
	send,
	if camera
		then camera.GetAim
		else function()
			return Vector3.zAxis, Vector3.zero, nil, nil
		end,
	launcher
)
local equipment = if combat and magic
	then startController("EquipmentController", send, combat, magic.WeaponAction)
	else nil
local generated = if magic then startController("GeneratedSpellController", magic, debug) else nil
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
	local _, point, target = if camera then camera.GetAim() else Vector3.zAxis, Vector3.zero, nil
	send(Protocol.SummonCommand, {
		SummonMode = mode,
		TargetModel = if mode == "Attack" then target else nil,
		WorldPoint = if mode == "Move" or mode == "Patrol" then point else nil,
		SummonId = if mode == "Dismiss" then nil else selectedSummonId,
	})
end

local summonCommands = startController("SummonCommandController", summonCommand, cycleSummonSelection)
if movement and combat and magic and equipment and generated then
	startController(
		"InputController",
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
else
	warn("Enfleshed input is disabled because a required combat or magic controller did not start")
end

local function reset()
	selectedSummonId = nil
	player:SetAttribute("MagicSelectedSummonId", nil)
	if movement then
		movement.Reset()
	end
	if aerial then
		aerial.Reset()
	end
	if combat then
		combat.Reset()
	end
	if magic then
		magic.Reset()
	end
	if equipment then
		equipment.Reset()
	end
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
		if equipment then
			equipment.Feedback(message)
		end
	elseif message.Kind == "ImpactNumber" then
		local target = if typeof(message.Target) == "Instance" and message.Target:IsA("Model")
			then message.Target
			else nil
		if typeof(message.Amount) == "number" and typeof(message.Effect) == "string" then
			if debug then
				debug.Number(message.Effect, message.Amount, target)
			end
		end
	elseif message.Kind == "Magic" then
		if debug then
			debug.Magic(message)
		end
	elseif message.Kind == "SummonCommand" then
		if debug then
			debug.SummonCommand(message)
		end
		if summonCommands then
			summonCommands.Feedback(message)
		end
	elseif
		message.Kind == "Swing"
		or message.Kind == "Guard"
		or (player.Character ~= nil and message.Character == player.Character)
	then
		if movement then
			movement.Feedback(message)
		end
		if combat then
			combat.Feedback(message)
		end
	end
end)
