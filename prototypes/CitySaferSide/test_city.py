"""Offline checks against built collision and compiled scripts. Not a Studio simulation."""
import collections
import hashlib
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE.parent/'KitBlock'))
from surface_cleanup import conflicts
geometry_only='--geometry-only' in sys.argv
source=Path(sys.argv[sys.argv.index('--geometry-only')+1]) if geometry_only else HERE/'assembly.json'
D=json.loads(source.read_text())
assert D['plan_sha256']==hashlib.sha256((ROOT/'docs/lower-layer-city/layout.json').read_bytes()).hexdigest()
errors=[]; buckets=collections.defaultdict(list)
for p in D['parts']:
    if not p['collision']:continue
    lo=[c-s/2 for c,s in zip(p['center'],p['size'])];hi=[c+s/2 for c,s in zip(p['center'],p['size'])]
    for x in range(math.floor((lo[0]-2)/12),math.floor((hi[0]+2)/12)+1):
        for z in range(math.floor((lo[1]-2)/12),math.floor((hi[1]+2)/12)+1):buckets[x,z].append((p['name'],lo,hi))
def probe(p):
    x,z,h=p
    near=[(n,a,b) for n,a,b in buckets[math.floor(x/12),math.floor(z/12)] if a[0]<x+2-1e-5 and b[0]>x-2+1e-5 and a[1]<z+2-1e-5 and b[1]>z-2+1e-5]
    support=any(a[0]-.01<=x<=b[0]+.01 and a[1]-.01<=z<=b[1]+.01 and abs(b[2]-h)<.09 for n,a,b in near)
    hit=[n for n,a,b in near if a[2]<h+9.5-.01 and b[2]>h+1.6]
    return support and not hit, hit or ([] if support else ['unsupported'])
def world(p,placed):
    c,s=round(math.cos(math.radians(placed['angle']))),round(math.sin(math.radians(placed['angle'])))
    x,z,h=p
    return [c*x-s*z+placed['origin'][0],s*x+c*z+placed['origin'][1],h+placed['origin'][2]]
def check(label,p):
    good,why=probe(p)
    if not good:errors.append([label,p,why])
assets={}
for name in ('circulation','habitation'):
    assets.update({a['name']:a for a in json.loads((ROOT/f'assets/blender/generated/lower_layer_{name}_kit_v1/manifest.json').read_text())['assets']})
samples=0
for p in D['placements']:
    if p['asset'] not in assets:continue
    for sample in assets[p['asset']]['samples']:
        check(p['id'],world(sample['position'],p));samples+=1
upper_samples=0
for r in D['upper_routes']:
    for a,b in zip(r['points'],r['points'][1:]):
        length=round(abs(a[0]-b[0])+abs(a[1]-b[1]))
        for t in range(length+1):
            check(r['id'],[a[0]+(b[0]-a[0])*t/max(1,length),a[1]+(b[1]-a[1])*t/max(1,length),r['height']]);upper_samples+=1
# New room lights must not be buried in the split-room cores or backing masses.
for light in D['parts']:
    if 'B_RoomLamp_' not in light['name']:continue
    for p in D['parts']:
        if p is light or not p['visible']:continue
        if all(abs(light['center'][axis]-p['center'][axis])<p['size'][axis]/2-.01 for axis in range(3)):
            errors.append(['Buried room light',light['name'],p['name']])
# Every open tenant frontage must have a usable doorway and a real floor inside.
front_manifest=json.loads((ROOT/'assets/blender/generated/lower_layer_frontage_kit_v1/manifest.json').read_text())
front_assets={a['name']:a for a in front_manifest['assets']}
door_checks=0
for p in D['frontages']:
    for opening in front_assets[p['asset']]['openings']:
        for depth in (-2,0,2,4):
            check(p['id']+' doorway',world([opening['x'],depth,0],p));door_checks+=1
# Flood-fill actual supported ground, including through-room detours around solid cores.
walkable=set()
for x in range(310,1224):
    for z in range(64,725):
        if probe((x,z,0))[0]:walkable.add((x,z))
for x in range(48,1233):
    for z in range(364,437):
        if probe((x,z,0))[0]:walkable.add((x,z))
start=tuple(D['spawn'][:2]);assert start in walkable,'Spawn blocked'
seen={start};q=collections.deque([start])
while q:
    x,z=q.popleft()
    for p in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
        if p in walkable and p not in seen:seen.add(p);q.append(p)
for r in D['ground_routes']:
    for p in r['points']:
        if tuple(p) not in seen:errors.append(['Unreachable planned ground point',p,probe((*p,0))[1]])
for t in D['towers']:
    if tuple(t['bottom'][:2]) not in seen:errors.append(['Unreachable stairs',t['id']])
for p in ((1020,380),(1104,568),(64,380),(1216,380)):
    if p not in seen:errors.append(['Unreachable landmark',p])
# Courtyard is visibly floored, connected by either independent street approach.
for x in range(962,1064,8):
    for z in range(140,220,8):
        if (x,z) not in seen:errors.append(['Unreachable courtyard floor',[x,z]])
for blocked_x in (928,1152):
    alternate={start};queue=collections.deque([start])
    while queue:
        x,z=queue.popleft()
        for p in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
            if abs(p[0]-blocked_x)<=8 and 360<=p[1]<=368:continue
            if p in walkable and p not in alternate:alternate.add(p);queue.append(p)
    assert (1012,176) in alternate, ('Courtyard lacks independent return approach',blocked_x)
