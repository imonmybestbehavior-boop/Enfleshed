"""Generate structural surface circulation around the actual building anchors.
Only the marked layout-data section in PhaseATopology is replaced.
"""
from pathlib import Path
import subprocess
import math
import re
from hive_routing import STEP, find_route, simplify

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'src/shared/Configuration/PhaseATopology.luau'
lua = r'''
local f=assert(io.open('src/shared/Configuration/PhaseATopology.luau'));local text=f:read('*a');f:close()
text=text:gsub('%-%- HIVE GENERATED BEGIN.-%-%- HIVE GENERATED END','local hive={Routes={},Accretions={},Branches={},Spawns={}}')
local env=setmetatable({Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}},{__index=_G})
local p=assert(load(text,'topology','t',env))()
for i,e in ipairs(p.Edges)do
 if e.Kind=='Street' or e.Kind=='Alley' then
  local points=e.Points or {p.Nodes[e[1]],p.Nodes[e[2]]}
  io.write('E\t'..i..'\t'..e.Kind..'\t'..e.Width)
  for _,v in ipairs(points)do io.write('\t'..v.X..'\t'..v.Z)end;io.write('\n')
 end
end
for _,b in ipairs(p.Buildings)do local n=p.Nodes[b.Ground];print('B',n.X,n.Z)end
for _,a in ipairs(dofile('src/server/Development/LowerLayer/CompressionPilot.luau').Assets)do print('A',a.Name,a.X,a.Z,a.Yaw)end
for _,a in ipairs(dofile('src/server/Development/LowerLayer/BuildingSites.luau'))do print('A',a.Name,a.X,a.Z,a.Yaw)end
local g=dofile('src/server/Development/LowerLayer/RouteGeometry.luau').build(p,dofile('src/server/Development/LowerLayer/InfillLayout.luau'))
for _,r in ipairs(g.Holes[0])do print('W',table.unpack(r))end
for _,s in ipairs(p.SpawnCandidates)do if s.Kind=='Surface' then local v=s.Position or p.Nodes[s.Node];print('S',s.Id,v.X+s.Offset.X,v.Z+s.Offset.Z)end end
'''
lines=subprocess.check_output(['lua','-'],input=lua,cwd=ROOT,text=True).splitlines()
edges=[];bodies=[];legacy=[];assets=[];wells=[];spawns=[];door_clear=[]
for line in lines:
    f=line.split('\t')
    if f[0]=='E':
        v=list(map(float,f[4:]));edges.append((int(f[1]),f[2],float(f[3]),list(zip(v[::2],v[1::2]))))
    elif f[0]=='B':
        x,z=map(float,f[1:]);legacy.append((x-56,z-68,x+56,z+68))
    elif f[0]=='W':
        x,z,xx,zz=map(float,f[1:]);wells.append((x-6,z-6,xx+6,zz+6))
    elif f[0]=='S':spawns.append((f[1],float(f[2]),float(f[3])))
    elif f[0]=='A':assets.append((f[1],*map(float,f[2:])))

def transform(a,u,v):
    c=round(math.cos(math.radians(a[3])));s=round(math.sin(math.radians(a[3])))
    return a[1]+c*u+s*v,a[2]-s*u+c*v

for a in assets:
    commercial=a[0]=='Commercial';half=54 if commercial else 46
    corners=[transform(a,u,v) for u in [-half,half] for v in [-2 if commercial else -14,38]]
    bodies.append((min(x for x,z in corners),min(z for x,z in corners),max(x for x,z in corners),max(z for x,z in corners)))
    for u in ([-47,-2,9,47] if commercial else [-23,21]):
        x,z=transform(a,u,-6 if commercial else -17)
        door_clear.append((x-6,z-6,x+6,z+6))

def overlap(a,b):return a[0]<b[2] and a[2]>b[0] and a[1]<b[3] and a[3]>b[1]
def inflated(r,n):return r[0]-n,r[1]-n,r[2]+n,r[3]+n

def near_endpoint(x,z):
    return any(abs(x-p[0])+abs(z-p[1])<48 for _,_,_,points in edges for p in (points[0],points[-1]))

# Occupied extensions take ownership of former straight route space. Their
# positions precede routing, so the paths must bend around actual architecture.
accretions=[]
for ei,kind,width,points in edges:
    for a,b in zip(points,points[1:]):
        length=abs(a[0]-b[0])+abs(a[1]-b[1])
        if length<110:continue
        dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
        for distance in range(56,int(length)-40,80):
            x,z=a[0]+dx*distance,a[1]+dz*distance
            if near_endpoint(x,z):continue
            core=(x-10,z-12,x+10,z+12)
            if any(overlap(inflated(core,4),r) for r in bodies+legacy+wells+door_clear+accretions):continue
            # Where possible attach to the nearest existing building, forming
            # a substantial wing rather than a freestanding traffic obstacle.
            options=[]
            for r in bodies:
                if r[1]<z<r[3]:
                    face=r[2] if r[2]<x else r[0]
                    if abs(face-x)<60:options.append((min(face,x-10),z-12,max(face,x+10),z+12))
                if r[0]<x<r[2]:
                    face=r[3] if r[3]<z else r[1]
                    if abs(face-z)<60:options.append((x-10,min(face,z-12),x+10,max(face,z+12)))
            for wing in sorted(options,key=lambda r:(r[2]-r[0])*(r[3]-r[1])):
                if not any(overlap(wing,r) for r in legacy+wells+door_clear+accretions):core=wing;break
            accretions.append(core)

