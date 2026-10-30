local pg=game:GetService("Players").LocalPlayer.PlayerGui
local previous=pg:FindFirstChild("ConnectedFireCheckHarness")
if previous and previous:GetAttribute("Finished") then
 local review=pg:FindFirstChild("ConnectedFireRuntimeReview")
 if review then review:Destroy() end
 previous:Destroy()
end
assert(not pg:FindFirstChild("ConnectedFireCheckHarness"),"A check is already running")
local output=Instance.new("Folder");output.Name="ConnectedFireCheckHarness";output.Parent=pg
local runner=Instance.new("LocalScript");runner.Name="ConnectedFireClientCheck";runner.Source=[=[local output=script.Parent
local ok,result=xpcall(function()
-- Full normal-controller lifecycle, including intentional visibility loss mid-flight.
local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local analyzer=require(system.Core.SpellVFXAnalyzer)
local renderer=require(system.Signature.SignatureRenderer)
local composer=require(system.Core.SpellVFXComposer)
local run=game:GetService("RunService")
local collection=game:GetService("CollectionService")
renderer.stopAll();composer.Quality="High";renderer.Quality="High"
local origin=CFrame.new(10000,10,10000);local away=false
local function camera()
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
 workspace.CurrentCamera.CFrame=if away then CFrame.new(20000,10,20000) else CFrame.lookAt(origin.Position+Vector3.new(10,8,22),origin.Position-Vector3.zAxis*25)
end
camera();run:BindToRenderStep("DustRegressionCamera",Enum.RenderPriority.Last.Value,camera)
local results={}
for _,school in {"Poison","Water","Earth","Arcane"} do
 for _,cull in {false,true} do
  local spell={Form="Projectile",Targeting="AimDirection",Geometry="Sphere",Motion="Linear",
   Source={Principle="Energy",Expression="Unawakened"},Element=if school=="Arcane" then nil else school,
   Casting={Mode="Instant",Cooldown=.5},Lifetime={Mode="FixedDuration",Duration=3},Triggers={},
   Projectile={Speed=72,Radius=1.1},Payloads={{Kind="Damage",Amount=10}},Visual={}}
  local anchors={};local smoke={};local cancelled=false
  local function anchor(name,cf,size,phase)
   local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Transparency=1
   p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Size=size;p.CFrame=cf;p.Parent=workspace
   analyzer.stamp(p,spell,size,phase);table.insert(anchors,p);return p
  end
  local watch=workspace.DescendantAdded:Connect(function(e)
   if e:IsA("ParticleEmitter") and string.find(e.Name,"Dissipate",1,true) then
    local path=e:GetFullName()
    local host=e.Parent;local pos=if host:IsA("Attachment") then host.WorldPosition else host.Position
    if (pos-origin.Position).Magnitude<200 then table.insert(smoke,{Path=path,Position=pos}) end
   end
  end)
  local release=anchor("SpellReleaseComposition",origin,Vector3.new(5,6,5),"Release")
  local projectile=anchor("MagicProjectile",origin*CFrame.new(0,.5,-2),Vector3.one*2.2,"Sustain")
  local begin=os.clock();local hidden=false;local restored=false
  while os.clock()-begin<.65 do
   local t=os.clock()-begin
   projectile.CFrame=origin*CFrame.new(0,.5,-2-72*t)
   if cull and t>.1 and not hidden then
    away=true;camera();hidden=true
    -- A new tag invokes the actual controller's selection pass immediately.
    local marker=anchor("SelectionProbe",origin,Vector3.one,"End")
    task.wait(.06)
    local folder=workspace:FindFirstChild("SignatureVFX")
    cancelled=not(folder and folder:FindFirstChild("Signature_"..school.."_Projectile"))
    marker:Destroy()
   elseif cull and hidden and not restored then away=false;camera();restored=true end
   run.Heartbeat:Wait()
  end
  projectile:SetAttribute("VFXPhase","End")
  local endpoint=projectile.Position
  anchor("MagicElementImpact",CFrame.new(endpoint),Vector3.one*5,"Impact")
  task.wait(.3)
  watch:Disconnect()
  assert(#smoke==1,school.." expected one impact cloud, got "..#smoke)
  assert(string.find(smoke[1].Path,"_Impact.",1,true),school.." cloud came from teardown")
  assert((smoke[1].Position-endpoint).Magnitude<.01,school.." cloud at source instead of endpoint")
  if cull then assert(cancelled,school.." selection removal did not cancel the active visual") end
  table.insert(results,{School=school,Culled=cull,Clouds=#smoke,CloudDistance=(smoke[1].Position-origin.Position).Magnitude})
  for _,p in anchors do p:Destroy() end
  renderer.stopAll();task.wait(.65)
 end
end
run:UnbindFromRenderStep("DustRegressionCamera")
local stats=renderer.stats()
assert(stats.Sessions==0 and stats.Emitters==0 and stats.Meshes==0 and stats.Trails==0 and math.abs(stats.Rate)<1e-8,"Dust regression leaked: "..game:GetService("HttpService"):JSONEncode(stats))
return game:GetService("HttpService"):JSONEncode({Cases=results,Cleanup=stats})

end,debug.traceback)
output:SetAttribute("Result",tostring(result))
output:SetAttribute("OK",ok)
output:SetAttribute("Finished",true)
]=];runner.Parent=output
local deadline=os.clock()+35
while not output:GetAttribute("Finished") and os.clock()<deadline do task.wait(.1) end
local finished,ok,result=output:GetAttribute("Finished"),output:GetAttribute("OK"),output:GetAttribute("Result")
if not finished or not ok then
 local gui=pg:FindFirstChild("ConnectedFireBenchmarkReview")
 if gui then gui:Destroy() end
end
if not false or not ok then output:Destroy() end
assert(finished,"Client check timed out")
assert(ok,result)
return result
