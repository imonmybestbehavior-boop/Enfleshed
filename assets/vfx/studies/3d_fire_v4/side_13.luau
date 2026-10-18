local g=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4Review
g:SetAttribute("Paused",true)
g:SetAttribute("ReviewFrame",13)
g:SetAttribute("ReviewAngle",0)
task.wait(.2)
return game:GetService("HttpService"):JSONEncode(g:GetAttributes())
