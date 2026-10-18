local run=game:GetService("RunService")
local ok,err=pcall(function() run:Set3dRenderingEnabled(true) end)
local camera=workspace.CurrentCamera
return game:GetService("HttpService"):JSONEncode({EnableOK=ok,Error=if ok then nil else tostring(err),Camera={camera.CFrame:GetComponents()}})
