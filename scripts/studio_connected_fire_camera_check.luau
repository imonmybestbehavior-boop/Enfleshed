local g=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4Review
local v=g:FindFirstChildOfClass("ViewportFrame")
local m=v:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model").ConnectedFireVolume
local camera=v.CurrentCamera
local result={Camera={camera.CFrame:GetComponents()},Mesh={m.CFrame:GetComponents()},Root={m.Root.WorldCFrame:GetComponents()},Enabled=g.Enabled,Visible=v.Visible}
g:SetAttribute("ReviewAngle",.0001)
task.wait(.2)
return game:GetService("HttpService"):JSONEncode(result)
