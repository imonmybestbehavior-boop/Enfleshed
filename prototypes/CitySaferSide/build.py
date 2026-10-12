"""City assembly: internal wall, safer E/F, courtyard C, and service weave B in plan X,Z.
No main-city, kit, or approved prototype files are modified.
"""
import copy
import hashlib
import json
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
REF=HERE.parent/'KitBlock'
sys.path.insert(0,str(REF))
from surface_cleanup import separate
PLAN=ROOT/'docs/lower-layer-city/layout.json'
plan=json.loads(PLAN.read_text())
components=json.loads((REF/'components.json').read_text())
assets={}
for name in ('frontage','circulation','habitation'):
    for a in json.loads((ROOT/f'assets/blender/generated/lower_layer_{name}_kit_v1/manifest.json').read_text())['assets']:
        assets[a['name']]=a
records=[]; placements=[]; rooms=[]; towers=[]

def part(name,c,s,mat='Plaster',collision=True,visible=True):
    assert min(s)>0,(name,s)
    records.append(dict(name=name,center=list(c),size=list(s),material=mat,collision=collision,visible=visible))
    return records[-1]

def turn(p,angle):
    c,s=round(math.cos(math.radians(angle))),round(math.sin(math.radians(angle)))
    return [c*p[0]-s*p[1],s*p[0]+c*p[1],p[2]]

def world(p,origin,angle):return [a+b for a,b in zip(turn(p,angle),origin)]

def box_world(c,s,origin,angle):
    s=list(s)
    if angle%180:s[0],s[1]=s[1],s[0]
    return world(c,origin,angle),s

def asset(label,key,origin,angle=0):
    placements.append(dict(id=label,asset=key,origin=list(origin),angle=angle))
    a=components['assets'][key]
    for kind,items in [('VIS',a['parts']),('COL',a['colliders'])]:
        for i,p in enumerate(items):
            p=copy.deepcopy(p)
            # Stacked flights need a thin structural underside, not the kit's
            # solid-to-base tread fill. Preserve every tread's top and riser.
            if key=='I07_StairFlight' and origin[2]>=18 and p['size'][0]>11 and 4<p['center'][1]<28 and p['size'][2]>1:
                top=p['center'][2]+p['size'][2]/2
                p['size'][2]=1; p['center'][2]=top-.5
            c,s=box_world(p['center'],p['size'],origin,angle)
            part(label+'__'+kind+'_%03d'%i,c,s,p.get('material','Masonry'),kind=='COL',kind=='VIS')

def rect_cells(x0,z0,x1,z1):
    return {(x,z) for x in range(math.floor(x0),math.ceil(x1)) for z in range(math.floor(z0),math.ceil(z1))}

def footprint(origin,angle,width,depth,front=0,pad=0):
    c,s=box_world([0,(front+depth)/2,0],[width,depth-front,1],origin,angle)
    return rect_cells(c[0]-s[0]/2-pad,c[1]-s[1]/2-pad,c[0]+s[0]/2+pad,c[1]+s[1]/2+pad)

def path_cells(points,width):
    result=set();h=width/2
    for a,b in zip(points,points[1:]):
        assert a[0]==b[0] or a[1]==b[1]
        result |= rect_cells(min(a[0],b[0])-h,min(a[1],b[1])-h,max(a[0],b[0])+h,max(a[1],b[1])+h)
    return result

def merged(cells):
    rows={}
    for x,z in cells:rows.setdefault(z,[]).append(x)
    runs={}
    for z,xs in sorted(rows.items()):
        xs.sort();start=prev=xs[0]
        for x in xs[1:]+[99999]:
            if x!=prev+1:runs.setdefault((start,prev+1),[]).append(z);start=x
            prev=x
    for (left,right),zs in runs.items():
        start=prev=zs[0]
        for z in zs[1:]+[99999]:
            if z!=prev+1:
                yield left,start,right,prev+1
                start=z
            prev=z

