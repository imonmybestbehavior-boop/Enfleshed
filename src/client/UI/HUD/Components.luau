--!strict
-- Small builders shared by every HUD screen. All looks come from Theme.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

local C = {}
local Color = Theme.Color

function C.new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function C.screen(name: string, order: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	return C.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = order,
	}, playerGui)
end

-- Full-screen root with a UIScale fitted to the viewport (and 10-foot boost on console).
function C.root(gui: ScreenGui): Frame
	local root = C.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	local scale = C.new("UIScale", {}, root)
	local player = Players.LocalPlayer
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local fit = math.min(viewport.X / Theme.ReferenceSize.X, viewport.Y / Theme.ReferenceSize.Y)
		local setting = player:GetAttribute("UIScaleSetting")
		local user = if type(setting) == "number" then math.clamp(setting, 0.75, 1.5) else 1
		local tenFoot = if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
			then Theme.TenFootScale
			else 1
		local value = math.clamp(fit * user * tenFoot, Theme.MinScale, Theme.MaxScale)
		scale.Scale = value
		-- The root is authored in reference units; stretch it so Scale children still fill the screen.
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	local function watch()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		end
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	player:GetAttributeChangedSignal("UIScaleSetting"):Connect(update)
	watch()
	return root
end

-- Near-black translucent panel, brass hairline, rivets in the corners.
function C.panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = C.new("Frame", {
		BackgroundColor3 = Color.Panel,
		BackgroundTransparency = Theme.Transparency.Panel,
		BorderSizePixel = 0,
	}, parent)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	C.new("UICorner", { CornerRadius = UDim.new(0, Theme.Size.Corner) }, frame)
	C.new("UIStroke", {
		Name = "Edge",
		Color = Color.Brass,
		Transparency = Theme.Transparency.Stroke,
		Thickness = Theme.Size.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	C.new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0.25),
		}),
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 230), Color3.fromRGB(170, 160, 150)),
	}, frame)
	C.rivets(frame)
	return frame
end

-- Diamond studs on the four corners read as an angled/bevelled metal frame.
function C.rivets(frame: GuiObject)
	local size = Theme.Size.Rivet
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		C.new("Frame", {
			Name = "Rivet",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(corner.X, corner.Y),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = Color.Gold,
			BorderSizePixel = 0,
			ZIndex = frame.ZIndex + 2,
		}, frame)
	end
end

function C.text(
	parent: Instance,
	text: string,
	size: number,
	color: Color3,
	font: Enum.Font?,
	props: { [string]: any }?
): TextLabel
	local label = C.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Theme.Font.Body,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	return label
end

export type Bar = {
	Frame: Frame,
	Fill: Frame,
	Ghost: Frame,
	Text: TextLabel?,
	Set: (ratio: number, text: string?) -> (),
}

-- Eased bar with a delayed "ghost" chip that drains after damage.
function C.bar(parent: Instance, size: Vector2, color: Color3, withText: boolean): Bar
	local frame = C.new("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color.Track,
		BackgroundTransparency = Theme.Transparency.Track,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	C.new("UICorner", { CornerRadius = UDim.new(0, 2) }, frame)
	C.new("UIStroke", { Color = Color.Brass, Transparency = 0.5, Thickness = 1 }, frame)
	local ghost = C.new("Frame", {
		Name = "Ghost",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color.Ghost,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, frame)
	local fill = C.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, frame)
	C.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
	}, fill)
	local label = if withText
		then C.text(frame, "", math.max(11, size.Y - 6), Color.Text, Theme.Font.Number, {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			TextStrokeTransparency = 0.3,
		})
		else nil
	local current = 1
	local ghostToken = 0
	local bar: Bar = {
		Frame = frame,
		Fill = fill,
		Ghost = ghost,
		Text = label,
		Set = function(ratio: number, text: string?)
			ratio = math.clamp(if ratio == ratio then ratio else 0, 0, 1)
			if label and text then
				label.Text = text
			end
			if math.abs(ratio - current) < 0.0005 then
				return
			end
			local dropped = ratio < current
			current = ratio
			TweenService:Create(fill, Theme.Motion.Bar, { Size = UDim2.fromScale(ratio, 1) }):Play()
			if dropped then
				ghostToken += 1
				local token = ghostToken
				task.delay(Theme.Motion.GhostDelay, function()
					if token == ghostToken then
						TweenService:Create(ghost, Theme.Motion.Ghost, { Size = UDim2.fromScale(current, 1) }):Play()
					end
				end)
			else
				ghost.Size = UDim2.fromScale(ratio, 1)
			end
		end,
	}
	return bar
end

-- Slight scale-up on hover/selection; works for mouse and gamepad focus.
function C.hover(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or C.new("UIScale", {}, button)
	local function to(value: number)
		TweenService:Create(scale, Theme.Motion.Hover, { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		to(Theme.Motion.HoverScale)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.SelectionGained:Connect(function()
		to(Theme.Motion.HoverScale)
	end)
	button.SelectionLost:Connect(function()
		to(1)
	end)
end

function C.button(parent: Instance, text: string, props: { [string]: any }?): TextButton
	local button = C.new("TextButton", {
		BackgroundColor3 = Color.PanelRaised,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Active = true,
		Selectable = true,
		Text = text,
		TextColor3 = Color.Gold,
		TextSize = Theme.TextSize.Label,
		Font = Theme.Font.Display,
	}, parent)
	for key, value in props or {} do
		(button :: any)[key] = value
	end
	C.new("UICorner", { CornerRadius = UDim.new(0, Theme.Size.Corner) }, button)
	C.new("UIStroke", {
		Color = Color.Brass,
		Transparency = 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, button)
	C.rivets(button)
	C.hover(button)
	return button
end

return C
