local probe = workspace:FindFirstChild("FireRigDeformationProbe")
if probe then
	local camera = workspace.CurrentCamera
	camera.CFrame = probe:GetAttribute("SavedCameraFrame") or camera.CFrame
	local kind = probe:GetAttribute("SavedCameraType")
	if kind then camera.CameraType = Enum.CameraType[kind] end
	probe:Destroy()
end
local gui = game:GetService("CoreGui"):FindFirstChild("FireSkinProbeReview")
if gui then gui:Destroy() end
local player = game:GetService("Players").LocalPlayer
local playerGui = player and player:FindFirstChild("PlayerGui")
local clientGui = playerGui and playerGui:FindFirstChild("FireSkinProbeReview")
if clientGui then clientGui:Destroy() end
return "Removed only the temporary fire probe; original import preserved."