def inside(x,z,poly):
    result=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>z)!=(b[1]>z) and x<(b[0]-a[0])*(z-a[1])/(b[1]-a[1])+a[0]:result=not result
    return result

routes=[r for r in plan['ground_routes'] if r['id'].startswith(('E','F'))]
# E1 includes the wall-edge connection into future D; close only that unfinished end.
routes=copy.deepcopy(routes)
# All existing E/F ground-route vertices remain at their approved coordinates.
walk=set()
for r in routes:walk |= path_cells(r['points'],r['width'])
x0,z0,x1,z1=plan['gate_space']['rect'];walk|=rect_cells(x0,z0,x1,z1)
# The full wall-side street is available to inspect the divider at its approved length.
walk |= path_cells(plan['street']['points'],24)
# A physical 32-stud opening, rather than a painted gate over a ten-stud corridor.
walk |= rect_cells(1004,368,1036,444)
room_clear=set(); pocket_clear=set(); tower_clear=set(); indoor=set()
for label,key,origin,angle in [
 ('E_EntryHall','I05_SplitRoom',(584,488,0),0),
 ('E_WestHall','U03_BridgeApartment',(456,504,0),0),
 ('E_LowerHall','I05_SplitRoom',(528,600,0),0),
 ('E_EastHall','I05_SplitRoom',(648,608,0),0),
 ('F_WestHall','I05_SplitRoom',(896,576,0),0),
 ('F_LowerHall','U03_BridgeApartment',(952,640,0),0),
 ('F_EntryHall','I05_SplitRoom',(1080,476,0),0),
 ('F_EastHall','U03_BridgeApartment',(1144,528,0),0),
 ('F_CrossHall','I05_SplitRoom',(1032,600,0),180),
 ('E_ThroughFront','F08_ThroughPassage',(744,599,0),-90),
]:
    asset(label,key,origin,angle)
    a=assets[key];cells=footprint(origin,angle,a['width'],a['depth'])
    room_clear|=cells;walk|=cells;indoor|=cells
    rooms.append(label)
    if key=='I05_SplitRoom':
        side=world([12,12,0],origin,angle)
        asset(label+'_SideRoom','I13_ServiceAlcove',side,angle-90)
        cells=footprint(side,angle-90,12,12)
        room_clear|=cells;walk|=cells;indoor|=cells

# Switchback towers use original step/landing components, never stretched stairs.
def tower(label,origin,angle,levels):
    for level in range(levels):
        base=level*18
        asset(label+f'_Flight{level*2}', 'I07_StairFlight',world([0,0,base],origin,angle),angle)
        asset(label+f'_Half{level}', 'I08_ReturnLanding',world([6,32,base+9],origin,angle),angle)
        asset(label+f'_Flight{level*2+1}', 'I07_StairFlight',world([12,32,base+9],origin,angle),angle+180)
        if level<levels-1:
            asset(label+f'_Storey{level}', 'I08_ReturnLanding',world([6,0,base+18],origin,angle),angle+180)
    cells=footprint(world([6,0,0],origin,angle),angle,24,44,-12 if levels>1 else -4,1)
    tower_clear.update(cells);walk.update(cells)
    roof_c,roof_s=box_world([6,16,levels*18+13.55],[26,58 if levels>1 else 50,.6],origin,angle)
    part(label+'_Roof',roof_c,roof_s,'Masonry')
    top=world([12,0,levels*18],origin,angle)
    towers.append(dict(id=label,bottom=list(origin),top=top,levels=levels,exit_direction=turn([0,1,0],angle+180)[:2]))
    return top

a=tower('E_WestStairs',(432,616,0),180,1)
b=tower('E_EastStairs',(584,592,0),90,1)
c=tower('F_WestStairs',(952,624,0),180,2)
e=tower('F_EastStairs',(1080,544,0),-90,2)
upper=[dict(id='E_Upper',height=18,points=[a[:2],[420,624],[472,624],[472,560],[544,560],[544,580],[600,580],[600,604],b[:2]]),
       dict(id='F_Upper',height=36,points=[c[:2],[940,632],[992,632],[992,584],[1068,584],[1068,532],e[:2]])]
