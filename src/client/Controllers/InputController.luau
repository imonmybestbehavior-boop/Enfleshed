--!strict

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Input = {}

function Input.start(
	sprint: (boolean) -> (),
	dash: () -> (),
	magicStart: (string, boolean?) -> (),
	magicRelease: () -> (),
	useEquipment: (string) -> (),
	switchEquipment: () -> (),
	cycleGenerated: () -> (),
	startGenerated: () -> (),
	releaseGenerated: () -> ()
)
	ContextActionService:BindAction("SandboxSprint", function(_, state)
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			sprint(false)
		elseif state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			sprint(true)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift)
	ContextActionService:BindAction("SandboxDash", function(_, state)
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			dash()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q)
	ContextActionService:BindAction("SandboxLight", function(_, state)
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			useEquipment("Primary")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction("SandboxEquipmentArea", function(_, state)
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			useEquipment("Area")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton2)
	ContextActionService:BindAction("SandboxEquipmentSwitch", function(_, state)
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			switchEquipment()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E)
	for spellId, key in
		{
			Fireball = Enum.KeyCode.One,
			BodyBurst = Enum.KeyCode.Two,
			StoneShot = Enum.KeyCode.Three,
			LightningLance = Enum.KeyCode.Four,
			BurningGround = Enum.KeyCode.Five,
			BodyReinforcement = Enum.KeyCode.Six,
			StoneRaise = Enum.KeyCode.Seven,
		}
	do
		ContextActionService:BindAction("Sandbox" .. spellId, function(_, state)
			if UserInputService:GetFocusedTextBox() then
				return Enum.ContextActionResult.Sink
			end
			if state == Enum.UserInputState.Begin then
				magicStart(spellId, spellId == "StoneShot")
			elseif
				spellId == "StoneShot" and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel)
			then
				magicRelease()
			end
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	ContextActionService:BindAction("SandboxGeneratedCycle", function(_, state)
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			cycleGenerated()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F)
	ContextActionService:BindAction("SandboxGeneratedCast", function(_, state)
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Sink
		end
		if state == Enum.UserInputState.Begin then
			startGenerated()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			releaseGenerated()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R)
	UserInputService.WindowFocusReleased:Connect(function()
		sprint(false)
	end)
	UserInputService.TextBoxFocused:Connect(function()
		sprint(false)
	end)
end

return Input
