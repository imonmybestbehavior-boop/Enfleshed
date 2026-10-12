import bpy
import os
from math import radians

OUTPUT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/storefront_kit_v1.blend"
)

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

def clean_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)

def make_collection(name):
    coll = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(coll)
    return coll

def link_to_collection(obj, coll):
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)

def make_material(name, base=(0.8, 0.8, 0.8, 1.0), rough=0.7, metallic=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    return mat

def assign_mat(obj, mat):
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)

def cube(name, size, loc, coll, mat=None):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    link_to_collection(obj, coll)
    if mat:
        assign_mat(obj, mat)
    return obj

def plane(name, size, loc, coll, mat=None):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0] / 2.0, size[1] / 2.0, 1.0)
    link_to_collection(obj, coll)
    if mat:
        assign_mat(obj, mat)
    return obj

def bevel(obj, amount=0.03, segments=2):
    mod = obj.modifiers.new(name="Bevel", type="BEVEL")
    mod.width = amount
    mod.segments = segments

def lamp_area(name, loc, energy=2500, size=6):
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.shape = "RECTANGLE"
    data.size = size
    data.size_y = size * 0.6
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler[0] = radians(90)
    return obj

def camera(name, loc, rot):
    cam = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, cam)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    return obj

# ------------------------------------------------------------
# Scene setup
# ------------------------------------------------------------

clean_scene()
kit = make_collection("STOREFRONT_KIT")

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.eevee.taa_render_samples = 32
scene.eevee.taa_samples = 16

# Materials
mat_plaster_light = make_material("Plaster_Light", (0.73, 0.71, 0.67, 1), 0.9, 0.0)
mat_plaster_dark = make_material("Plaster_Dark", (0.47, 0.43, 0.38, 1), 0.88, 0.0)
mat_stone = make_material("Stone_Dusty", (0.60, 0.56, 0.50, 1), 0.92, 0.0)
mat_wood = make_material("Wood_Faded", (0.42, 0.31, 0.22, 1), 0.75, 0.0)
mat_wood_pale = make_material("Wood_Pale", (0.63, 0.52, 0.40, 1), 0.72, 0.0)
mat_metal = make_material("Metal_Dark", (0.18, 0.20, 0.22, 1), 0.45, 0.1)
mat_rust = make_material("Metal_Rust", (0.42, 0.23, 0.14, 1), 0.8, 0.0)
mat_red = make_material("Cloth_FadedRed", (0.44, 0.16, 0.14, 1), 0.82, 0.0)
mat_glass = make_material("Glass_Dirty", (0.60, 0.67, 0.74, 1), 0.05, 0.0)

# Ground pad
ground = plane("KIT_GROUND", (90, 70), (0, 0, 0), kit, mat_stone)
ground.rotation_euler[0] = radians(90)

# ------------------------------------------------------------
# Module builders
# ------------------------------------------------------------

def facade_frame(origin=(0, 0, 0), width=10, depth=1.5, height=16, interior_depth=8):
    x, y, z = origin

    floor = cube("Floor", (width, interior_depth, 0.25), (x, y + interior_depth / 2, z + 0.125), kit, mat_stone)
    front_l = cube("Front_Left", (1.0, depth, 10), (x - width / 2 + 0.5, y, z + 5), kit, mat_plaster_dark)
    front_r = cube("Front_Right", (1.0, depth, 10), (x + width / 2 - 0.5, y, z + 5), kit, mat_plaster_dark)
    lintel = cube("Lintel", (width, depth, 2.0), (x, y, z + 15), kit, mat_plaster_dark)
    back = cube("BackWall", (width, 0.5, height), (x, y + interior_depth, z + height / 2), kit, mat_plaster_light)
    side_l = cube("SideWall_L", (0.5, interior_depth, height), (x - width / 2, y + interior_depth / 2, z + height / 2), kit, mat_plaster_light)
    side_r = cube("SideWall_R", (0.5, interior_depth, height), (x + width / 2, y + interior_depth / 2, z + height / 2), kit, mat_plaster_light)

    for obj in (front_l, front_r, lintel, back, side_l, side_r):
        bevel(obj, 0.04, 2)

    return floor

def build_general_store(origin):
    x, y, z = origin
    facade_frame(origin, width=12, interior_depth=9, height=16)

    window_l = cube("Window_L", (3.0, 0.25, 4.5), (x - 3.6, y + 0.15, z + 4.5), kit, mat_glass)
    door = cube("Door", (2.2, 0.25, 5.4), (x, y + 0.16, z + 2.7), kit, mat_wood)
    window_r = cube("Window_R", (3.0, 0.25, 4.5), (x + 3.6, y + 0.15, z + 4.5), kit, mat_glass)
    sign = cube("SignBand", (9.0, 0.3, 1.1), (x, y + 0.2, z + 11.8), kit, mat_red)
    canopy = cube("Awning", (10.0, 2.2, 0.25), (x, y + 1.25, z + 10.4), kit, mat_red)

    counter = cube("Counter", (7.0, 1.3, 1.2), (x, y + 4.0, z + 0.6), kit, mat_wood_pale)
    shelf_l = cube("Shelf_L", (1.2, 0.4, 5.5), (x - 4.3, y + 7.2, z + 2.75), kit, mat_wood)
    shelf_r = cube("Shelf_R", (1.2, 0.4, 5.5), (x + 4.3, y + 7.2, z + 2.75), kit, mat_wood)

    for obj in (window_l, door, window_r, sign, canopy, counter, shelf_l, shelf_r):
        bevel(obj, 0.03, 2)

