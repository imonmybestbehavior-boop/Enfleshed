-- Filled by run_connected_fire_benchmark.py. Measures the production renderer in a fixed scene.
local COUNT=12
local QUALITY="High"
local shared=game:GetService("ReplicatedStorage").Shared
local system=shared.SpellVFXSystem
local rendererModule=system.Signature.SignatureRenderer:Clone()
rendererModule.Name="ConnectedFireBenchmarkRenderer"
rendererModule.Parent=system.Signature
local renderer=require(rendererModule)
local fire=require(system.Signature.ConnectedFire)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local run=game:GetService("RunService")
local player=game:GetService("Players").LocalPlayer
local pg=player.PlayerGui
for _,name in {"ConnectedFireRuntimeReview","ConnectedFireBenchmarkReview"} do local old=pg:FindFirstChild(name);if old then old:Destroy() end end
assert(fire.stats().Active==0,"Finish existing fire effects before isolated measurements")
local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
assert(root,"Player character unavailable")
local center=root.Position+Vector3.new(0,8,-20)
local folder=Instance.new("Folder");folder.Name="ConnectedFireBenchmark";folder.Parent=workspace
local gui=Instance.new("ScreenGui");gui.Name="ConnectedFireBenchmarkReview";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=20000
local hidden={}
for _,g in pg:GetChildren() do if g:IsA("ScreenGui") then hidden[g]=g.Enabled;g.Enabled=false end end
local label=Instance.new("TextLabel");label.Size=UDim2.new(1,0,0,50);label.Position=UDim2.fromOffset(0,64)
label.BackgroundTransparency=1;label.TextColor3=Color3.new(1,1,1);label.TextSize=22;label.Text=COUNT.." integrated fireballs · "..QUALITY;label.Parent=gui
local close=Instance.new("TextButton");close.Position=UDim2.new(0,16,1,-58);close.Size=UDim2.fromOffset(150,42);close.Text="Close test";close.Parent=gui
close.Activated:Connect(function() gui:Destroy() end)
local camera=workspace.CurrentCamera
local saved={CFrame=camera.CFrame,Type=camera.CameraType,FOV=camera.FieldOfView}
camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=46
camera.CFrame=CFrame.lookAt(center+Vector3.new(14,8,23),center)
local anchors,sessions={},{ }
local plan=analyzer.resolve(require(shared.Configuration.Spells).Fireball)
local creationStarted=os.clock()
for i=1,COUNT do
    local anchor=Instance.new("Part");anchor.Name="CosmeticBenchmarkAnchor";anchor.Anchored=true
    anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Transparency=1;anchor.Size=Vector3.one*2.2
    anchor.CFrame=CFrame.new(center+Vector3.new(((i-1)%4-1.5)*4,math.floor((i-1)/4)*3-3,0));anchor.Parent=folder
    local session=renderer.attach(anchor,plan,{Parent=folder,Quality=QUALITY})
    assert(session and session.ConnectedFire,"Expected connected body at benchmark count "..i)
    anchors[i]=anchor;sessions[i]=session
end
local creationMS=(os.clock()-creationStarted)*1000
local born=os.clock()
local movement=run.Heartbeat:Connect(function()
    local t=os.clock()-born
    for i,anchor in anchors do
        local base=center+Vector3.new(((i-1)%4-1.5)*4,math.floor((i-1)/4)*3-3,0)
        local pos=base+Vector3.new(math.sin(t+i)*.5,0,math.cos(t+i)*.5)
        local heading=Vector3.new(math.cos(t+i),0,-math.sin(t+i))
        anchor.CFrame=CFrame.lookAt(pos,pos+heading)
    end
    camera=workspace.CurrentCamera
    camera.CameraType=Enum.CameraType.Scriptable
    camera.CFrame=CFrame.lookAt(center+Vector3.new(14,8,23),center)
end)
gui.Destroying:Connect(function()
    movement:Disconnect()
    for _,session in sessions do session:Stop() end
    renderer.stopAll();rendererModule:Destroy()
    folder:Destroy();camera.CFrame=saved.CFrame;camera.CameraType=saved.Type;camera.FieldOfView=saved.FOV
    for g,value in hidden do if g.Parent then g.Enabled=value end end
end)
gui.Parent=pg
local profiler={Ready=false,Scope="RenderStepped intervals and per-body wall time only; MicroProfiler capture was unavailable in this session"}
task.wait(1.5)
fire.resetTiming()
local frames,rendered={},{ }
local sampling=run.Heartbeat:Connect(function(dt) table.insert(frames,dt*1000) end)
local renderSampling=run.RenderStepped:Connect(function(dt) table.insert(rendered,dt*1000) end)
task.wait(3)
sampling:Disconnect();renderSampling:Disconnect()
assert(#frames>0,"No Heartbeat samples")
table.sort(frames)
local sum=0
for _,v in frames do sum+=v end
local stats=fire.stats()
local distance=(workspace.CurrentCamera.CFrame.Position-center).Magnitude
assert(distance<100,"Benchmark camera is outside the visible effect range")
if COUNT>0 and stats.Updates==0 then gui:Destroy();error("No visible body updates; refuse an invalid benchmark") end
local function percentile(p) return frames[math.clamp(math.ceil(#frames*p),1,#frames)] end
local memory={}
pcall(function() memory.TextureMB=game:GetService("Stats"):GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture) end)
local result={Count=COUNT,Quality=QUALITY,HeartbeatSamples=#frames,RenderedFrames=#rendered,WindowSeconds=3,FrameMeanMS=sum/#frames,
    FrameP50MS=percentile(.5),FrameP95MS=percentile(.95),FrameMaxMS=frames[#frames],
    ScriptMSPerHeartbeat=stats.MeanUpdateMS*stats.Updates/#frames,Fire=stats,Renderer=renderer.stats(),
    CreationMS=creationMS,Memory=memory,MicroProfiler=profiler,CameraDistance=distance,
    Scope="Local Studio Heartbeat cadence and body CPU wall time; RenderedFrames reports whether render callbacks ran. Not GPU timing, mobile or published-server benchmark"}
-- Exercise both graceful and abrupt cleanup, leaving only a bounded reusable pool.
for _,session in sessions do session:Finish() end
task.wait(.6)
gui:Destroy()
result.AfterCleanup=fire.stats()
assert(result.AfterCleanup.Active==0,"Fire body leaked after its session ended")
return game:GetService("HttpService"):JSONEncode(result)
