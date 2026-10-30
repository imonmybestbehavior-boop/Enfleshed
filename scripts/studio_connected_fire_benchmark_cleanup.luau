local system=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem
-- Run only between checks in this isolated playtest; prior failed fixtures may own sessions.
require(system.Signature.SignatureRenderer).stopAll()
for _,item in workspace:GetChildren() do
    if item.Name=="ConnectedFireBenchmark" then item:Destroy() end
end
local pg=game:GetService("Players").LocalPlayer.PlayerGui
local gui=pg:FindFirstChild("ConnectedFireBenchmarkReview");if gui then gui:Destroy() end
for _,item in system.Signature:GetChildren() do
    if item.Name=="ConnectedFireBenchmarkRenderer" then item:Destroy() end
end
return game:GetService("HttpService"):JSONEncode(require(system.Signature.ConnectedFire).stats())
