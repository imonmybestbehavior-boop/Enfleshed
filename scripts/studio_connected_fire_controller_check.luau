local system=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local composer=require(system.Core.SpellVFXComposer)
local client=game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("Client")
return game:GetService("HttpService"):JSONEncode({ComposerUsesRenderer=composer.Signatures==renderer,
    Renderer=renderer.stats(),ConnectedEnabled=renderer.UseConnectedFire,
    ClientStartsVFX=client and string.find(client.Source,'startController("SpellVFXController"',1,true)~=nil,
    ControllerHasBridge=client and string.find(client.Controllers.SpellVFXController.Source,"Composer.Signatures = Signatures",1,true)~=nil,
    AssetReady=require(system.Signature.ConnectedFire).ready()})
