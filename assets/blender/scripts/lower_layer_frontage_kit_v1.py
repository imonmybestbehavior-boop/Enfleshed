"""Lower Layer frontage kit: deterministic, stud-authored modular mesh library.
Blender 5.2: --background --python this_file.py -- --render
Never reads or changes the generated city or earlier asset libraries.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument('--output-dir', type=Path, default=ROOT/'assets/blender/generated/lower_layer_frontage_kit_v1')
parser.add_argument('--render', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = args.output_dir
OUT.mkdir(parents=True, exist_ok=True)
(OUT/'exports').mkdir(exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'
scene.unit_settings.scale_length = 1
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.image_settings.file_format = 'PNG'
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('ReviewWorld')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.12,.15,.19,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .45
scene.view_settings.view_transform = 'AgX'

PALETTE = {
    'Plaster': ((.32,.285,.23), .94, 0),
    'RepairPlaster': ((.43,.39,.32), .98, 0),
    'Masonry': ((.21,.205,.185), .91, 0),
    'CutStone': ((.37,.365,.32), .86, 0),
    'Brick': ((.30,.185,.12), .94, 0),
    'Mortar': ((.25,.245,.215), 1, 0),
    'Timber': ((.145,.105,.068), .85, 0),
    'PaintedTimber': ((.105,.18,.16), .83, 0),
    'Iron': ((.07,.085,.085), .67, .65),
    'Oxide': ((.24,.135,.075), .85, .35),
    'Zinc': ((.27,.29,.275), .62, .6),
    'Glass': ((.11,.185,.17), .24, .12),
    'Canvas': ((.33,.25,.14), .97, 0),
}
MATS = {}
for name,(color,rough,metal) in PALETTE.items():
    m = bpy.data.materials.new('LL_'+name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    m.diffuse_color = (*color,1)
    MATS[name] = m

LIB = bpy.data.collections.new('LOWER_LAYER_FRONTAGE_KIT_V1')
scene.collection.children.link(LIB)
REVIEW = bpy.data.collections.new('00_REVIEW_ONLY_DO_NOT_EXPORT')
scene.collection.children.link(REVIEW)
ASSETS = []
CURRENT = None


def new_asset(name, kind, width, depth=2, use='', openings=None):
    global CURRENT
    coll = bpy.data.collections.new(name)
    LIB.children.link(coll)
    root = bpy.data.objects.new(name+'_ROOT', None)
    coll.objects.link(root)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 1
    CURRENT = {'name':name,'kind':kind,'width':width,'depth':depth,'height':18 if kind=='frontage' else None,
               'use':use,'openings':openings or [],'collection':coll,'root':root,'colliders':[], 'sockets':[], 'objects':[]}
    root['AssetId'] = name
    root['AuthoredUnits'] = 'stud; verify 12-unit calibration on import'
    root['FrontDirection'] = '-Y Blender / +Z glTF'
    root['Pivot'] = 'front centre at finished floor; detail: attachment centre'
    ASSETS.append(CURRENT)
    return CURRENT


def register(obj, label, material):
    a = CURRENT
    obj.name = a['name']+'__'+label
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    a['collection'].objects.link(obj)
    obj.parent = a['root']
    obj.data.materials.append(MATS[material])
    obj['Role'] = 'visual'
    a['objects'].append(obj)
    return obj


def collision(label, loc, size):
    CURRENT['colliders'].append({'name':label,'center':list(loc),'size':list(size)})


def box(label, loc, size, material='Plaster', bevel=.035, solid=False):
    assert min(size)>0, (label,size)
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = register(bpy.context.object,label,material)
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new('ManufacturedEdge','BEVEL')
        mod.width = min(bevel,min(size)*.18)
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if solid:
        collision(label,loc,size)
    return ob


def rod(label, a, b, radius=.08, material='Iron', vertices=8):
    a,b = Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length, location=(a+b)/2)
    ob = register(bpy.context.object,label,material)
    ob.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return ob


def beam(label, a, b, width=.15, material='Iron'):
    a,b=Vector(a),Vector(b)
    ob=box(label,(a+b)/2,(width,width,(b-a).length),material,.015)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    bpy.context.view_layer.objects.active=ob
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    return ob


def socket(name,loc):
    ob=bpy.data.objects.new(CURRENT['name']+'__SOCKET_'+name,None)
    CURRENT['collection'].objects.link(ob)
    ob.parent=CURRENT['root'];ob.location=loc;ob.empty_display_size=.4
    ob['Role']='socket'
    CURRENT['sockets'].append({'name':name,'position':list(loc),'outward':[0,-1,0]})


def wall(label,l,r,bottom,top,y=.6,depth=1.2,mat='Plaster'):
    if r-l>.001 and top-bottom>.001:
        box(label,((l+r)/2,y,(bottom+top)/2),(r-l,depth,top-bottom),mat,.04,True)


def surround(label,x,width,bottom,top,y=0,mat='CutStone',sill=True):
    # Structural reveal projects slightly outward; opening dimensions remain clear.
    for sign in [-1,1]:
        box(label+'_Jamb',(x+sign*(width/2+.18),y,(bottom+top)/2),(.36,.55,top-bottom),mat)
    box(label+'_Lintel',(x,y-.03,top+.24),(width+.8,.75,.48),mat)
    if sill:
        box(label+'_Sill',(x,y-.12,bottom-.15),(width+.85,.95,.3),mat)


def door(label,x,width=5.5,y=.55,height=11,closed=False):
    surround(label,x,width,0,height,y-.30,'CutStone',False)
    # Flush threshold is safe for a character capsule; no raised invisible lip.
    box(label+'_Threshold',(x,y, -.10),(width+.3,1.5,.24),'CutStone',.02)
    if closed:
        box(label+'_Leaf',(x,y+.15,height/2),(width-.1,.22,height-.12),'PaintedTimber',.025,True)
        for z in [2.5,7.3]:
            box(label+'_Panel',(x,y-.015,z),(width-.65,.14,3.6),'Timber')
        rod(label+'_Pull',(x+width*.3,y-.25,4.4),(x+width*.3,y-.25,5.2),.07,'Zinc')
    else:
        # A leaf folded against an inner side wall, outside the portal clearance.
        box(label+'_OpenLeaf',(x+width/2+.28,y+1.2,5.4),(.2,2.5,10.8),'Timber')
        for z in [2,8]:
            box(label+'_Hinge',(x+width/2+.2,y+.12,z),(.14,.28,.35),'Iron')
    box(label+'_TransomFrame',(x,y,12),(width,.26,1.4),'Timber')
    for offset in [-width*.30,0,width*.30]:
        box(label+'_TransomPane',(x+offset,y-.16,12),(width*.27,.06,1.05),'Glass',.006)


def window(label,x,width,bottom=3.2,top=11.5,y=.75,columns=2,bars=False):
    surround(label,x,width,bottom,top,y-.6)
    box(label+'_RevealBack',(x,y+.23,(bottom+top)/2),(width,.18,top-bottom),'Timber',.02)
    for k in range(columns):
        xx=x-width/2+(k+.5)*width/columns
        box(label+'_Glazing',(xx,y,(bottom+top)/2),(width/columns-.24,.07,top-bottom-.35),'Glass',.005)
    for k in range(columns+1):
        box(label+'_Mullion',(x-width/2+k*width/columns,y-.1,(bottom+top)/2),(.16,.24,top-bottom),'PaintedTimber',.018)
    box(label+'_CrossRail',(x,y-.15,top-2.1),(width,.28,.17),'PaintedTimber')
    if bars:
        n=max(2,round(width/.65))
        for k in range(n+1):
            xx=x-width/2+k*width/n
            rod(label+'_SecurityBar',(xx,y-.85,bottom+.1),(xx,y-.85,top-.1),.055)
        for z in [bottom+.4,top-.4]:
            box(label+'_BarRail',(x,y-.85,z),(width+.2,.14,.16),'Iron',.015)
    # Glazing is deliberately opaque/tinted: clean robust export, no alpha sorting.
    collision(label+'_Window',(x,y,(bottom+top)/2),(width,.35,top-bottom))


def frame(width,piers,finish='Plaster'):
    left,right=-width/2,width/2
    for i,(l,r) in enumerate(piers):
        wall('Pier%02d'%i,l,r,0,14,mat=finish)
        box('PierFoot',((l+r)/2,-.09,.65),(r-l+.08,1.5,1.3),'Masonry',.03)
        # Few strong course joints; no indiscriminate small-block clutter.
        for z in [3.5,7,10.5]:
            box('PierCourse',((l+r)/2,-.025,z),(r-l,.045,.075),'Mortar',.006)
    wall('LoadBearingHeader',left,right,14,18,mat=finish)
    box('ContinuousHeadCourse',(0,-.13,14.2),(width,1.65,.55),'CutStone',.045)
    box('TopBedJoint',(0,.5,17.9),(width,1.25,.2),'Mortar',.015)
    socket('LEFT_SEAM',(left,0,0));socket('RIGHT_SEAM',(right,0,0))
    socket('UPPER_STOREY',(0,0,18));socket('SIGN',(0,-.38,15.7))
    socket('AWNING',(0,-.48,13.4));socket('PIPE',(right-.45,-.75,0))


def shallow_room(l,r,depth=5,y=1.25):
    # Shallow usable vestibule; rear is intentionally OPEN to the next module.
    wall('VestibuleLeft',l-.35,l,0,13,y+depth/2,depth,'Masonry')
    wall('VestibuleRight',r,r+.35,0,13,y+depth/2,depth,'Masonry')
    box('VestibuleFloor',((l+r)/2,(y+depth)/2,-.15),(r-l,y+depth,.3),'CutStone',.02,True)
    box('VestibuleSoffit',((l+r)/2,y+depth/2,13.5),(r-l,depth,.5),'Masonry',.025,True)
    socket('INTERIOR_CONNECTION',((l+r)/2,y+depth,0))


# 01 — a genuinely narrow tenant, side door and deep framed display.
new_asset('F01_NarrowShop','frontage',12,6.25,'Main/local streets', [{'x':3.05,'width':5.1,'height':11,'y0':-.6,'y1':6.25}])
frame(12,[(-6,-5.2),(.2,.5),(5.6,6)])
wall('DisplayApron',-5.2,.2,0,3.2)
window('Display',-2.5,5.4,columns=2)
wall('DisplayUpper',-5.2,.2,11.5,14)
door('TenantEntry',3.05,5.1)
wall('DoorHead',.5,5.6,12.8,14)
shallow_room(-5.2,5.6)

# 02 — front returns form a proper recess, not an applied flat doorway.
new_asset('F02_RecessedShop','frontage',16,8,'Main/local streets', [{'x':-3.3,'width':5.4,'height':11,'y0':-.6,'y1':8}])
frame(16,[(-8,-6),(6.3,8)])
for x in [-6.15,6.45]:
    box('RecessReturn',(x,1.8,6.8),(.3,3.2,13.6),'Masonry',.04,True)
door('RecessEntry',-3.3,5.4,3.2)
wall('RecessMullion',-.6,.15,0,14,3.2)
wall('RecessApron',.15,6.3,0,3,3.2)
window('RecessDisplay',3.225,6.15,3,11.5,3.2,3)
wall('RecessHead',-6,6.3,12.8,14,3.2)
shallow_room(-6,6.3,4.75,3.25)

# 03 — closed rolling shutters, guides, headbox and separate service leaf.
new_asset('F03_ShutteredStore','frontage',16,2.5,'Closed commercial bays; not a through route')
frame(16,[(-8,-7),(.7,1.35),(7,8)],'RepairPlaster')
for l,r in [(-7,.7),(1.35,7)]:
    x=(l+r)/2;w=r-l
    box('ShutterBacking',(x,.8,6.7),(w,.25,13.4),'Iron',.015,True)
    for z in [i*.43+.28 for i in range(30)]:
        box('RolledSteelSlat',(x,.56,z),(w-.22,.18,.33),'Zinc',.025)
    for xx in [l+.08,r-.08]:box('GuideRail',(xx,.27,6.7),(.16,.38,13.4),'Iron',.02)
    box('Headbox',(x,-.22,13.25),(w+.12,1.1,1.3),'Oxide',.07)
    box('BottomLockRail',(x,.28,.28),(w,.24,.4),'Iron')
    box('LockPlate',(x,.08,.75),(.7,.1,.65),'Iron')

# 04 — deep grilled display and an open independent doorway.
new_asset('F04_BarredStore','frontage',16,6.25,'Alleys; secure stores', [{'x':4.2,'width':5.2,'height':11,'y0':-.6,'y1':6.25}])
frame(16,[(-8,-7),(0.8,1.6),(6.8,8)])
wall('DisplayBase',-7,.8,0,3.5)
window('GrilledDisplay',-3.1,7.8,3.5,11.6,.85,3,True)
wall('WindowHead',-7,.8,11.6,14)
door('ShopEntry',4.2,5.2)
wall('DoorHead',1.6,6.8,12.8,14)
shallow_room(-7,6.8)

# 05 — heavier residential threshold, transom and small lower-level lights.
new_asset('F05_ResidentialEntry','frontage',12,6.25,'Residential lanes; upper courtyards', [{'x':-.65,'width':5.5,'height':11,'y0':-.6,'y1':6.25}])
frame(12,[(-6,-3.4),(2.1,6)])
door('SharedResidentialDoor',-.65,5.5,1.0)
wall('EntryOverdoor',-3.4,2.1,12.8,14)
# inset grilles in pier faces are shallow fixtures, not pretend full-depth doors.
for x in [-4.7,4.0]:
    box('LowerLightRecess',(x,-.03,2.0),(1.7,.12,2.1),'Iron')
    for dx in [-.5,0,.5]:rod('LowerLightBar',(x+dx,-.19,1.15),(x+dx,-.19,2.85),.045,'Zinc')
box('EntryCrown',(-.65,-.6,13.7),(7.1,1.3,.45),'CutStone')
shallow_room(-3.4,2.1)

# 06 — opening sized for repair/service traffic with open metal leaves.
new_asset('F06_ServiceEntry','frontage',12,6.25,'Service routes; workshops', [{'x':-.4,'width':7.2,'height':12,'y0':-.6,'y1':6.25}])
frame(12,[(-6,-4),(3.2,6)],'RepairPlaster')
surround('ServicePortal',-.4,7.2,0,12,.1,'Iron',False)
wall('ServiceHead',-4,3.2,12.5,14)
for x in [-4.25,3.45]:
    box('FoldedMetalLeaf',(x,2,5.9),(.18,3.2,11.8),'Zinc',.025)
    for z in [2,9]:box('LeafCrossBrace',(x-.1,2,z),(.2,3.0,.18),'Iron')
shallow_room(-4,3.2)

# 07 — thick masonry reveals establish an alley mouth beneath occupation.
new_asset('F07_AlleyMouth','frontage',16,8,'Street-to-alley transition', [{'x':-.5,'width':9,'height':13,'y0':-.7,'y1':8}])
frame(16,[(-8,-5),(4,8)],'Masonry')
surround('AlleyPortal',-.5,9,0,13,-.05,'CutStone',False)
wall('AlleyStructuralSpandrel',-5,4,13.5,14)
shallow_room(-5,4,6.75)

# 08 — broad enough for enemies; structural piers and a real open rear socket.
new_asset('F08_ThroughPassage','frontage',24,16,'Main street into interior circulation', [{'x':-1,'width':12,'height':12,'y0':-.7,'y1':16}])
frame(24,[(-12,-7),(5,12)],'Masonry')
surround('PassagePortal',-1,12,0,13,-.08,'CutStone',False)
wall('PassageHead',-7,5,13.5,14)
shallow_room(-7,5,14.75)
for y in [5,10.5,15.4]:
    box('CeilingBeam',(-1,y,12.7),(12,.45,.5),'Timber',.035)
    for x in [-7.2,5.2]:box('EngagedPilaster',(x,y,6.3),(.35,.5,12.6),'CutStone',.03)

# 09 — intentionally opaque wall, visibly repaired by broad coherent sections.
new_asset('F09_PatchedBlank','frontage',12,2,'Party walls; closed side routes')
frame(12,[(-6,6)],'Masonry')
box('BroadReplaster',(-1.25,-.055,8.6),(7.9,.16,9.1),'RepairPlaster',.015)
box('OldPlasterRemnant',(4.0,-.08,10),(2.7,.13,6.0),'Plaster',.015)
for row in range(5):
    for col in range(5):
        x=-5.4+col*1.2+(row%2)*.5
        box('ExposedBrick',(x,-.15,1.6+row*.48),(1.06,.16,.38),'Brick',.025)
box('RepairJoint',(-1.25,-.15,4.1),(8,.08,.12),'Mortar',.005)

# 10 — three different glazed lights grouped within one structural bay.
new_asset('F10_WindowFront','frontage',24,2,'Upper floors; communal rooms facing streets')
frame(24,[(-12,-10.8),(-4.7,-3.8),(3,4.2),(10.8,12)])
for i,(l,r,bottom,top) in enumerate([(-10.8,-4.7,3.5,12.0),(-3.8,3,2.9,12.0),(4.2,10.8,4.0,11.3)]):
    wall('WindowApron',l,r,0,bottom)
    wall('WindowHead',l,r,top,14)
    window('ApartmentLight%02d'%i,(l+r)/2,r-l,bottom,top,.8,2 if i!=1 else 3)

# 11 — balcony deck has collision, metal guard and an actual rear door opening.
new_asset('F11_BalconyFront','frontage',16,2,'Upper galleries; stacked residential frontage', [{'x':-3.6,'width':5.4,'height':11,'y0':-3.5,'y1':2}])
frame(16,[(-8,-6.3),(-.9,.4),(7,8)])
door('BalconyDoor',-3.6,5.4)
wall('BalconyDoorHead',-6.3,-.9,12.8,14)
wall('ApartmentApron',.4,7,0,3.5)
window('BalconyLight',3.7,6.6,3.5,11.5,.8,2)
wall('WindowHead',.4,7,11.5,14)
box('BalconyDeck',(0,-2,-.35),(16,4.2,.7),'CutStone',.05,True)
for x in [-6.5,5.8]:beam('BalconyBrace',(x,-.1,-3.5),(x,-3.7,-.7),.32,'Iron')
for x in [-7.6,7.6]:
    box('BalconySideGuard',(x,-2,2),(.2,4,4),'Iron',.02,True)
for x in [-7.5+i*1.25 for i in range(13)]:rod('BalconyPicket',(x,-4,0),(x,-4,3.9),.055)
for z in [.3,3.9]:box('BalconyRail',(0,-4,z),(16,.22,.22),'Iron')
collision('BalconyFrontGuard',(0,-4,2),(16,.25,4))
socket('BALCONY_DECK',(0,-2,0)) # terminal balcony, guarded sides are not route sockets

# 12 — occupied bay projects above a usable ground entrance, not a cosmetic slab.
new_asset('F12_OverhangingRoom','frontage',24,3,'Covered main/local streets', [{'x':-7,'width':6,'height':11,'y0':-.7,'y1':3}])
frame(24,[(-12,-10),(-4,-3),(3.5,4.3),(11,12)])
door('LowerEntry',-7,6)
wall('LowerDoorHead',-10,-4,12.8,14)
for l,r in [(-3,3.5),(4.3,11)]:
    wall('LowerApron',l,r,0,3.2);window('LowerDisplay',(l+r)/2,r-l,3.2,11.5,.8,2);wall('LowerHead',l,r,11.5,14)
# Upper projecting room occupies the 18..30 band; standard seam stays at Z18.
box('OverhangFloor',(0,-1.4,18.3),(24,4.4,.6),'Masonry',.045,True)
for x in [-11.5,-3.6,4.0,11.5]:beam('OverhangCorbel',(x,0,12.5),(x,-3.5,17.7),.38,'Timber')
for l,r in [(-12,-10.5),(-4.7,-3.5),(2.3,3.7),(9.5,12)]:wall('UpperPier',l,r,18.6,29,-3.2,1,'RepairPlaster')
for l,r in [(-10.5,-4.7),(-3.5,2.3),(3.7,9.5)]:
    wall('UpperApron',l,r,18.6,21,-3.2,1)
    window('ProjectingRoomLight',(l+r)/2,r-l,21,27.4,-3.35,2)
    wall('UpperHead',l,r,27.4,29,-3.2,1)
wall('RoomLeftReturn',-12,-11.5,18.6,29,-.1,6.2)
wall('RoomRightReturn',11.5,12,18.6,29,-.1,6.2)
box('OverhangRoof',(0,-.1,29.5),(24,6.2,1),'Masonry',.04,True)
CURRENT['height']=30
CURRENT['occupied_upper_band']=[18,30]

# Details have their own origins at the attachment surface and no mandatory
# collision. They can be combined without changing the base frontage library.
def detail(name,width,use):
    new_asset(name,'detail',width,use=use)
    socket('ATTACH',(0,0,0))

for style,width in [('Canvas',12),('Corrugated',16),('Retracted',12)]:
    detail('D_Awning_'+style,width,'AWNING socket; project toward street')
    if style=='Retracted':
        rod('RolledCanvas',(-width/2,-.35,-.25),(width/2,-.35,-.25),.32,'Canvas',12)
        box('Housing',(0,-.2,.1),(width,.65,.32),'Zinc')
    else:
        for x in [-width/2+.35,width/2-.35]:
            beam('SupportArm',(x,0,-1.5),(x,-3.8,-1),.14)
            beam('TopArm',(x,0,0),(x,-3.8,-1),.12)
        canopy=box('Canopy',(0,-1.9,-.48),(width,3.95,.09),'Canvas' if style=='Canvas' else 'Zinc',.01)
        canopy.rotation_euler.x=math.atan(1/3.8)
        box('Valance',(0,-3.82,-1.22),(width,.1,.5),'Canvas' if style=='Canvas' else 'Oxide',.012)
        if style=='Corrugated':
            for i in range(int(width/.6)):
                x=-width/2+(i+.5)*.6
                beam('RoofSeam',(x,0,.04),(x,-3.8,-.96),.055,'Zinc')

for style,width,mat in [('Timber',12,'Timber'),('Steel',16,'Oxide'),('Recessed',24,'Masonry')]:
    detail('D_SignBand_'+style,width,'SIGN socket; blank tenant panel for later lettering')
    box('SignBacking',(0,-.12,0),(width,.24,1.7),mat)
    for z in [-.87,.87]:box('BandMoulding',(0,-.26,z),(width,.25,.16),'Iron' if style=='Steel' else 'CutStone')
    if style=='Recessed':box('InsetPanel',(-.8,-.26,0),(width-2.4,.08,1.2),'PaintedTimber')

for elbow in [False,True]:
    detail('D_SignBracket_'+('Elbow' if elbow else 'Braced'),.4,'Wall mounting; hung sign supplied separately')
    box('WallPlate',(0,.12,-.65),(.45,.24,1.8),'Iron')
    beam('ProjectingArm',(0,0,0),(0,-2.6,0),.16)
    beam('Brace',(0,0,-1.4),(0,-2.4,-.1),.12)
    if elbow:beam('ReturnArm',(0,-2.6,0),(.8,-2.6,0),.14)
    for y in [-1.1,-2.3]:rod('HangerEye',(0,y,-.05),(0,y,-.45),.055)

for style in ['Straight12','Elbow','Offset']:
    detail('D_Drain_'+style,.6,'Pipe centre at attachment origin; endpoints in manifest')
    if style=='Straight12':pts=[(0,-.3,0),(0,-.3,12)]
    elif style=='Elbow':pts=[(0,-.3,0),(0,-.3,1.1),(0,-.5,1.45),(0,-1.5,1.45)]
    else:pts=[(0,-.3,0),(0,-.3,2),(.7,-.3,2.7),(.7,-.3,5)]
    for i,(a,b) in enumerate(zip(pts,pts[1:])):rod('Pipe%02d'%i,a,b,.19,'Zinc',10)
    for p in [pts[0],pts[-1]]:
        rod('JointCollar',(p[0],p[1],p[2]-.12),(p[0],p[1],p[2]+.12),.23,'Iron',10)
    for z in ([2,9] if style=='Straight12' else [1]):
        box('WallClip',(0,-.03,z),(.62,.12,.2),'Iron')
    socket('PIPE_START',pts[0]);socket('PIPE_END',pts[-1])

for bent in [False,True]:
    detail('D_Conduit_'+('Bend' if bent else 'Straight12'),1.1,'Side pier utility chase; non-colliding')
    for i in range(3):
        x=(i-1)*.28
        pts=[(x,-.2,0),(x,-.2,12)] if not bent else [(x,-.2,0),(x,-.2,2),(x+1.5,-.2,3.5),(x+3,-.2,3.5)]
        for a,b in zip(pts,pts[1:]):rod('Conduit',a,b,.07,'Iron')
    for z in ([1,5.5,10.5] if not bent else [1]):box('Saddle',(0,-.13,z),(1,.17,.15),'Zinc')

for wide in [False,True]:
    width=3.6 if wide else 2
    detail('D_Vent_'+('Wide' if wide else 'Square'),width,'Wall-mounted louver, inset dark backing')
    box('VentBacking',(0,-.15,0),(width,.3,1.9),'Iron')
    for z in [-.9,.9]:box('VentFlange',(0,-.35,z),(width+.15,.1,.12),'Zinc')
    for i in range(7):
        ob=box('Louver',(0,-.36,-.72+i*.24),(width-.2,.33,.07),'Zinc',.008);ob.rotation_euler.x=.4

for meter in [False,True]:
    detail('D_Utility_'+('Meter' if meter else 'FuseBox'),1.6,'Service pier; keep outside capsule clearances')
    box('BackBox',(0,-.25,0),(1.6,.5,2.3),'Oxide')
    box('LippedCover',(0,-.55,0),(1.5,.12,2.15),'Zinc')
    if meter:
        box('MeterWindow',(0,-.63,.45),(1,.06,.8),'Glass',.02)
        box('Scale',(0,-.675,.43),(.75,.03,.08),'CutStone',.003)
    else:
        for z in [-.45,-.25,-.05]:box('CoverVent',(0,-.625,z),(1,.035,.055),'Iron',.003)
    rod('Latch',(.52,-.67,-.45),(.52,-.67,-.1),.045)

# Polygonal repair patches, not rectangles placed at random. Solid shallow
# extrusions remain manifold and exportable; corners describe missing plaster.
def patch(label,points,material):
    verts=[(x,y,z) for y in [0,-.085] for x,z in points]
    n=len(points);faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(label);mesh.from_pydata(verts,[],faces);mesh.update()
    ob=bpy.data.objects.new(label,mesh);scene.collection.objects.link(ob);register(ob,label,material)

for tall in [False,True]:
    detail('D_PlasterPatch_'+('Tall' if tall else 'Broad'),4,'Place 0.01 off an opaque wall; no route blocking')
    points=[(-2,-1.3),(-1.4,-1.3),(-1.4,-1.7),(.8,-1.7),(.8,-1.1),(2,-1.1),(2,.6),(1.45,.6),(1.45,1.5),(-1.2,1.5),(-1.2,.9),(-2,.9)]
    if tall:points=[(x*.65,z*1.8) for x,z in points]
    patch('PlasterRepair',points,'RepairPlaster')

for wide in [False,True]:
    detail('D_MasonryPatch_'+('Wide' if wide else 'Narrow'),5 if wide else 3,'Wall repair exposing coherent staggered brick courses')
    rows,cols=(5,5) if wide else (7,3)
    patch('MortarBed',[(-cols*.51,-rows*.25),(cols*.51,-rows*.25),(cols*.51,rows*.25),(-cols*.51,rows*.25)],'Mortar')
    for row in range(rows):
        for col in range(cols):
            w=.87 if (row%2==0 or col not in [0,cols-1]) else .65
            x=(col-(cols-1)/2)*1.0+(row%2)*.1
            box('BrickRepair',(x,-.14,(row-(rows-1)/2)*.48),(w,.15,.38),'Brick',.025)


# Shared surface atlas: exportable base color, roughness, metalness and tangent
# normal maps. Subtle material wear is baked into pixels, never a Blender-only
# procedural shader. UV0 uses atlas regions; UV1 retains the unique packed unwrap.
def make_surface_atlas():
    size=512;cell=size//4
    (OUT/'textures').mkdir(exist_ok=True)
    maps={name:[] for name in ['color','roughness','metalness','normal']}
    names=list(PALETTE)
    def height(u,v,kind):
        broad=math.sin(u*17+math.sin(v*11))*math.sin(v*19+u*3)
        grain=math.sin(u*139+v*31)*math.sin(v*151-u*13)
        if kind in ['Timber','PaintedTimber']:
            return .55*math.sin(u*117+math.sin(v*9)*1.7)+.12*grain
        if kind in ['Iron','Zinc','Glass']:
            return .08*grain+.08*broad
        return .45*broad+.18*grain
    def srgb(c):
        return 12.92*c if c<=.0031308 else 1.055*c**(1/2.4)-.055
    for y in range(size):
        for x in range(size):
            index=(y//cell)*4+x//cell
            name=names[min(index,len(names)-1)]
            color,rough,metal=PALETTE[name]
            u=min(1,max(0,((x%cell)-4)/(cell-9)))
            v=min(1,max(0,((y%cell)-4)/(cell-9)))
            h=height(u,v,name)
            shade=1+.14*h
            maps['color'].extend([*(srgb(min(1,max(0,c*shade))) for c in color),1])
            r=min(1,max(.05,rough+h*.07))
            maps['roughness'].extend([r,r,r,1]);maps['metalness'].extend([metal,metal,metal,1])
            dx=(height(u+.005,v,name)-height(u-.005,v,name))*.16
            dy=(height(u,v+.005,name)-height(u,v-.005,name))*.16
            normal=Vector((-dx,-dy,1)).normalized()
            maps['normal'].extend([*(c*.5+.5 for c in normal),1])
    images={}
    for channel,pixels in maps.items():
        image=bpy.data.images.new('LL_Frontage_'+channel,width=size,height=size,alpha=True)
        image.colorspace_settings.name='sRGB' if channel=='color' else 'Non-Color'
        image.pixels.foreach_set(pixels)
        image.filepath_raw=str(OUT/'textures'/f'frontage_atlas_{channel}.png')
        image.file_format='PNG';image.save();image.pack();images[channel]=image
    mat=bpy.data.materials.new('LL_Frontage_Shared_PBR_Atlas');mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links;p=nodes.get('Principled BSDF')
    for channel,input_name in [('color','Base Color'),('roughness','Roughness'),('metalness','Metallic')]:
        n=nodes.new('ShaderNodeTexImage');n.image=images[channel];n.interpolation='Linear';links.new(n.outputs['Color'],p.inputs[input_name])
    n=nodes.new('ShaderNodeTexImage');n.image=images['normal'];n.interpolation='Linear'
    normal=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],p.inputs['Normal'])
    return mat

ATLAS=make_surface_atlas()

def apply_surface_atlas(ob):
    mesh=ob.data
    # Preserve the nonoverlapping layout for future unique texture/lightmap work.
    packed=mesh.uv_layers.new(name='UV1_Packed')
    for dst,src in zip(packed.data,mesh.uv_layers['UV0'].data):dst.uv=src.uv
    uv=mesh.uv_layers['UV0']
    palette=list(PALETTE)
    for face in mesh.polygons:
        name=mesh.materials[face.material_index].name.removeprefix('LL_')
        index=palette.index(name);col,row=index%4,index//4
        axis=max(range(3),key=lambda k:abs(face.normal[k]))
        axes=[k for k in range(3) if k!=axis]
        points=[mesh.vertices[mesh.loops[i].vertex_index].co for i in face.loop_indices]
        lo=[min(p[k] for p in points) for k in axes];hi=[max(p[k] for p in points) for k in axes]
        for loop,point in zip(face.loop_indices,points):
            q=[(point[k]-lo[j])/max(.00001,hi[j]-lo[j]) for j,k in enumerate(axes)]
            uv.data[loop].uv=((col+.04+.92*q[0])/4,(row+.04+.92*q[1])/4)
        face.material_index=0
    mesh.materials.clear();mesh.materials.append(ATLAS)
    mesh.uv_layers.active_index=0
    mesh.uv_layers['UV0'].active_render=True


def unwrap_and_join(asset):
    obs=asset['objects']
    bpy.ops.object.select_all(action='DESELECT')
    for ob in obs:ob.select_set(True)
    bpy.context.view_layer.objects.active=obs[0]
    bpy.ops.object.join()
    ob=bpy.context.object;ob.name=asset['name']+'__VIS'
    # Each logical asset is one editable mesh; glTF exports its material primitives.
    scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.data.uv_layers.active.name='UV0'
    apply_surface_atlas(ob)
    ob.data.calc_loop_triangles()
    asset['visual']=ob
    asset['triangles']=len(ob.data.loop_triangles)
    asset['vertices']=len(ob.data.vertices)
    assert asset['triangles']<=18000,(asset['name'],asset['triangles'])
    corners=[ob.matrix_local@Vector(c) for c in ob.bound_box]
    asset['bounds']={'min':[min(c[k] for c in corners) for k in range(3)],'max':[max(c[k] for c in corners) for k in range(3)]}
    ob['RecommendedCanCollide']=False
    ob['TriangleCount']=asset['triangles']
    ob['Role']='visual'
    asset['collection'].asset_mark()
    asset['collection'].asset_data.description=asset['use']+' | 1 authored unit = 1 stud | front -Y | see manifest'
    asset['collection'].asset_data.author='Enfleshed'
    asset['collection'].asset_data.catalog_id='7aeeed2b-0da8-4a39-95e9-bd1a375cb001' if asset['kind']=='frontage' else '7aeeed2b-0da8-4a39-95e9-bd1a375cb002'
    for tag in ['Lower Layer',asset['kind'],'modular']:
        asset['collection'].asset_data.tags.new(tag)
    return ob


# Individual exports are at LOCAL origin, never the catalogue layout position.
manifest=[]
for asset in ASSETS:
    visual=unwrap_and_join(asset)
    colliders=[]
    for i,c in enumerate(asset['colliders']):
        bpy.ops.mesh.primitive_cube_add(size=1,location=c['center'])
        ob=bpy.context.object;ob.name=asset['name']+'__COL_%02d'%i
        for coll in list(ob.users_collection):coll.objects.unlink(ob)
        asset['collection'].objects.link(ob);ob.parent=asset['root'];ob.dimensions=c['size']
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        ob['Role']='collision';ob.display_type='WIRE';ob.hide_render=True
        colliders.append(ob)
    asset['collision_objects']=colliders
    for suffix,objects in [('visual',[visual,asset['root']]),('collision',colliders)]:
        if not objects:continue
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.hide_set(False);ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        path=OUT/'exports'/f"{asset['name']}_{suffix}"
        bpy.ops.export_scene.gltf(filepath=str(path.with_suffix('.glb')),export_format='GLB',use_selection=True,
                                  export_extras=True,export_yup=True,export_materials='EXPORT')
        bpy.ops.export_scene.fbx(filepath=str(path.with_suffix('.fbx')),use_selection=True,object_types={'MESH','EMPTY'},
                                 apply_unit_scale=False,global_scale=1,axis_forward='-Z',axis_up='Y',
                                 add_leaf_bones=False,bake_anim=False,use_custom_props=True,path_mode='COPY',embed_textures=True)
    for ob in colliders:ob.hide_set(True)
    manifest.append({k:v for k,v in asset.items() if k in ['name','kind','width','depth','height','use','openings','sockets','colliders','triangles','vertices','bounds','occupied_upper_band']})

# Review catalogue: originals are translated together; instance_offset keeps
# Asset Browser placement at the authored front-centre origin.
fronts=[a for a in ASSETS if a['kind']=='frontage']
details=[a for a in ASSETS if a['kind']=='detail']
for i,asset in enumerate(fronts):
    x=(i%4-1.5)*32;z=(2-i//4)*36
    asset['root'].location=(x,0,z)
    asset['collection'].instance_offset=(x,0,z)
for i,asset in enumerate(details):
    x=(i%6-2.5)*23;z=-22-(i//6)*20
    asset['root'].location=(x,0,z)
    asset['collection'].instance_offset=(x,0,z)


def review_text(text,loc,size=1):
    curve=bpy.data.curves.new(text,'FONT');curve.body=text;curve.size=size;curve.align_x='CENTER';curve.extrude=0
    ob=bpy.data.objects.new('REVIEW_LABEL_'+text,curve);REVIEW.objects.link(ob);ob.location=loc;ob.rotation_euler=(math.pi/2,0,0)
    mat=MATS['CutStone'];curve.materials.append(mat)
    ob['ReviewKind']='frontage' if loc[2]>-10 else 'detail'

for a in fronts:
    x,y,z=a['root'].location
    review_text(a['name'].replace('_',' '),(x,-1,z-2),.95)
    review_text(f"{a['width']} STUD | {a['triangles']:,} TRI",(x,-1,z-3.5),.7)
for a in details:
    x,y,z=a['root'].location
    review_text(a['name'].replace('D_','').replace('_',' '),(x,-1,z-4.7),.8)

# Distinct assembly scene made only of collection instances, not unique geometry.
ASSEMBLY=bpy.data.collections.new('01_REVIEW_ASSEMBLY_INSTANCES');scene.collection.children.link(ASSEMBLY)
selected=[fronts[i] for i in [4,0,6,1,2,3]]
x=-sum(a['width'] for a in selected)/2
for a in selected:
    ob=bpy.data.objects.new('REVIEW_INSTANCE_'+a['name'],None);ob.instance_type='COLLECTION';ob.instance_collection=a['collection']
    ASSEMBLY.objects.link(ob);ob.location=(x+a['width']/2,65,0)
    # Upper window modules fill selected 24-unit bays in a separate demonstration.
    x+=a['width']
x=-44
for i,a in enumerate([fronts[9],fronts[10],fronts[11],fronts[9]]):
    ob=bpy.data.objects.new('REVIEW_UPPER_'+a['name'],None);ob.instance_type='COLLECTION';ob.instance_collection=a['collection'];ASSEMBLY.objects.link(ob)
    ob.location=(x+a['width']/2,65,18)
    x+=a['width']
# A restrained attachment example demonstrates layered use without masking
# the structural apertures. These remain review instances, never export meshes.
by_name={a['name']:a for a in ASSETS}
for name,position in [
    ('D_Awning_Canvas',(-26,64.52,13.4)),
    ('D_Awning_Corrugated',(4,64.52,13.4)),
    ('D_Utility_Meter',(-33.5,64.96,7)),
    ('D_PlasterPatch_Tall',(-6,64.97,8)),
    ('D_Drain_Straight12',(-19.55,64.25,0)),
    ('D_Drain_Straight12',(-19.55,64.25,12)),
    ('D_Drain_Straight12',(-19.55,64.25,24)),
]:
    ob=bpy.data.objects.new('REVIEW_DETAIL_'+name,None);ob.instance_type='COLLECTION';ob.instance_collection=by_name[name]['collection'];ASSEMBLY.objects.link(ob);ob.location=position
ASSEMBLY.hide_render=True


def camera(name,loc,target,scale):
    data=bpy.data.cameras.new(name);ob=bpy.data.objects.new(name,data);REVIEW.objects.link(ob)
    ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';data.ortho_scale=scale;data.clip_end=2000
    return ob

cams={
 'frontages':camera('REVIEW_Frontages',(30,-180,110),(0,0,43),148),
 'details':camera('REVIEW_Details',(24,-170,20),(0,0,-48),148),
 'assembly':camera('REVIEW_Assembly',(66,-55,55),(0,66,16),112),
}
for name,loc,target,power,size in [('Key',(-65,-65,145),(0,0,25),150000,95),('Fill',(85,-30,70),(0,0,20),90000,85),('Low',(-45,-40,-25),(0,0,-45),45000,80)]:
    data=bpy.data.lights.new('REVIEW_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new('REVIEW_'+name,data);REVIEW.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
scene.camera=cams['frontages']
scene.render.resolution_x=1800;scene.render.resolution_y=1600
scene['KitVersion']='LL_FRONTAGE_V1'
scene['Units']='1 local Blender unit = 1 target Roblox stud; use manifest collision coordinates'
scene['ExportPolicy']='Only files in exports/ contain runtime assets. Review lights/text/instances are excluded.'
text=bpy.data.texts.new('START_HERE')
text.write('LOWER LAYER FRONTAGE KIT V1\n12 frontage assets + 21 attachment assets.\nFront -Y, Z up; width units 12/16/24 studs, shared 18-stud storey.\nF12 includes an upper projecting room: occupies Z18..30.\nCollection assets carry corrected instance offsets. Export files are LOCAL to origin.\nUse the external manifest and guide for collision, sockets and import calibration.\nNo city integration. Source meshes have atlas UV0, packed UV1 and a portable shared PBR atlas.\n')
scene.render.filepath=str(OUT/'frontages.png')
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lower_layer_frontage_kit_v1.blend'))

report={'kit':'LL_FRONTAGE_V1','blender':bpy.app.version_string,'frontages':len(fronts),'details':len(details),
        'units':'one authored unit targets one Roblox stud','axis':'Blender X right, Y inward, Z up; front -Y',
        'surface_atlas':{'size':512,'uv':'UV0','packed_unique_uv':'UV1_Packed','maps':['color','roughness','metalness','normal']},
        'width_grid':[12,16,24],'storey_height':18,'assets':manifest,
        'materials':{name:{'base_color':color,'roughness':rough,'metallic':metal} for name,(color,rough,metal) in PALETTE.items()},
        'limitations':['Studio import, scale, material appearance and character collision need engine acceptance testing.',
                       'Shared 512px PBR atlas supplies restrained material wear; unique storytelling/weathering textures are not included.',
                       'Portals require connecting floor/interior modules in world assembly; library assets do not create destinations.']}
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n7aeeed2b-0da8-4a39-95e9-bd1a375cb001:Lower Layer/Frontages:Frontages\n7aeeed2b-0da8-4a39-95e9-bd1a375cb002:Lower Layer/Attachments:Attachments\n')
(OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
if args.render:
    for name in ['frontages','details','assembly']:
        scene.camera=cams[name]
        scene.render.resolution_x=1800;scene.render.resolution_y=1600 if name=='frontages' else 1100
        ASSEMBLY.hide_render=name!='assembly'
        LIB.hide_render=name=='assembly'
        for asset in ASSETS:
            asset['collection'].hide_render = False if name=='assembly' else ((asset['kind']=='detail') if name=='frontages' else (asset['kind']=='frontage'))
        for ob in REVIEW.objects:
            if ob.type=='FONT': ob.hide_render = name=='assembly' or ob.get('ReviewKind') != ('detail' if name=='details' else 'frontage')
        scene.render.filepath=str(OUT/f'{name}.png')
        bpy.ops.render.render(write_still=True)
    # Save the useful initial state, not the last review camera.
    ASSEMBLY.hide_render=True;LIB.hide_render=False;scene.camera=cams['frontages']
    for asset in ASSETS: asset['collection'].hide_render=False
    for ob in REVIEW.objects:
        if ob.type=='FONT': ob.hide_render=False
    scene.render.resolution_x=1800;scene.render.resolution_y=1600
    scene.render.filepath=str(OUT/'frontages.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lower_layer_frontage_kit_v1.blend'))
print('KIT_COMPLETE',len(fronts),len(details),sum(a['triangles'] for a in ASSETS),flush=True)
