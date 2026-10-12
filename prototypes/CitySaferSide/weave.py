"""Neighborhood B: service/residential weave and explicit connections into C."""
import copy
import math

# The same explicit portal reservations are used by B and C; no unseen wall bypass.
CONNECTIONS = [
    dict(id='BC_North',width=8,points=[[752,200],[800,200],[800,176],[884,176]]),
    dict(id='BC_South',width=8,points=[[752,320],[808,320],[808,352],[880,352],[880,356],[928,356]]),
]


def build_weave(*, part, asset, tower, footprint, path_cells, rect_cells,
                    merged, edges, world, box_world, plan, assets):
    routes = copy.deepcopy([r for r in plan['ground_routes'] if r['id'].startswith('B')])
    routes += copy.deepcopy(CONNECTIONS)
    routes += [dict(id='B_WestStairApproach',width=8,points=[[560,280],[584,280]]),
               dict(id='B_EastStairApproach',width=8,points=[[752,256],[776,256]]),
               dict(id='B_RepairBranch',width=8,points=[[504,224],[472,224],[472,244]])]
    walk=set()
    for r in routes:
        walk |= {(x,z) for x,z in path_cells(r['points'],r['width']) if x<840}
    rooms = []
    room_clear = set()
    for label, key, origin, angle in [
        ('B_WestThreshold','I05_SplitRoom',(512,360,0),180),
        ('B_Workshop','I05_SplitRoom',(528,280,0),-90),
        ('B_NorthHome','U03_BridgeApartment',(504,160,0),180),
        ('B_EastThreshold','U03_BridgeApartment',(752,360,0),180),
        ('B_ServiceHall','I05_SplitRoom',(704,312,0),180),
        ('B_NorthService','U03_BridgeApartment',(652,136,0),-90),
        ('B_CrossRoom','I05_SplitRoom',(568,224,0),-90),
    ]:
        asset(label,key,origin,angle)
        cells=footprint(origin,angle,assets[key]['width'],assets[key]['depth'])
        room_clear |= cells;walk |= cells;rooms.append(label)
        if key=='I05_SplitRoom':
            side=world([12,12,0],origin,angle)
            asset(label+'_SideRoom','I13_ServiceAlcove',side,angle-90)
            cells=footprint(side,angle-90,12,12)
            room_clear |= cells;walk |= cells
    west=tower('B_WestStairs',(584,280,0),0,2)
    east=tower('B_EastStairs',(776,256,0),0,2)
    stair_clear=footprint((590,280,0),0,24,44,-12,1)
    stair_clear |= footprint((782,256,0),0,24,44,-12,1)
    walk |= stair_clear
    upper=dict(id='B_ServiceGallery',height=36,points=[west[:2],[596,264],[640,264],
        [640,248],[672,248],[672,216],[720,216],[720,232],[800,232],
        [800,248],[788,248],east[:2]])
    upper_mask=path_cells(upper['points'],8)
    asset('B_UpperThroughHome','U03_BridgeApartment',(736,232,36),-90)
    upper_room=footprint((736,232,36),-90,16,24)
    upper_mask |= upper_room
    occupied=rect_cells(416,64,840,368)-walk
    pockets=set();fronts=[]
    for dx,dz,fixed,lo,hi in edges(walk):
        if hi-lo<22:continue
        for along in range(lo+11,hi-9,28):
            pos=[fixed,along,0] if dx else [along,fixed,0]
            if pos[1]>360:continue
            angle={(0,1):0,(0,-1):180,(1,0):-90,(-1,0):90}[dx,dz]
            key=['F06_ServiceEntry','F05_ResidentialEntry','F02_RecessedShop','F03_ShutteredStore','F09_PatchedBlank'][len(fronts)%5]
            data=assets[key];depth=max(data['depth'],8)
            cells=footprint(pos,angle,data['width'],depth,0,1)
            body=footprint(world([0,1,0],pos,angle),angle,data['width'],depth,0,1)
            if len(body&occupied)<len(body)*.94 or cells&(room_clear|stair_clear|pockets):continue
            if footprint(world([0,2,0],pos,angle),angle,data['width'],max(data['depth']-2,1))&walk:continue
            label='B_Front_%03d'%len(fronts)
            asset(label,key,pos,angle);fronts.append(dict(id=label,asset=key,origin=pos,angle=angle));pockets |= cells
            if key in ('F06_ServiceEntry','F05_ResidentialEntry','F02_RecessedShop'):
                c,s=box_world([0,data['depth']+.2,6.5],[data['width'],.4,13],pos,angle)
                part(label+'_RearWall',c,s,'RepairPlaster')
                walk |= footprint(pos,angle,data['width'],data['depth'])
            for h in (18,36,54):
                if footprint(pos,angle,12,2,0,1)&(stair_clear|upper_mask):continue
                asset(label+'_Windows%d'%h,'U01_ApartmentWindowBay',world([0,0,h],pos,angle),angle)
    occupied -= pockets
    # Real route-shaped building volumes, with visible structural masonry repairs.
    for layer,(bottom,top) in enumerate(((0,18),(18,36),(36,54),(54,72),(72,90))):
        cells=occupied-stair_clear
        if bottom<54 and top>35:cells-=upper_mask
        for i,(x0,z0,x1,z1) in enumerate(merged(cells)):
            if layer==4 and (x0//24+z0//24)%3:continue
            part(f'B_Building_{layer}_{i}',[(x0+x1)/2,(z0+z1)/2,(bottom+top)/2],
                 [x1-x0,z1-z0,top-bottom],'Masonry' if (x0//12+z0//12)%3==0 else 'RepairPlaster')
    for i,(x0,z0,x1,z1) in enumerate(merged(room_clear-stair_clear-upper_mask)):
        part('B_RoomUpperMass_%d'%i,[(x0+x1)/2,(z0+z1)/2,45],[x1-x0,z1-z0,54],'RepairPlaster')
    for i,(x0,z0,x1,z1) in enumerate(merged(walk)):
        part('B_GroundDeck_%d'%i,[(x0+x1)/2,(z0+z1)/2,-.3],[x1-x0,z1-z0,.6],'CutStone')
        part('B_GroundSupport_%d'%i,[(x0+x1)/2,(z0+z1)/2,-.8],[x1-x0+.8,z1-z0+.8,1],visible=False)
    cover=walk-room_clear-stair_clear-pockets
    # Stop lane ceilings at the street; no low canopy across the main inspection road.
    cover={(x,z) for x,z in cover if z<368}
    for i,(x0,z0,x1,z1) in enumerate(merged(cover)):
        part('B_LaneCeiling_%d'%i,[(x0+x1)/2,(z0+z1)/2,13.55],[x1-x0+.3,z1-z0+.3,.6],'Masonry')
    for i,(x0,z0,x1,z1) in enumerate(merged(upper_mask)):
        part('B_UpperDeck_%d'%i,[(x0+x1)/2,(z0+z1)/2,35.7],[x1-x0,z1-z0,.6],'CutStone')
        part('B_UpperSupport_%d'%i,[(x0+x1)/2,(z0+z1)/2,35.2],[x1-x0+.6,z1-z0+.6,1],visible=False)
        if (x0,z0) not in upper_room:
            part('B_UpperCeiling_%d'%i,[(x0+x1)/2,(z0+z1)/2,49.55],[x1-x0+.3,z1-z0+.3,.6],'Masonry')
    holes=rect_cells(592,283,600,285)|rect_cells(784,259,792,261)
    for i,(dx,dz,fixed,lo,hi) in enumerate(edges(upper_mask,holes)):
        mid=(lo+hi)/2;point=(fixed,mid) if dx else (mid,fixed)
        if (math.floor(point[0]),math.floor(point[1])) in upper_room:continue
        part('B_GalleryGuard_%d'%i,[fixed,mid,37.7] if dx else [mid,fixed,37.7],
             [.5,hi-lo,3.4] if dx else [hi-lo,.5,3.4],'Masonry')
    for x,z,h in (west,east):part('B_StairTopDeck',[x,z,h-.3],[12,8,.6],'CutStone')
    # Upper occupation and ancient structure remain attached to solid building masses.
    part('B_AncientOverheadRib',[452,212,143],[20,304,74],'Masonry')
    for x,z in ((464,92),(736,80),(800,120)):
        part('B_BackgroundBearing',[x,z,94],[52,28,8],'Masonry')
        part('B_BackgroundHousing',[x,z,112],[48,24,28],'RepairPlaster')
        for offset in (-14,0,14):asset(f'B_Background_{x}_{offset}','U01_ApartmentWindowBay',(x+offset,z+12,98),180)
    lamps=[]
    for r in routes:
        for a,b in zip(r['points'],r['points'][1:]):
            x,z=(a[0]+b[0])/2,(a[1]+b[1])/2
            if (math.floor(x),math.floor(z)) not in cover:continue
            if any(math.dist((x,z),v[:2])<22 for v in lamps):continue
            lamps.append([x,z,12.95])
    for a,b in zip(upper['points'],upper['points'][1:]):lamps.append([(a[0]+b[0])/2,(a[1]+b[1])/2,48.9])
    for i,c in enumerate(lamps):part('B_Lamp_%03d'%i,c,[.6,.6,.3],'Zinc',False)
    for label,origin,angle in [('West',(512,360,0),180),('Workshop',(528,280,0),-90),
        ('NorthHome',(504,160,0),180),('East',(752,360,0),180),('Service',(704,312,0),180),
        ('NorthService',(652,136,0),-90),('Cross',(568,224,0),-90)]:
        # Split-room cores occupy the center; mount the light over the side aisle.
        offset=6 if label in ('West','Workshop','Service','Cross') else 0
        part('B_RoomLamp_'+label,world([offset,10,13],origin,angle),[.6,.6,.5],'Zinc',False)
    return dict(routes=routes,upper=upper,rooms=rooms,frontages=fronts,
                bounds=[416,64,840,368],connections=CONNECTIONS)
