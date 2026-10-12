--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = {}

function Controller.start(remote: RemoteEvent)
	local player = Players.LocalPlayer
	local character: Model? = nil
	local active = false
	local ascending = false
	local descending = false
	local lastSent = 0
	local attributeConnection: RBXScriptConnection? = nil
	local sendInterval = 0.1

	local function showTouchControls(value: boolean)
		for _, actionName in { "MagicAerialAscend", "MagicAerialDescend" } do
			local button = ContextActionService:GetButton(actionName)
			if button then
				button.Visible = value
			end
		end
	end

	local function setActive(value: boolean)
		active = value
		showTouchControls(value)
		if not active then
			ascending = false
			descending = false
		end
	end

	local function bindCharacter(nextCharacter: Model)
		if attributeConnection then
			attributeConnection:Disconnect()
			attributeConnection = nil
		end
		character = nextCharacter
		setActive((nextCharacter:GetAttribute("MagicAerialSpeed") or 0) > 0)
		attributeConnection = nextCharacter:GetAttributeChangedSignal("MagicAerialSpeed"):Connect(function()
			setActive((nextCharacter:GetAttribute("MagicAerialSpeed") or 0) > 0)
		end)
	end

	local function verticalAction(direction: number, inputState: Enum.UserInputState)
		if not active then
			return Enum.ContextActionResult.Pass
		end
		local pressed = inputState == Enum.UserInputState.Begin
		if direction > 0 then
			ascending = pressed
		else
			descending = pressed
		end
		if inputState == Enum.UserInputState.Cancel then
			ascending = false
			descending = false
		end
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindActionAtPriority("MagicAerialAscend", function(_, state)
		return verticalAction(1, state)
	end, true, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("MagicAerialAscend", "Rise")
	ContextActionService:BindActionAtPriority("MagicAerialDescend", function(_, state)
		return verticalAction(-1, state)
	end, true, 3000, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("MagicAerialDescend", "Descend")

	player.CharacterAdded:Connect(bindCharacter)
	if player.Character then
		bindCharacter(player.Character)
	end

	RunService.Heartbeat:Connect(function()
		if not active or not character or player.Character ~= character or UserInputService:GetFocusedTextBox() then
			return
		end
		local now = os.clock()
		if now - lastSent < sendInterval then
			return
		end
		lastSent = now
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local move = humanoid.MoveDirection
		local interfaceOpen = player:GetAttribute("MagicLabOpen") == true
		local direction = if interfaceOpen
			then Vector3.zero
			else Vector3.new(move.X, (if ascending then 1 else 0) - (if descending then 1 else 0), move.Z)
		if direction.Magnitude > 1 then
			direction = direction.Unit
		end
		remote:FireServer(character, direction)
	end)

	return {
		Reset = function()
			setActive(false)
		end,
	}
end

return Controller
