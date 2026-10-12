import bpy
import os
import math

# ============================================================
# ENFLESHED
# Lower Layer Material Library V1
# ============================================================

OUTPUT_PATH = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/"
    "lower_layer_material_library_v1.blend"
)

# ------------------------------------------------------------
# CLEAN SCENE
# ------------------------------------------------------------

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

for datablocks in (
    bpy.data.materials,
    bpy.data.meshes,
    bpy.data.curves,
    bpy.data.cameras,
    bpy.data.lights,
):
    pass


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

def rgba(hex_string):
    """Convert hex color to Blender RGBA."""
    hex_string = hex_string.lstrip("#")
    r = int(hex_string[0:2], 16) / 255.0
    g = int(hex_string[2:4], 16) / 255.0
    b = int(hex_string[4:6], 16) / 255.0
    return (r, g, b, 1.0)


def new_material(name):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True

    nodes = mat.node_tree.nodes
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (700, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (420, 0)

    mat.node_tree.links.new(
        bsdf.outputs["BSDF"],
        output.inputs["Surface"]
    )

    return mat, nodes, mat.node_tree.links, bsdf


def add_noise(nodes, scale, detail, roughness, location=(-600, 0)):
    noise = nodes.new("ShaderNodeTexNoise")
    noise.location = location
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    noise.inputs["Roughness"].default_value = roughness
    return noise


def add_ramp(nodes, colors, location=(-200, 120)):
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.location = location

    color_ramp = ramp.color_ramp

    while len(color_ramp.elements) > 2:
        color_ramp.elements.remove(color_ramp.elements[-1])

    first = color_ramp.elements[0]
    last = color_ramp.elements[1]

    first.position = colors[0][0]
    first.color = colors[0][1]

    last.position = colors[-1][0]
    last.color = colors[-1][1]

    for pos, color in colors[1:-1]:
        element = color_ramp.elements.new(pos)
        element.color = color

    return ramp


def procedural_surface(
    name,
    dark,
    mid,
    light,
    scale=5.0,
    detail=6.0,
    noise_roughness=0.7,
    surface_roughness=0.8,
    bump_strength=0.25,
    bump_distance=0.15,
    metallic=0.0,
):
    mat, nodes, links, bsdf = new_material(name)

    noise = add_noise(
        nodes,
        scale,
        detail,
        noise_roughness,
        (-700, 80)
    )

    ramp = add_ramp(
        nodes,
        [
            (0.20, dark),
            (0.52, mid),
            (0.82, light),
        ],
        (-300, 180)
    )

    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])

    bump = nodes.new("ShaderNodeBump")
    bump.location = (160, -170)
    bump.inputs["Strength"].default_value = bump_strength
    bump.inputs["Distance"].default_value = bump_distance

    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    rough_noise = add_noise(
        nodes,
        scale * 1.8,
        max(2.0, detail - 1),
        0.65,
        (-500, -300)
    )

    rough_ramp = add_ramp(
        nodes,
        [
            (0.15, (surface_roughness - 0.12,) * 3 + (1.0,)),
            (0.85, (min(surface_roughness + 0.12, 1.0),) * 3 + (1.0,)),
        ],
        (-100, -320)
    )

    links.new(rough_noise.outputs["Fac"], rough_ramp.inputs["Fac"])
    links.new(rough_ramp.outputs["Color"], bsdf.inputs["Roughness"])

    bsdf.inputs["Metallic"].default_value = metallic

    return mat


# ------------------------------------------------------------
# MATERIAL 01
# ANCIENT DARK STONE
# ------------------------------------------------------------

ancient_stone = procedural_surface(
    "LL_Ancient_Dark_Stone",
    rgba("#111417"),
    rgba("#252a2d"),
    rgba("#3a4042"),
    scale=3.0,
    detail=8.0,
    surface_roughness=0.88,
    bump_strength=0.42,
    bump_distance=0.22,
)


# ------------------------------------------------------------
# MATERIAL 02
# AGED HUMAN MASONRY
# ------------------------------------------------------------

aged_masonry = procedural_surface(
    "LL_Aged_Masonry",
    rgba("#332f2a"),
    rgba("#575047"),
    rgba("#756c5e"),
    scale=7.0,
    detail=7.0,
    surface_roughness=0.92,
    bump_strength=0.48,
    bump_distance=0.18,
)


# ------------------------------------------------------------
# MATERIAL 03
# WORN PLASTER
# ------------------------------------------------------------

worn_plaster = procedural_surface(
    "LL_Worn_Plaster",
    rgba("#504b42"),
    rgba("#777064"),
    rgba("#9a9283"),
    scale=10.0,
    detail=5.0,
    surface_roughness=0.86,
    bump_strength=0.20,
    bump_distance=0.08,
)


