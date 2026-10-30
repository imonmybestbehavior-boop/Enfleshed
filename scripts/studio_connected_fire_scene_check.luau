local camera=workspace.CurrentCamera
local folder=workspace:FindFirstChild("ConnectedFireRuntimeTest")
local mesh=folder and folder:FindFirstChild("ConnectedFireVolume",true)
local lighting=game:GetService("Lighting")
local position,visible
if mesh then position,visible=camera:WorldToViewportPoint(mesh.Position) end
return game:GetService("HttpService"):JSONEncode({Camera={camera.CFrame:GetComponents()},Viewport={camera.ViewportSize.X,camera.ViewportSize.Y},
    Mesh=mesh and {Position={mesh.Position.X,mesh.Position.Y,mesh.Position.Z},Transparency=mesh.Transparency,
        Projected=position and {position.X,position.Y,position.Z},OnScreen=visible},
    Lighting={Exposure=lighting.ExposureCompensation,Brightness=lighting.Brightness,FogStart=lighting.FogStart,FogEnd=lighting.FogEnd},
    Descendants=#workspace:GetDescendants()})
