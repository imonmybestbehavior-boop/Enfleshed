"""Prepare a Studio clone-only pose probe from the imported rig and Blender poses."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/"assets/vfx/studies/3d_fire_v1"
poses = (OUT/"pose_probe.json").read_text()
code = '''-- Client-only isolated deformation probe. Original imported model remains unchanged.
assert(game:GetService("RunService"):IsClient(), "Run the animated probe in a Studio playtest client")
local frames = game:GetService("HttpService"):JSONDecode([==[__POSES__]==])
local source = workspace:FindFirstChild("single_flame_transport")
assert(source and source:FindFirstChild("Flame_00"), "Imported test model is missing")
assert(not workspace:FindFirstChild("FireRigDeformationProbe"), "Existing probe must be cleaned up before another is created")
local clone = source:Clone()
clone.Name = "FireRigDeformationProbe"
clone:ScaleTo(source:GetScale()*.01)
local mesh = clone.Flame_00
mesh.Anchored = true
mesh.CanCollide,mesh.CanTouch,mesh.CanQuery = false,false,false
clone.Parent = workspace
local gui = Instance.new("ScreenGui")
gui.Name = "FireSkinProbeReview"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10000
local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1,1)
viewport.BackgroundColor3 = Color3.fromRGB(24,27,35)
viewport.Ambient = Color3.new(1,1,1)
viewport.LightColor = Color3.new(0,0,0)
viewport.Parent = gui
local world = Instance.new("WorldModel")
world.Parent = viewport
clone.Parent = world
local camera = Instance.new("Camera")
camera.Parent = viewport
viewport.CurrentCamera = camera
clone:PivotTo(CFrame.new())
local root = mesh.Root
local target = root.WorldCFrame.Position+Vector3.new(-.4,0,0)
camera.CFrame = CFrame.lookAt(target+Vector3.new(0,3,7),target)
gui.Parent = if game:GetService("RunService"):IsClient() then game:GetService("Players").LocalPlayer.PlayerGui else game:GetService("CoreGui")
local function convert(v)
    return Vector3.new(v[1],-v[3],v[2])
end
local function apply(index)
    for i,pose in frames[index] do
        local bone = root[string.format("Flow_%02d",i-1)]
        local position = convert({pose[1],pose[2],pose[3]})
        local right = convert({pose[4],pose[7],pose[10]})
        local up = convert({pose[5],pose[8],pose[11]})
        local back = convert({pose[6],pose[9],pose[12]})
        bone.Transform = bone.CFrame:Inverse()*CFrame.fromMatrix(position,right,up,back)
    end
    clone:SetAttribute("ProbeFrame",index)
end
apply(13)
local born = os.clock()
local updates, previous = 0, 0
local connection
connection = game:GetService("RunService").RenderStepped:Connect(function()
    if not gui.Parent then connection:Disconnect(); return end
    local index = math.floor((os.clock()-born)*24)%48+1
    if index ~= previous then
        previous = index
        updates += 1
        apply(index)
        gui:SetAttribute("FrameUpdates",updates)
        gui:SetAttribute("Frame",index)
    end
end)
clone:SetAttribute("ProbeScope","Rigid bone poses only; Blender width scaling is not represented")
task.wait(2)
return game:GetService("HttpService"):JSONEncode({Clone=clone:GetFullName(),MeshId=mesh.MeshId,
    TextureID=mesh.TextureID,Frame=13,Size={mesh.Size.X,mesh.Size.Y,mesh.Size.Z},
    Scope="Isolated cloned import; source unchanged; per-bone scale omitted"})
'''.replace("__POSES__",poses)
(ROOT/"scripts/studio_fire_deformation_probe.luau").write_text(code,encoding="utf-8")
print("Prepared isolated Studio deformation probe from actual source poses")
