local system=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem
return game:GetService("HttpService"):JSONEncode({Renderer=system.Signature.SignatureRenderer.Source,
    Imported=workspace.connected_fireball.ConnectedFireVolume.MeshId,
    ExistingRuntime=system.Signature:FindFirstChild("ConnectedFire")~=nil,
    ExistingRig=system.Assets:FindFirstChild("ConnectedFireRig")~=nil})
