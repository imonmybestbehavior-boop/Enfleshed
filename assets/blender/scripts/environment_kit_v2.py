import bpy
import math
import os
import random

random.seed(81)

OUT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/lower_layer_environment_kit_v2.blend"
)

# ============================================================
# CLEAN
# ============================================================

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# ============================================================
# COLLECTIONS
# ============================================================

def collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

FACADE = collection("01_FACADES")
OPENINGS = collection("02_OPENINGS")
STRUCTURE = collection("03_STRUCTURE")
ACCRETION = collection("04_ACCRETED_CONSTRUCTION")
TRAVERSAL = collection("05_TRAVERSAL")
DESTRUCTION = collection("06_DESTRUCTION")
DETAIL = collection("07_DETAILS")
DISPLAY = collection("99_DISPLAY")


# ============================================================
# MATERIALS
# ============================================================

def material(name, rgb, metallic=0.0, roughness=.8):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True

    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m


STONE = material("Aged_Masonry", (.19,.17,.15), 0, .9)
PLASTER = material("Dirty_Plaster", (.31,.28,.23), 0, .94)
IRON = material("Blackened_Iron", (.055,.05,.045), .75, .55)
PATCH = material("Old_Patch_Metal", (.13,.11,.09), .58, .72)
RED = material("Faded_Military_Red", (.24,.035,.025), .18, .78)
WOOD = material("Dark_Aged_Timber", (.12,.075,.045), 0, .9)
ANCIENT = material("Ancient_Structure", (.025,.027,.03), .3, .5)


# ============================================================
# HELPERS
# ============================================================

def relocate(obj, col):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)


def box(name, loc, size, col, mat, bevel=.08, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0]/2, size[1]/2, size[2]/2)

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True
    )

    relocate(o, col)

    if mat:
        o.data.materials.append(mat)

    if bevel:
        mod = o.modifiers.new("EdgeWear", "BEVEL")
        mod.width = bevel
        mod.segments = 2

    return o


def cylinder(name, loc, radius, depth, col, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=loc
    )
    o = bpy.context.object
    o.name = name
    relocate(o, col)
    o.data.materials.append(mat)
    return o


def empty(name, loc, col):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    o.empty_display_type = "CUBE"
    o.empty_display_size = .4
    col.objects.link(o)
    return o


def parent_all(parent, objects):
    for o in objects:
        o.parent = parent


# ============================================================
# GENERIC FACADE
# ============================================================

def facade(name, x, y, width=16, height=16,
           inset=True, lower_iron=True,
           side_frames=True):

    p = empty(name, (x,y,0), FACADE)
    pieces = []

    pieces.append(box(
        name+"_CORE",
        (x,y,height/2),
        (width,2,height),
        FACADE, STONE, .16
    ))

    if inset:
        pieces.append(box(
            name+"_INSET",
            (x,y-1.08,height/2),
            (width-1.3,.16,height-1.4),
            FACADE, PLASTER, .035
        ))

    if lower_iron:
        pieces.append(box(
            name+"_LOWER_BAND",
            (x,y-1.22,1.25),
            (width,.30,2.5),
            FACADE, IRON, .04
        ))

    if side_frames:
        for s in (-1,1):
            pieces.append(box(
                name+"_EDGE",
                (x+s*(width/2-.35),y-1.23,height/2),
                (.55,.32,height-.5),
                FACADE, IRON, .04
            ))

    parent_all(p,pieces)
    return p


# ============================================================
# RECESSED FACADE
# ============================================================

def recessed_facade(name,x,y,width=16):
    p = empty(name,(x,y,0),FACADE)
    pieces=[]

    pieces.append(box(
        name+"_BACK",
        (x,y+.35,8),
        (width,1.3,16),
        FACADE,STONE,.18
    ))

    # deep border
    pieces += [
        box(name+"_L",(x-width/2+.65,y-.6,8),
            (1.3,1.8,16),FACADE,STONE,.12),
        box(name+"_R",(x+width/2-.65,y-.6,8),
            (1.3,1.8,16),FACADE,STONE,.12),
        box(name+"_TOP",(x,y-.6,15.25),
            (width-2.6,1.8,1.5),FACADE,STONE,.12),
        box(name+"_BOTTOM",(x,y-.6,1.0),
            (width-2.6,1.8,2),FACADE,STONE,.12)
    ]

    pieces.append(box(
        name+"_PANEL",
        (x,y-.38,8),
        (width-3.2,.25,11.8),
        FACADE,PLASTER,.04
    ))

    parent_all(p,pieces)
    return p


