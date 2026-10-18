local viewport = game:GetService("CoreGui").FireSkinProbeReview.ViewportFrame
local mesh = viewport.WorldModel.FireRigDeformationProbe.Flame_00
local before={Transparency=mesh.Transparency,LocalTransparencyModifier=mesh.LocalTransparencyModifier,DoubleSided=mesh.DoubleSided}
mesh.Transparency = 0
mesh.LocalTransparencyModifier = 0
mesh.DoubleSided = true
for _, bone in mesh:GetDescendants() do if bone:IsA("Bone") then bone.Transform = CFrame.identity end end
viewport.CurrentCamera.CFrame = CFrame.lookAt(mesh.Position+Vector3.new(0,3,9),mesh.Position)
task.wait(2)
return game:GetService("HttpService"):JSONEncode(before)
