--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Profiles = require(Shared.Configuration.MagicProfiles)
local Controller = {}

function Controller.start(send: (string, any?) -> number)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	local rebuild: () -> ()
	gui.Name = "MagicFocusProfileGui"
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenFocusProfiles"
	openButton.AnchorPoint = Vector2.new(1, 1)
	openButton.Position = UDim2.new(1, -18, 1, -88)
	openButton.Size = UDim2.fromOffset(156, 34)
	openButton.BackgroundColor3 = Color3.fromRGB(34, 40, 43)
	openButton.TextColor3 = Color3.fromRGB(236, 230, 215)
	openButton.Font = Enum.Font.GothamMedium
	openButton.TextSize = 13
	openButton.Text = "FOCUS PROFILE · K"
	openButton.Visible = true
	openButton.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 390)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 23)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -24, 0, 34)
	header.Position = UDim2.fromOffset(12, 10)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextSize = 18
	header.TextColor3 = Color3.fromRGB(232, 225, 210)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "MAGIC FOCUS PROFILES"
	header.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(32, 30)
	close.Position = UDim2.new(1, -42, 0, 8)
	close.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.Text = "×"
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	openButton.Activated:Connect(function()
		if player:GetAttribute("MagicLabOpen") then
			return
		end
		panel.Visible = not panel.Visible
		if panel.Visible then
			rebuild()
		end
	end)

	local current = Instance.new("TextLabel")
	current.Size = UDim2.new(1, -24, 0, 25)
	current.Position = UDim2.fromOffset(12, 48)
	current.BackgroundTransparency = 1
	current.Font = Enum.Font.Gotham
	current.TextSize = 13
	current.TextColor3 = Color3.fromRGB(202, 206, 210)
	current.TextXAlignment = Enum.TextXAlignment.Left
	current.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Name = "Profiles"
	list.Position = UDim2.fromOffset(12, 78)
	list.Size = UDim2.new(1, -24, 1, -122)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -24, 0, 30)
	status.Position = UDim2.new(0, 12, 1, -36)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(190, 196, 202)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Text = "K · every test profile is available. The Magic Focus uses the selected profile for its casts."
	status.Parent = panel

	local buttons: { [string]: TextButton } = {}
	rebuild = function()
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		buttons = {}
		local ids = {}
		for id in Profiles do
			table.insert(ids, id)
		end
		table.sort(ids)
		for order, id in ipairs(ids) do
			local definition = Profiles[id]
			local selected = player:GetAttribute("MagicAwakeningProfileId") == id
			local button = Instance.new("TextButton")
			button.Name = id
			button.LayoutOrder = order
			button.Size = UDim2.new(1, -4, 0, 66)
			button.BackgroundColor3 = if selected then Color3.fromRGB(62, 83, 83) else Color3.fromRGB(42, 46, 49)
			button.TextColor3 = Color3.fromRGB(239, 235, 225)
			button.Font = Enum.Font.Gotham
			button.TextSize = 13
			button.TextWrapped = true
			button.TextXAlignment = Enum.TextXAlignment.Left
			button.Text = string.format(
				"  %s%s\n  %s",
				definition.Label,
				if selected then "  ·  EQUIPPED" else "",
				definition.Description
			)
			button.AutoButtonColor = true
			button.Parent = list
			buttons[id] = button
			button.Activated:Connect(function()
				status.Text = "Applying " .. definition.Label .. "…"
				send(Protocol.MagicAwakeningSelect, { AwakeningProfileId = id })
			end)
		end
		local selectedId = player:GetAttribute("MagicAwakeningProfileId") or "RecruitGeneric"
		local selectedDefinition = Profiles[selectedId]
		current.Text = "Current focus profile: " .. (selectedDefinition and selectedDefinition.Label or "Recruit Focus")
	end

	player:GetAttributeChangedSignal("MagicAwakeningProfileId"):Connect(rebuild)
	player:GetAttributeChangedSignal("MagicLabOpen"):Connect(function()
		if player:GetAttribute("MagicLabOpen") then
			panel.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.K and not player:GetAttribute("MagicLabOpen") then
			panel.Visible = not panel.Visible
			if panel.Visible then
				rebuild()
			end
		end
	end)
	rebuild()

	return {
		Feedback = function(message: any)
			if message.Kind ~= "MagicAwakening" then
				return
			end
			status.Text = if message.Accepted
				then "Test profile selected. The focus now uses this profile."
				else tostring(message.Reason or "Profile selection rejected")
			rebuild()
		end,
		Reset = function()
			panel.Visible = false
		end,
	}
end

return Controller
