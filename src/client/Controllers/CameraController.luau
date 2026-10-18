--!strict

-- A compact Scriptable third-person camera. It owns gameplay mouse look but can
-- release the cursor for a future UI without that UI depending on camera internals.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Configuration.Sandbox).Camera
local studioSandbox = game:GetService("RunService"):IsStudio()
	and require(game:GetService("ReplicatedStorage").Shared.Configuration.DevelopmentSandbox).Enabled
local Camera = {}

function Camera.start()
	local player = Players.LocalPlayer
	local enabled = true
	local yaw = 0
	local pitch = Config.InitialPitch
	local gui = Instance.new("ScreenGui")
	gui.Name = "SandboxCrosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 120
	gui.Parent = player:WaitForChild("PlayerGui")
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Center"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(0, 0)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = gui
	for _, line in
		{
			{
				UDim2.fromOffset(Config.Crosshair.Thickness, Config.Crosshair.Size),
				UDim2.fromOffset(0, -Config.Crosshair.Gap),
			},
			{
				UDim2.fromOffset(Config.Crosshair.Thickness, Config.Crosshair.Size),
				UDim2.fromOffset(0, Config.Crosshair.Gap),
			},
			{
				UDim2.fromOffset(Config.Crosshair.Size, Config.Crosshair.Thickness),
				UDim2.fromOffset(-Config.Crosshair.Gap, 0),
			},
			{
				UDim2.fromOffset(Config.Crosshair.Size, Config.Crosshair.Thickness),
				UDim2.fromOffset(Config.Crosshair.Gap, 0),
			},
		}
	do
		local part = Instance.new("Frame")
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Size = line[1]
		part.Position = UDim2.fromScale(0.5, 0.5) + line[2]
		part.BackgroundColor3 = Color3.fromRGB(255, 239, 198)
		part.BackgroundTransparency = math.min(Config.Crosshair.Transparency, 0.05)
		part.BorderSizePixel = 0
		part.ZIndex = 10
		part.Parent = crosshair
	end

	-- ALT toggles a free cursor during gameplay; aim stays on the crosshair.
	local hint = Instance.new("TextLabel")
	hint.Name = "CursorHint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.5, 26)
	hint.Size = UDim2.fromOffset(220, 18)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.GothamBold
	hint.TextSize = 12
	hint.TextColor3 = Color3.fromRGB(255, 239, 198)
	hint.TextStrokeTransparency = 0.4
	hint.Text = "ALT · LOCK AIM"
	hint.Visible = false
	hint.Parent = gui
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			player:SetAttribute("CursorFreed", player:GetAttribute("CursorFreed") ~= true)
		end
	end)

	local mouseLocked: boolean? = nil
	local function setMouseLocked(value: boolean)
		local grimoireOpen = player:GetAttribute("MagicLabOpen") == true
		local missionCursor = player:GetAttribute("UIModalOpen") == true
		value = value and not missionCursor
		local desiredBehavior = if value then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
		local desiredIconEnabled = not value and (missionCursor or not grimoireOpen)
		-- Only repair properties when another UI (for example, the Escape menu)
		-- has changed them. This keeps gameplay mouse state stable without
		-- rewriting it every frame, while the grimoire can own its custom cursor.
		if mouseLocked == value then
			if UserInputService.MouseBehavior ~= desiredBehavior then
				UserInputService.MouseBehavior = desiredBehavior
			end
			if UserInputService.MouseIconEnabled ~= desiredIconEnabled then
				UserInputService.MouseIconEnabled = desiredIconEnabled
			end
			return
		end
		mouseLocked = value
		UserInputService.MouseBehavior = desiredBehavior
		UserInputService.MouseIconEnabled = desiredIconEnabled
		-- Keep the aim reticle visible while the editor releases the mouse. The
		-- crosshair marks the viewport-center aim ray in both states.
		gui.Enabled = true
	end

	local function getRoot(): BasePart?
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		return if root and root:IsA("BasePart") then root else nil
	end

	local function getAim(): (Vector3, Vector3, Model?, Instance?)
		local camera = Workspace.CurrentCamera
		if not camera then
			return Vector3.zAxis, Vector3.zero, nil, nil
		end
		local viewport = camera.ViewportSize
		local centerRay = camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character or Workspace }
		params.RespectCanCollide = true
		local direction = centerRay.Direction.Unit
		local hit = Workspace:Raycast(centerRay.Origin, direction * Config.AimDistance, params)
		local target: Model? = nil
		local targetParams = RaycastParams.new()
		targetParams.FilterType = Enum.RaycastFilterType.Exclude
		targetParams.FilterDescendantsInstances = { player.Character or Workspace }
		targetParams.RespectCanCollide = false
		local targetHit = Workspace:Raycast(centerRay.Origin, direction * Config.AimDistance, targetParams)
		if targetHit then
			local model = targetHit.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				target = model
			end
		end
		return direction,
			if hit then hit.Position else centerRay.Origin + direction * Config.AimDistance,
			target,
			if targetHit then targetHit.Instance else nil
	end

	function Camera:SetGameplayMouseLookEnabled(value: boolean)
		enabled = value
		setMouseLocked(
			value
				and player:GetAttribute("MagicLabOpen") ~= true
				and (studioSandbox or player:GetAttribute("CharacterReady") == true)
		)
	end

	RunService:BindToRenderStep("SandboxThirdPersonCamera", Enum.RenderPriority.Camera.Value, function()
		local camera = Workspace.CurrentCamera
		local root = getRoot()
		if not camera or not root then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local playing = enabled
			and (studioSandbox or player:GetAttribute("CharacterReady") == true)
			and not player:GetAttribute("MagicLabOpen")
			and not player:GetAttribute("InventoryOpen")
			and not player:GetAttribute("UIModalOpen")
		hint.Visible = playing and player:GetAttribute("CursorFreed") == true
		setMouseLocked(playing and player:GetAttribute("CursorFreed") ~= true)
		local character = player.Character
		local rotationLocked = character and character:GetAttribute("MagicRotationLocked") == true
		local delta = if playing and not rotationLocked then UserInputService:GetMouseDelta() else Vector2.zero
		yaw -= delta.X * Config.MouseSensitivity
		pitch = math.clamp(pitch - delta.Y * Config.MouseSensitivity, Config.MinimumPitch, Config.MaximumPitch)
		local target = root.Position + Vector3.new(0, Config.Height, 0)
		local rotation = CFrame.fromOrientation(pitch, yaw, 0)
		local desired = target - rotation.LookVector * Config.Distance + rotation.RightVector * Config.ShoulderOffset
		local offset = desired - target
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		params.RespectCanCollide = true
		local obstruction = Workspace:Raycast(target, offset, params)
		local position = desired
		if obstruction then
			position = target + offset.Unit * math.max(0, obstruction.Distance - Config.ObstructionPadding)
		end
		camera.CFrame = CFrame.lookAt(position, target)
		camera.Focus = CFrame.new(target)
	end)

	UserInputService.TextBoxFocused:Connect(function()
		Camera:SetGameplayMouseLookEnabled(false)
	end)
	UserInputService.TextBoxFocusReleased:Connect(function()
		Camera:SetGameplayMouseLookEnabled(true)
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		Camera:SetGameplayMouseLookEnabled(false)
	end)
	UserInputService.WindowFocused:Connect(function()
		Camera:SetGameplayMouseLookEnabled(true)
	end)
	GuiService.MenuOpened:Connect(function()
		Camera:SetGameplayMouseLookEnabled(false)
	end)
	GuiService.MenuClosed:Connect(function()
		Camera:SetGameplayMouseLookEnabled(true)
	end)

	setMouseLocked(studioSandbox or player:GetAttribute("CharacterReady") == true)
	return {
		GetAim = getAim,
		SetGameplayMouseLookEnabled = function(value: boolean)
			Camera:SetGameplayMouseLookEnabled(value)
		end,
	}
end

return Camera
