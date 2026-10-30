local pg=game:GetService("Players").LocalPlayer.PlayerGui
for _,name in {"ConnectedFireV4Review","ConnectedFireV4StaticCompare","ConnectedFireV4WorldReview"} do
    local gui=pg:FindFirstChild(name);if gui then gui:Destroy() end
end
for _,name in {"ConnectedFireV4Preview","ConnectedFireV4WorldPreview","ConnectedFireV4DiagnosticMarker"} do
    local item=workspace:FindFirstChild(name);if item then item:Destroy() end
end
return "Closed temporary review windows and restored camera/menu state"
