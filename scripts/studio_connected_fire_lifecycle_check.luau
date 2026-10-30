local shared=game:GetService("ReplicatedStorage").Shared
local system=shared.SpellVFXSystem
local fire=require(system.Signature.ConnectedFire)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local module=system.Signature.SignatureRenderer:Clone();module.Name="ConnectedFireLifecycleRenderer";module.Parent=system.Signature
local renderer=require(module)
local folder=Instance.new("Folder");folder.Name="ConnectedFireLifecycleCheck";folder.Parent=workspace
local sessions={}
local function anchor()
    local p=Instance.new("Part");p.Anchored=true;p.CanCollide=false;p.Transparency=1;p.Size=Vector3.one*2.2;p.Parent=folder
    return p
end
local ok,result=xpcall(function()
    assert(fire.stats().Active==0,"Live effects must finish first")
    local plan=analyzer.resolve(require(shared.Configuration.Spells).Fireball)
    local a=anchor()
    local session=renderer.attach(a,plan,{Parent=folder});table.insert(sessions,session)
    assert(session and session.ConnectedFire,"Connected body not selected")
    local body=session.ConnectedFire
    assert(math.abs(body.Mesh.Size.Y-2.2)<.01,"Visual width does not match standard projectile")
    local frame=CFrame.lookAt(Vector3.new(10,20,30),Vector3.new(11,21,30))
    body:Update(frame,0,true,1,"High",false)
    assert((-body.Mesh.CFrame.RightVector):Dot(frame.LookVector)>.999,"Head is not aligned with flight")
    body:Update(frame,1,false,1,"High",false);assert(body.Mesh.Transparency==1,"Distance-hidden body remained visible")
    session:Stop();session:Stop();assert(fire.stats().Active==0,"Repeated stop leaked or double-released")
    local many={}
    for i=1,13 do
        local s=renderer.attach(anchor(),plan,{Parent=folder});assert(s,"Session budget unexpectedly exhausted")
        table.insert(sessions,s);many[i]=s
    end
    assert(fire.stats().Active==12 and many[13].ConnectedFire==nil,"Connected body cap did not fall back safely")
    for _,s in many do s:Stop() end
    local beam=table.clone(plan);beam.Form="Beam"
    local b=renderer.attach(anchor(),beam,{Parent=folder});table.insert(sessions,b)
    assert(b and not b.ConnectedFire,"Projectile body replaced another form")
    b:Stop()
    assert(fire.stats().Active==0 and fire.stats().Pooled<=8,"Pool is not bounded")
    local stats=renderer.stats()
    assert(stats.Sessions==0 and stats.Meshes==0 and stats.Lights==0,"Renderer budgets leaked")
    return {Checks=7,BodyWidth=true,FlightAlignment=true,DistanceHide=true,IdempotentStop=true,
        ConnectedCapAndFallback=true,OtherFormPreserved=true,PoolAndBudgetsClean=true,Fire=fire.stats()}
end,debug.traceback)
for _,s in sessions do if s then s:Stop() end end
folder:Destroy();module:Destroy()
assert(ok,result)
return game:GetService("HttpService"):JSONEncode(result)
