local viewport = game:GetService("CoreGui").FireSkinProbeReview.ViewportFrame
local mesh = viewport.WorldModel.FireRigDeformationProbe.Flame_00
local root = mesh.Root
local function v(p) return {p.X,p.Y,p.Z} end
local result = {Camera=v(viewport.CurrentCamera.CFrame.Position),Mesh=v(mesh.Position),Root=v(root.WorldPosition),Bones={}}
for _, bone in {root.Flow_00,root.Flow_10,root.Flow_20} do
	table.insert(result.Bones,{Name=bone.Name,Bind=v(bone.Position),World=v(bone.TransformedWorldCFrame.Position),Transform=v(bone.Transform.Position)})
end
return game:GetService("HttpService"):JSONEncode(result)
