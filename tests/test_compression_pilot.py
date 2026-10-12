"""Sample the city-wide compression, retained pilot, routes and static assets.
No Roblox engine emulation: these are conservative geometric regression checks.
"""
import subprocess
import xml.etree.ElementTree as ET
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LUA = r'''
local env=setmetatable({Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}},{__index=_G})
local plan=assert(loadfile('src/shared/Configuration/PhaseATopology.luau','t',env))()
local clip=dofile('src/server/Development/LowerLayer/InfillLayout.luau')
local g=dofile('src/server/Development/LowerLayer/RouteGeometry.luau').build(plan,clip)
local lots=clip.build(g.Reservations)
local pilot={Parts={},ReplacedLots={}}
local pm=dofile('src/server/Development/LowerLayer/CompressionPilot.luau')
local city=dofile('src/server/Development/LowerLayer/CityCompression.luau').build(plan,g,clip,lots,pilot,pm,dofile('src/server/Development/LowerLayer/BuildingSites.luau'))
local function part(p) if p.Collision then print('P',p.Name,p.X,p.Y,p.Z,p.W,p.H,p.D) end end
for _,p in ipairs(g.Parts) do part(p) end
for _,p in ipairs(pilot.Parts) do part(p) end
for _,p in ipairs(city.Parts) do part(p) end
for i,r in ipairs(lots) do
 if city.RetainedLots[i] then
 part({Name='OldLot_'..i,X=(r[1]+r[3])/2,Y=32,Z=(r[2]+r[4])/2,W=r[3]-r[1],H=64,D=r[4]-r[2],Collision=true}) end
end
for _,a in ipairs(pm.Assets) do print('A',a.Name,a.X,a.Z,a.Yaw) end
for _,a in ipairs(city.Assets) do print('A',a.Name,a.X,a.Z,a.Yaw) end
print('D',#city.Parts,#city.Assets,city.Overbuilds)
for _,home in ipairs(city.Homes) do print('S','MerchantHome',home.X,0,home.Z) end

local population=dofile('src/server/Services/CityPopulationLayout.luau')
env.Color3={fromRGB=function(...)return{...}end}
local life=assert(loadfile('src/shared/Configuration/CityLife.luau','t',env))()
local fronts={}
for _,home in ipairs(city.Homes)do table.insert(fronts,{Kind='Shopfront',Enterable=true,Home={X=home.X,Y=0,Z=home.Z}})end
for _,npc in ipairs(population.build(plan,life.NPCs.Roster,fronts,life.NPCs.AmbientTarget))do
 if npc.Position then print('S','Population_'..npc.Name,npc.Position.X,npc.Position.Y,npc.Position.Z)end
end
local function sample(name,p) print('S',name,p.X,p.Y,p.Z) end
for i,e in ipairs(plan.Edges) do
 if e.Kind~='InteriorStair' and e.Kind~='UndergroundStair' then
  local points=e.Points or {plan.Nodes[e[1]],plan.Nodes[e[2]]}
  for k=2,#points do
   local a,b=points[k-1],points[k]
   local steps=math.max(1,math.ceil((math.abs(a.X-b.X)+math.abs(a.Z-b.Z))/3))
   for j=0,steps do sample('Route_'..i,{X=a.X+(b.X-a.X)*j/steps,Y=a.Y,Z=a.Z+(b.Z-a.Z)*j/steps}) end
  end
 end
end
for i,branch in ipairs(plan.Hive.Branches) do
 for k=2,#branch do
  local a,b=branch[k-1],branch[k]
  local steps=math.max(1,math.ceil((math.abs(a[1]-b[1])+math.abs(a[3]-b[3]))/2))
  for j=0,steps do sample('Branch_'..i,{X=a[1]+(b[1]-a[1])*j/steps,Y=a[2]+(b[2]-a[2])*math.min(1,math.floor(j/steps*6+0.00001)/6+1/6),Z=a[3]+(b[3]-a[3])*j/steps}) end
 end
end
for _,s in ipairs(g.Stairs) do for _,p in ipairs(s.Samples) do sample(s.Name,p) end end
for _,s in ipairs(plan.SpawnCandidates) do
 local p=s.Position or plan.Nodes[s.Node]
 sample('Spawn_'..s.Id,{X=p.X+s.Offset.X,Y=p.Y+s.Offset.Y,Z=p.Z+s.Offset.Z})
end
local count=0;for _ in pairs(pilot.ReplacedLots)do count=count+1 end
print('C',count,#pilot.Parts,#plan.Edges)
'''