# New B/C connectors must be usable along their full length, not just at endpoints.
for route in D['weave']['connections']:
    for a,b in zip(route['points'],route['points'][1:]):
        length=round(abs(a[0]-b[0])+abs(a[1]-b[1]))
        for t in range(length+1):
            check(route['id'],[a[0]+(b[0]-a[0])*t/max(1,length),a[1]+(b[1]-a[1])*t/max(1,length),0])
# Either connection must support travel between B and C without the wall street.
for blocked_z in (176,352):
    origin=(1012,176);reachable={origin};queue=collections.deque([origin])
    while queue:
        x,z=queue.popleft()
        for p in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
            if p[1]>=360 or (836<=p[0]<=844 and abs(p[1]-blocked_z)<=8):continue
            if p in walkable and p not in reachable:reachable.add(p);queue.append(p)
    assert (552,224) in reachable, ('B/C independent interior connection blocked',blocked_z)
# The wall street must end against solid structure, never a strip down to the catch floor.
for x in range(64,1225,4):
    if 1000<x<1040:continue
    for z in (392,396,400,368):
        ok,why=probe((x,z,0))
        assert ok or why!=['unsupported'], ('Unprotected wall-street edge',x,z)
if geometry_only:
    print(json.dumps(dict(errors=errors,samples=samples,upper_samples=upper_samples),indent=2))
    assert not errors,f'{len(errors)} geometry errors'
    sys.exit(0)
# A compiled build is mandatory, so XML ordering/visibility errors cannot hide in source records.
place=ET.parse(ROOT/'Enfleshed_CitySaferSide.rbxlx').getroot();items=list(place.iter('Item'))
workspace=next(i for i in items if i.get('class')=='Workspace')
assert workspace.findtext("Properties/bool[@name='StreamingEnabled']")=='true'
assert workspace.findtext("Properties/*[@name='StreamingMinRadius']")=='256'
assert workspace.findtext("Properties/*[@name='StreamingTargetRadius']")=='768'
assert any(i.findtext("Properties/string[@name='Name']")=='AncientEnvelope' for i in items)
server=next(i for i in items if i.get('class')=='Script' and i.findtext("Properties/string[@name='Name']")=='Server')
assert 'Enum.ModelStreamingMode.Persistent' in server.findtext("Properties/*[@name='Source']")
parts=[i for i in items if i.get('class')=='Part'];assert len(parts)==len(D['parts'])
assert len([i for i in items if i.get('class')=='SpawnLocation'])==1
spawn=next(i for i in items if i.get('class')=='SpawnLocation')
spawn_props=spawn.find('Properties')
spawn_cf=spawn_props.find("CoordinateFrame[@name='CFrame']")
assert spawn_cf is not None, 'Spawn must serialize CFrame; Position alone does not persist placement'
assert [float(spawn_cf.findtext(k)) for k in 'XYZ']==[D['spawn'][0],-.5,D['spawn'][1]]
assert spawn_props.findtext("bool[@name='CanCollide']")=='true'
spawn_size=spawn_props.find("Vector3[@name='size']")
assert float(spawn_cf.findtext('Y'))+float(spawn_size.findtext('Y'))/2==D['spawn'][2]
check('spawn landing',D['spawn'])

expected={p['name']:p for p in D['parts']};surfaces=[]
for i in parts:
    props=i.find('Properties');p=expected[props.findtext("string[@name='Name']")]
    assert (props.findtext("bool[@name='CanCollide']")=='true')==p['collision']
    assert (float(props.findtext("float[@name='Transparency']",'0'))<1)==p['visible']
    cf=props.find("CoordinateFrame[@name='CFrame']");sz=props.find("Vector3[@name='size']")
    center=[float(cf.findtext(k)) for k in ('X','Z','Y')];size=[float(sz.findtext(k)) for k in ('X','Z','Y')]
    assert all(abs(a-b)<.0002 for a,b in zip(center+size,p['center']+p['size'])),p['name']
    if p['visible']:surfaces.append(dict(name=p['name'],visible=True,center=center,size=size))
assert not list(conflicts(surfaces)), 'Coplanar surfaces in the compiled place'
def child(node,name):return next(i for i in node.findall('Item') if i.findtext("Properties/string[@name='Name']")==name)
parents={item:parent for parent in place.iter() for item in parent};references=0
shared=child(child(place,'ReplicatedStorage'),'Shared')
for script in items:
    source=script.findtext("Properties/*[@name='Source']") or ''
    for ref in re.findall(r'require\((script(?:\.[A-Za-z_]\w*)+)\)',source):
        node=script
        for name in ref.split('.')[1:]:node=parents[node] if name=='Parent' else child(node,name)
        assert node.get('class')=='ModuleScript',ref
        references+=1
    for ref in re.findall(r'Shared((?::WaitForChild\("[^\"]+"\))+)',source):
        node=shared
        for name in re.findall(r':WaitForChild\("([^\"]+)"\)',ref):node=child(node,name)
        assert node.get('class')=='ModuleScript'
        references+=1
report=dict(passed=not errors,parts=len(parts),frontages=len(D['frontages']),through_rooms=len(D['rooms']),doorway_samples=door_checks,stair_towers=len(D['towers']),module_route_samples=samples,upper_samples=upper_samples,ground_cells_reachable=len(seen),module_references=references,coplanar_overlaps=0,errors=errors,studio_verified=False)
(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({**report,'errors':errors[:20]},indent=2))
assert not errors, f'{len(errors)} blocked/unsupported/unreachable checks; full report in validation.json'
