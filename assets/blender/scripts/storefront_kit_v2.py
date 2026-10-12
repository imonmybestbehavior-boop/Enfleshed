"""Enfleshed Storefront Kit V2. Blender 5.2; run in a NEW file.
CLI: flatpak run org.blender.Blender --background --python SCRIPT -- --output-dir DIRECTORY
Only the current scene is rebuilt. Never opens or overwrites V1.
"""
import bpy, math, argparse, sys, json
from pathlib import Path
from mathutils import Vector
p=argparse.ArgumentParser()
p.add_argument('--output-dir', default=str(Path.home()/'Projects/Enfleshed/assets/blender/generated/storefront_v2'))
p.add_argument('--render', action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
out=Path(a.output_dir); out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.users==0 or c.name=='Collection': bpy.data.collections.remove(c)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=1800; scene.render.resolution_y=720; scene.render.resolution_percentage=100
scene.world.color=(.22,.22,.22)
scene.view_settings.view_transform='AgX'
M={}
def mat(n,c,metal=0):
    m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*c,1); bs.inputs['Roughness'].default_value=.78; bs.inputs['Metallic'].default_value=metal
    M[n]=m
for n,c in {'stone':(.29,.265,.22),'plaster':(.49,.44,.34),'wood':(.18,.095,.045),'edge':(.32,.20,.10),'iron':(.065,.075,.07),'rust':(.24,.10,.04),'red':(.30,.065,.045),'green':(.10,.20,.15),'cloth':(.57,.44,.26),'cream':(.76,.66,.46),'jar':(.30,.22,.12),'glass':(.09,.23,.20)}.items(): mat(n,c,.6 if n=='iron' else 0)
# Subtle material grain, no external image dependencies.
for n in ['stone','plaster','wood']:
    m=M[n]; nt=m.node_tree; noise=nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=15 if n!='wood' else 7
    bump=nt.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.23; bump.inputs['Distance'].default_value=.04
    nt.links.new(noise.outputs['Fac'],bump.inputs['Height']); nt.links.new(bump.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
coll=None; ox=0; root=None
def register(ob,n,ma):
    ob.name=n
    for c in list(ob.users_collection): c.objects.unlink(ob)
    coll.objects.link(ob)
    ob.data.materials.append(M[ma])
    if root: ob.parent=root
    return ob
def box(n,pos,size,ma='wood',bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0]+ox,pos[1],pos[2])); ob=register(bpy.context.object,n,ma); ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=ob.modifiers.new('Worn edges','BEVEL'); b.width=bevel;b.segments=2
    return ob
def cyl(n,pos,r,depth,ma='iron',rot=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=depth,location=(pos[0]+ox,pos[1],pos[2]));ob=register(bpy.context.object,n,ma)
    if rot: ob.rotation_euler=rot
    return ob
def text(body,pos,size=.18,ma='cream'):
    bpy.ops.object.text_add(location=(pos[0]+ox,pos[1],pos[2]),rotation=(math.pi/2,0,0));ob=register(bpy.context.object,'Lettering '+body,ma);ob.data.body=body;ob.data.align_x='CENTER';ob.data.size=size;ob.data.extrude=.002
    return ob
def beam(n,a,b,r=.025,ma='iron'):
    mid=(Vector(a)+Vector(b))/2; ob=cyl(n,mid,r,(Vector(b)-Vector(a)).length,ma); ob.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler(); return ob
def shelf(x,y,w=1.5):
    for z in [.6,1.2,1.8]:
        box('Shelf plank',(x,y,z),(w,.42,.075),'edge')
        for i in range(5):
            xx=x-w*.38+i*w*.19
            cyl('Storage jar',(xx,y,z+.17),.095,.26,'jar');cyl('Jar lid',(xx,y,z+.31),.10,.025,'wood')
    for xx in [x-w/2,x+w/2]:box('Shelf upright',(xx,y,1.1),(.07,.45,2.1),'wood')