upper_masks={18:set(),36:set()}
for r in upper:upper_masks[r['height']] |= path_cells(r['points'],8)
asset('F_UpperHome','U03_BridgeApartment',(1008,584,36),-90)
upper_room=footprint((1008,584,36),-90,16,24)
upper_masks[36]|=upper_room

# Occupied neighborhood envelopes: final facades are attached to these real masses.
polys=[a['polygon'] for a in plan['areas'] if a['id'] in ('E','F')]
occupied={(x,z) for x in range(312,1216) for z in range(440,720) if any(inside(x+.5,z+.5,p) for p in polys)}
occupied -= walk
# Structured deterministic frontage pockets along long straight boundary runs.
# The entire kit footprint must fit; corners and stair/room reservations win.
def edges(cells,exclude=None):
    runs={}
    for x,z in cells:
        for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
            if (x+dx,z+dz) in cells:continue
            if exclude and ((x,z) in exclude or (x+dx,z+dz) in exclude):continue
            fixed=x+(dx==1) if dx else z+(dz==1)
            runs.setdefault((dx,dz,fixed),[]).append(z if dx else x)
    for (dx,dz,fixed),vals in sorted(runs.items()):
        vals.sort();start=prev=vals[0]
        for v in vals[1:]+[99999]:
            if v!=prev+1:
                yield dx,dz,fixed,start,prev+1
                start=v
            prev=v
frontages=[]
for dx,dz,fixed,lo,hi in list(edges(walk)):
    if hi-lo<22:continue
    for along in range(lo+11,hi-9,28):
        pos=[fixed,along,0] if dx else [along,fixed,0]
        if pos[1]<444:continue
        angle={ (0,1):0,(0,-1):180,(1,0):-90,(-1,0):90 }[dx,dz]
        keys=['F05_ResidentialEntry','F06_ServiceEntry','F01_NarrowShop','F03_ShutteredStore','F09_PatchedBlank']
        key=keys[len(frontages)%len(keys)]
        data=assets[key]
        cells=footprint(pos,angle,data['width'],max(data['depth'],8),0,1)
        # One-cell facade seam may touch the walkable side; require the body behind it.
        body=footprint(world([0,1,0],pos,angle),angle,data['width'],max(data['depth'],8),0,1)
        if len(body & occupied)<len(body)*.94 or cells & (room_clear|tower_clear|pocket_clear):continue
        # Keep a genuine margin from corners/nearby paths, not randomly scattered fronts.
        if any((x,z) in walk for x,z in footprint(world([0,2,0],pos,angle),angle,data['width'],max(data['depth']-2,1))):continue
        label='Front_%03d'%len(frontages)
        asset(label,key,pos,angle)
        frontages.append(dict(id=label,asset=key,origin=pos,angle=angle))
        pocket_clear|=cells
        # Flush closure behind a shallow tenant room; main route interiors are separate.
        if key in ('F05_ResidentialEntry','F06_ServiceEntry','F01_NarrowShop'):
            rear_c,rear_s=box_world([0,data['depth']+.2,6.5],[data['width'],.4,13],pos,angle)
            part(label+'_RearWall',rear_c,rear_s,'RepairPlaster')
            walk |= footprint(pos,angle,data['width'],data['depth'])
        # Upper windows belong to the same building width/language.
        for height in (18,36):
            if footprint(pos,angle,12,2,0,1) & (upper_masks[height]|tower_clear):continue
            asset(label+f'_Windows{height}','U01_ApartmentWindowBay',world([0,0,height],pos,angle),angle)
occupied -= pocket_clear

