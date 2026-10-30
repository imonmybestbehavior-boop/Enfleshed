local system=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local composer=require(system.Core.SpellVFXComposer)
return game:GetService("HttpService"):JSONEncode({ComposerUsesRenderer=composer.Signatures==renderer,
    Renderer=renderer.stats(),ConnectedEnabled=renderer.UseConnectedFire,
    AssetReady=require(system.Signature.ConnectedFire).ready(),Scope="Normal LocalScript VM"})