def table(x,y,w=1.6):
    box('Worktop',(x,y,.91),(w,.72,.10),'edge')
    for xx in [x-w/2+.1,x+w/2-.1]:
        for yy in [y-.25,y+.25]:box('Table leg',(xx,yy,.44),(.10,.10,.88))
def sign(s,ma):
    box('Signboard',(0,-.23,2.85),(3.38,.16,.45),ma);text(s,(0,-.325,2.77),.22)
def awning(ma):
    # Proper outward projection, shallow slope and hanging scalloped valance.
    for i in range(10):
        x=-1.62+i*.36
        ob=box('Canvas canopy',(x,-.62,2.53),(.355,1.24,.04),ma if i%2==0 else 'cloth');ob.rotation_euler.x=.14
        box('Canvas valance',(x,-1.22,2.35),(.355,.04,.22),ma if i%2==0 else 'cloth')
    for x in [-1.7,1.7]: beam('Canopy bracket',(x,-.05,1.95),(x,-1.22,2.42))
def shell(name,x,through=False):
    global coll,ox,root
    ox=x;coll=bpy.data.collections.new(name);scene.collection.children.link(coll)
    root=bpy.data.objects.new(name+'_ROOT',None);coll.objects.link(root);root.location=(0,0,0)
    root['front_plane']='Y=0; street is -Y';root['width_m']=4;root['depth_m']=3.4;root['door_clearance_m']=1.05
    box('Stone floor',(0,1.65,-.10),(4,3.6,.20),'stone')
    for xx in [-1.88,1.88]:box('Side masonry',(xx,1.65,1.65),(.24,3.5,3.3),'plaster')
    if through:
        for xx in [-1.30,1.30]:box('Rear passage jamb',(xx,3.3,1.65),(1.15,.22,3.3),'plaster')
        box('Rear passage lintel',(0,3.3,2.85),(1.5,.22,.9),'plaster')
    else:box('Back wall',(0,3.3,1.65),(4,.22,3.3),'plaster')
    for xx in [-1.75,1.75]:
        for z in range(8):box('Old structural block',(xx,-.02,z*.40+.2),(.48,.50,.38),'stone')
    box('Old lintel',(0,0,3.13),(4,.55,.34),'stone')
    box('Ceiling',(0,1.6,3.4),(4,3.65,.20),'wood')
    for xx in [-1.4,0,1.4]:box('Ceiling beam',(xx,1.6,3.23),(.16,3.4,.20),'wood')
    # Later utility additions are attached to the masonry, not floating decor.
    beam('Retrofit drain',(1.96,-.30,.1),(1.96,-.30,3.4),.045)
    for z in [.5,1.8,3]:box('Pipe strap',(1.96,-.29,z),(.17,.13,.04),'iron')
    box('Repaired plinth',(-1.75,-.29,.4),(.47,.09,.65),'plaster')
    for z in [.16,.38,.60]:box('Exposed brick repair',(-1.74,-.35,z),(.40,.08,.16),'rust')
    box('Threshold',(0,-.19,.025),(3.1,.46,.05),'stone')
def door(x):
    for xx in [x-.57,x+.57]:box('Door jamb',(xx,.24,1.15),(.09,.17,2.3),'wood')
    box('Door header',(x,.24,2.32),(1.23,.17,.12),'wood')
    # Leaf open inward, leaving a 1.05m passage.
    box('Open door leaf',(x+.50,.80,1.08),(.08,1.05,2.15),'green')
    cyl('Door handle',(x+.43,.47,1.02),.035,.06,'iron',(0,math.pi/2,0))
def window(x,w=1.8):
    box('Window apron',(x,.05,.50),(w,.20,1),'wood')
    for xx in [x-w/2,x+w/2]:box('Window stile',(xx,.03,1.58),(.09,.22,1.2),'edge')
    for z in [1,2.2]:box('Window rail',(x,-.02,z),(w+.12,.28,.10),'edge')
    for i in range(5):box('Window security bar',(x-w*.40+i*w*.2,.02,1.60),(.025,.04,1.13),'iron')
    for xx in [x-w/2-.17,x+w/2+.17]:box('Folded shutter',(xx,.08,1.60),(.24,.14,1.18),'green')

