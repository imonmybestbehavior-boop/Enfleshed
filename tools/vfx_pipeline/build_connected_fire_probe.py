"""Build an isolated client preview using measured imported bind-space mapping."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/vfx/studies/3d_fire_v4"
poses = json.loads((OUT / "pose_probe.json").read_text())
mapping = json.loads((OUT / "bind_mapping.json").read_text())
assert mapping["max_bind_error"] < 1e-5, "Imported rig does not match source bind positions"
m = mapping["matrix"]
converted = []
for frame in poses["frames"]:
    converted.append([[round(sum(delta[i]*m[i][j] for i in range(3)), 8) for j in range(3)] for delta in frame])
payload = json.dumps({"names":poses["names"], "frames":converted}, separators=(",", ":"))
code = '''-- Isolated client preview. Original import and live spell renderer are untouched.
local run = game:GetService("RunService")
assert(run:IsClient(), "Run in a Studio playtest client")
local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
assert(not playerGui:FindFirstChild("ConnectedFireV4Review"), "Existing review must be closed before another is created")
local data = game:GetService("HttpService"):JSONDecode([==[__PAYLOAD__]==])
local source = game:GetService("ReplicatedStorage"):WaitForChild("ConnectedFireV4ImportClone",15)
assert(source, "Stage the complete import on the test server first")
local bank = game:GetService("ReplicatedStorage"):WaitForChild("ConnectedFireV4Study")
local clone = source:Clone()
clone.Name = "ConnectedFireV4Preview"
local mesh = clone:FindFirstChild("ConnectedFireVolume", true)
assert(mesh and mesh:IsA("MeshPart"), "Missing imported mesh")
for _, child in clone:GetDescendants() do
    if child:IsA("BaseScript") or child:IsA("SurfaceAppearance") then child:Destroy()
    elseif child:IsA("BasePart") then
        child.Anchored=true; child.CanCollide=false; child.CanTouch=false; child.CanQuery=false
        child.CastShadow=false
    end
end
mesh.Color = Color3.new(1,1,1)
mesh.Transparency=0
local gui = Instance.new("ScreenGui")
gui.Name="ConnectedFireV4Review"; gui.IgnoreGuiInset=true; gui.DisplayOrder=10000; gui.ResetOnSpawn=false
gui:SetAttribute("Paused", false); gui:SetAttribute("Orbit", false)
local viewport=Instance.new("ViewportFrame")
viewport.Size=UDim2.fromScale(1,1); viewport.BackgroundColor3=Color3.fromRGB(40,42,47)
viewport.Ambient=Color3.new(1,1,1); viewport.LightColor=Color3.new(0,0,0); viewport.Parent=gui
local world=Instance.new("WorldModel"); world.Parent=viewport; clone.Parent=world
clone:PivotTo(CFrame.Angles(0,math.pi,0))
local camera=Instance.new("Camera"); camera.FieldOfView=38; camera.Parent=viewport; viewport.CurrentCamera=camera
local root=mesh:FindFirstChild("Root")
local target=root.WorldCFrame.Position+Vector3.new(-.8,0,0)
local pool=Instance.new("Folder"); pool.Name="SurfaceFramePool"; pool.Parent=gui
local surfaces, ids = {}, {}
for index=1,24 do
    surfaces[index]=bank[string.format("Frame_%03d",index)]:Clone()
    surfaces[index].Parent=pool
    ids[index]=surfaces[index].ColorMap
end
local statuses={}
local fetchOK,fetchError=pcall(function()
    game:GetService("ContentProvider"):PreloadAsync(ids,function(id,status)
        table.insert(statuses,{Id=id,Status=status.Name})
    end)
end)
local bones={}
for index,name in data.names do bones[index]=root:FindFirstChild(name); assert(bones[index],name) end
local label=Instance.new("TextLabel")
label.Size=UDim2.new(1,-32,0,52); label.Position=UDim2.fromOffset(16,72)
label.BackgroundTransparency=1; label.TextColor3=Color3.new(1,1,1); label.TextSize=18
label.Font=Enum.Font.Gotham; label.TextXAlignment=Enum.TextXAlignment.Left
label.Text="3D fireball · isolated Studio test"; label.Parent=gui
local function button(text,x,callback)
    local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(110,36); b.Position=UDim2.new(0,x,1,-52)
    b.Text=text; b.Font=Enum.Font.Gotham; b.TextSize=15; b.BackgroundColor3=Color3.fromRGB(244,184,70)
    b.Parent=gui; b.Activated:Connect(callback); return b
end
local pause=button("Pause",16,function() gui:SetAttribute("Paused",not gui:GetAttribute("Paused")) end)
button("Side / Orbit",138,function() gui:SetAttribute("Orbit",not gui:GetAttribute("Orbit")) end)
button("Close test",260,function() gui:Destroy() end)
gui.Parent=playerGui
local active,previous=0,0
local baseFrame=mesh.CFrame
local time,updates,switches,totalCost,maxCost=0,0,0,0,0
local connection
connection=run.RenderStepped:Connect(function(dt)
    if not gui.Parent then connection:Disconnect(); return end
    if not gui:GetAttribute("Paused") then time+=dt end
    local index=if gui:GetAttribute("Paused") and gui:GetAttribute("ReviewFrame") then math.clamp(gui:GetAttribute("ReviewFrame"),1,48) else math.floor(time*24)%48+1
    local texture=math.floor((index-1)/2)+1
    local started=os.clock()
    if previous~=index then
        previous=index
        if active~=texture then
            if active>0 then surfaces[active].Parent=pool end
            surfaces[texture].Parent=mesh;active=texture;switches+=1
        end
        for i,bone in bones do
            local v=data.frames[index][i]
            local delta=Vector3.new(v[1],v[2],v[3])
            bone.Transform=CFrame.new(bone.CFrame:VectorToObjectSpace(delta))
        end
        updates+=1
        local cost=(os.clock()-started)*1000; totalCost+=cost; maxCost=math.max(maxCost,cost)
        gui:SetAttribute("FrameUpdates",updates); gui:SetAttribute("SurfaceSwitches",switches)
        gui:SetAttribute("Frame",index); gui:SetAttribute("TextureFrame",texture)
        gui:SetAttribute("MeanUpdateMS",totalCost/updates); gui:SetAttribute("MaxUpdateMS",maxCost)
    end
    local angle=if gui:GetAttribute("ReviewAngle") then gui:GetAttribute("ReviewAngle") elseif gui:GetAttribute("Orbit") then time*.65 else 0
    camera.CFrame=CFrame.lookAt(target+Vector3.new(7*math.sin(angle),1.1,7*math.cos(angle)),target)
    mesh.CFrame=baseFrame*CFrame.new(0,0,math.sin(os.clock()*30)*.00001)
    pause.Text=if gui:GetAttribute("Paused") then "Play" else "Pause"
end)
task.wait(2)
return game:GetService("HttpService"):JSONEncode({MeshId=mesh.MeshId, Bones=#bones, Size={mesh.Size.X,mesh.Size.Y,mesh.Size.Z},
    FetchCallOK=fetchOK, FetchError=if fetchOK then nil else tostring(fetchError), Statuses=statuses,
    FrameUpdates=gui:GetAttribute("FrameUpdates"), SurfaceSwitches=gui:GetAttribute("SurfaceSwitches"),
    MeanUpdateMS=gui:GetAttribute("MeanUpdateMS"), MaxUpdateMS=gui:GetAttribute("MaxUpdateMS"),
    Scope="Client clone only; visual inspection and GPU performance not established by counters"})
'''.replace("__PAYLOAD__",payload)
(ROOT / "scripts/studio_connected_fire_preview.luau").write_text(code, encoding="utf-8")
(OUT / "start_play.json").write_text(json.dumps({"is_start":True}))
(OUT / "stop_play.json").write_text(json.dumps({"is_start":False}))
(OUT / "capture.json").write_text(json.dumps({"capture_id":"ConnectedFireV4Review"}))
print("Prepared client preview with measured source-to-import translation mapping")
