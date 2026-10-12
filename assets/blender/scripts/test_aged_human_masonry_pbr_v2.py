import bpy
import os
import mathutils

ROOT = os.path.expanduser("~/Projects/Enfleshed")

TEXTURE_DIR = os.path.join(
    ROOT,
    "assets/textures/aged_human_masonry_v2"
)

OUTPUT = os.path.join(
    ROOT,
    "assets/blender/generated/aged_human_masonry_pbr_test_v2.blend"
)

COLOR = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_v2_color.png"
)

NORMAL = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_v2_normal.png"
)

ROUGHNESS = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_v2_roughness.png"
)

METALNESS = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_v2_metalness.png"
)


# ------------------------------------------------------------
# CLEAN SCENE
# ------------------------------------------------------------

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


# ------------------------------------------------------------
# PBR MATERIAL
# ------------------------------------------------------------

material = bpy.data.materials.new(
    "Aged_Human_Masonry_PBR_V2"
)

material.use_nodes = True

nodes = material.node_tree.nodes
links = material.node_tree.links

nodes.clear()

output = nodes.new(
    "ShaderNodeOutputMaterial"
)

output.location = (750, 0)

bsdf = nodes.new(
    "ShaderNodeBsdfPrincipled"
)

bsdf.location = (470, 0)

links.new(
    bsdf.outputs["BSDF"],
    output.inputs["Surface"]
)


# COLOR

color_node = nodes.new(
    "ShaderNodeTexImage"
)

color_node.image = bpy.data.images.load(
    COLOR
)

color_node.location = (
    -650,
    250,
)

links.new(
    color_node.outputs["Color"],
    bsdf.inputs["Base Color"]
)


# ROUGHNESS

rough_node = nodes.new(
    "ShaderNodeTexImage"
)

rough_node.image = bpy.data.images.load(
    ROUGHNESS
)

rough_node.image.colorspace_settings.name = (
    "Non-Color"
)

rough_node.location = (
    -650,
    0,
)

links.new(
    rough_node.outputs["Color"],
    bsdf.inputs["Roughness"]
)


# METALNESS

metal_node = nodes.new(
    "ShaderNodeTexImage"
)

metal_node.image = bpy.data.images.load(
    METALNESS
)

metal_node.image.colorspace_settings.name = (
    "Non-Color"
)

metal_node.location = (
    -650,
    -220,
)

links.new(
    metal_node.outputs["Color"],
    bsdf.inputs["Metallic"]
)


# NORMAL

normal_texture = nodes.new(
    "ShaderNodeTexImage"
)

normal_texture.image = bpy.data.images.load(
    NORMAL
)

normal_texture.image.colorspace_settings.name = (
    "Non-Color"
)

normal_texture.location = (
    -650,
    -450,
)

normal_map = nodes.new(
    "ShaderNodeNormalMap"
)

normal_map.location = (
    100,
    -300,
)

normal_map.inputs[
    "Strength"
].default_value = 1.15

links.new(
    normal_texture.outputs["Color"],
    normal_map.inputs["Color"]
)

links.new(
    normal_map.outputs["Normal"],
    bsdf.inputs["Normal"]
)


# ------------------------------------------------------------
# WALL
#
# Large enough that repetition becomes obvious.
# ------------------------------------------------------------

bpy.ops.mesh.primitive_cube_add(
    location=(0, 0, 7),
    scale=(15, 0.75, 7),
)

wall = bpy.context.active_object

wall.name = (
    "Aged_Masonry_V2_Test_Wall"
)

wall.data.materials.append(
    material
)

bpy.ops.object.transform_apply(
    location=False,
    rotation=False,
    scale=True,
)


# ------------------------------------------------------------
# SMALL BEVEL
# ------------------------------------------------------------

bevel = wall.modifiers.new(
    "Edge_Bevel",
    "BEVEL"
)

bevel.width = 0.08
bevel.segments = 3


# ------------------------------------------------------------
# UV SCALE
#
# Intentionally displays multiple repetitions across a large
# wall so we can judge game-scale tiling.
# ------------------------------------------------------------

