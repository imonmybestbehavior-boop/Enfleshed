--!strict
-- Small client entry point that can render before server remotes are ready.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local InputMode = require(script.Parent.Parent.UI.Kit.InputMode)

local Launcher = {}

function Launcher.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "GrimoireLauncher"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "OpenGrimoire"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -24, 1, -84)
	button.Size = UDim2.fromOffset(224, 54)
	-- Spell Forge palette (SpellForgeTheme), inlined so this renders before UI modules load.
	button.BackgroundColor3 = Color3.fromRGB(21, 18, 24)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.Text = "◆  SPELLS  ·  P"
	button.TextColor3 = Color3.fromRGB(238, 228, 212)
	button.TextSize = 16
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(218, 174, 96)
	edge.Transparency = 0.3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = button
	button.ZIndex = 10
	-- Hidden: the HUD spell bar's ✦ button opens the Grimoire now (P / View still work).
	button.Visible = false
	button.Parent = gui

	local callback: (() -> ())? = nil
	local pending = false
	local function activate()
		if callback then
			callback()
		else
			pending = true
			button.Text = "CONNECTING…"
		end
	end
	button.Activated:Connect(activate)
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.P and not processed and not UserInputService:GetFocusedTextBox() then
			activate()
		end
	end)
	-- Gamepad: the View/Select button opens and closes the Grimoire.
	ContextActionService:BindAction("GrimoireToggleGamepad", function(_, state)
		if state == Enum.UserInputState.Begin then
			activate()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonSelect)
	local function label(): string
		local glyph = InputMode.glyph("Grimoire", InputMode.get())
		return if glyph == "" then "◆  SPELLS" else "◆  SPELLS  ·  " .. glyph
	end
	InputMode.Changed:Connect(function()
		if callback then
			button.Text = label()
		end
	end)

	return {
		-- Lets the HUD spell bar open the Grimoire exactly like the P key does.
		Open = function(_)
			activate()
		end,
		Bind = function(_, open: () -> ())
			callback = open
			button.Text = label()
			if pending then
				pending = false
				task.defer(callback)
			end
		end,
		SetOpen = function(_, _open: boolean) end,
		SetError = function(_, message: string)
			button.Text = "GRIMOIRE ERROR · VIEW OUTPUT"
			warn("Grimoire launcher: " .. message)
		end,
	}
end

return Launcher