obstacles=[inflated(r,6) for r in bodies]+legacy+wells+[inflated(r,6) for r in accretions]
cache={}
def clear(n):
    if n not in cache:
        x,z=n[0]*STEP,n[1]*STEP
        cache[n]=(-668<=x<=668 and 358<=z<=1742 and not any(l<x<r and b<z<t for l,b,r,t in obstacles))
    return cache[n]

def snap(p):
    options=[(i,j) for i in range(round(p[0]/STEP)-5,round(p[0]/STEP)+6) for j in range(round(p[1]/STEP)-5,round(p[1]/STEP)+6) if clear((i,j))]
    return min(options,key=lambda n:(abs(n[0]*STEP-p[0])+abs(n[1]*STEP-p[1]),n))

def lead(p,g):
    # Direct endpoint leads stay in their existing courts / door approaches.
    return [p,(g[0]*STEP,p[1]),(g[0]*STEP,g[1]*STEP)]

routes=[];branches=[]
for ei,kind,width,old in edges:
    start,end=old[0],old[-1]
    # Through-building nodes are reached through their actual axial doorway.
    inside=next((r for r in legacy if r[0]<end[0]<r[2] and r[1]<end[1]<r[3]),None)
    approach=end
    if inside:
        sign=1 if old[-2][1]>=end[1] else -1
        approach=(end[0],end[1]+sign*76)
    a,b=snap(start),snap(approach)
    path=lead(start,a)+[(x*STEP,z*STEP) for x,z in find_route(a,b,clear)]+list(reversed(lead(approach,b)))
    if inside:path.append(end)
    points=simplify(path)
    widths=[];spaces=[]
    for j,(a,b) in enumerate(zip(points,points[1:])):
        mx,mz=(a[0]+b[0])/2,(a[1]+b[1])/2
        desired=[8,12,18,10,24][(ei+j)%5]
        clearance=50
        for r in bodies+legacy+wells+accretions:
            # Distance from this segment's bounding rectangle to each body.
            dx=max(r[0]-max(a[0],b[0]),min(a[0],b[0])-r[2],0)
            dz=max(r[1]-max(a[1],b[1]),min(a[1],b[1])-r[3],0)
            clearance=min(clearance,max(dx,dz))
        allowed=max(8,2*clearance-2)
        widths.append(min(desired,allowed))
        spaces.append(['Alley','Covered','Service','Room','Court'][(ei+j)%5])
    routes.append((ei,points,widths,spaces))
    # Side rooms are short, bounded branches with a turn, not loose props.
    for j,p in enumerate(points[2:-2],2):
        if (ei+j)%5:continue
        a=points[j-1];dx=0 if a[0]==p[0] else (1 if p[0]>a[0] else -1);dz=0 if a[1]==p[1] else (1 if p[1]>a[1] else -1)
        q=(p[0]-dz*16,p[1]+dx*16);r=(q[0]+dx*12,q[1]+dz*12)
        bound=(min(p[0],q[0],r[0])-5,min(p[1],q[1],r[1])-5,max(p[0],q[0],r[0])+5,max(p[1],q[1],r[1])+5)
        if not any(overlap(bound,o) for o in bodies+legacy+wells+accretions):branches.append([p,q,r]);break

