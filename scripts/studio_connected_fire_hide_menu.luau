local pg=game:GetService("Players").LocalPlayer.PlayerGui
local g=pg.ConnectedFireV4WorldReview
local restore={}
for _,item in pg:GetChildren() do
    if item:IsA("ScreenGui") and item~=g then restore[item]=item.Enabled;item.Enabled=false end
end
g.Destroying:Connect(function() for item,value in restore do if item.Parent then item.Enabled=value end end end)
return "Temporarily hid the game's opaque menu overlays; they restore when the test closes"