def load_scene():
    output = subprocess.check_output(['lua','-'],input=LUA,text=True,cwd=ROOT)
    parts, samples, counts, assets = [], [], None, []
    for line in output.splitlines():
        fields=line.split('\t')
        if fields[0]=='P': parts.append((fields[1],*map(float,fields[2:])))
        elif fields[0]=='S': samples.append((fields[1],*map(float,fields[2:])))
        elif fields[0]=='C': counts=tuple(map(int,fields[1:]))
        elif fields[0]=='A': assets.append((fields[1],*map(float,fields[2:])))
        elif fields[0]=='D': print('City parts / new buildings / overbuilds:',*fields[1:])
    for family,tx,tz,yaw in assets:
        source='FacadeStudy/Facade.rbxmx' if family=='Commercial' else 'TenementStudy/Tenement.rbxmx'
        ca,sa=round(math.cos(math.radians(yaw))),round(math.sin(math.radians(yaw)))
        def transform(x,y,z): return tx+ca*x+sa*z,y,tz-sa*x+ca*z
        if family=='Commercial':
            for door in [-47,-2,9,47]:
                for depth in range(-5,9,2): samples.append(('CommercialDoor',*transform(door,0,depth)))
        else:
            for door in [-23,21]:
                for step in range(6): samples.append(('TenementStoop',*transform(door,(step+1)*.75,-13+(step+.5)*1.5)))
                for depth in range(-3,9,2): samples.append(('TenementHall',*transform(door,4.5,depth)))
        tree=ET.parse(ROOT/'prototypes'/source)
        for item in tree.iter('Item'):
            if item.attrib['class']!='Part': continue
            props=item.find('Properties')
            if props.findtext("bool[@name='CanCollide']")=='false': continue
            cf=props.find("CoordinateFrame[@name='CFrame']")
            size=props.find("Vector3[@name='size']")
            x,y,z=[float(cf.findtext(k)) for k in 'XYZ']
            name=props.findtext("string[@name='Name']")
            sizes=[float(size.findtext(k)) for k in 'XYZ']
            extents=[sum(abs(float(cf.findtext(f'R{i}{j}')))*sizes[j] for j in range(3)) for i in range(3)]
            parts.append((source+':'+props.findtext("string[@name='Name']"),*transform(x,y,z),abs(ca)*extents[0]+abs(sa)*extents[2],extents[1],abs(sa)*extents[0]+abs(ca)*extents[2]))
    # Run the SAME clipping and circulation builder as runtime, against actual
    # source-model bounds. Existing route samples are retained, not weakened.
    commands=[LUA[:LUA.index('local function part')],
        "local solid=dofile('src/server/Development/LowerLayer/SolidClipping.luau')",
        "local layoutModule=dofile('src/server/Development/LowerLayer/BuildingCirculation.luau')",
        "local connections=dofile('src/server/Development/LowerLayer/BuildingConnections.luau')",
        "local layout=layoutModule.build(connections,plan,solid)",
        "local index=solid.index(layout.Cuts)",
        "local function emit(p) print('P',p.Name,p.X,p.Y,p.Z,p.W,p.H,p.D) end",
        "local function old(name,x,y,z,w,h,d) local raw=name:match(':(.*)$');if raw and layoutModule.removeSourcePart(raw,y)then return end;local p={Name=name,X=x,Y=y,Z=z,W=w,H=h,D=d};for _,v in ipairs(solid.parts(p,solid.near(p,index)))do emit(v)end end"]
    for name,x,y,z,w,h,d in parts:
        commands.append("old(%s,%s)"%(repr(name),','.join(map(str,[x,y,z,w,h,d]))))
    commands.extend([
        "for _,p in ipairs(layout.Parts) do emit(p) end",
        "for _,p in ipairs(layout.Samples) do print('S',p.Name,p.X,p.Y,p.Z) end",
        "assert(#connections.Buildings==47 and #connections.Links>=60)",
        "for _,y in ipairs({36.5,52.5})do local degree={};for _,e in ipairs(connections.Links)do if e.Y==y then degree[e.A]=true;degree[e.B]=true end end;for i=1,#connections.Buildings do assert(degree[i],'Opened portal has no connection: '..i..' at '..y)end end",
        "local visited={[1]=true};local changed=true;while changed do changed=false;for _,e in ipairs(connections.Links)do if visited[e.A]~=visited[e.B] and (visited[e.A] or visited[e.B])then visited[e.A]=true;visited[e.B]=true;changed=true end end end;for i=1,#connections.Buildings do assert(visited[i],'Disconnected building '..i)end",
        "local all={};for _,a in ipairs(pm.Assets)do table.insert(all,a)end;for _,a in ipairs(city.Assets)do table.insert(all,a)end;for i,a in ipairs(all)do local b=connections.Buildings[i];assert(a.X==b.X and a.Z==b.Z and a.Yaw==b.Yaw and a.Name==b.Name,'Stale connection data')end"
    ])
    output=subprocess.check_output(['lua','-'],input='\n'.join(commands),text=True,cwd=ROOT)
    parts=[]
    for line in output.splitlines():
        fields=line.split('\t')
        if fields[0]=='P':parts.append((fields[1],*map(float,fields[2:])))
        elif fields[0]=='S':samples.append((fields[1],*map(float,fields[2:])))
    # Guard against silently falling back to another small validation cluster.
    assert len(assets)>=40, len(assets)
    assert len(parts)<65000, len(parts)
    for west in [False,True]:
        for north in [False,True]:
            assert sum((x<0)==west and (z>1050)==north for _,x,z,_ in assets)>=5
    return parts,samples,counts

