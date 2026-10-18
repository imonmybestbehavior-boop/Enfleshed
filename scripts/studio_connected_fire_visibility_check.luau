local g=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4StaticCompare
local rows={}
for _,v in g:GetChildren() do
    if v:IsA("ViewportFrame") then
        local mesh=v:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model").ConnectedFireVolume
        table.insert(rows,{Transparency=mesh.Transparency,LocalTransparency=mesh.LocalTransparencyModifier,
            Position={mesh.Position.X,mesh.Position.Y,mesh.Position.Z},Size={mesh.Size.X,mesh.Size.Y,mesh.Size.Z},
            Root={mesh.Root.WorldCFrame.Position.X,mesh.Root.WorldCFrame.Position.Y,mesh.Root.WorldCFrame.Position.Z}})
        mesh.LocalTransparencyModifier=0;mesh.Transparency=0
        mesh.CFrame=mesh.CFrame*CFrame.new(.001,0,0)
    end
end
return game:GetService("HttpService"):JSONEncode(rows)
