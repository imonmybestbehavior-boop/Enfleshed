--!strict
-- Scales a screen to the player's viewport from the reference design size, keeps
-- it inside the device safe area, and respects the player's UI scale setting
-- (Player attribute "UIScaleSetting", 0.75–1.5; Phase 2 settings menu writes it).
local Players = game:GetService("Players")
local Tokens = require(script.Parent.Tokens)

local Responsive = {}
Responsive.MinScale = 0.6
Responsive.MaxScale = 1.4

-- Pure: scale for a viewport (fits the reference size, clamped).
function Responsive.scaleFor(viewport: Vector2, setting: number?): number
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	local fit = math.min(viewport.X / Tokens.ReferenceSize.X, viewport.Y / Tokens.ReferenceSize.Y)
	local user = if type(setting) == "number" and setting == setting then math.clamp(setting, 0.75, 1.5) else 1
	return math.clamp(fit * user, Responsive.MinScale, Responsive.MaxScale)
end

-- Adds (or reuses) a UIScale on `root` and keeps it updated. Returns a cleanup function.
function Responsive.attach(gui: ScreenGui, root: GuiObject): () -> ()
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local scale = root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = root
	local player = Players.LocalPlayer
	local connections: { RBXScriptConnection } = {}
	local function update()
		local camera = workspace.CurrentCamera
		if camera then
			(scale :: UIScale).Scale = Responsive.scaleFor(camera.ViewportSize, player:GetAttribute("UIScaleSetting"))
		end
	end
	local function watchCamera()
		local camera = workspace.CurrentCamera
		if camera then
			table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(update))
		end
		update()
	end
	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
	table.insert(connections, player:GetAttributeChangedSignal("UIScaleSetting"):Connect(update))
	watchCamera()
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

return Responsive
