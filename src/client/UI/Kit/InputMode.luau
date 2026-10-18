--!strict
-- Tracks the player's current input device and gives prompt glyph text for it,
-- so prompts read "P", "View" or a tap hint depending on what the player uses.
local UserInputService = game:GetService("UserInputService")

local InputMode = {}
export type Mode = "Keyboard" | "Gamepad" | "Touch"

-- Pure: input type → mode (nil = does not change the mode, e.g. focus events).
function InputMode.classify(inputType: Enum.UserInputType): Mode?
	local name = inputType.Name
	if string.sub(name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif inputType == Enum.UserInputType.Keyboard or string.sub(name, 1, 5) == "Mouse" then
		return "Keyboard"
	end
	return nil
end

-- Prompt labels per action. Keep in sync with the bindings (docs/CONTROLS.md).
InputMode.Glyphs = {
	Grimoire = { Keyboard = "P", Gamepad = "View", Touch = "" },
	Inventory = { Keyboard = "I", Gamepad = "D-pad ↓", Touch = "" },
	Close = { Keyboard = "Esc", Gamepad = "B", Touch = "" },
	Confirm = { Keyboard = "Click", Gamepad = "A", Touch = "Tap" },
	CastSpell = { Keyboard = "1–9", Gamepad = "RB", Touch = "" },
	NextSpell = { Keyboard = "", Gamepad = "D-pad ←/→", Touch = "" },
}

function InputMode.glyph(action: string, mode: Mode): string
	local entry = InputMode.Glyphs[action]
	return if entry then entry[mode] or "" else ""
end

local current: Mode = if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
	then "Gamepad"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Touch"
	else "Keyboard"
local changed = Instance.new("BindableEvent")
InputMode.Changed = changed.Event -- (mode)

function InputMode.get(): Mode
	return current
end

UserInputService.LastInputTypeChanged:Connect(function(inputType)
	local mode = InputMode.classify(inputType)
	if mode and mode ~= current then
		current = mode
		changed:Fire(mode)
	end
end)

return InputMode
