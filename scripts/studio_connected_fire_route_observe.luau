local shared=game:GetService("ReplicatedStorage").Shared
local result=Instance.new("Folder");result.Name="ConnectedFireRouteObservation";result.Parent=shared
result:SetAttribute("Packets",0)
local conn=shared.SandboxRemotes.ActionRequest.OnServerEvent:Connect(function(player,data)
    result:SetAttribute("Packets",result:GetAttribute("Packets")+1)
    if type(data)=="table" then result:SetAttribute("LastSequence",data.Sequence);result:SetAttribute("LastAction",data.Action) end
end)
task.delay(30,function() conn:Disconnect() end)
local players={}
for _,p in game:GetService("Players"):GetPlayers() do
    local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
    table.insert(players,{Name=p.Name,Ready=p:GetAttribute("CharacterReady"),Health=hum and hum.Health})
end
return game:GetService("HttpService"):JSONEncode({Sandbox=require(shared.Configuration.DevelopmentSandbox).Enabled,Players=players})