# ============================================================
# PATCHED / GENERATIONAL FACADE
# ============================================================

def patched_facade(name,x,y,width=16):
    p = facade(name,x,y,width)
    pieces=[]

    patches = [
        (-.28,4.5,4.2,3.4,-4),
        (.23,9.7,3.3,4.5,5),
        (.32,2.7,2.6,2.2,-7)
    ]

    for i,(xp,z,w,h,r) in enumerate(patches):
        q=box(
            name+"_PATCH_"+str(i),
            (x+xp*width,y-1.39,z),
            (w,.18,h),
            FACADE,
            RED if i==1 else PATCH,
            .035,
            (0,math.radians(r),0)
        )
        q.parent=p
        pieces.append(q)

    # ugly later reinforcement
    q=box(
        name+"_LATE_BEAM",
        (x-width*.12,y-1.52,7.5),
        (.5,.42,14),
        FACADE,IRON,.04,
        (0,math.radians(-7),0)
    )
    q.parent=p

    return p


# ============================================================
# BUTTRESSED WALL
# ============================================================

def buttressed(name,x,y,width=16):
    p=facade(name,x,y,width)
    for s in (-1,1):
        q=box(
            name+"_BUTTRESS",
            (x+s*(width/2-1.5),y-2.0,5),
            (2.3,3.7,10),
            FACADE,STONE,.14,
            (0,math.radians(s*7),0)
        )
        q.parent=p
    return p


# ============================================================
# DOOR FACADE
# ============================================================

def doorway(name,x,y,width=16,industrial=False):
    p=empty(name,(x,y,0),OPENINGS)
    pieces=[]

    dw=6
    dh=10
    side=(width-dw)/2

    for s in (-1,1):
        pieces.append(box(
            name+"_SIDE",
            (x+s*(dw/2+side/2),y,8),
            (side,2,16),
            OPENINGS,STONE,.15
        ))

    pieces.append(box(
        name+"_HEADER",
        (x,y,13),
        (dw,2,6),
        OPENINGS,STONE,.15
    ))

    # projecting frame
    for s in (-1,1):
        pieces.append(box(
            name+"_FRAME",
            (x+s*3.35,y-1.3,5),
            (.7,.65,10),
            OPENINGS,IRON,.06
        ))

    pieces.append(box(
        name+"_FRAME_TOP",
        (x,y-1.3,10.2),
        (7.4,.65,.75),
        OPENINGS,IRON,.06
    ))

    if industrial:
        pieces.append(box(
            name+"_AWNING",
            (x,y-2.15,12.2),
            (10,3,.5),
            OPENINGS,IRON,.05,
            (math.radians(-5),0,0)
        ))

        for s in (-1,1):
            pieces.append(box(
                name+"_AWNING_SUPPORT",
                (x+s*4,y-1.65,10.9),
                (.35,.35,3.8),
                OPENINGS,IRON,.035,
                (math.radians(25),0,0)
            ))

    parent_all(p,pieces)
    return p


# ============================================================
# WINDOW TYPES
# ============================================================

def window_wall(name,x,y,width=16,barred=True):
    p=empty(name,(x,y,0),OPENINGS)
    pieces=[]

    ww=5.5
    wh=4.5
    sill=5.5
    side=(width-ww)/2

    for s in (-1,1):
        pieces.append(box(
            name+"_SIDE",
            (x+s*(ww/2+side/2),y,8),
            (side,2,16),
            OPENINGS,STONE,.15
        ))

    pieces.append(box(
        name+"_BOTTOM",
        (x,y,sill/2),
        (ww,2,sill),
        OPENINGS,STONE,.15
    ))

    top_start=sill+wh
    pieces.append(box(
        name+"_TOP",
        (x,y,top_start+(16-top_start)/2),
        (ww,2,16-top_start),
        OPENINGS,STONE,.15
    ))

    # thick projecting sill
    pieces.append(box(
        name+"_SILL",
        (x,y-1.4,sill),
        (ww+1.2,1,.5),
        OPENINGS,STONE,.07
    ))

    if barred:
        for dx in (-1.8,0,1.8):
            pieces.append(box(
                name+"_BAR",
                (x+dx,y-1.18,sill+wh/2),
                (.16,.22,wh),
                OPENINGS,IRON,.015
            ))

    parent_all(p,pieces)
    return p


