local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local analyzer=require(system.Core.SpellVFXAnalyzer)
local renderer=require(system.Signature.SignatureRenderer)
renderer.stopAll()
local origin=CFrame.new(10000,10,10000)
local function camera()
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
 workspace.CurrentCamera.CFrame=CFrame.lookAt(origin.Position+Vector3.new(10,8,22),origin.Position-Vector3.zAxis*25)
end
camera();game:GetService("RunService"):BindToRenderStep("DustTraceCamera",Enum.RenderPriority.Last.Value,camera)
local events={};local begin=os.clock()
local originalAttach=renderer.attach
renderer.attach=function(...)
 local session=originalAttach(...)
 if session then
  local finish=session.Finish
  session.Finish=function(self)
   table.insert(events,{Time=os.clock()-begin,FinishRole=self.Role,Anchor=self.Anchor.Name,Trace=debug.traceback()})
   return finish(self)
  end
 end
 return session
end
local function pos(p)
 if p:IsA("Attachment") then return p.WorldPosition elseif p:IsA("BasePart") then return p.Position end
 return Vector3.zero
end
local monitor=workspace.DescendantAdded:Connect(function(e)
 if e:IsA("ParticleEmitter") then
  local p=pos(e.Parent)
  if (p-origin.Position).Magnitude<200 then
   table.insert(events,{Time=os.clock()-begin,Name=e.Name,Path=e:GetFullName(),FromCaster=(p-origin.Position).Magnitude,Position={p.X,p.Y,p.Z},Texture=e.Texture})
  end
 end
end)
local spell={Form="Projectile",Targeting="AimDirection",Geometry="Sphere",Motion="Linear",
 Source={Principle="Body",Expression="BodyEnhancement"},Element="Poison",
 Casting={Mode="Instant",Cooldown=.5},Lifetime={Mode="FixedDuration",Duration=3},Cost={},Triggers={},
 Projectile={Speed=72,Radius=1.1},Payloads={{Kind="Damage",Amount=10}},Visual={}}
local function anchor(name,cf,size,phase)
 local p=Instance.new("Part");p.Anchored=true;p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.Name=name;p.CFrame=cf;p.Size=size;p.Parent=workspace;analyzer.stamp(p,spell,size,phase);return p
end
local release=anchor("SpellReleaseComposition",origin,Vector3.new(5,6,5),"Release")
task.delay(.6,function() release:Destroy() end)
local projectile=anchor("MagicProjectile",origin*CFrame.new(0,.5,-2),Vector3.one*2.2,"Sustain")
local position=projectile.Position;local travelled=0
while travelled<70 do
 local dt=game:GetService("RunService").Heartbeat:Wait();local distance=72*dt
 position+=origin.LookVector*distance;travelled+=distance;projectile.CFrame=CFrame.lookAt(position,position+origin.LookVector)
end
projectile:SetAttribute("VFXPhase","End")
local impact=anchor("MagicElementImpact",CFrame.new(position),Vector3.one*5,"Impact")
task.wait(2)
monitor:Disconnect();release:Destroy();projectile:Destroy();impact:Destroy();renderer.stopAll()
renderer.attach=originalAttach
game:GetService("RunService"):UnbindFromRenderStep("DustTraceCamera")
return game:GetService("HttpService"):JSONEncode({Travelled=travelled,Events=events})