names=['01 Hearth food counter','02 Ration and dry goods','03 Tool repair workshop','04 Lower dispensary','05 Cloth and mending','06 Residential through passage']
for i,n in enumerate(names):
    shell(n,(i-2.5)*4.35,i==5)
    if i==0:
        sign('HEARTH / HOT BROTH','red');awning('red');door(1.04)
        box('Serving counter',(-.61,.12,.95),(1.92,.75,.13),'edge')
        for j in range(8):box('Counter boards',(-1.46+j*.24,.0,.46),(.22,.12,.92),'wood')
        shelf(-.3,2.9,2.5);table(-.6,1.9,1.8)
        for x in [-1,-.25]:
            cyl('Cooking pot',(x,1.9,1.15),.24,.38,'iron');cyl('Pot lid',(x,1.9,1.36),.26,.03,'iron')
        for x in [-1.25,-.7,-.15]:cyl('Serving bowl',(x,-.05,1.07),.13,.12,'cream')
        box('Menu board',(-1.1,.04,1.8),(.70,.1,.85),'iron');text('BROTH\nBREAD\n2 SCRIP',(-1.1,-.02,2.02),.105)
    elif i==1:
        sign('DAILY RATIONS','green');door(1.05);window(-.63,1.75);shelf(-.6,2.9,2.2);table(-.65,1.85)
        for j in range(3):
            box('Display grain bin',(-1.22+j*.56,.6,1.11),(.49,.55,.27),'edge')
            for k in range(4):cyl('Loaf',(-1.37+j*.56+k*.09,.53,1.28),.065,.10,'cloth')
        box('Weighing scale foot',(-.8,1.85,1.03),(.42,.30,.10),'iron');beam('Scale upright',(-.8,1.85,1.05),(-.8,1.85,1.5));beam('Balance',(-1.15,1.85,1.5),(-.45,1.85,1.5))
    elif i==2:
        sign('TOOLS / REPAIR','iron');table(-.60,2.3,2.1)
        box('Tool board',(-.5,3.13,1.9),(2.35,.07,1.15),'wood')
        for j in range(6):
            xx=-1.42+j*.35;box('Hanging tool handle',(xx,3.02,1.88),(.055,.07,.48),'edge');box('Hammer head',(xx,3.01,2.12),(.22,.12,.11),'iron')
        box('Bench vise',(-.4,2.1,1.09),(.32,.26,.26),'iron')
        for xx in [-1.45,1.45]:
            for j in range(5):box('Folded workshop shutter',(xx,.2+j*.12,1.24),(.27,.10,2.45),'wood')
        for z in [.55,1.2,1.85]:cyl('Spare wheel',(1.5,2.65,z),.27,.12,'iron',(math.pi/2,0,0))
        box('Repair chest',(-1.1,.65,.34),(.95,.75,.68),'green')
    elif i==3:
        sign('LOWER DISPENSARY','green');door(-1.05);window(.65,1.72);shelf(.65,2.9,1.7);table(.65,1.8,1.4)
        box('Treatment cot',(-.7,2.1,.62),(.72,1.45,.20),'cream')
        for yy in [1.5,2.7]:box('Cot leg',(-.7,yy,.3),(.65,.09,.6),'iron')
        for x in [.25,.60,1.0]:cyl('Medicine bottle',(x,.50,1.19),.075,.30,'glass');cyl('Bottle stopper',(x,.50,1.37),.045,.06,'wood')
        box('Service emblem',(.65,-.18,1.7),(.42,.06,.09),'cream');box('Service emblem',(.65,-.18,1.7),(.09,.06,.42),'cream')
    elif i==4:
        sign('CLOTH / MENDING','red');awning('green');door(1.05);window(-.65,1.72);table(-.6,2,1.8)
        beam('Cloth hanging rail',(-1.5,2.8,2.4),(.6,2.8,2.4))
        for j in range(7):box('Hanging folded cloth',(-1.35+j*.28,2.78,1.67),(.24,.08,1.4),['cloth','red','green'][j%3])
        for j in range(4):cyl('Fabric bolt',(-1.25+j*.37,.55,1.22),.14,.65,['cloth','red','green'][j%3],(math.pi/2,0,0))
        for j in range(3):box('Folded fabric',(-.6,2,1.02+j*.07),(.8,.50,.055),'cloth')
    else:
        sign('COURT 17 / ROOMS','wood')
        for xx in [-1.1,1.1]:box('Passage subdivision',(xx,1.7,1.25),(.13,2.8,2.5),'plaster')
        door(0)
        # Right leaf lies against side wall; passage leads to an actual rear exit.
        for j in range(4):box('Resident mail cubby',(-1.48,.26,.65+j*.30),(.44,.35,.24),'wood')
        for j in range(11):
            box('Side stair tread',(1.48,.55+j*.23,.10+j*.20),(.59,.25,.12),'wood')
        beam('Stair handrail',(1.13,.4,1),(1.13,2.95,3.1),.035,'wood')
        text('COURTYARD',(0,3.15,2.59),.13)
    # Fixture with readable bracket and warm source.
    box('Lamp bracket',(-1.45,-.48,2.57),(.07,.6,.07),'iron')
    box('Lamp housing',(-1.45,-.7,2.34),(.21,.20,.30),'iron')
    box('Lamp pane',(-1.45,-.81,2.34),(.15,.02,.21),'cream')
    ld=bpy.data.lights.new('Warm shop light','AREA');ld.energy=65;ld.color=(1,.72,.43);ld.shape='DISK';ld.size=1.6
    lo=bpy.data.objects.new('Warm shop light',ld);coll.objects.link(lo);lo.location=(ox,1.5,2.95)
    root['archetype']=n
    for part in coll.objects:
        if part != root:
            part.parent=root
            part.location.x-=ox
    root.location.x=ox
    coll.instance_offset=(ox,0,0)
    coll.asset_mark()

