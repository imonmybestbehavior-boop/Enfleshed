--!strict

-- A compact Scriptable third-person camera. It owns gameplay mouse look but can
-- release the cursor for a future UI without that UI depending on camera internals.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Configuration.Sandbox).Camera
local Camera = {}

function Camera.start()
	local player = Players.LocalPlayer
	local enabled = true
	local yaw = 0
	local pitch = math.rad(-12)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SandboxCrosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
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
		part.BackgroundColor3 = Color3.new(1, 1, 1)
		part.BackgroundTransparency = Config.Crosshair.Transparency
		part.BorderSizePixel = 0
		part.Parent = crosshair
	end

	local function setMouseLocked(value: boolean)
		UserInputService.MouseBehavior = if value then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = not value
		gui.Enabled = value
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
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character or Workspace }
		params.RespectCanCollide = true
		local direction = camera.CFrame.LookVector
		local hit = Workspace:Raycast(camera.CFrame.Position, direction * Config.AimDistance, params)
		local target: Model? = nil
		local targetParams = RaycastParams.new()
		targetParams.FilterType = Enum.RaycastFilterType.Exclude
		targetParams.FilterDescendantsInstances = { player.Character or Workspace }
		targetParams.RespectCanCollide = false
		local targetHit = Workspace:Raycast(camera.CFrame.Position, direction * Config.AimDistance, targetParams)
		if targetHit then
			local model = targetHit.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				target = model
			end
		end
		return direction,
			if hit then hit.Position else camera.CFrame.Position + direction * Config.AimDistance,
			target,
			if targetHit then targetHit.Instance else nil
	end

	function Camera:SetGameplayMouseLookEnabled(value: boolean)
		enabled = value
		setMouseLocked(value and player:GetAttribute("OpeningComplete") == true)
	end

	RunService:BindToRenderStep("SandboxThirdPersonCamera", Enum.RenderPriority.Camera.Value, function()
		local camera = Workspace.CurrentCamera
		local root = getRoot()
		if not camera or not root then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local playing = enabled
			and player:GetAttribute("OpeningComplete") == true
			and not player:GetAttribute("MagicLabOpen")
		setMouseLocked(playing)
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

	setMouseLocked(player:GetAttribute("OpeningComplete") == true)
	return {
		GetAim = getAim,
		SetGameplayMouseLookEnabled = function(value: boolean)
			Camera:SetGameplayMouseLookEnabled(value)
		end,
	}
end

return Camera
