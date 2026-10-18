local gui = game:GetService("Players").LocalPlayer.PlayerGui.FireSkinProbeReview
local before = gui:GetAttributes()
task.wait(2.2)
local after = gui:GetAttributes()
local mesh = gui.ViewportFrame.WorldModel.FireRigDeformationProbe.Flame_00
return game:GetService("HttpService"):JSONEncode({Before=before,After=after,MeshId=mesh.MeshId,
	TextureID=mesh.TextureID,Bones=#mesh:GetDescendants(),Scope="Imported mesh animated with rigid Bone.Transform poses; per-bone scale omitted"})
