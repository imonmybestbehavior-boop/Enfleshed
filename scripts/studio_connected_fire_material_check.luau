local g=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4Review
local mesh=g:FindFirstChildOfClass("ViewportFrame"):FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model").ConnectedFireVolume
local surface=mesh:FindFirstChildOfClass("SurfaceAppearance")
if surface then surface.Parent=g.SurfaceFramePool end
mesh.TextureID=""
task.wait(.3)
return "Removed material from the paused test clone to isolate rendering from surface loading"
