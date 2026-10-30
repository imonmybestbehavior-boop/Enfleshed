local shared=game:GetService("ReplicatedStorage").Shared
local rows={}
for _,p in game:GetService("Players"):GetPlayers() do
    table.insert(rows,{Name=p.Name,Ready=p:GetAttribute("CharacterReady"),Character=p.Character~=nil})
end
local result=Instance.new("Folder");result.Name="ConnectedFireTransportProbe";result.Parent=shared
result:SetAttribute("Packets",0)
local conn=shared.SandboxRemotes.ActionRequest.OnServerEvent:Connect(function(p,data)
    result:SetAttribute("Packets",result:GetAttribute("Packets")+1)
    if type(data)=="table" then result:SetAttribute("Sequence",data.Sequence) end
end)
task.delay(60,function() conn:Disconnect() end)
return game:GetService("HttpService"):JSONEncode({Running=game:GetService("RunService"):IsRunning(),Players=rows})