class CompressionPilot(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parts,cls.samples,cls.counts=load_scene()
    def test_existing_routes_stairs_and_spawn_envelopes(self):
        failures=[]
        buckets={}
        for part in self.parts:
            _,px,py,pz,w,h,d=part
            for bx in range(math.floor((px-w/2-2)/32), math.floor((px+w/2+2)/32)+1):
                for bz in range(math.floor((pz-d/2-2)/32), math.floor((pz+d/2+2)/32)+1):
                    buckets.setdefault((bx,bz),[]).append(part)
        for name,x,y,z in self.samples:
            for pn,px,py,pz,w,h,d in buckets.get((math.floor(x/32),math.floor(z/32)),[]):
                if abs(x-px)<w/2+1.9999 and abs(z-pz)<d/2+1.9999 and py+h/2>y+1.6 and py-h/2<y+9:
                    failures.append(f'{name} at {(x,y,z)} blocked by {pn}')
                    break
        Path('/tmp/enfleshed-clearance-failures.txt').write_text('\n'.join(failures))
        self.assertEqual(failures[:20],[])
    def test_added_entries_have_visible_collision_floors(self):
        buckets={}
        for part in self.parts:
            _,px,py,pz,w,h,d=part
            for bx in range(math.floor((px-w/2)/32),math.floor((px+w/2)/32)+1):
                for bz in range(math.floor((pz-d/2)/32),math.floor((pz+d/2)/32)+1):
                    buckets.setdefault((bx,bz),[]).append(part)
        for name,x,y,z in self.samples:
            self.assertTrue(any(
                abs(x-px)<=w/2 and abs(z-pz)<=d/2 and abs(py+h/2-y)<=(0.55 if name.startswith("Route_") else 0.15)
                for _,px,py,pz,w,h,d in buckets.get((math.floor(x/32),math.floor(z/32)),[])
            ), (name,x,y,z))

    def test_bounded_scope_and_dimensions(self):
        self.assertEqual(self.counts[0],0) # Retired the old pilot street geometry.
        for name,x,y,z,w,h,d in self.parts:
            self.assertGreater(min(w,h,d),0,name)
            if name.startswith('Pilot_'):
                self.assertGreaterEqual(x-w/2,-330)
                self.assertLessEqual(x+w/2,80)
                self.assertGreaterEqual(z-d/2,985)
                self.assertLessEqual(z+d/2,1310)
    def test_city_wide_surface_routes(self):
        # Every retained graph edge and newly authored branch participates in
        # the same physical clearance/floor checks, rather than an obsolete plaza.
        names={sample[0] for sample in self.samples}
        self.assertGreaterEqual(sum(n.startswith('Branch_') for n in names),27)
        self.assertIn('Route_1',names)
        self.assertIn('Route_36',names)

if __name__=='__main__': unittest.main()
