local g=Instance.new("ScreenGui");g.Name="ConnectedFireV4ImageCheck";g.DisplayOrder=50000;g.IgnoreGuiInset=true;g.ResetOnSpawn=false
local images={}
local bank=game:GetService("ReplicatedStorage").ConnectedFireV4Study
for index=1,24 do
    local image=Instance.new("ImageLabel")
    image.Name=string.format("Frame_%03d",index)
    image.Size=UDim2.fromScale(1/6,1/4)
    image.Position=UDim2.fromScale((index-1)%6/6,math.floor((index-1)/6)/4)
    image.BackgroundColor3=Color3.fromRGB(40,42,47)
    image.Image=bank[image.Name].ColorMap;image.Parent=g;images[index]=image
end
g.Parent=game:GetService("Players").LocalPlayer.PlayerGui
task.wait(3)
local result={Loaded=0,Frames={}}
for index,image in images do
    if image.IsLoaded then result.Loaded+=1 end
    table.insert(result.Frames,{Frame=index,Id=image.Image,Loaded=image.IsLoaded})
end
g:Destroy()
return game:GetService("HttpService"):JSONEncode(result)