def build_service_front(origin):
    x, y, z = origin
    facade_frame(origin, width=10, interior_depth=7, height=15)

    opening = cube("CounterFront", (6.4, 0.45, 1.3), (x, y + 0.15, z + 1.3), kit, mat_wood_pale)
    sign = cube("ServiceSign", (6.8, 0.25, 1.0), (x, y + 0.1, z + 10.5), kit, mat_metal)
    shutter_l = cube("ShutterL", (1.3, 0.25, 5.0), (x - 3.7, y + 0.11, z + 4.2), kit, mat_rust)
    shutter_r = cube("ShutterR", (1.3, 0.25, 5.0), (x + 3.7, y + 0.11, z + 4.2), kit, mat_rust)
    table = cube("WorkTable", (5.5, 1.8, 1.1), (x, y + 4.0, z + 0.55), kit, mat_wood)

    for obj in (opening, sign, shutter_l, shutter_r, table):
        bevel(obj, 0.03, 2)

def build_boarded_shop(origin):
    x, y, z = origin
    facade_frame(origin, width=11, interior_depth=8, height=15)

    door = cube("DoorBoarded", (2.0, 0.25, 5.0), (x, y + 0.15, z + 2.5), kit, mat_wood)
    board1 = cube("Board1", (4.0, 0.18, 0.35), (x - 2.9, y + 0.2, z + 4.7), kit, mat_wood_pale)
    board2 = cube("Board2", (4.0, 0.18, 0.35), (x + 2.9, y + 0.2, z + 3.6), kit, mat_wood_pale)
    board1.rotation_euler[1] = radians(12)
    board2.rotation_euler[1] = radians(-10)
    sign = cube("BoardedSign", (8.2, 0.25, 1.0), (x, y + 0.1, z + 11.1), kit, mat_rust)

    pile1 = cube("Crate1", (1.0, 1.0, 1.0), (x - 2.5, y + 4.8, z + 0.5), kit, mat_wood)
    pile2 = cube("Crate2", (1.0, 1.0, 1.0), (x - 1.5, y + 4.8, z + 0.5), kit, mat_wood)
    pile3 = cube("Crate3", (1.0, 1.0, 1.0), (x - 2.0, y + 4.8, z + 1.5), kit, mat_wood)

    for obj in (door, board1, board2, sign, pile1, pile2, pile3):
        bevel(obj, 0.03, 2)

def build_market_stall_front(origin):
    x, y, z = origin
    facade_frame(origin, width=9, interior_depth=6, height=14)

    counter = cube("StallCounter", (7.2, 1.2, 1.2), (x, y + 1.3, z + 0.6), kit, mat_wood_pale)
    awning = cube("StallAwning", (8.2, 2.2, 0.2), (x, y + 1.0, z + 8.6), kit, mat_red)
    pole1 = cube("Pole1", (0.2, 0.2, 6.5), (x - 3.6, y + 1.0, z + 3.25), kit, mat_metal)
    pole2 = cube("Pole2", (0.2, 0.2, 6.5), (x + 3.6, y + 1.0, z + 3.25), kit, mat_metal)
    shelf = cube("StallShelf", (6.0, 0.5, 1.8), (x, y + 4.3, z + 1.7), kit, mat_wood)

    for obj in (counter, awning, pole1, pole2, shelf):
        bevel(obj, 0.03, 2)

def build_upper_walk_module(origin):
    x, y, z = origin
    floor = cube("UpperWalk", (9.0, 3.0, 0.35), (x, y, z + 0.175), kit, mat_metal)
    rail_l = cube("RailL", (9.0, 0.15, 1.0), (x, y - 1.4, z + 0.8), kit, mat_metal)
    rail_r = cube("RailR", (9.0, 0.15, 1.0), (x, y + 1.4, z + 0.8), kit, mat_metal)
    brace1 = cube("Brace1", (0.2, 1.5, 0.2), (x - 3.0, y, z - 1.0), kit, mat_metal)
    brace2 = cube("Brace2", (0.2, 1.5, 0.2), (x + 3.0, y, z - 1.0), kit, mat_metal)
    brace1.rotation_euler[0] = radians(60)
    brace2.rotation_euler[0] = radians(60)
    for obj in (floor, rail_l, rail_r, brace1, brace2):
        bevel(obj, 0.02, 2)

# ------------------------------------------------------------
# Build the kit layout
# ------------------------------------------------------------

build_general_store((-28, -18, 0))
build_service_front((-12, -18, 0))
build_boarded_shop((4, -18, 0))
build_market_stall_front((19, -18, 0))

build_general_store((-28, 4, 0))
build_service_front((-12, 4, 0))
build_boarded_shop((4, 4, 0))
build_market_stall_front((19, 4, 0))

build_upper_walk_module((-28, 22, 7))
build_upper_walk_module((-14, 22, 7))
build_upper_walk_module((0, 22, 7))
build_upper_walk_module((14, 22, 7))

# Lighting and cameras
lamp_area("KeyLight", (-8, -22, 22), energy=3800, size=11)
lamp_area("FillLight", (18, 18, 18), energy=2000, size=9)
lamp_area("BackLight", (-30, 25, 16), energy=1800, size=8)

cam_main = camera(
    "CAMERA_STOREFRONT_OVERVIEW",
    (0, -48, 16),
    (radians(76), 0, 0),
)
cam_close = camera(
    "CAMERA_STOREFRONT_CLOSE",
    (-10, -6, 8),
    (radians(82), 0, radians(-30)),
)
scene.camera = cam_main

# Save
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)

print("Saved storefront kit to:", OUTPUT)