bpy.context.view_layer.objects.active = wall

wall.select_set(True)

bpy.ops.object.mode_set(
    mode="EDIT"
)

bpy.ops.mesh.select_all(
    action="SELECT"
)

bpy.ops.uv.cube_project(
    cube_size=5.5
)

bpy.ops.object.mode_set(
    mode="OBJECT"
)


# ------------------------------------------------------------
# FLOOR
# ------------------------------------------------------------

bpy.ops.mesh.primitive_plane_add(
    size=55,
    location=(0, 0, 0),
)

floor = bpy.context.active_object

floor.name = "Inspection_Floor"

floor_material = bpy.data.materials.new(
    "Inspection_Floor_Material"
)

floor_material.diffuse_color = (
    0.08,
    0.08,
    0.08,
    1.0,
)

floor.data.materials.append(
    floor_material
)


# ------------------------------------------------------------
# PLAYER-SCALE REFERENCE
# ------------------------------------------------------------

bpy.ops.mesh.primitive_cube_add(
    location=(-11, -2.5, 3),
    scale=(1.0, 0.6, 3.0),
)

reference = bpy.context.active_object

reference.name = "PLAYER_SCALE_REFERENCE"

reference_material = bpy.data.materials.new(
    "Player_Reference_Red"
)

reference_material.diffuse_color = (
    0.45,
    0.035,
    0.025,
    1.0,
)

reference.data.materials.append(
    reference_material
)


# ------------------------------------------------------------
# LIGHTING
# ------------------------------------------------------------

def add_area_light(
    name,
    location,
    target,
    energy,
    size,
    color,
):

    bpy.ops.object.light_add(
        type="AREA",
        location=location,
    )

    light = bpy.context.active_object

    light.name = name
    light.data.energy = energy
    light.data.size = size
    light.data.color = color

    direction = (
        mathutils.Vector(target)
        - light.location
    )

    light.rotation_euler = (
        direction
        .to_track_quat(
            "-Z",
            "Y"
        )
        .to_euler()
    )


add_area_light(
    "Warm_Key",
    (-12, -10, 16),
    (0, 0, 6),
    1800,
    8,
    (1.0, 0.76, 0.52),
)

add_area_light(
    "Cool_Fill",
    (11, -6, 13),
    (0, 0, 6),
    1300,
    8,
    (0.70, 0.82, 1.0),
)


# ------------------------------------------------------------
# CAMERA
# ------------------------------------------------------------

bpy.ops.object.camera_add(
    location=(18, -25, 12)
)

camera = bpy.context.active_object

camera.name = "Masonry_V2_Test_Camera"

target = mathutils.Vector(
    (0, 0, 6.5)
)

direction = (
    target
    - camera.location
)

camera.rotation_euler = (
    direction
    .to_track_quat(
        "-Z",
        "Y"
    )
    .to_euler()
)

camera.data.lens = 52

bpy.context.scene.camera = camera


# ------------------------------------------------------------
# WORLD
# ------------------------------------------------------------

world = bpy.context.scene.world

if world is None:

    world = bpy.data.worlds.new(
        "Inspection_World"
    )

    bpy.context.scene.world = world

world.use_nodes = True

background = (
    world.node_tree.nodes.get(
        "Background"
    )
)

if background:

    background.inputs[
        "Strength"
    ].default_value = 0.4


# ------------------------------------------------------------
# RENDER
# ------------------------------------------------------------

scene = bpy.context.scene

scene.render.engine = (
    "BLENDER_EEVEE"
)

try:

    scene.view_settings.look = (
        "AgX - Medium High Contrast"
    )

except Exception:

    pass


# ------------------------------------------------------------
# SAVE
# ------------------------------------------------------------

os.makedirs(
    os.path.dirname(OUTPUT),
    exist_ok=True,
)

bpy.ops.wm.save_as_mainfile(
    filepath=OUTPUT
)

print("")
print("==============================================")
print(" AGED HUMAN MASONRY PBR V2 TEST CREATED")
print("==============================================")
print(OUTPUT)
print("==============================================")