def refine_functional_props():
    """Small functional shapes that distinguish tools, chests and serving bowls."""
    def part(c,n,loc,size,material):
        bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        for old in list(o.users_collection):old.objects.unlink(o)
        c.objects.link(o);o.data.materials.append(bpy.data.materials[material])
        b=o.modifiers.new('Edge rounding','BEVEL');b.width=.008;b.segments=2
        root=next(ob for ob in c.objects if ob.type=='EMPTY');o.parent=root;o.location.x-=root.location.x
        return o
    c=bpy.data.collections['03 Tool repair workshop'];x=-2.175
    for xx in [x-.49,x-.30]:part(c,'Vise jaw',(xx,2.1,1.24),(.07,.30,.15),'iron')
    part(c,'Vise screw',(x-.39,1.90,1.12),(.04,.30,.04),'iron')
    part(c,'Vise turning handle',(x-.39,1.74,1.12),(.04,.035,.27),'edge')
    part(c,'Chest lid',(x-1.1,.65,.70),(.99,.79,.09),'wood')
    for xx in [x-1.4,x-.8]:
        part(c,'Chest iron strap',(xx,.263,.34),(.065,.018,.66),'iron')
        part(c,'Chest lid strap',(xx,.65,.751),(.065,.76,.016),'iron')
    part(c,'Chest latch',(x-1.1,.241,.55),(.13,.045,.19),'iron')
    for z in [.55,1.2,1.85]:
        for ob in list(c.objects):
            if ob.name.startswith('Spare wheel') and abs(ob.location.z-z)<.01:bpy.data.objects.remove(ob,do_unlink=True)
        bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,location=(x+1.5,2.65,z),major_radius=.235,minor_radius=.035,rotation=(math.pi/2,0,0))
        o=bpy.context.object;o.name='Wheel rim'
        for old in list(o.users_collection):old.objects.unlink(o)
        c.objects.link(o);o.data.materials.append(bpy.data.materials['iron']);o.parent=next(ob for ob in c.objects if ob.type=='EMPTY');o.location.x-=o.parent.location.x
        part(c,'Wheel spoke',(x+1.5,2.65,z),(.46,.06,.035),'edge');part(c,'Wheel spoke',(x+1.5,2.65,z),(.035,.06,.46),'edge')
    c=bpy.data.collections['01 Hearth food counter'];x=-10.875
    for xx in [-1.25,-.7,-.15]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.108,depth=.008,location=(x+xx,-.05,1.131))
        o=bpy.context.object;o.name='Visible broth inside bowl'
        for old in list(o.users_collection):old.objects.unlink(o)
        c.objects.link(o);o.data.materials.append(bpy.data.materials['jar']);o.parent=next(ob for ob in c.objects if ob.type=='EMPTY');o.location.x-=o.parent.location.x
