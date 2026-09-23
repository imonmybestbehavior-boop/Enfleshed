--!strict

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Input = {}

function Input.start(sprint: (boolean) -> (), dash: () -> (), attack: () -> ())
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
			attack()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1)
	UserInputService.WindowFocusReleased:Connect(function()
		sprint(false)
	end)
	UserInputService.TextBoxFocused:Connect(function()
		sprint(false)
	end)
end

return Input
