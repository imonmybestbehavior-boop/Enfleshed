-- Client-only playtest review; no saved objects or gameplay changes.
local RunService = game:GetService("RunService")
assert(RunService:IsClient(), "Run this review in a Studio playtest client")
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local prior = playerGui:FindFirstChild("DirectionalFirePlaybackReview")
if prior then prior:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "DirectionalFirePlaybackReview"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(1,1)
panel.BackgroundColor3 = Color3.fromRGB(18,21,28)
panel.Parent = gui
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,0,0,60)
title.BackgroundTransparency = 1
title.Text = "PAINTED FIRE | STUDIO PLAYBACK REVIEW"
title.TextColor3 = Color3.new(1,1,1)
title.TextSize = 24
title.Font = Enum.Font.GothamBold
title.Parent = panel
local entries = {
	{"FRONT", "rbxassetid://81011468551955"},
	{"THREE QUARTER", "rbxassetid://81316819745490"},
	{"TRUE SIDE", "rbxassetid://97561699384624"},
	{"REAR", "rbxassetid://92127109486544"},
}
local images = {}
for index, entry in entries do
	local image = Instance.new("ImageLabel")
	image.Name = entry[1]
	image.AnchorPoint = Vector2.new(.5,.5)
	image.Position = UDim2.fromScale((index-.5)/4,.5)
	image.Size = UDim2.fromScale(.245,.65)
	image.ScaleType = Enum.ScaleType.Fit
	image.BackgroundTransparency = 1
	image.ImageColor3 = Color3.new(1,1,1)
	image.Image = entry[2]
	image.ImageRectSize = Vector2.new(256,256)
	image.Parent = panel
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = image
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(.5,0)
	label.Position = UDim2.fromScale((index-.5)/4,.8)
	label.Size = UDim2.fromScale(.24,.07)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1,1,1)
	label.Font = Enum.Font.Gotham
	label.TextSize = 16
	label.Text = entry[1]
	label.Parent = panel
	table.insert(images, image)
end
local status = title:Clone()
status.Position = UDim2.fromScale(0,.89)
status.TextSize = 16
status.Font = Enum.Font.Gotham
status.Parent = panel
gui.Parent = playerGui
local born, updates, loops, lastFrame = os.clock(), 0, 0, -1
local connection
connection = RunService.RenderStepped:Connect(function()
	if not gui.Parent then connection:Disconnect(); return end
	local step = math.floor((os.clock()-born)*8)
	local frame = step % 8
	if frame ~= lastFrame then
		updates += 1
		if frame == 0 and lastFrame == 7 then loops += 1 end
		lastFrame = frame
	end
	local loaded = 0
	for _, image in images do
		image.ImageRectOffset = Vector2.new((frame % 4)*256, math.floor(frame/4)*256)
		if image.IsLoaded then loaded += 1 end
	end
	gui:SetAttribute("FrameUpdates", updates)
	gui:SetAttribute("CompletedLoops", loops)
	gui:SetAttribute("LoadedImages", loaded)
	gui:SetAttribute("CurrentFrame", frame+1)
	status.Text = string.format("8 FPS  |  FRAME %d / 8  |  %d / 4 IMAGES LOADED  |  %d LOOPS", frame+1, loaded, loops)
end)
return "Client review started. Inspect DirectionalFirePlaybackReview attributes for frame/loop and load evidence."