refine_functional_props()

root=None;ox=0;coll=bpy.data.collections.new('00 REVIEW ONLY - ground lights cameras');scene.collection.children.link(coll)
box('Review street',(0,-1.5,-.23),(28,11,.26),'stone')
for j in range(36):box('Drain cover',(-13.2+j*.75,-1.7,-.085),(.67,.20,.04),'iron')
def camera(n,loc,target,lens=48):
    d=bpy.data.cameras.new(n);ob=bpy.data.objects.new(n,d);coll.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;return ob
cam=camera('00 Overview',(15,-29,13),(0,1,1.2),42);scene.camera=cam
for i,n in enumerate(names):camera(n+' CAMERA',((i-2.5)*4.35+.5,-7.7,2.95),((i-2.5)*4.35,1.1,1.5),42)
for n,loc,power,size in [('Key',(-8,-9,12),2400,10),('Fill',(12,-4,8),1800,9)]:
    d=bpy.data.lights.new(n,'AREA');d.energy=power;d.shape='DISK';d.size=size;ob=bpy.data.objects.new(n,d);coll.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,1,0))-ob.location).to_track_quat('-Z','Y').to_euler()
# Neutral sun keeps the shaded thresholds readable.
d=bpy.data.lights.new('Ambient daylight','SUN');d.energy=1.4;d.angle=.4;ob=bpy.data.objects.new('Ambient daylight',d);coll.objects.link(ob);ob.rotation_euler=(.4,-.5,-.3)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
scene['README']='Six collection assets. Metric scale. Front -Y. Review-only scene; see STOREFRONT_KIT_V2.md. V1 untouched.'
# Embedded directions travel with the blend.
t=bpy.data.texts.new('START HERE');t.write('STOREFRONT KIT V2\nSix recognizable Lower Layer fronts.\nNumpad 0: overview. Mouse wheel: zoom. Middle mouse: orbit.\nSelect a shop in the Outliner and use numpad period to frame.\nCameras: Overview plus one per shop.\nMetric: 4m frontage, 3.4m interior, ~2.2m door height.\nCollection assets include lights; remove lights before game export.\nThis is an art review kit, not integrated into Roblox.\n')
scene.render.filepath=str(out/'storefront_v2_overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out/'storefront_kit_v2.blend'))
if a.render:
    bpy.ops.render.render(write_still=True)
    scene.render.resolution_x=1000;scene.render.resolution_y=900
    for i,n in enumerate(names):
        scene.camera=bpy.data.objects[n+' CAMERA'];scene.render.filepath=str(out/f'{i+1:02d}_detail.png');bpy.ops.render.render(write_still=True)
report={'blender':bpy.app.version_string,'archetypes':names,'mesh_objects':sum(o.type=='MESH' for o in scene.objects),'unit':'meters','v1_modified':False}
(out/'validation.json').write_text(json.dumps(report,indent=2))
print('V2 COMPLETE',report)
