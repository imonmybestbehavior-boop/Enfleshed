"""Bounded neighborhood C assembly; uses the existing kit, never rewrites E/F."""
import copy
import math


def build_courtyard(*, part, asset, tower, footprint, path_cells, rect_cells,
                    merged, edges, world, box_world, plan, assets, connections=()):
    # Seal the narrow seam between the C envelope and the existing street end.
    part('C_StreetEndClosure',[1222,366,36],[12,4,72],'Masonry')
    routes = copy.deepcopy([r for r in plan['ground_routes'] if r['id'].startswith('C')])
    routes += [dict(id='C_WestStairApproach', width=8, points=[[928,312],[904,312]]),
               dict(id='C_EastStairApproach', width=8, points=[[1152,296],[1184,296]])]
    court = rect_cells(*plan['courtyard']['rect'])
    walk = set(court)
    for r in routes:
        walk |= path_cells(r['points'], r['width'])
    rooms = []
    room_clear = set()
    for label, key, origin, angle in [
        ('C_WestThreshold', 'I05_SplitRoom', (928,344,0),180),
        ('C_CourtApproach', 'U03_BridgeApartment',(1000,256,0),180),
        ('C_EastThreshold','U03_BridgeApartment',(1152,360,0),180),
        ('C_ServiceCrossing','I05_SplitRoom',(1056,280,0),-90),
        ('C_NorthTenement','U03_BridgeApartment',(952,104,0),90),
    ]:
        asset(label,key,origin,angle)
        cells=footprint(origin,angle,assets[key]['width'],assets[key]['depth'])
        room_clear |= cells;walk |= cells;rooms.append(label)
        if key=='I05_SplitRoom':
            side=world([12,12,0],origin,angle)
            asset(label+'_SideRoom','I13_ServiceAlcove',side,angle-90)
            cells=footprint(side,angle-90,12,12)
            room_clear |= cells;walk |= cells
    # Stair footprints sit beside the approaches, not across mandatory ground paths.
    west=tower('C_WestStairs',(904,312,0),180,1)
    east=tower('C_EastStairs',(1184,296,0),0,1)
    stair_clear=footprint((898,312,0),180,24,44,-4,1)
    stair_clear |= footprint((1190,296,0),0,24,44,-4,1)
    walk |= stair_clear
    upper=dict(id='C_CourtyardGallery',height=18,points=[west[:2],[892,320],[944,320],
        [944,240],[980,240],[980,216],[1080,216],[1080,280],[1168,280],
        [1168,288],[1196,288],east[:2]])
    upper_mask=path_cells(upper['points'],8)
    # Habitable bridge spans the southern courtyard rim; portals stay on the loop.
    asset('C_UpperThroughHome','U03_BridgeApartment',(1000,216,18),-90)
    upper_room=footprint((1000,216,18),-90,16,24)
    upper_mask |= upper_room
    connection_walk=set()
    for r in connections:
        connection_walk |= {(x,z) for x,z in path_cells(r['points'],r['width']) if x>=840}
    # Preserve the established frontage sequence outside the two connection cuts.
    occupied=rect_cells(840,64,1216,368)-walk
    pockets=set();fronts=[];front_serial=0;omitted_pockets=set()
    for dx,dz,fixed,lo,hi in edges(walk):
        if hi-lo<22:continue
        for along in range(lo+11,hi-9,28):
            pos=[fixed,along,0] if dx else [along,fixed,0]
            if pos[1]>360:continue
            angle={(0,1):0,(0,-1):180,(1,0):-90,(-1,0):90}[dx,dz]
            key=['F03_ShutteredStore','F09_PatchedBlank','F06_ServiceEntry','F04_BarredStore','F05_ResidentialEntry'][front_serial%5]
            data=assets[key];depth=max(data['depth'],8)
            cells=footprint(pos,angle,data['width'],depth,0,1)
            body=footprint(world([0,1,0],pos,angle),angle,data['width'],depth,0,1)
            if len(body&occupied)<len(body)*.94 or cells&(room_clear|stair_clear|pockets):continue
            if footprint(world([0,2,0],pos,angle),angle,data['width'],max(data['depth']-2,1))&walk:continue
            label='C_Front_%03d'%front_serial
            front_serial+=1
            if cells & (connection_walk-walk):
                pockets |= cells
                omitted_pockets |= cells
                continue
            asset(label,key,pos,angle);fronts.append(dict(id=label,asset=key,origin=pos,angle=angle));pockets |= cells
            if key in ('F06_ServiceEntry','F05_ResidentialEntry'):
                c,s=box_world([0,data['depth']+.2,6.5],[data['width'],.4,13],pos,angle)
                part(label+'_RearWall',c,s,'Masonry')
                walk |= footprint(pos,angle,data['width'],data['depth'])
            for h in (18,36,54):
                if footprint(pos,angle,12,2,0,1)&(stair_clear|upper_mask):continue
                asset(label+'_Windows%d'%h,'U01_ApartmentWindowBay',world([0,0,h],pos,angle),angle)
    walk |= connection_walk
    occupied -= pockets | connection_walk
    occupied |= omitted_pockets - walk
    # Real route-shaped building volumes, with visible structural masonry repairs.
    for layer,(bottom,top) in enumerate(((0,18),(18,36),(36,54),(54,72),(72,90))):
        cells=occupied-stair_clear
        if bottom<36 and top>17:cells-=upper_mask
        for i,(x0,z0,x1,z1) in enumerate(merged(cells)):
            if layer==4 and (x0//24+z0//24)%3:continue
            part(f'C_Building_{layer}_{i}',[(x0+x1)/2,(z0+z1)/2,(bottom+top)/2],
                 [x1-x0,z1-z0,top-bottom],'Masonry' if (x0//12+z0//12)%3==0 else 'RepairPlaster')
    for i,(x0,z0,x1,z1) in enumerate(merged(room_clear-stair_clear-upper_mask)):
        part('C_RoomUpperMass_%d'%i,[(x0+x1)/2,(z0+z1)/2,45],[x1-x0,z1-z0,54],'RepairPlaster')
    for i,(x0,z0,x1,z1) in enumerate(merged(walk)):
        part('C_GroundDeck_%d'%i,[(x0+x1)/2,(z0+z1)/2,-.3],[x1-x0,z1-z0,.6],'CutStone')
        part('C_GroundSupport_%d'%i,[(x0+x1)/2,(z0+z1)/2,-.8],[x1-x0+.8,z1-z0+.8,1],visible=False)
    cover=walk-room_clear-stair_clear-(pockets-omitted_pockets)-court
    # Stop lane ceilings at the street; no low canopy across the main inspection road.
    cover={(x,z) for x,z in cover if z<368}
    for i,(x0,z0,x1,z1) in enumerate(merged(cover)):
        part('C_LaneCeiling_%d'%i,[(x0+x1)/2,(z0+z1)/2,13.55],[x1-x0+.3,z1-z0+.3,.6],'Masonry')
    for i,(x0,z0,x1,z1) in enumerate(merged(upper_mask)):
        part('C_UpperDeck_%d'%i,[(x0+x1)/2,(z0+z1)/2,17.7],[x1-x0,z1-z0,.6],'CutStone')
        part('C_UpperSupport_%d'%i,[(x0+x1)/2,(z0+z1)/2,17.2],[x1-x0+.6,z1-z0+.6,1],visible=False)
        if (x0,z0) not in upper_room:
            part('C_UpperCeiling_%d'%i,[(x0+x1)/2,(z0+z1)/2,31.55],[x1-x0+.3,z1-z0+.3,.6],'Masonry')
    holes=rect_cells(888,307,896,309)|rect_cells(1192,299,1200,301)
    for i,(dx,dz,fixed,lo,hi) in enumerate(edges(upper_mask,holes)):
        mid=(lo+hi)/2;point=(fixed,mid) if dx else (mid,fixed)
        if (math.floor(point[0]),math.floor(point[1])) in upper_room:continue
        part('C_GalleryGuard_%d'%i,[fixed,mid,19.7] if dx else [mid,fixed,19.7],
             [.5,hi-lo,3.4] if dx else [hi-lo,.5,3.4],'Masonry')
    for x,z,h in (west,east):part('C_StairTopDeck',[x,z,h-.3],[12,8,.6],'CutStone')
    # Tall courtyard faces, recessed windows, and broad supported lintels create enclosure.
    # The court remains open only to the ancient interior, never to outdoor sky.
    for x in (972,1048):
        # Upper masonry piers bear on the existing ground-storey header,
        # leaving the recessed tenant door depth clear below.
        part('C_CourtUpperPier',[x,122,51],[5,8,66],'Masonry')
    part('C_CourtOverheadSpan',[1012,122,85],[112,12,6],'Masonry')
    part('C_AncientOverheadRib',[1132,200,143],[20,320,74],'Masonry')
    for x,z in ((880,100),(1180,160),(1032,80)):
        part('C_BackgroundBearing',[x,z,94],[52,28,8],'Masonry')
        part('C_BackgroundHousing',[x,z,112],[48,24,28],'RepairPlaster')
        for offset in (-14,0,14):asset(f'C_Background_{x}_{offset}','U01_ApartmentWindowBay',(x+offset,z+12,98),180)
    lamps=[]
    for r in routes+list(connections):
        for a,b in zip(r['points'],r['points'][1:]):
            x,z=(a[0]+b[0])/2,(a[1]+b[1])/2
            if (math.floor(x),math.floor(z)) not in cover:continue
            if any(math.dist((x,z),v[:2])<22 for v in lamps):continue
            lamps.append([x,z,12.95])
    for a,b in zip(upper['points'],upper['points'][1:]):lamps.append([(a[0]+b[0])/2,(a[1]+b[1])/2,30.9])
    for x,z in ((956.4,152),(956.4,200),(1067.6,152),(1067.6,200),(984,128.4),(1040,223.6)):
        lamps.append([x,z,10])
    for i,c in enumerate(lamps):part('C_Lamp_%03d'%i,c,[.6,.6,.3],'Zinc',False)
    # Ceiling fixtures inside kit rooms, mounted below their actual ceilings.
    for label,key,origin,angle in [('West','I05',(928,344,0),180),('South','U03',(1000,256,0),180),
        ('East','U03',(1152,360,0),180),('Cross','I05',(1056,280,0),-90),('North','U03',(952,104,0),90)]:
        part('C_RoomLamp_'+label,world([0,10,12.8],origin,angle),[.6,.6,.3],'Zinc',False)
    return dict(routes=routes,upper=upper,rooms=rooms,frontages=fronts,
                bounds=[840,64,1216,368],courtyard=plan['courtyard']['rect'])
