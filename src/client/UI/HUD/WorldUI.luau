--!strict
-- World-space presentation: themed ProximityPrompts and client-only target
-- health bars (shown only when the target is on screen and unobstructed).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local C = require(script.Parent.Components)

local WorldUI = {}
local Color = Theme.Color
local player = Players.LocalPlayer

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function startPrompts(container: Instance)
	local function adopt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, prompt in workspace:GetDescendants() do
		adopt(prompt)
	end
	workspace.DescendantAdded:Connect(adopt)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local board = C.new("BillboardGui", {
			Name = "ThemedPrompt",
			Adornee = prompt.Parent,
			AlwaysOnTop = true,
			Size = UDim2.fromOffset(250, 52),
			StudsOffset = Vector3.new(0, 2.6, 0),
			Active = true,
			ResetOnSpawn = false,
		}, container)
		local frame = C.panel(board, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
		C.new("UIScale", { Scale = 0.85 }, frame)
		local key = C.new("TextButton", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = Color.PanelRaised,
			Text = keyText(prompt, inputType),
			TextColor3 = Color.Gold,
			Font = Theme.Font.Number,
			TextSize = Theme.TextSize.Label,
			TextScaled = false,
			AutoButtonColor = true,
		}, frame)
		C.new("UICorner", { CornerRadius = UDim.new(0, 3) }, key)
		C.new("UIStroke", { Color = Color.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, key)
		local hold = C.new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Color.Gold,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
		}, key)
		C.text(frame, prompt.ActionText, Theme.TextSize.Body, Color.Text, Theme.Font.Strong, {
			Position = UDim2.fromOffset(52, 7),
			Size = UDim2.new(1, -60, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		C.text(frame, prompt.ObjectText, Theme.TextSize.Small, Color.Muted, Theme.Font.Body, {
			Position = UDim2.fromOffset(52, 27),
			Size = UDim2.new(1, -60, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- Touch / click: drive the prompt directly.
		key.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
		key.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
		local holding: Tween? = nil
		local links = {
			prompt.PromptButtonHoldBegan:Connect(function()
				holding =
					TweenService:Create(hold, TweenInfo.new(prompt.HoldDuration), { Size = UDim2.fromScale(1, 1) })
				if holding then
					holding:Play()
				end
			end),
			prompt.PromptButtonHoldEnded:Connect(function()
				if holding then
					holding:Cancel()
				end
				hold.Size = UDim2.fromScale(1, 0)
			end),
			prompt.Triggered:Connect(function()
				hold.Size = UDim2.fromScale(1, 0)
			end),
		}
		prompt.PromptHidden:Once(function()
			for _, link in links do
				link:Disconnect()
			end
			board:Destroy()
		end)
	end)
end

local function healthTint(ratio: number): Color3
	return Color.Health:Lerp(Color3.fromRGB(214, 168, 70), math.clamp((ratio - 0.25) * 1.5, 0, 1))
end

local function resolveModel(instance: Instance): Model?
	if instance:IsA("Model") and instance:FindFirstChildOfClass("Humanoid") then
		return instance
	end
	local ancestor = instance:FindFirstAncestorOfClass("Model")
	if ancestor and ancestor:FindFirstChildOfClass("Humanoid") then
		return ancestor
	end
	return nil
end

local function relationship(model: Model): string?
	local ownerId = model:GetAttribute("MagicSummonOwnerUserId")
	if type(ownerId) == "number" then
		local owner = Players:GetPlayerByUserId(ownerId)
		if owner then
			if owner == player then
				return "Ally"
			end
			if player.Team and owner.Team then
				return if player.Team == owner.Team then "Ally" else "Enemy"
			end
			return "Enemy"
		end
	end
	local alignment = model:GetAttribute("SandboxAlignment") or model:GetAttribute("MagicAlignment")
	if alignment == "Ally" or alignment == "Enemy" then
		return alignment
	end
	if CollectionService:HasTag(model, "MagicAllyTarget") then
		return "Ally"
	end
	if CollectionService:HasTag(model, "MagicHostileTarget") then
		return "Enemy"
	end
	local targetPlayer = Players:GetPlayerFromCharacter(model)
	if targetPlayer then
		if targetPlayer == player then
			return nil
		end
		if player.Team and targetPlayer.Team then
			return if player.Team == targetPlayer.Team then "Ally" else "Enemy"
		end
		return "Enemy"
	end
	return nil
end

local function candidates(): { Model }
	local found: { [Model]: boolean } = {}
	local result = {}
	local function add(instance: Instance)
		local model = resolveModel(instance)
		if model and not found[model] and relationship(model) then
			found[model] = true
			table.insert(result, model)
		end
	end
	for _, tag in { "MagicHostileTarget", "MagicAllyTarget" } do
		for _, instance in CollectionService:GetTagged(tag) do
			add(instance)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			add(other.Character)
		end
	end
	local summons = workspace:FindFirstChild("MagicSummons")
	if summons then
		for _, model in summons:GetChildren() do
			add(model)
		end
	end
	return result
end

local function targetBar(model: Model, humanoid: Humanoid, anchor: BasePart, alignment: string): BillboardGui
	local gui = C.new("BillboardGui", {
		Name = "ClientTargetHealth",
		Adornee = anchor,
		Size = UDim2.fromOffset(170, 34),
		StudsOffset = Vector3.new(0, 2.8, 0),
		AlwaysOnTop = false,
		MaxDistance = 180,
		Enabled = false,
	}, model)
	local name = C.text(
		gui,
		"",
		Theme.TextSize.Small,
		if alignment == "Ally" then Color.Ally else Color.Bone,
		Theme.Font.Display,
		{
			Size = UDim2.new(1, 0, 0, 16),
			TextStrokeTransparency = 0.35,
		}
	)
	local bar = C.bar(gui, Vector2.new(150, 10), Color.Health, false)
	bar.Frame.Position = UDim2.fromOffset(10, 19)
	local function update()
		if not humanoid.Parent or not gui.Parent then
			return
		end
		local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
		bar.Set(ratio)
		bar.Fill.BackgroundColor3 = if alignment == "Ally" then Color.Ok else healthTint(ratio)
		name.Text = model:GetAttribute("SandboxLabel") or model.Name
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	model:GetAttributeChangedSignal("SandboxLabel"):Connect(update)
	update()
	return gui
end

local function startTargetBars()
	local active: { [Model]: { Gui: BillboardGui, Humanoid: Humanoid } } = {}
	local lastDiscover, lastVisibility, cursor = 0, 0, 1
	local function add(model: Model)
		if model == player.Character or active[model] or not model:IsDescendantOf(workspace) then
			return
		end
		local team = relationship(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local anchor = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if not team or not humanoid or not anchor or not anchor:IsA("BasePart") or humanoid.Health <= 0 then
			return
		end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BillboardGui") and descendant.Name ~= "ClientTargetHealth" then
				descendant.Enabled = false
			end
		end
		active[model] = { Gui = targetBar(model, humanoid, anchor, team), Humanoid = humanoid }
	end
	local function clear(model: Model)
		local record = active[model]
		if record then
			record.Gui:Destroy()
			active[model] = nil
		end
	end
	workspace.DescendantRemoving:Connect(function(instance)
		if instance:IsA("Model") then
			clear(instance)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local hidden = player:GetAttribute("MagicLabOpen") == true
		local now = os.clock()
		if now - lastDiscover >= 0.7 then
			lastDiscover = now
			for _, model in candidates() do
				add(model)
			end
			for model in active do
				if not model:IsDescendantOf(workspace) or not model:FindFirstChildOfClass("Humanoid") then
					clear(model)
				end
			end
		end
		if now - lastVisibility < 0.1 then
			return
		end
		lastVisibility = now
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local models = {}
		for model in active do
			table.insert(models, model)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		params.IgnoreWater = true
		params.RespectCanCollide = false
		for _ = 1, math.min(#models, 14) do
			if cursor > #models then
				cursor = 1
			end
			local model = models[cursor]
			cursor += 1
			local record = active[model]
			local anchor = record and record.Gui.Adornee
			if record and anchor and anchor:IsA("BasePart") then
				local visible = not hidden and record.Humanoid.Health > 0
				if visible then
					local screen, onScreen = camera:WorldToViewportPoint(anchor.Position + Vector3.new(0, 0.4, 0))
					local offset = anchor.Position - camera.CFrame.Position
					visible = onScreen and screen.Z > 0 and offset.Magnitude <= 180
					if visible then
						local hit = workspace:Raycast(camera.CFrame.Position, offset, params)
						visible = hit == nil or hit.Instance:IsDescendantOf(model)
					end
				end
				record.Gui.Enabled = visible
			end
		end
	end)
end

function WorldUI.start(container: Instance)
	startPrompts(container)
	startTargetBars()
end

return WorldUI