# ------------------------------------------------------------
# MATERIAL 04
# BLACKENED STRUCTURAL IRON
# ------------------------------------------------------------

blackened_iron = procedural_surface(
    "LL_Blackened_Iron",
    rgba("#090a0a"),
    rgba("#17191a"),
    rgba("#292b2a"),
    scale=8.0,
    detail=5.0,
    surface_roughness=0.58,
    bump_strength=0.16,
    bump_distance=0.06,
    metallic=0.88,
)


# ------------------------------------------------------------
# MATERIAL 05
# RUSTED PATCH METAL
# ------------------------------------------------------------

rusted_metal = procedural_surface(
    "LL_Rusted_Patch_Metal",
    rgba("#251812"),
    rgba("#633722"),
    rgba("#9a6441"),
    scale=5.5,
    detail=8.0,
    surface_roughness=0.72,
    bump_strength=0.30,
    bump_distance=0.10,
    metallic=0.70,
)


# ------------------------------------------------------------
# MATERIAL 06
# WORN TIMBER
# ------------------------------------------------------------

worn_timber = procedural_surface(
    "LL_Worn_Timber",
    rgba("#211a15"),
    rgba("#49372a"),
    rgba("#705744"),
    scale=4.0,
    detail=5.0,
    surface_roughness=0.84,
    bump_strength=0.30,
    bump_distance=0.10,
)


# ------------------------------------------------------------
# MATERIAL 07
# STREET STONE
# ------------------------------------------------------------

street_stone = procedural_surface(
    "LL_Street_Stone",
    rgba("#202120"),
    rgba("#3b3b38"),
    rgba("#595851"),
    scale=9.0,
    detail=7.0,
    surface_roughness=0.90,
    bump_strength=0.38,
    bump_distance=0.14,
)


# ------------------------------------------------------------
# MATERIAL 08
# FADED MILITARY RED
# ------------------------------------------------------------

military_red = procedural_surface(
    "LL_Faded_Military_Red",
    rgba("#351413"),
    rgba("#692523"),
    rgba("#8b4138"),
    scale=7.0,
    detail=6.0,
    surface_roughness=0.76,
    bump_strength=0.18,
    bump_distance=0.07,
)


# ------------------------------------------------------------
# MATERIAL 09
# SOOT / GRIME
# ------------------------------------------------------------

soot_grime = procedural_surface(
    "LL_Soot_Grime",
    rgba("#050505"),
    rgba("#12110f"),
    rgba("#28251f"),
    scale=12.0,
    detail=9.0,
    surface_roughness=0.96,
    bump_strength=0.12,
    bump_distance=0.04,
)


# ------------------------------------------------------------
# MATERIAL 10
# FRACTURED MASONRY INTERIOR
# ------------------------------------------------------------

fracture_masonry = procedural_surface(
    "LL_Fracture_Masonry",
    rgba("#514b40"),
    rgba("#817767"),
    rgba("#aaa08c"),
    scale=13.0,
    detail=9.0,
    surface_roughness=0.96,
    bump_strength=0.58,
    bump_distance=0.20,
)


# ------------------------------------------------------------
# MATERIAL 11
# FRACTURED / EXPOSED METAL
# ------------------------------------------------------------

fracture_metal = procedural_surface(
    "LL_Fracture_Metal",
    rgba("#2a2925"),
    rgba("#656158"),
    rgba("#aaa497"),
    scale=14.0,
    detail=5.0,
    surface_roughness=0.50,
    bump_strength=0.22,
    bump_distance=0.06,
    metallic=0.92,
)


# ------------------------------------------------------------
# PREVIEW COLLECTION
# ------------------------------------------------------------

preview_collection = bpy.data.collections.new("MATERIAL_PREVIEWS")
bpy.context.scene.collection.children.link(preview_collection)


def move_to_collection(obj, collection):
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)


def create_preview_block(name, material, location):
    bpy.ops.mesh.primitive_cube_add(
        location=location,
        scale=(3.4, 3.4, 3.4)
    )

    obj = bpy.context.active_object
    obj.name = name

    move_to_collection(obj, preview_collection)

    bevel = obj.modifiers.new("Preview_Bevel", "BEVEL")
    bevel.width = 0.15
    bevel.segments = 3

    obj.data.materials.append(material)

    return obj