# Dense solids are merged from exact route boundaries, not inflated coarse floor tiles.
# Upper paths cut physical volumes through these buildings while leaving ground rooms intact.
for layer,(bottom,top) in enumerate([(0,18),(18,36),(36,54),(54,72)]):
    cells=set(occupied)
    for height,mask in upper_masks.items():
        if bottom<height+18 and top>height-.7:cells-=mask
    cells-=tower_clear
    for i,(x0,z0,x1,z1) in enumerate(merged(cells)):
        # Uppermost accretions are selective; three-storey walls still enclose every lane.
        if layer==3 and (x0//24+z0//24)%3:continue
        part(f'Building_{layer}_{i}',[(x0+x1)/2,(z0+z1)/2,(bottom+top)/2],[x1-x0,z1-z0,top-bottom], 'RepairPlaster' if (x0//12)%4==0 else 'Plaster')
# The volume above kit rooms is part of the building, not an unoccupied roofless cavity.
for i,(x0,z0,x1,z1) in enumerate(merged(room_clear - tower_clear - upper_masks[18] - upper_masks[36])):
    part('RoomUpperMass_%d'%i,[(x0+x1)/2,(z0+z1)/2,36],[x1-x0,z1-z0,36])
# Ground deck union gives visible surfaces and continuous hidden collision support.
for i,(x0,z0,x1,z1) in enumerate(merged(walk)):
    c=[(x0+x1)/2,(z0+z1)/2,-.3];s=[x1-x0,z1-z0,.6]
    part('GroundDeck_%d'%i,c,s,'CutStone')
    part('GroundSupport_%d'%i,[c[0],c[1],-.8],[s[0]+.8,s[1]+.8,1],visible=False)
# Covers span ordinary lanes; kit room/stair ceilings retain their own geometry.
cover=walk - room_clear - tower_clear - pocket_clear
cover={(x,z) for x,z in cover if z>=440 and not (992<=x<1048 and 440<=z<480)}
for i,(x0,z0,x1,z1) in enumerate(merged(cover)):
    part('LaneCeiling_%d'%i,[(x0+x1)/2,(z0+z1)/2,13.55],[x1-x0+.3,z1-z0+.3,.6],'Masonry')
boundary_occupied=occupied|room_clear|pocket_clear|tower_clear
# Close external route boundaries only where a building or kit does not already do so.
for i,(dx,dz,fixed,lo,hi) in enumerate(edges(walk)):
    mid=(lo+hi)/2
    outside=(fixed+dx*.75,mid) if dx else (mid,fixed+dz*.75)
    if (math.floor(outside[0]),math.floor(outside[1])) in boundary_occupied:continue
    # Full main street has its own wall and unbuilt-side boundary below.
    if (mid if dx else fixed)<440:continue
    c=[fixed,mid,6.5] if dx else [mid,fixed,6.5]
    s=[.5,hi-lo,13] if dx else [hi-lo,.5,13]
    part('ExternalBoundary_%d'%i,c,s,'Masonry')

for r in upper:
    height=r['height'];mask=upper_masks[height]
    # Do not put a second deck or ceiling through the stair flights.
    floor_mask=mask
    for i,(x0,z0,x1,z1) in enumerate(merged(floor_mask)):
        part(r['id']+'_Deck%d'%i,[(x0+x1)/2,(z0+z1)/2,height-.3],[x1-x0,z1-z0,.6],'CutStone')
        part(r['id']+'_Support%d'%i,[(x0+x1)/2,(z0+z1)/2,height-.8],[x1-x0+.6,z1-z0+.6,1],visible=False)
        if height==36 and (x0,z0) in upper_room:continue
        part(r['id']+'_Ceiling%d'%i,[(x0+x1)/2,(z0+z1)/2,height+13.55],[x1-x0+.3,z1-z0+.3,.6],'Masonry')
    port_holes=set()
    for t in towers:
        if t['top'][2]==height:
            x,z,_=t['top'];dx,dz=t['exit_direction']
            # Remove only the cap across the arriving stair, not its side rails.
            if dx:port_holes |= rect_cells(x-4*dx-1,z-4,x-4*dx+1,z+4)
            else:port_holes |= rect_cells(x-4,z-4*dz-1,x+4,z-4*dz+1)
    for i,(dx,dz,fixed,lo,hi) in enumerate(edges(mask,port_holes)):
        mid=(lo+hi)/2
        # Open the boundary around actual stair arrivals and the inhabited bridge.
        point=(fixed,mid) if dx else (mid,fixed)

        if (math.floor(point[0]),math.floor(point[1])) in upper_room:continue
        c=[fixed,mid,height+1.7] if dx else [mid,fixed,height+1.7]
        s=[.5,hi-lo,3.4] if dx else [hi-lo,.5,3.4]
        part(r['id']+'_Guard%d'%i,c,s,'Masonry')

# Residential frames on solid upper-route backing walls; keep every portal clear.
upper_window_count=0
for height,mask in upper_masks.items():
    for dx,dz,fixed,lo,hi in edges(mask):
        if hi-lo<20:continue
        for along in range(lo+10,hi-9,28):
            pos=[fixed,along,height] if dx else [along,fixed,height]
            angle={(0,1):0,(0,-1):180,(1,0):-90,(-1,0):90}[dx,dz]
            body=footprint(world([0,1,0],pos,angle),angle,12,2)
            if not body or len(body&occupied)<len(body)*.95:continue
            if body&(tower_clear|pocket_clear|upper_room):continue
            if upper_window_count>=24:break
            asset('UpperBackingWindow_%02d'%upper_window_count,'U01_ApartmentWindowBay',pos,angle)
            upper_window_count+=1

# Landings span the small transition between module tops and native upper connections.
for t in towers:
    x,z,h=t['top'];part(t['id']+'_TopDeck',[x,z,h-.3],[12,8,.6],'CutStone')
# Divider at the approved full length. The 32-wide opening has a true lintel.
x0,z0,x1,z1=plan['wall']['rect'];g0,g1=plan['wall']['opening']
for lo,hi in ((x0,g0),(g1,x1)):
    part('InternalWall',[(lo+hi)/2,(z0+z1)/2,21],[hi-lo,z1-z0,42],'Masonry')
    part('InternalWallFooting',[(lo+hi)/2,396,1.5],[hi-lo,8,3],'Masonry')
part('InternalOpeningLintel',[(g0+g1)/2,412,36],[g1-g0,24,12],'Masonry')
for x in (1002,1038):part('OpeningJamb',[x,412,15],[4,26,30],'CutStone')
# Unbuilt areas have visible physical ends, not invisible walkable gaps or pretend streets.
# Retain only the A closure; B/C connect through their real approaches.
part('DangerousSideReservation',[238,366,36],[356,4,72],'Masonry')
for x in (52,1228):part('StreetEnd',[x,380,14],[4,28,28],'Masonry')
# Underground entry reserved as a visible sealed hatch; no tunnel or wall bypass yet.
part('ReservedUnderworksHatch',[1104,568,.08],[5,5,.16],'Iron',False)
for x in (1100.9,1107.1):part('HatchFrame',[x,568,.15],[.25,6.4,.3],'Zinc',False)
# Ancient envelope exceeds the human block limits; actual roof prevents sky exposure.
part('AncientRoof',[640,400,186],[1376,896,12],'Masonry')
part('DevelopmentCatch',[640,400,-20],[1376,896,4],'Masonry')
for x in (-42,1322):part('AncientSide',[x,400,80],[12,896,224],'Masonry')
for z in (-42,842):part('AncientEnd',[640,z,80],[1376,12,224],'Masonry')
for x in (344,752,1184):
    part('AncientRib',[x,594,142],[16,340,76],'Masonry')
# Closed background habitation above the playable city, supported by broad transfer beams.
for x,z in ((416,700),(688,708),(872,696),(1184,652)):
    part('UpperBackgroundBearing',[x,z,86],[80,28,8],'Masonry')
    part('UpperBackgroundMass',[x,z,108],[64,24,36],'RepairPlaster')
    for offset in (-20,0,20):asset('Background_%d_%d_%d'%(x,z,offset),'U01_ApartmentWindowBay',(x+offset,z-12,90))
# Mounted lamps: ground fixtures touch the ceiling; street fixtures touch the divider.
lamps=[]
for i,r in enumerate(routes):
    for j,(a,b) in enumerate(zip(r['points'],r['points'][1:])):
        x,z=(a[0]+b[0])/2,(a[1]+b[1])/2
        cell=(math.floor(x),math.floor(z))
        if cell not in cover:continue
        if any(math.dist((x,z),(v[0],v[1]))<22 for v in lamps):continue
        lamps.append([x,z,12.95])
for r in upper:
    for a,b in zip(r['points'],r['points'][1:]):lamps.append([(a[0]+b[0])/2,(a[1]+b[1])/2,r['height']+12.9])
for x in range(104,1216,48):
    if not 1004<x<1036:lamps.append([x,399.5,12])
lamps.extend([[1004.6,426,10],[1035.4,426,10],[992.4,448,10],[1047.6,448,10]])
for i,c in enumerate(lamps):part('Lamp_%03d'%i,c,[.6,.6,.3],'Zinc',False)
# Source kit lamps are not present in the component library; light the through rooms too.
for p in placements:
    if p['id'] in rooms:
        c=world([0,10,12.8],p['origin'],p['angle']);lamps.append(c);part('RoomLamp_%03d'%len(lamps),c,[.6,.6,.3],'Zinc',False)

from weave import build_weave, CONNECTIONS
from courtyard import build_courtyard
courtyard=build_courtyard(part=part,asset=asset,tower=tower,footprint=footprint,path_cells=path_cells,
    rect_cells=rect_cells,merged=merged,edges=edges,world=world,box_world=box_world,plan=plan,assets=assets,connections=CONNECTIONS)
routes.extend(courtyard['routes']);upper.append(courtyard['upper'])
rooms.extend(courtyard['rooms']);frontages.extend(courtyard['frontages'])

weave=build_weave(part=part,asset=asset,tower=tower,footprint=footprint,path_cells=path_cells,
    rect_cells=rect_cells,merged=merged,edges=edges,world=world,box_world=box_world,plan=plan,assets=assets)
routes.extend(weave['routes']);upper.append(weave['upper'])
rooms.extend(weave['rooms']);frontages.extend(weave['frontages'])

if '--geometry-only' in sys.argv:
    target=Path(sys.argv[sys.argv.index('--geometry-only')+1])
    target.write_text(json.dumps(dict(weave=weave,courtyard=courtyard,parts=records,placements=placements,
        frontages=frontages,rooms=rooms,towers=towers,ground_routes=routes,upper_routes=upper,spawn=[1020,460,0],
        plan_sha256=hashlib.sha256(PLAN.read_bytes()).hexdigest())))
    print('Wrote collision preflight:',target)
    sys.exit(0)

print('Geometry assembled:',len(records),'Parts; separating visible faces',flush=True)
original=copy.deepcopy(records)
cleanup,changed=separate(records)
for i in sorted(changed):
    if original[i]['collision']:
        p=original[i]
        part(p['name']+'_PreservedCollision',p['center'],p['size'],p['material'],True,False)
        records[i]['collision']=False
sig=lambda ps:sorted((tuple(p['center']),tuple(p['size'])) for p in ps if p['collision'])
assert sig(original)==sig(records)

xml=ET.Element('roblox',version='4');model=ET.SubElement(xml,'Item',{'class':'Model'})
ET.SubElement(ET.SubElement(model,'Properties'),'string',name='Name').text='CitySaferSide'
enclosure=ET.SubElement(model,'Item',{'class':'Model'})
ET.SubElement(ET.SubElement(enclosure,'Properties'),'string',name='Name').text='AncientEnvelope'
for i,p in enumerate(records):
    p['name']='%05d_%s'%(i,p['name'])
    parent=enclosure if any(tag in p['name'] for tag in ('Ancient','InternalWall','InternalOpening','OpeningJamb','DevelopmentCatch')) else model
    item=ET.SubElement(parent,'Item',{'class':'Part'});props=ET.SubElement(item,'Properties')
    ET.SubElement(props,'string',name='Name').text=p['name']
    for name,value in {'Anchored':True,'CanCollide':p['collision'],'CanQuery':p['collision'],'CanTouch':False,'CastShadow':p['visible'],'Locked':True}.items():ET.SubElement(props,'bool',name=name).text=str(value).lower()
    ET.SubElement(props,'float',name='Transparency').text='0' if p['visible'] else '1'
    ET.SubElement(props,'token',name='Material').text=str({'Iron':1088,'Zinc':1088,'Glass':272,'Timber':512,'PaintedTimber':512}.get(p['material'],816))
    for name in ('TopSurface','BottomSurface'):ET.SubElement(props,'token',name=name).text='0'
    col=ET.SubElement(props,'Color3',name='Color')
    for k,v in zip('RGB',components['materials'][p['material']]['base_color']):ET.SubElement(col,k).text=str(v)
    size=ET.SubElement(props,'Vector3',name='size');cf=ET.SubElement(props,'CoordinateFrame',name='CFrame')
    for k,v in zip('XYZ',(p['size'][0],p['size'][2],p['size'][1])):ET.SubElement(size,k).text=str(round(v,6))
    for k,v in zip('XYZ',(p['center'][0],p['center'][2],p['center'][1])):ET.SubElement(cf,k).text=str(round(v,6))
    for row in range(3):
        for col in range(3):ET.SubElement(cf,'R%d%d'%(row,col)).text='1' if row==col else '0'
    if p['visible'] and ('Lamp_' in p['name'] or 'RoomLamp_' in p['name']):
        l=ET.SubElement(ET.SubElement(item,'Item',{'class':'PointLight'}),'Properties')
        ET.SubElement(l,'float',name='Brightness').text='1.8';ET.SubElement(l,'float',name='Range').text='30'
        ET.SubElement(l,'bool',name='Shadows').text='false'
        c=ET.SubElement(l,'Color3',name='Color')
        for k,v in zip('RGB',(1,.78,.52)):ET.SubElement(c,k).text=str(v)
ET.indent(xml);ET.ElementTree(xml).write(HERE/'City.rbxmx',encoding='utf-8',xml_declaration=True)
project=json.loads((REF/'review.project.json').read_text());project['name']='Enfleshed_CitySaferSide'
project['tree']['Workspace'].pop('KitBlock');project['tree']['Workspace']['CitySaferSide']={'$path':'City.rbxmx'}
# Roblox place files persist BasePart transforms as CFrame, not Position.
spawn_props=project['tree']['Workspace']['TestSpawn']['$properties']
spawn_props.pop('Position',None)
spawn_props.update(CFrame=[1020,-.5,460,1,0,0,0,1,0,0,0,1],Size=[8,1,8],CanCollide=True)
project['tree']['ServerScriptService']['Server']['Services']['OpeningService']['$path']='../KitBlock/OpeningService.luau'
# Match the existing city's streaming distances; enclosure is persisted by startup.
project['tree']['Workspace']['$properties'].update(StreamingEnabled=True,StreamingMinRadius=256,StreamingTargetRadius=768)
(HERE/'review.project.json').write_text(json.dumps(project,indent=2)+'\n')
report=dict(weave=weave,courtyard=courtyard,parts=records,placements=placements,frontages=frontages,rooms=rooms,towers=towers,ground_routes=routes,upper_routes=upper,spawn=[1020,460,0],cleanup=cleanup,plan_sha256=hashlib.sha256(PLAN.read_bytes()).hexdigest())
(HERE/'assembly.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(dict(parts=len(records),frontages=len(frontages),through_rooms=len(rooms),stair_towers=len(towers),lamps=sum(p['visible'] and 'Lamp_' in p['name'] for p in records),cleanup=cleanup),indent=2))