# ============================================================
# SHUTTERED / SEALED WINDOW
# ============================================================

def sealed_window(name,x,y):
    p=window_wall(name,x,y,16,False)

    for i,dx in enumerate((-1.6,0,1.6)):
        q=box(
            name+"_SHUTTER_"+str(i),
            (x+dx,y-1.32,7.7),
            (1.45,.18,4.1),
            OPENINGS,
            PATCH if i!=1 else WOOD,
            .025,
            (0,math.radians(random.uniform(-3,3)),0)
        )
        q.parent=p

    return p


# ============================================================
# STRUCTURE
# ============================================================

def column(name,x,y,heavy=False):
    p=empty(name,(x,y,0),STRUCTURE)

    w=5 if heavy else 3
    h=24 if heavy else 16

    core=box(name+"_CORE",(x,y,h/2),(w,w,h),
             STRUCTURE,STONE,.2)

    base=box(name+"_BASE",(x,y,1),
             (w+1.5,w+1.5,2),STRUCTURE,IRON,.07)

    cap=box(name+"_CAP",(x,y,h-1),
            (w+1,w+1,2),STRUCTURE,IRON,.07)

    parent_all(p,[core,base,cap])

    for z in range(5,int(h),6):
        band=box(
            name+"_BAND",
            (x,y,z),
            (w+.3,w+.3,.4),
            STRUCTURE,IRON,.03
        )
        band.parent=p

    return p


def beam(name,x,y,length=16):
    p=empty(name,(x,y,0),STRUCTURE)

    main=box(
        name+"_MAIN",
        (x,y,2),
        (length,2.3,3.4),
        STRUCTURE,IRON,.09
    )
    main.parent=p

    # reinforcement plate
    plate=box(
        name+"_PLATE",
        (x,y-1.22,2),
        (length*.55,.15,2.2),
        STRUCTURE,PATCH,.025
    )
    plate.parent=p
    return p


def diagonal_brace(name,x,y):
    p=empty(name,(x,y,0),STRUCTURE)

    for r in (-42,42):
        q=box(
            name+"_MEMBER",
            (x,y,6),
            (.65,1,14),
            STRUCTURE,IRON,.04,
            (0,math.radians(r),0)
        )
        q.parent=p
    return p


def arch_support(name,x,y):
    p=empty(name,(x,y,0),STRUCTURE)

    pieces=[
        box(name+"_L",(x-5,y,6),(2.5,3,12),
            STRUCTURE,STONE,.16),
        box(name+"_R",(x+5,y,6),(2.5,3,12),
            STRUCTURE,STONE,.16),
        box(name+"_TOP",(x,y,12),(12.5,3,2.5),
            STRUCTURE,STONE,.16),
    ]

    # imperfect retrofit braces
    pieces += [
        box(name+"_BRACE_L",(x-3.9,y-1.1,10),
            (.55,.55,5.5),STRUCTURE,IRON,.04,
            (0,math.radians(-38),0)),
        box(name+"_BRACE_R",(x+3.9,y-1.1,10),
            (.55,.55,5.5),STRUCTURE,IRON,.04,
            (0,math.radians(38),0))
    ]

    parent_all(p,pieces)
    return p


# ============================================================
# ACCRETED CONSTRUCTION
# ============================================================

def hanging_room(name,x,y):
    p=empty(name,(x,y,0),ACCRETION)

    pieces=[
        box(name+"_BODY",(x,y,6),(12,8,9),
            ACCRETION,PLASTER,.13),

        box(name+"_FLOOR",(x,y,1.25),(13,9,1),
            ACCRETION,IRON,.06),

        box(name+"_ROOF",(x,y,10.7),(13,9,.7),
            ACCRETION,PATCH,.05),

        box(name+"_WINDOW",(x,y-4.12,6.3),(4,.18,3),
            ACCRETION,IRON,.025),
    ]

    for s in (-1,1):
        pieces.append(box(
            name+"_SUPPORT",
            (x+s*4.5,y+1,0),
            (.65,.65,9),
            ACCRETION,IRON,.04,
            (0,math.radians(s*38),0)
        ))

    parent_all(p,pieces)
    return p


