"""Checks proposal geometry and kit compatibility, not Roblox walking/navigation."""
import collections
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
d=json.loads((HERE/'layout.json').read_text())
assert all(a['side']==('dangerous' if a['id'] in 'ABC' else 'safer') for a in d['areas'])
for a in d['areas']:
 assert all(0<=x<=1280 and 0<=z<=800 for x,z in a['polygon'])
cells=set()
for r in [d['street']]+d['ground_routes']:
 for (x0,z0),(x1,z1) in zip(r['points'],r['points'][1:]):
  assert x0==x1 or z0==z1, r
  if r is not d['street']:
   assert abs(x1-x0)+abs(z1-z0)<=96,(r['id'],'long segment')
  half=r['width']//2
  cells.update((x,z) for x in range(min(x0,x1)-half,max(x0,x1)+half+1) for z in range(min(z0,z1)-half,max(z0,z1)+half+1))
for key in ('courtyard','gate_space'):
 x0,z0,x1,z1=d[key]['rect'];cells.update((x,z) for x in range(x0,x1+1) for z in range(z0,z1+1))
x0,z0,x1,z1=d['wall']['rect'];g0,g1=d['wall']['opening']
assert not any(x0<=x<=x1 and z0<=z<=z1 and not g0<=x<=g1 for x,z in cells),'Unintended ground wall crossing'
a,b,c,e=d['structural_void']['rect']
assert not any(a<=x<=c and b<=z<=e for x,z in cells),'Route enters reserved void'
start=(1020,464);seen={start};q=collections.deque([start])
while q:
 x,z=q.popleft()
 for p in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
  if p in cells and p not in seen:seen.add(p);q.append(p)
for r in d['ground_routes']:
 assert all(tuple(p) in seen for p in r['points']),r['id']
for r in d['upper_routes']:
 assert all(tuple(p) in seen for p in r['stairs']),r['id']
 assert r['width']>=8
 assert r['elevation']%9==0
 assert all(0<=x<=1280 and 0<=z<=800 for x,z in r['points'])
kit=ROOT/'assets/blender/generated'
front=json.loads((kit/'lower_layer_frontage_kit_v1/manifest.json').read_text())
assert set(d['standards']['frontage_widths'])=={a['width'] for a in front['assets'] if a['name'].startswith('F')}
circ=json.loads((kit/'lower_layer_circulation_kit_v1/manifest.json').read_text())
assert {'I01_OffsetVestibule','I02_DoglegPassage','I05_SplitRoom','I07_StairFlight','I12_BridgeLink'} <= {a['name'] for a in circ['assets']}
report={'passed':True,'plan_only':True,'confirmed_courtyard_side':'dangerous','ground_route_reservations':len(d['ground_routes']),'upper_route_reservations':len(d['upper_routes']),'ground_route_endpoints_connected':True,'upper_stair_endpoints_on_ground_network':True,'unintended_ground_wall_crossings':0,'kit_widths_verified':d['standards']['frontage_widths'],'not_validated':['final building footprints','sightlines through final geometry','stair footprints','collision','Roblox navigation','runtime performance']}
(HERE/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
