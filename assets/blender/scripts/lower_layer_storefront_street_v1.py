"""Build the Enfleshed Lower Layer storefront street review scene.

Run against storefront_kit_v2.blend with Blender 5.2:
  blender --background storefront_kit_v2.blend --python lower_layer_street_v1.py -- --output-dir DIR --render

The source storefront blend is opened read-only and a new street scene is saved.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", default=str(Path.home() / "Projects/Enfleshed/assets/blender/generated/lower_layer_storefront_street_v1"))
parser.add_argument("--render", action="store_true")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
output_dir = Path(args.output_dir)
output_dir.mkdir(parents=True, exist_ok=True)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world.color = (0.018, 0.022, 0.026)
scene.view_settings.view_transform = "AgX"
scene.unit_settings.system = "METRIC"

# Remove only V2's review ground, lights and cameras. The six approved shop collections remain.
review = bpy.data.collections.get("00 REVIEW ONLY - ground lights cameras")
if review:
    for obj in list(review.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(review)

for light in list(bpy.data.lights):
    if light.users == 0:
        bpy.data.lights.remove(light)
for camera_data in list(bpy.data.cameras):
    if camera_data.users == 0:
        bpy.data.cameras.remove(camera_data)

environment = bpy.data.collections.new("STREET ENVIRONMENT")
scene.collection.children.link(environment)
route_review = bpy.data.collections.new("REVIEW ROUTE OVERLAYS - hide for beauty")
scene.collection.children.link(route_review)


def material(name, color, roughness=0.8, metallic=0.0, emission=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*color, 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 2.5
    return mat


materials = {
    "ancient": material("Street Ancient Stone", (0.19, 0.205, 0.20), 0.95),
    "plaster": material("Street Patched Plaster", (0.36, 0.33, 0.28), 0.92),
    "brick": material("Street Repair Brick", (0.31, 0.135, 0.075), 0.92),
    "wood": material("Street Old Wood", (0.17, 0.085, 0.038), 0.88),
    "metal": material("Street Black Iron", (0.045, 0.055, 0.055), 0.55, 0.55),
    "cloth": material("Street Faded Cloth", (0.27, 0.075, 0.055), 0.9),
    "glass": material("Street Dirty Glass", (0.075, 0.15, 0.14), 0.35, 0.05),
    "street": material("Street Dust", (0.15, 0.145, 0.13), 1.0),
    "route_main": material("REVIEW Main Route", (0.55, 0.09, 0.045), 0.55, emission=(0.45, 0.035, 0.015)),
    "route_secret": material("REVIEW Discovered Route", (0.035, 0.38, 0.25), 0.55, emission=(0.015, 0.4, 0.18)),
}


def link_object(obj, collection=environment):
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def box(name, location, dimensions, mat="ancient", bevel=0.035, collection=environment, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = link_object(bpy.context.object, collection)
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(materials[mat] if isinstance(mat, str) else mat)
    if bevel:
        modifier = obj.modifiers.new("Soft worn edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def cylinder(name, location, radius, depth, mat="metal", rotation=(0, 0, 0), collection=environment):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = link_object(bpy.context.object, collection)
    obj.name = name
    obj.data.materials.append(materials[mat])
    return obj


def beam(name, point_a, point_b, radius=0.035, mat="metal", collection=environment):
    a = Vector(point_a)
    b = Vector(point_b)
    obj = cylinder(name, (a + b) / 2, radius, (b - a).length, mat, collection=collection)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def add_text(name, body, location, size=0.22, color="plaster", rotation=(math.pi / 2, 0, 0), collection=route_review):
    bpy.ops.object.text_add(location=location, rotation=rotation)
    obj = link_object(bpy.context.object, collection)
    obj.name = name
    obj.data.body = body
    obj.data.align_x = "CENTER"
    obj.data.size = size
    obj.data.extrude = 0.008
    obj.data.materials.append(materials[color])
    return obj


def area_light(name, location, target, energy, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.color = color
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    environment.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def camera(name, location, target, lens=36):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.sensor_width = 36
    obj = bpy.data.objects.new(name, data)
    environment.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def upper_house(center_x, width, base_z, height, setback, material_name, windows=2, overhang=0.0):
    depth = 4.0 + overhang
    front_y = 1.85 - overhang / 2 + setback
    box("Later upper room", (center_x, front_y, base_z + height / 2), (width, depth, height), material_name, 0.045)
    box("Timber course", (center_x, -0.08 + setback - overhang, base_z + 0.15), (width + 0.18, 0.18, 0.23), "wood")
    for index in range(windows):
        x = center_x + (index - (windows - 1) / 2) * min(1.45, width / max(windows, 1) * 0.65)
        box("Deep upper window", (x, -0.19 + setback - overhang, base_z + height * 0.58), (0.62, 0.16, 0.85), "glass", 0.018)
        for side in (-0.38, 0.38):
            box("Upper window shutter", (x + side, -0.29 + setback - overhang, base_z + height * 0.58), (0.20, 0.09, 0.92), "wood", 0.012)
    for x in (center_x - width / 2 + 0.25, center_x + width / 2 - 0.25):
        box("Vertical retrofit timber", (x, -0.04 + setback - overhang, base_z + height / 2), (0.16, 0.22, height), "wood")


def balcony(center_x, width, y, z):
    box("Occupied timber balcony", (center_x, y, z), (width, 1.2, 0.16), "wood")
    for x in (center_x - width / 2 + 0.12, center_x + width / 2 - 0.12):
        beam("Balcony diagonal brace", (x, y + 0.35, z - 1.35), (x, y - 0.2, z), 0.055, "wood")
        box("Balcony railing post", (x, y - 0.48, z + 0.58), (0.10, 0.10, 1.15), "wood")
    box("Balcony top rail", (center_x, y - 0.48, z + 1.12), (width, 0.10, 0.10), "wood")
    for x_index in range(max(2, int(width / 0.5))):
        x = center_x - width / 2 + 0.25 + x_index * ((width - 0.5) / max(1, int(width / 0.5) - 1))
        box("Balcony railing", (x, y - 0.48, z + 0.58), (0.045, 0.065, 1.0), "metal", 0.008)


def stairs(name, start, end, steps, width, direction="y"):
    sx, sy, sz = start
    ex, ey, ez = end
    for index in range(steps):
        factor = index / max(steps - 1, 1)
        x = sx + (ex - sx) * factor
        y = sy + (ey - sy) * factor
        z = sz + (ez - sz) * factor
        tread_depth = abs(ey - sy) / steps + 0.08 if direction == "y" else width
        tread_width = width if direction == "y" else abs(ex - sx) / steps + 0.08
        box(name + " tread", (x, y, z), (tread_width, tread_depth, 0.13), "wood", 0.012)


# Arrange the approved V2 fronts with a deliberate alley gap between repair and dispensary.
shop_positions = {
    "01 Hearth food counter": -10.4,
    "02 Ration and dry goods": -6.2,
    "03 Tool repair workshop": -2.0,
    "04 Lower dispensary": 3.2,
    "05 Cloth and mending": 7.4,
    "06 Residential through passage": 11.6,
}
for collection_name, x in shop_positions.items():
    collection = bpy.data.collections.get(collection_name)
    root = next((obj for obj in collection.objects if obj.type == "EMPTY"), None)
    if root:
        root.location.x = x
        root.location.y = 0
        root.hide_render = False

# Street and old superstructure foundations.
box("Main street paving", (0, -3.65, -0.19), (31, 7.0, 0.30), "street", 0)
box("North ancient footing", (0, 2.95, -0.45), (31, 6.1, 0.7), "ancient", 0)
box("Opposite ancient footing", (0, -8.05, -0.45), (31, 2.0, 0.7), "ancient", 0)
for x in range(-15, 16):
    if x % 2 == 0:
        box("Uneven street slab", (x, -3.7 + 0.08 * ((x // 2) % 3), -0.015), (1.75, 2.1, 0.08), "ancient", 0.015)

# Upper growth above every shop: uneven heights, setbacks and later additions.
upper_house(-10.4, 4.0, 3.35, 3.1, 0.05, "plaster", 2, 0.35)
upper_house(-6.2, 4.0, 3.35, 4.4, 0.12, "brick", 2, 0.15)
upper_house(-2.0, 4.0, 3.35, 3.4, 0.02, "plaster", 2, 0.55)
upper_house(3.2, 4.0, 3.35, 4.9, 0.17, "ancient", 2, 0.10)
upper_house(7.4, 4.0, 3.35, 3.7, 0.04, "brick", 2, 0.45)
upper_house(11.6, 4.0, 3.35, 5.2, 0.10, "plaster", 2, 0.25)
upper_house(-6.0, 3.3, 7.55, 2.7, 0.65, "plaster", 1, 0.0)
upper_house(3.35, 3.2, 8.05, 2.9, 0.72, "brick", 1, 0.0)
upper_house(11.7, 3.4, 8.4, 2.6, 0.52, "ancient", 1, 0.0)
balcony(-2.0, 3.3, -0.62, 5.25)
balcony(7.4, 3.4, -0.65, 5.7)

# Opposite side is an older defensive/service wall with inhabited additions.
box("Opposite old retaining wall", (0, -8.0, 3.1), (31, 1.1, 6.2), "ancient")
for x in (-12.0, -7.5, -3.2, 1.8, 6.7, 11.6):
    box("Opposite deep service recess", (x, -7.39, 1.35), (2.2, 0.16, 2.5), "metal", 0.02)
    box("Opposite repaired lintel", (x, -7.24, 2.74), (2.7, 0.34, 0.35), "brick")
for x, z, width in ((-10.0, 6.7, 5.2), (-3.0, 7.0, 4.4), (4.1, 6.9, 5.3), (10.5, 7.3, 4.5)):
    box("Opposite attached habitation", (x, -7.35, z), (width, 2.6, 2.8), "plaster")
    box("Opposite habitation window", (x, -5.98, z), (0.85, 0.12, 0.9), "glass")
    balcony(x, width * 0.74, -5.72, z - 0.65)

# Guard choke point: the main street remains usable but exposed and indirect.
box("Checkpoint tower west", (4.7, -7.0, 4.25), (2.1, 2.8, 8.5), "ancient")
box("Checkpoint tower east", (8.0, -7.0, 4.25), (2.1, 2.8, 8.5), "ancient")
box("Checkpoint overhead watchroom", (6.35, -6.7, 7.45), (5.4, 2.2, 2.1), "plaster")
box("Checkpoint barrier left", (5.0, -4.05, 0.65), (3.0, 0.26, 1.3), "wood")
box("Checkpoint barrier right", (8.25, -3.2, 0.65), (3.2, 0.26, 1.3), "wood", rotation=(0, 0, 0.10))
for x in (3.6, 4.25, 5.0, 7.0, 7.75, 8.9):
    beam("Checkpoint iron spike", (x, -4.03, 1.25), (x, -4.03, 1.95), 0.035)
box("Guard inspection desk", (6.3, -5.45, 0.82), (1.5, 0.7, 1.1), "wood")
box("Checkpoint warning cloth", (6.35, -5.76, 3.9), (3.0, 0.05, 1.0), "cloth", 0.015)
add_text("Checkpoint warning", "INSPECTION / CURFEW", (6.35, -5.81, 4.0), 0.22, "plaster")

# Court 17 route: passage -> rear courtyard -> stairs -> catwalk -> alley -> street.
box("Court 17 rear paving", (10.3, 7.0, -0.10), (7.0, 7.2, 0.18), "ancient", 0)
box("Court east wall", (14.0, 7.0, 3.1), (0.55, 7.2, 6.2), "ancient")
box("Court rear wall", (10.3, 10.65, 3.1), (7.9, 0.55, 6.2), "ancient")
box("Court upper residence", (11.3, 10.0, 7.2), (5.0, 2.1, 2.6), "brick")
box("Court cistern", (9.8, 8.4, 0.65), (1.6, 1.25, 1.3), "metal")
cylinder("Court water barrel", (12.6, 8.9, 0.65), 0.55, 1.3, "wood")
for x, y, z in ((8.2, 6.2, 0.6), (8.7, 6.3, 0.5), (8.45, 6.6, 1.4)):
    box("Court storage crate", (x, y, z), (0.9, 0.9, 0.9), "wood")

stairs("Court stair", (13.15, 5.0, 0.12), (13.15, 8.1, 3.45), 15, 1.05, "y")
beam("Court stair rail", (12.58, 4.9, 0.9), (12.58, 8.15, 4.25), 0.04, "metal")
box("Courtyard landing", (12.2, 8.5, 3.65), (2.4, 1.1, 0.17), "wood")
box("Discovered route catwalk", (6.7, 8.45, 3.65), (9.2, 1.15, 0.17), "metal")
for x in (2.3, 4.5, 6.7, 8.9, 11.1):
    beam("Catwalk wall brace", (x, 8.85, 2.25), (x, 8.45, 3.65), 0.045, "metal")
    box("Catwalk rail post", (x, 7.93, 4.2), (0.07, 0.07, 1.15), "metal", 0.008)
box("Catwalk top rail", (6.7, 7.93, 4.75), (9.2, 0.08, 0.08), "metal", 0.008)

# The narrow alley is the actual western exit of the discovered route.
box("Alley west wall", (0.52, 4.3, 3.0), (0.42, 8.5, 6.0), "ancient")
box("Alley east wall", (1.18, 6.3, 3.0), (0.35, 4.4, 6.0), "brick")
stairs("Alley drop stair", (1.85, 8.25, 3.55), (1.85, 4.25, 0.12), 17, 1.1, "y")
beam("Alley stair handrail", (2.45, 8.3, 4.3), (2.45, 4.2, 0.9), 0.04, "metal")
box("Alley rain gutter", (0.7, 4.0, 4.9), (0.12, 6.6, 0.12), "metal")
box("Alley street threshold", (0.85, 0.25, 2.0), (1.15, 0.45, 4.0), "ancient")

# Overhead density: bridges, pipes, clothes lines and retrofit cabling.
box("Street room bridge", (-8.4, -3.65, 7.6), (3.2, 5.6, 2.3), "brick")
box("Bridge under-beam", (-8.4, -3.65, 6.34), (3.6, 5.8, 0.22), "wood")
for x in (-9.7, -7.1):
    beam("Bridge brace", (x, -0.9, 5.0), (x, -2.7, 6.3), 0.07, "wood")
for x in (-12, -5, 0, 10.5):
    beam("Street utility pipe", (x, -0.45, 0.2), (x, -0.45, 7.2), 0.055, "metal")
for z in (5.2, 6.4):
    beam("Overhead cable", (-14.0, -0.8, z), (13.8, -6.8, z + 0.35), 0.018, "metal")
for x, color in ((-4.2, "cloth"), (-2.4, "plaster"), (-0.6, "brick")):
    box("Hanging laundry", (x, -3.15, 5.65), (1.0, 0.04, 1.35), color, 0.015, rotation=(0.0, 0.06, 0.02))

# Route overlays are hidden in beauty renders and enabled only for the diagram render.
for index, x in enumerate(range(-13, 14)):
    box("MAIN ROUTE marker", (x, -3.7 + 0.55 * math.sin(index * 0.6), 0.06), (0.65, 0.20, 0.025), "route_main", 0.01, route_review)
secret_points = [
    (11.6, -1.1, 0.06), (11.6, 0.8, 0.06), (11.6, 2.7, 0.06),
    (11.6, 4.8, 0.06), (12.5, 6.4, 1.7), (11.0, 8.45, 3.78),
    (8.7, 8.45, 3.78), (6.5, 8.45, 3.78), (4.3, 8.45, 3.78),
    (2.2, 8.0, 3.65), (1.85, 6.4, 2.15), (1.4, 4.2, 0.15), (0.9, 1.1, 0.10),
]
for index, point in enumerate(secret_points):
    box("DISCOVERED ROUTE marker", point, (0.42, 0.42, 0.045), "route_secret", 0.02, route_review)
add_text("Main route label", "OBVIOUS ROUTE: EXPOSED CHECKPOINT", (6.3, -2.1, 0.14), 0.25, "route_main")
add_text("Secret route label", "COURT 17 SHORTCUT", (10.5, 6.2, 0.15), 0.25, "route_secret")
route_review.hide_render = True

# Lighting is dim enough to retain the Lower Layer but clear enough for review.
area_light("Street ambient", (0, -2, 15), (0, -2.5, 2), 1800, (0.39, 0.48, 0.58), 14)
area_light("Street warm bounce", (-8, -2, 6), (-3, 0, 2), 900, (1.0, 0.50, 0.25), 8)
area_light("Courtyard light", (10, 8, 12), (8, 7, 2), 1200, (0.50, 0.62, 0.75), 8)
area_light("Courtyard route fill", (6.8, 5.1, 7.2), (10.8, 8.0, 2.2), 850, (0.44, 0.55, 0.66), 6)
for x in (-10.4, -6.2, -2.0, 3.2, 7.4, 11.6):
    data = bpy.data.lights.new("Shop spill light", "AREA")
    data.energy = 90
    data.color = (1.0, 0.50, 0.23)
    data.shape = "RECTANGLE"
    data.size = 1.8
    data.size_y = 1.0
    obj = bpy.data.objects.new("Shop spill light", data)
    environment.objects.link(obj)
    obj.location = (x, -0.9, 2.0)
    obj.rotation_euler = (math.pi / 2, 0, 0)

cameras = {
    "CAM 01 Street Arrival": camera("CAM 01 Street Arrival", (-14.2, -4.5, 2.1), (2.0, -2.5, 2.9), 30),
    "CAM 02 Shops Player Height": camera("CAM 02 Shops Player Height", (-4.8, -5.7, 1.75), (1.0, 0.2, 2.1), 35),
    "CAM 03 Checkpoint": camera("CAM 03 Checkpoint", (0.0, -3.55, 2.1), (6.3, -3.8, 1.3), 40),
    "CAM 04 Passage Entry": camera("CAM 04 Passage Entry", (9.4, -5.3, 1.9), (11.6, 1.5, 1.65), 33),
    "CAM 05 Secret Courtyard": camera("CAM 05 Secret Courtyard", (7.2, 4.7, 6.2), (11.1, 7.9, 2.2), 27),
    "CAM 06 Catwalk Route": camera("CAM 06 Catwalk Route", (3.6, 6.1, 5.25), (8.8, 8.45, 3.55), 30),
    "CAM 07 Overhead Layout": camera("CAM 07 Overhead Layout", (0.0, 0.7, 36.0), (0.0, 0.7, 0.0), 28),
}
scene.camera = cameras["CAM 01 Street Arrival"]

instructions = bpy.data.texts.get("START HERE") or bpy.data.texts.new("START HERE")
instructions.clear()
instructions.write(
    "ENFLESHED LOWER LAYER STOREFRONT STREET V1\n"
    "Use Numpad 0 for the active camera. Choose cameras from the Outliner.\n"
    "The street is the obvious route; its inspection checkpoint is exposed and slow.\n"
    "Court 17 is the discovered route: passage -> courtyard -> stairs -> catwalk -> alley.\n"
    "REVIEW ROUTE OVERLAYS is hidden for beauty renders. Enable it to inspect route markers.\n"
    "This is an art and navigation review scene. It is not optimized or collision-tested for Roblox.\n"
)
scene["README"] = "Playable-layout art review. Approved Storefront V2 collections preserved. Main route: street checkpoint. Discovered route: Court 17 passage, courtyard, catwalk and alley."

bpy.context.preferences.filepaths.save_version = 0
blend_path = output_dir / "lower_layer_storefront_street_v1.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

if args.render:
    for index, (name, cam) in enumerate(cameras.items(), start=1):
        scene.camera = cam
        scene.render.filepath = str(output_dir / f"{index:02d}_{name[7:].lower().replace(' ', '_')}.png")
        bpy.ops.render.render(write_still=True)
    route_review.hide_render = False
    scene.camera = cameras["CAM 07 Overhead Layout"]
    scene.render.filepath = str(output_dir / "08_route_diagram.png")
    bpy.ops.render.render(write_still=True)
    route_review.hide_render = True
    scene.camera = cameras["CAM 01 Street Arrival"]
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

report = {
    "blender": bpy.app.version_string,
    "source": "storefront_kit_v2.blend",
    "storefront_collections": list(shop_positions),
    "main_route": "street through exposed inspection checkpoint",
    "discovered_route": "Court 17 passage -> courtyard -> stair -> catwalk -> alley -> street",
    "cameras": list(cameras),
    "mesh_objects": sum(obj.type == "MESH" for obj in scene.objects),
    "limitations": ["art review geometry", "not optimized", "not Roblox collision tested"],
}
(output_dir / "validation.json").write_text(json.dumps(report, indent=2))
print("STREET V1 COMPLETE", report)