def overstreet_room(name,x,y):
    p=empty(name,(x,y,0),ACCRETION)

    pieces=[
        box(name+"_ROOM",(x,y,15),(18,8,8),
            ACCRETION,PLASTER,.12),

        box(name+"_BOTTOM",(x,y,10.7),(19,9,.8),
            ACCRETION,IRON,.05),

        box(name+"_ROOF",(x,y,19.3),(19,9,.7),
            ACCRETION,PATCH,.05)
    ]

    # dangling support structure
    for s in (-1,1):
        pieces.append(box(
            name+"_BRACE",
            (x+s*7,y,7),
            (.6,.8,8),
            ACCRETION,IRON,.04,
            (0,math.radians(s*28),0)
        ))

    parent_all(p,pieces)
    return p


def lean_to(name,x,y):
    p=empty(name,(x,y,0),ACCRETION)

    pieces=[
        box(name+"_BACK",(x,y+2,4),(10,.5,8),
            ACCRETION,WOOD,.05),

        box(name+"_SIDE_L",(x-5,y,4),(.5,4,8),
            ACCRETION,PATCH,.04),

        box(name+"_SIDE_R",(x+5,y,4),(.5,4,8),
            ACCRETION,PATCH,.04),

        box(name+"_ROOF",(x,y,8.2),(11,6,.5),
            ACCRETION,PATCH,.04,
            (math.radians(-7),0,0))
    ]

    parent_all(p,pieces)
    return p


def balcony(name,x,y):
    p=empty(name,(x,y,0),ACCRETION)

    pieces=[
        box(name+"_FLOOR",(x,y,1),(12,5,.7),
            ACCRETION,IRON,.04),
    ]

    for s in (-1,1):
        pieces.append(box(
            name+"_SUPPORT",
            (x+s*4.5,y+1.2,-1),
            (.45,.45,5),
            ACCRETION,IRON,.03,
            (0,math.radians(s*35),0)
        ))

    # rail
    pieces.append(box(
        name+"_RAIL_TOP",
        (x,y-2.2,3),
        (12,.25,.25),
        ACCRETION,IRON,.02
    ))

    for dx in (-5,-2.5,0,2.5,5):
        pieces.append(box(
            name+"_RAIL",
            (x+dx,y-2.2,2),
            (.18,.18,2),
            ACCRETION,IRON,.01
        ))

    parent_all(p,pieces)
    return p


# ============================================================
# TRAVERSAL
# ============================================================

def catwalk(name,x,y,length=16):
    p=empty(name,(x,y,0),TRAVERSAL)

    floor=box(
        name+"_DECK",
        (x,y,0),
        (length,5,.6),
        TRAVERSAL,IRON,.04
    )
    floor.parent=p

    for sy in (-1,1):
        rail=box(
            name+"_RAIL",
            (x,y+sy*2.35,2),
            (length,.2,.2),
            TRAVERSAL,IRON,.015
        )
        rail.parent=p

        for dx in range(
            int(-length/2+1),
            int(length/2),
            3
        ):
            q=box(
                name+"_POST",
                (x+dx,y+sy*2.35,1),
                (.16,.16,2),
                TRAVERSAL,IRON,.01
            )
            q.parent=p

    return p


def bridge(name,x,y):
    return catwalk(name,x,y,24)


def stairs(name,x,y):
    p=empty(name,(x,y,0),TRAVERSAL)

    steps=10
    for i in range(steps):
        q=box(
            name+"_STEP_"+str(i),
            (x,y+i*.8,i*.5),
            (6,1,.5),
            TRAVERSAL,STONE,.035
        )
        q.parent=p

    # side reinforcement
    for s in (-1,1):
        q=box(
            name+"_STRINGER",
            (x+s*3,y+3.6,2.3),
            (.35,9,.35),
            TRAVERSAL,IRON,.025,
            (math.radians(30),0,0)
        )
        q.parent=p

    return p