# Bounded alternate passages leave and rejoin an existing route. Reject paths
# that merely retrace it; the bypass must make a genuinely separate local loop.
loops=0
for _,points,_,_ in routes:
    if loops>=12:break
    if len(points)<7:continue
    start=snap(points[2]);end=snap(points[5])
    original=find_route(start,end,clear)
    if len(original)<8:continue
    middle=original[len(original)//2]
    excluded={(middle[0]+dx,middle[1]+dz) for dx in range(-1,2) for dz in range(-1,2)}
    if start in excluded or end in excluded:continue
    try: alternate=find_route(start,end,lambda n:clear(n) and n not in excluded)
    except RuntimeError:continue
    if len(alternate)>len(original)+24:continue
    if len(set(alternate)-set(original))<4:continue
    path=simplify(lead(points[2],start)+[(x*STEP,z*STEP) for x,z in alternate]+list(reversed(lead(points[5],end))))
    branches.append(path);loops+=1

# Connect actual doors/stoops to the irregular network. These are narrow
# architectural entrance passages, not a return to a continuous facade boulevard.
entries=[]
entry_obstacles=[inflated(r,4) for r in bodies+accretions]+legacy+wells
def entry_clear(n):
    x,z=n[0]*4,n[1]*4
    return -668<=x<=668 and 358<=z<=1742 and not any(l<x<r and b<z<t for l,b,r,t in entry_obstacles)
network=[(x/STEP,z/STEP) for _,points,_,_ in routes for x,z in points if x%STEP==0 and z%STEP==0 and clear((int(x/STEP),int(z/STEP)))]
for asset in assets:
    commercial=asset[0]=='Commercial'
    for u in ([-47,-2,9,47] if commercial else [-23,21]):
        p=transform(asset,u,-5 if commercial else -15)
        outside=transform(asset,u,-10 if commercial else -22)
        options=[(i,j) for i in range(round(outside[0]/4)-8,round(outside[0]/4)+9) for j in range(round(outside[1]/4)-8,round(outside[1]/4)+9) if entry_clear((i,j))]
        start=min(options,key=lambda n:abs(n[0]*4-outside[0])+abs(n[1]*4-outside[1]))
        goal=min([(int(x*2),int(z*2)) for x,z in network],key=lambda n:abs(n[0]-start[0])+abs(n[1]-start[1]))
        grid=(start[0]*4,start[1]*4)
        approach=[p,(grid[0],p[1]),grid] if asset[3] in (-90,90) else [p,(p[0],grid[1]),grid]
        path=simplify(approach+[(x*4,z*4) for x,z in find_route(start,goal,entry_clear,min_run=1,max_run=16)])
        entries.append(path)
branches.extend(entries)

# Relocate old straight-avenue spawn anchors to the actual new paths.
candidates=[]
for _,points,_,_ in routes:
    for a,b in zip(points,points[1:]):
        count=max(1,math.ceil((abs(a[0]-b[0])+abs(a[1]-b[1]))/4))
        for i in range(count+1):
            x=a[0]+(b[0]-a[0])*i/count;z=a[1]+(b[1]-a[1])*i/count
            if not any(l<x<r and b<z<t for l,b,r,t in bodies+legacy+wells+accretions):candidates.append((x,z))
projected=[];used=[]
for name,x,z in spawns:
    choices=sorted(candidates,key=lambda p:(abs(p[0]-x)+abs(p[1]-z),p))
    chosen=next(p for p in choices if all(abs(p[0]-q[0])+abs(p[1]-q[1])>=7 for q in used))
    used.append(chosen);projected.append((name,*chosen))

# Raise only side branches whose stair/landing envelope does not cut across
# another route or entrance approach. Other dead ends stay at street level.
raised=set()
all_lines=[(a,b,None) for _,points,_,_ in routes for a,b in zip(points,points[1:])]
all_lines += [(a,b,i) for i,points in enumerate(branches) for a,b in zip(points,points[1:])]
for i,points in enumerate(branches[:27]):
    a,b=points[-2:];length=abs(a[0]-b[0])+abs(a[1]-b[1]);dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length
    c=(a[0]+dx*length/2,a[1]+dz*length/2);d=(b[0]+dx*4,b[1]+dz*4)
    stair=(min(c[0],d[0])-6,min(c[1],d[1])-6,max(c[0],d[0])+6,max(c[1],d[1])+6)
    if any(owner!=i and overlap(stair,(min(p[0],q[0])-.01,min(p[1],q[1])-.01,max(p[0],q[0])+.01,max(p[1],q[1])+.01)) for p,q,owner in all_lines):continue
    raised.add(i)
    if len(raised)==7:break

out=['-- HIVE GENERATED BEGIN','local hive = {',' Routes = {']
for ei,points,widths,spaces in routes:
    out.append('[%d] = { Points = { %s }, Widths = { %s }, Spaces = { %s } },'%(ei,', '.join('{%g,0,%g}'%p for p in points),', '.join('%g'%w for w in widths),', '.join('"%s"'%v for v in spaces)))
out+=[' },',' Accretions = {']
for i,r in enumerate(accretions):out.append('{%s,%g},'%(','.join('%g'%v for v in r),48+(i%4)*16))
out+=[' },',' Branches = {']
for i,points in enumerate(branches):
    elevated=i in raised
    out.append('{ %s },'%(', '.join('{%g,%g,%g}'%(p[0],3 if elevated and k==len(points)-1 else 0,p[1]) for k,p in enumerate(points))))
out+=[' },',f' RejoiningBranches = {loops},',f' EntranceBranches = {len(entries)},',f' RaisedBranches = {len(raised)},',' Spawns = {']
for name,x,z in projected:out.append('["%s"]={%g,0,%g},'%(name,x,z))
out+=[' },','}','for index, route in pairs(hive.Routes) do',' local e=edges[index];e.Points={};e.SegmentWidths=route.Widths;e.Spaces=route.Spaces',' for _,p in ipairs(route.Points) do table.insert(e.Points,Vector3.new(p[1],p[2],p[3])) end','end','-- HIVE GENERATED END']
text=source.read_text();text=re.sub(r'-- HIVE GENERATED BEGIN.*?-- HIVE GENERATED END','\n'.join(out),text,flags=re.S);source.write_text(text)
print(f'{len(routes)} surface routes; {len(accretions)} occupied extensions; {len(branches)} branches; {len(raised)} raised landings',flush=True)
