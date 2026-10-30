-- Uses the real Studio-only action route: no replacement spell executor or resource bypass.
local run=game:GetService("RunService")
assert(run:IsStudio() and run:IsClient())
local shared=game:GetService("ReplicatedStorage").Shared
local fire=require(shared.SpellVFXSystem.Signature.ConnectedFire)
local player=game:GetService("Players").LocalPlayer
local review=player.PlayerGui:FindFirstChild("ConnectedFireRuntimeReview")
if review then review:Destroy() end
local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
assert(root and player.Character:FindFirstChildOfClass("Humanoid").Health>0,"Player must be alive")
local camera=workspace.CurrentCamera
local saved={CFrame=camera.CFrame,Type=camera.CameraType}
camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(root.Position+Vector3.new(25,20,30),root.Position+Vector3.new(0,30,0))
run:BindToRenderStep("ConnectedFireLiveCastCamera",Enum.RenderPriority.Last.Value,function()
    camera.CFrame=CFrame.lookAt(root.Position+Vector3.new(25,20,30),root.Position+Vector3.new(0,30,0))
end)
local remote=shared.SandboxRemotes.ActionRequest
local feedback=shared.SandboxRemotes.ActionFeedback
local events,anchors={},{}
local peak,aligned=0,0
local collection=game:GetService("CollectionService")
local added=collection:GetInstanceAddedSignal("ComposedSpellVFX"):Connect(function(anchor)
    if anchor:GetAttribute("VFXElement")=="Fire" and anchor:GetAttribute("VFXForm")=="Projectile" then
        table.insert(anchors,{Name=anchor.Name,Size={anchor.Size.X,anchor.Size.Y,anchor.Size.Z},CameraDistance=(camera.CFrame.Position-anchor.Position).Magnitude})
    end
end)
local feedbackConnection=feedback.OnClientEvent:Connect(function(value)
    if type(value)=="table" and #events<30 then
        table.insert(events,{Kind=value.Kind,Action=value.Action,Accepted=value.Accepted,State=value.State,Reason=value.Reason,SpellId=value.SpellId})
    end
end)
local sample=run.Heartbeat:Connect(function()
    peak=math.max(peak,fire.stats().Active)
    local container=workspace:FindFirstChild("SignatureVFX")
    if container then
        for _,folder in container:GetChildren() do
            local body=folder:FindFirstChild("ConnectedFireBody")
            local host=folder:FindFirstChild("Host")
            if body and host and (-body.ConnectedFireVolume.CFrame.RightVector):Dot(host.CFrame.LookVector)>.99 then aligned+=1 end
        end
    end
end)
local initial=fire.stats().Active
for index=1,3 do
    remote:FireServer({Action="MagicStart",Sequence=5000000+index,Character=player.Character,SpellId="Fireball",
        AimDirection=Vector3.yAxis,WorldPoint=root.Position+Vector3.yAxis*120})
    task.wait(.85)
end
task.wait(3)
sample:Disconnect();added:Disconnect();feedbackConnection:Disconnect()
run:UnbindFromRenderStep("ConnectedFireLiveCastCamera")
camera.CFrame=saved.CFrame;camera.CameraType=saved.Type
return game:GetService("HttpService"):JSONEncode({Initial=initial,PeakConnectedBodies=peak,Final=fire.stats(),
    AlignedBodySamples=aligned,ProjectileAnchors=anchors,Feedback=events,
    Scope="Three actual Fireball requests through existing action validation, server executor and client controller; no gameplay source changed"})