def ladder(name,x,y):
    p=empty(name,(x,y,0),TRAVERSAL)

    for s in (-1,1):
        q=box(
            name+"_SIDE",
            (x+s*1.2,y,5),
            (.2,.2,10),
            TRAVERSAL,IRON,.015
        )
        q.parent=p

    for z in range(1,10):
        q=box(
            name+"_RUNG",
            (x,y,z),
            (2.4,.18,.18),
            TRAVERSAL,IRON,.01
        )
        q.parent=p

    return p


# ============================================================
# DESTRUCTION FAMILIES
# ============================================================

def damaged_wall(name,x,y,width=16):
    p=empty(name,(x,y,0),DESTRUCTION)

    # intentionally uneven surviving masses
    data=[
        (-.39,4.0,.22,8),
        (-.38,12,.24,7.5),
        (-.10,12.7,.25,6.5),
        (.22,11.5,.26,9),
        (.40,4.2,.20,8.4)
    ]

    for i,(xp,z,wp,h) in enumerate(data):
        q=box(
            name+"_MASS_"+str(i),
            (x+xp*width,y,z),
            (width*wp,2,h),
            DESTRUCTION,STONE,.13,
            (0,math.radians(random.uniform(-3,3)),0)
        )
        q.parent=p

    for dx in (-1.5,0,1.4):
        q=box(
            name+"_REBAR",
            (x+dx,y-1.05,5),
            (.14,.14,5.5),
            DESTRUCTION,IRON,.01,
            (0,math.radians(random.uniform(-10,10)),0)
        )
        q.parent=p

    return p


def breached_wall(name,x,y,width=16):
    p=empty(name,(x,y,0),DESTRUCTION)

    breach=6
    side=(width-breach)/2

    pieces=[
        box(name+"_LEFT",
            (x-(breach/2+side/2),y,8),
            (side,2,16),DESTRUCTION,STONE,.15),

        box(name+"_RIGHT",
            (x+(breach/2+side/2),y,8),
            (side,2,16),DESTRUCTION,STONE,.15),

        box(name+"_TOP",
            (x,y,14),
            (breach+1.5,2,4),
            DESTRUCTION,STONE,.14,
            (0,math.radians(2),0))
    ]

    for s in (-1,1):
        for j in range(3):
            pieces.append(box(
                name+"_EDGE",
                (x+s*(breach/2+.25),y,2.2+j*3),
                (
                    random.uniform(.7,1.5),
                    2,
                    random.uniform(1.4,2.8)
                ),
                DESTRUCTION,STONE,.1,
                (0,math.radians(random.uniform(-15,15)),0)
            ))

    parent_all(p,pieces)
    return p


def broken_column(name,x,y):
    p=empty(name,(x,y,0),DESTRUCTION)

    lower=box(
        name+"_LOWER",
        (x,y,3.2),
        (4,4,6.4),
        DESTRUCTION,STONE,.16,
        (math.radians(2),math.radians(-2),0)
    )
    lower.parent=p

    for i in range(4):
        q=box(
            name+"_REBAR",
            (
                x+random.uniform(-1,1),
                y+random.uniform(-1,1),
                7
            ),
            (.14,.14,4),
            DESTRUCTION,IRON,.01,
            (
                math.radians(random.uniform(-8,8)),
                math.radians(random.uniform(-8,8)),
                0
            )
        )
        q.parent=p

    return p


# ============================================================
# DETAIL MODULES
# ============================================================

def repair_plate(name,x,y,w=5,h=4):
    p=empty(name,(x,y,0),DETAIL)

    plate=box(
        name+"_PLATE",
        (x,y,h/2),
        (w,.3,h),
        DETAIL,PATCH,.035
    )
    plate.parent=p

    for sx in (-1,1):
        for z in (.6,h-.6):
            bolt=cylinder(
                name+"_BOLT",
                (x+sx*(w/2-.5),y-.19,z),
                .11,.15,DETAIL,IRON,8
            )
            bolt.rotation_euler[0]=math.radians(90)
            bolt.parent=p

    return p


def pipe_module(name,x,y,radius=.55):
    p=empty(name,(x,y,0),DETAIL)

    pipe=cylinder(
        name+"_PIPE",
        (x,y,6),
        radius,12,
        DETAIL,IRON,12
    )
    pipe.parent=p

    for z in (2,6,10):
        ring=cylinder(
            name+"_CLAMP",
            (x,y,z),
            radius+.12,.25,
            DETAIL,PATCH,12
        )
        ring.parent=p

    return p


