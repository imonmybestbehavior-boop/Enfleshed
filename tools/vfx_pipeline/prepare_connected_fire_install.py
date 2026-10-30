"""Prepare a reviewable Studio install of the reusable rig and source modules."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"assets/vfx/studies/3d_fire_v4"
def literal(text):
    level="="
    while "]"+level+"]" in text: level+="="
    return "["+level+"["+text+"]"+level+"]"
files=["Signature/ConnectedFire", "Assets/ConnectedFirePoses", "Signature/DirectionalSprite",
    "Assets/DirectionalSpriteManifest", "Assets/VFXAssets", "Signature/SignaturePlanner",
    "Signature/SignatureLibrary", "Signature/SignatureRenderer"]
code=['assert(not game:GetService("RunService"):IsRunning(), "Install in Edit mode")',
    'local system=game:GetService("ReplicatedStorage").Shared.SpellVFXSystem',
    'local source=workspace.connected_fireball.ConnectedFireVolume',
    'assert(source.MeshId=="rbxassetid://135760105803974", "Unexpected source mesh")',
    'assert(not system.Assets:FindFirstChild("ConnectedFireRig"), "Runtime rig already exists; inspect before retrying")',
    'local model=Instance.new("Model");model.Name="ConnectedFireRig"',
    'local mesh=source:Clone();mesh.CFrame=CFrame.identity;mesh.Anchored=true',
    'mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false;mesh.CastShadow=false;mesh.Transparency=0',
    'for _,child in mesh:GetDescendants() do',
    ' if child:IsA("BaseScript") or child:IsA("SurfaceAppearance") then child:Destroy()',
    ' elseif child:IsA("Bone") then child.Transform=CFrame.identity end',
    'end',
    'mesh.Parent=model;model.PrimaryPart=mesh',
    'local frames=Instance.new("Folder");frames.Name="Frames";frames.Parent=model',
    'local bank=game:GetService("ReplicatedStorage").ConnectedFireV4Study',
    'for i=1,24 do bank[string.format("Frame_%03d",i)]:Clone().Parent=frames end',
    'model:SetAttribute("Revision",4);model:SetAttribute("MeshIdVerified",source.MeshId)',
    'model.Parent=system.Assets']
for file in files:
    parent,name=file.split("/")
    text=(ROOT/"src/shared/SpellVFXSystem"/(file+".luau")).read_text(encoding="utf-8")
    code += ['do',f' local parent=system.{parent}',f' local module=parent:FindFirstChild("{name}")',
        f' if not module then module=Instance.new("ModuleScript");module.Name="{name}";module.Parent=parent end',
        ' assert(module:IsA("ModuleScript"),"Source target is not a module")',
        ' module.Source='+literal(text),'end','task.wait()']
code += ['return game:GetService("HttpService"):JSONEncode({Rig=model:GetFullName(),Frames=#frames:GetChildren(),Modules=8,SourceImportChanged=false})']
(ROOT/"scripts/studio_connected_fire_install.luau").write_text("\n".join(code)+"\n",encoding="utf-8")
print("Prepared reusable rig install and eight source/dependency modules; original import remains untouched")
