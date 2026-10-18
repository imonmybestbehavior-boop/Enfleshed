--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local SummonConfig = require(game:GetService("ReplicatedStorage").Shared.Configuration.MagicSummons)
local studioSandbox = game:GetService("RunService"):IsStudio()
	and require(game:GetService("ReplicatedStorage").Shared.Configuration.DevelopmentSandbox).Enabled
local Controller = {}

local commandLabels = {
	Follow = "Follow",
	Protect = "Protect",
	Attack = "Attack target",
	Move = "Move here",
	Patrol = "Patrol point",
	Hold = "Hold",
	Support = "Support",
	Dismiss = "Dismiss all",
}
local commandButtons = {}
for _, mode in ipairs(SummonConfig.CommandOrder) do
	local label = commandLabels[mode]
	local key = SummonConfig.CommandKeys[mode]
	assert(label and key, "Missing summon command UI metadata for " .. mode)
	table.insert(commandButtons, { Mode = mode, Label = label, Key = key })
end

local function makeLabel(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function ownedSummons(): { Model }
	local folder = workspace:FindFirstChild("MagicSummons")
	local owned = {}
	if not folder then
		return owned
	end
	for _, model in folder:GetChildren() do
		if
			model:IsA("Model")
			and model:GetAttribute("MagicSummonOwnerUserId") == player.UserId
			and type(model:GetAttribute("MagicSummonId")) == "number"
		then
			table.insert(owned, model)
		end
	end
	return owned
end

function Controller.start(sendCommand: (string) -> (), cycleSelection: () -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "SummonCommandInterface"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "OrdersPanel"
	panel.AnchorPoint = if UserInputService.TouchEnabled then Vector2.zero else Vector2.new(1, 1)
	panel.Position = if UserInputService.TouchEnabled then UDim2.fromOffset(12, 52) else UDim2.new(1, -18, 1, -94)
	panel.Size = UDim2.fromOffset(292, 310)
	panel.BackgroundColor3 = Color3.fromRGB(21, 25, 30)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 8)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(101, 122, 138)
	panelStroke.Transparency = 0.45
	panelStroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Position = UDim2.fromOffset(8, 8)
	header.Size = UDim2.new(1, -16, 0, 34)
	header.BackgroundTransparency = 1
	header.Parent = panel
	local title = makeLabel(header, "SUMMON ORDERS", 13, Color3.fromRGB(218, 229, 237))
	title.Size = UDim2.new(1, -110, 1, 0)
	local cycleButton = Instance.new("TextButton")
	cycleButton.Name = "SelectNext"
	cycleButton.AnchorPoint = Vector2.new(1, 0)
	cycleButton.Position = UDim2.new(1, -32, 0, 0)
	cycleButton.Size = UDim2.fromOffset(68, 32)
	cycleButton.BackgroundColor3 = Color3.fromRGB(50, 67, 78)
	cycleButton.BorderSizePixel = 0
	cycleButton.Font = Enum.Font.GothamBold
	cycleButton.Text = "NEXT · " .. SummonConfig.SelectionKey
	cycleButton.TextColor3 = Color3.fromRGB(237, 245, 250)
	cycleButton.TextSize = 11
	cycleButton.Parent = header
	local cycleCorner = Instance.new("UICorner")
	cycleCorner.CornerRadius = UDim.new(0, 5)
	cycleCorner.Parent = cycleButton
	cycleButton.Activated:Connect(cycleSelection)

	local status = makeLabel(panel, "Cast a Summon spell to call a companion.", 12, Color3.fromRGB(195, 207, 216))
	status.Name = "SelectedStatus"
	status.Position = UDim2.fromOffset(10, 48)
	status.Size = UDim2.new(1, -20, 0, 58)
	status.TextYAlignment = Enum.TextYAlignment.Top
	local feedback = makeLabel(panel, "", 11, Color3.fromRGB(173, 220, 202))
	feedback.Name = "CommandFeedback"
	feedback.Position = UDim2.fromOffset(10, 108)
	feedback.Size = UDim2.new(1, -20, 0, 24)

	local grid = Instance.new("Frame")
	grid.Name = "CommandButtons"
	grid.Position = UDim2.fromOffset(8, 134)
	grid.Size = UDim2.new(1, -16, 0, 144)
	grid.BackgroundTransparency = 1
	grid.Parent = panel
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -3, 0, 32)
	gridLayout.CellPadding = UDim2.fromOffset(6, 4)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local buttons: { [string]: TextButton } = {}
	for index, command in ipairs(commandButtons) do
		local button = Instance.new("TextButton")
		button.Name = command.Mode
		button.LayoutOrder = index
		button.BackgroundColor3 = if command.Mode == "Dismiss"
			then Color3.fromRGB(89, 49, 47)
			else Color3.fromRGB(42, 51, 59)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamMedium
		button.Text = string.format("%s   ·   %s", command.Label, command.Key)
		button.TextColor3 = Color3.fromRGB(228, 234, 239)
		button.TextSize = 11
		button.Parent = grid
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = button
		button.Activated:Connect(function()
			if #ownedSummons() == 0 then
				return
			end
			sendCommand(command.Mode)
			feedback.Text = "Sending " .. command.Label .. " order…"
		end)
		buttons[command.Mode] = button
	end

	local hint = makeLabel(
		panel,
		"Attack uses your aimed target · Move uses your crosshair · Patrol needs two points",
		10,
		Color3.fromRGB(153, 169, 180)
	)
	hint.Position = UDim2.fromOffset(10, 292)
	hint.Size = UDim2.new(1, -20, 0, 12)

	local toggle = Instance.new("TextButton")
	toggle.Name = "OrdersToggle"
	toggle.AnchorPoint = if UserInputService.TouchEnabled then Vector2.zero else Vector2.new(1, 1)
	toggle.Position = if UserInputService.TouchEnabled then UDim2.fromOffset(12, 12) else UDim2.new(1, -18, 1, -94)
	toggle.Size = UDim2.fromOffset(132, 34)
	toggle.BackgroundColor3 = Color3.fromRGB(34, 44, 51)
	toggle.BackgroundTransparency = 0.08
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.GothamSemibold
	toggle.Text = "SUMMONS · 0"
	toggle.TextColor3 = Color3.fromRGB(220, 232, 240)
	toggle.TextSize = 12
	toggle.Parent = gui
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 7)
	toggleCorner.Parent = toggle
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseOrders"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(28, 32)
	closeButton.BackgroundColor3 = Color3.fromRGB(46, 56, 64)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.fromRGB(225, 233, 239)
	closeButton.TextSize = 18
	closeButton.Visible = false
	closeButton.Parent = header
	closeButton.Activated:Connect(function()
		panel.Visible = false
		toggle.Visible = true
		closeButton.Visible = false
	end)

	local function openPanel()
		panel.Visible = true
		toggle.Visible = false
		closeButton.Visible = true
	end
	toggle.Activated:Connect(openPanel)

	local feedbackRevision = 0
	local function refresh()
		local owned = ownedSummons()
		local selectedId = player:GetAttribute("MagicSelectedSummonId")
		local selected = nil
		for _, model in ipairs(owned) do
			if model:GetAttribute("MagicSummonId") == selectedId then
				selected = model
				break
			end
		end
		toggle.Text = string.format("SUMMONS · %d", #owned)
		if #owned == 0 then
			status.Text = "Cast a Summon spell to call a companion."
		elseif selected then
			local archetype = selected:GetAttribute("MagicSummonArchetype") or "Companion"
			local role = selected:GetAttribute("MagicSummonRole") or "Guardian"
			local spellStatus = selected:GetAttribute("MagicSummonSpellStatus") or "SEARCHING"
			local spellSlot = selected:GetAttribute("MagicSummonSpellSlot") or 0
			local spellReason = selected:GetAttribute("MagicSummonSpellReason")
			local spellTarget = selected:GetAttribute("MagicSummonSpellTarget")
			local guidance = spellReason
			if not guidance or guidance == "" then
				guidance = if spellStatus == "UNASSIGNED"
					then "Basic attack active · assign a companion spell in the Summon effect to use magic"
					elseif
						spellStatus == "SEARCHING"
					then "Looking for a visible target · Guardian protects nearby; Hunter searches farther"
					elseif
						spellStatus == "FOLLOWING"
					then "Following you · choose Protect or Attack to resume target acquisition"
					elseif spellStatus == "HOLDING" then "Holding position · choose another order to resume"
					elseif spellStatus == "PATROL SET" then "Choose Patrol again to set its second point"
					else ""
			end
			status.Text = string.format(
				"%d active · #%s %s (%s) · %s%s%s",
				#owned,
				tostring(selectedId),
				archetype,
				role,
				spellStatus,
				if spellSlot > 0 then " · spell slot " .. spellSlot else "",
				if spellTarget and spellTarget ~= "" then " · target " .. spellTarget else ""
			)
			if guidance ~= "" then
				status.Text ..= "\n" .. guidance
			end
		else
			status.Text = string.format("%d active · press NEXT or N to select one", #owned)
		end
		cycleButton.Active = #owned > 0
		cycleButton.AutoButtonColor = #owned > 0
		for _, button in pairs(buttons) do
			button.Active = #owned > 0
			button.AutoButtonColor = #owned > 0
			button.TextTransparency = if #owned > 0 then 0 else 0.45
		end
		gui.Enabled = (studioSandbox or player:GetAttribute("CharacterReady") == true)
			and player:GetAttribute("MagicLabOpen") ~= true
	end

	local watchedModels: { [Instance]: boolean } = {}
	local function watchModel(model: Instance)
		if watchedModels[model] then
			return
		end
		watchedModels[model] = true
		model:GetAttributeChangedSignal("MagicSummonOwnerUserId"):Connect(refresh)
		model:GetAttributeChangedSignal("MagicSummonId"):Connect(refresh)
		model:GetAttributeChangedSignal("MagicSummonRole"):Connect(refresh)
		model:GetAttributeChangedSignal("MagicSummonSpellStatus"):Connect(refresh)
		model:GetAttributeChangedSignal("MagicSummonSpellReason"):Connect(refresh)
		model:GetAttributeChangedSignal("MagicSummonSpellSlot"):Connect(refresh)
		model:GetAttributeChangedSignal("MagicSummonSpellTarget"):Connect(refresh)
	end
	local function watchFolder(folder: Instance)
		folder.ChildAdded:Connect(function(child)
			watchModel(child)
			refresh()
		end)
		folder.ChildRemoved:Connect(refresh)
		for _, model in folder:GetChildren() do
			watchModel(model)
		end
		refresh()
	end

	workspace.ChildAdded:Connect(function(child)
		if child.Name == "MagicSummons" then
			watchFolder(child)
		end
	end)
	local existingFolder = workspace:FindFirstChild("MagicSummons")
	if existingFolder then
		watchFolder(existingFolder)
	end
	player:GetAttributeChangedSignal("MagicSelectedSummonId"):Connect(refresh)
	player:GetAttributeChangedSignal("CharacterReady"):Connect(refresh)
	player:GetAttributeChangedSignal("MagicLabOpen"):Connect(refresh)

	return {
		Feedback = function(message: any)
			feedbackRevision += 1
			local currentRevision = feedbackRevision
			feedback.TextColor3 = if message.Accepted
				then Color3.fromRGB(173, 220, 202)
				else Color3.fromRGB(255, 174, 158)
			feedback.Text = tostring(
				message.Reason or message.Mode or if message.Accepted then "Order accepted" else "Order rejected"
			)
			task.delay(3, function()
				if feedbackRevision == currentRevision then
					feedback.Text = ""
				end
			end)
		end,
		Refresh = refresh,
	}
end

return Controller