# ============================================================
# GENERATE DISPLAY
# ============================================================

# Row 1 - Facades
xs=[-72,-52,-30,-8,14,36,58,80]

facade("Facade_8",-72,0,8)
facade("Facade_16",-52,0,16)
facade("Facade_24",-30,0,24)
recessed_facade("Facade_Recessed",-5,0,16)
patched_facade("Facade_Patched",16,0,16)
buttressed("Facade_Buttressed",38,0,16)
facade("Facade_Heavy",60,0,16,True,True,True)
patched_facade("Facade_Generational",82,0,20)

# Row 2 - openings
doorway("Doorway_Civilian",-65,28)
doorway("Doorway_Industrial",-43,28,industrial=True)
window_wall("Window_Barred",-21,28)
window_wall("Window_Open",1,28,barred=False)
sealed_window("Window_Sealed",23,28)
doorway("Doorway_Wide",45,28,20,True)

# Row 3 - structure
column("Column_Light",-65,55)
column("Column_Heavy",-53,55,True)
beam("Beam_16",-34,55,16)
beam("Beam_24",-10,55,24)
diagonal_brace("CrossBrace",10,55)
arch_support("RetrofitArch",30,55)

# Row 4 - accretion
hanging_room("HangingRoom_A",-62,85)
hanging_room("HangingRoom_B",-43,85)
overstreet_room("OverStreetRoom",-20,85)
lean_to("LeanTo_A",8,85)
lean_to("LeanTo_B",24,85)
balcony("Balcony_A",43,85)
balcony("Balcony_B",61,85)

# Row 5 - traversal
catwalk("Catwalk_16",-58,112,16)
catwalk("Catwalk_24",-32,112,24)
bridge("Bridge_24",-2,112)
stairs("Stairs_Standard",25,108)
ladder("Ladder_10",44,112)

# Row 6 - destruction
damaged_wall("Wall_Damaged_A",-58,140)
damaged_wall("Wall_Damaged_B",-36,140,20)
breached_wall("Wall_Breached_A",-10,140)
breached_wall("Wall_Breached_B",12,140,20)
broken_column("Column_Broken",34,140)

repair_plate("RepairPlate_A",50,140)
repair_plate("RepairPlate_B",60,140,7,3)
pipe_module("Pipe_Vertical_A",72,140,.5)
pipe_module("Pipe_Vertical_B",80,140,.8)


# ============================================================
# DISPLAY FLOOR
# ============================================================

box(
    "DISPLAY_GROUND",
    (5,70,-1.2),
    (190,175,1),
    DISPLAY,ANCIENT,.1
)


# ============================================================
# LIGHTING
# ============================================================

def point_at(obj,target):
    import mathutils
    direction=mathutils.Vector(target)-obj.location
    obj.rotation_euler=direction.to_track_quat("-Z","Y").to_euler()


bpy.ops.object.light_add(
    type="AREA",
    location=(0,-50,100)
)
key=bpy.context.object
key.data.energy=3500
key.data.size=60
point_at(key,(0,65,0))


bpy.ops.object.light_add(
    type="AREA",
    location=(-100,70,55)
)
fill=bpy.context.object
fill.data.energy=2200
fill.data.size=50
point_at(fill,(0,70,5))


bpy.ops.object.light_add(
    type="AREA",
    location=(100,100,70)
)
rim=bpy.context.object
rim.data.energy=2600
rim.data.size=45
point_at(rim,(10,80,5))


# ============================================================
# CAMERA
# ============================================================

bpy.ops.object.camera_add(
    location=(155,-175,125)
)

cam=bpy.context.object
cam.name="EnvironmentKitV2_Preview"
point_at(cam,(5,70,8))
bpy.context.scene.camera=cam


# ============================================================
# WORLD
# ============================================================

world=bpy.context.scene.world
world.use_nodes=True

bg=world.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value=(.012,.014,.018,1)
bg.inputs["Strength"].default_value=.35


# ============================================================
# SAVE
# ============================================================

os.makedirs(os.path.dirname(OUT),exist_ok=True)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT)

print("")
print("="*68)
print("ENFLESHED LOWER LAYER ENVIRONMENT KIT V2 GENERATED")
print(OUT)
print("="*68)