materials = [
    ("01_Ancient_Dark_Stone", ancient_stone),
    ("02_Aged_Masonry", aged_masonry),
    ("03_Worn_Plaster", worn_plaster),
    ("04_Blackened_Iron", blackened_iron),
    ("05_Rusted_Patch_Metal", rusted_metal),
    ("06_Worn_Timber", worn_timber),
    ("07_Street_Stone", street_stone),
    ("08_Faded_Military_Red", military_red),
    ("09_Soot_Grime", soot_grime),
    ("10_Fracture_Masonry", fracture_masonry),
    ("11_Fracture_Metal", fracture_metal),
]


# ------------------------------------------------------------
# ARRANGE MATERIAL BLOCKS
# ------------------------------------------------------------

spacing_x = 9.0
spacing_y = 10.0

for index, (name, material) in enumerate(materials):
    row = index // 4
    column = index % 4

    x = (column - 1.5) * spacing_x
    y = -row * spacing_y

    create_preview_block(
        name,
        material,
        (x, y, 3.4)
    )


# ------------------------------------------------------------
# GROUND
# ------------------------------------------------------------

bpy.ops.mesh.primitive_plane_add(
    size=80,
    location=(0, -10, 0)
)

ground = bpy.context.active_object
ground.name = "Preview_Ground"

ground_mat = bpy.data.materials.new("Preview_Ground_Material")
ground_mat.use_nodes = True

ground_bsdf = ground_mat.node_tree.nodes.get("Principled BSDF")
ground_bsdf.inputs["Base Color"].default_value = rgba("#101112")
ground_bsdf.inputs["Roughness"].default_value = 0.95

ground.data.materials.append(ground_mat)


# ------------------------------------------------------------
# LIGHTING
# ------------------------------------------------------------

world = bpy.context.scene.world

world.use_nodes = True

background = world.node_tree.nodes.get("Background")
background.inputs["Color"].default_value = (0.025, 0.03, 0.035, 1.0)
background.inputs["Strength"].default_value = 0.22


# Warm key light
bpy.ops.object.light_add(
    type="AREA",
    location=(-12, -8, 18)
)

key = bpy.context.active_object
key.name = "Warm_Key_Light"
key.data.energy = 1400
key.data.shape = "DISK"
key.data.size = 10
key.data.color = (1.0, 0.55, 0.28)

key.rotation_euler = (
    math.radians(25),
    0,
    math.radians(-25)
)


# Cool fill
bpy.ops.object.light_add(
    type="AREA",
    location=(15, 4, 14)
)

fill = bpy.context.active_object
fill.name = "Cool_Fill_Light"
fill.data.energy = 900
fill.data.size = 12
fill.data.color = (0.40, 0.52, 0.65)

fill.rotation_euler = (
    math.radians(35),
    0,
    math.radians(150)
)


# Overhead soft light
bpy.ops.object.light_add(
    type="AREA",
    location=(0, -10, 25)
)

top = bpy.context.active_object
top.name = "Overhead_Soft_Light"
top.data.energy = 1000
top.data.size = 18


# ------------------------------------------------------------
# CAMERA
# ------------------------------------------------------------

bpy.ops.object.camera_add(
    location=(30, -42, 27)
)

camera = bpy.context.active_object
camera.name = "Material_Library_Camera"


def point_camera_at(camera_obj, target):
    direction = (
        target[0] - camera_obj.location.x,
        target[1] - camera_obj.location.y,
        target[2] - camera_obj.location.z,
    )

    quat = mathutils.Vector(direction).to_track_quat("-Z", "Y")
    camera_obj.rotation_euler = quat.to_euler()


# mathutils imported here to keep main helper area simple
import mathutils

point_camera_at(
    camera,
    (0, -9, 3)
)

camera.data.lens = 48

bpy.context.scene.camera = camera


# ------------------------------------------------------------
# RENDER SETTINGS
# ------------------------------------------------------------

scene = bpy.context.scene

scene.render.engine = "BLENDER_EEVEE"

scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100

scene.render.image_settings.file_format = "PNG"

scene.render.filepath = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/"
    "lower_layer_material_library_v1_preview.png"
)


# ------------------------------------------------------------
# COLOR MANAGEMENT
# ------------------------------------------------------------

scene.view_settings.look = "AgX - Medium High Contrast"


# ------------------------------------------------------------
# SAVE
# ------------------------------------------------------------

os.makedirs(
    os.path.dirname(OUTPUT_PATH),
    exist_ok=True
)

bpy.ops.wm.save_as_mainfile(
    filepath=OUTPUT_PATH
)

print("")
print("============================================")
print("ENFLESHED LOWER LAYER MATERIAL LIBRARY V1")
print("============================================")
print("")
print("Created materials:")

for name, material in materials:
    print(" -", material.name)

print("")
print("Saved to:")
print(OUTPUT_PATH)
print("")
print("============================================")
