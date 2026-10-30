local rs=game:GetService("ReplicatedStorage")
local s=rs.Shared.SpellVFXSystem
return game:GetService("HttpService"):JSONEncode({
 RendererHasEndpointFix=string.find(s.Signature.SignatureRenderer.Source,'self.Role=="Beam"',1,true)~=nil,
 PlannerHasReleaseFix=string.find(s.Signature.SignaturePlanner.Source,'spec.Kind~="Light"',1,true)~=nil,
 ComposerHasReleaseFix=string.find(s.Core.SpellVFXComposer.Source,'render.Layers = {}',1,true)~=nil,
 Renderer=s.Signature.SignatureRenderer.Source,
})
