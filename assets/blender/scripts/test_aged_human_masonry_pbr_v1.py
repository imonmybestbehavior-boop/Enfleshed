import bpy
import os
import math
import mathutils

ROOT = os.path.expanduser("~/Projects/Enfleshed")

TEXTURE_DIR = os.path.join(
    ROOT,
    "assets/textures/aged_human_masonry_v1"
)

OUTPUT = os.path.join(
    ROOT,
    "assets/blender/generated/aged_human_masonry_pbr_test_v1.blend"
)

COLOR = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_color.png"
)

NORMAL = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_normal.png"
)

ROUGHNESS = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_roughness.png"
)

METALNESS = os.path.join(
    TEXTURE_DIR,
    "aged_human_masonry_metalness.png"
)


# Clean scene

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


# ------------------------------------------------------------
# MATERIAL
# ------------------------------------------------------------

material = bpy.data.materials.new(
    "Aged_Human_Masonry_PBR_V1"
)

material.use_nodes = True

nodes = material.node_tree.nodes
links = material.node_tree.links

nodes.clear()


output = nodes.new(
    "ShaderNodeOutputMaterial"
)

output.location = (
    700,
    0
)


bsdf = nodes.new(
    "ShaderNodeBsdfPrincipled"
)

bsdf.location = (
    430,
    0
)


links.new(
    bsdf.outputs["BSDF"],
    output.inputs["Surface"]
)


# Color

color_node = nodes.new(
    "ShaderNodeTexImage"
)

color_node.image = bpy.data.images.load(
    COLOR
)

color_node.location = (
    -650,
    250
)

links.new(
    color_node.outputs["Color"],
    bsdf.inputs["Base Color"]
)


# Roughness

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
    -50
)

links.new(
    rough_node.outputs["Color"],
    bsdf.inputs["Roughness"]
)


# Metalness

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
    -260
)

links.new(
    metal_node.outputs["Color"],
    bsdf.inputs["Metallic"]
)


# Normal

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
    -480
)


normal_map = nodes.new(
    "ShaderNodeNormalMap"
)

normal_map.location = (
    100,
    -300
)

normal_map.inputs[
    "Strength"
].default_value = 1.0


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
# ------------------------------------------------------------

bpy.ops.mesh.primitive_cube_add(
    location=(0, 0, 5),
    scale=(10, 1, 5),
)

wall = bpy.context.active_object

wall.name = "Masonry_PBR_Test_Wall"

wall.data.materials.append(
    material
)

bevel = wall.modifiers.new(
    "Small_Edge_Bevel",
    "BEVEL"
)

bevel.width = 0.08
bevel.segments = 3


# ------------------------------------------------------------
# UV
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
    cube_size=5.0
)

bpy.ops.object.mode_set(
    mode="OBJECT"
)


# ------------------------------------------------------------
# FLOOR
# ------------------------------------------------------------

bpy.ops.mesh.primitive_plane_add(
    size=45,
    location=(0, 0, 0),
)

floor = bpy.context.active_object

floor.name = "Inspection_Floor"


floor_mat = bpy.data.materials.new(
    "Inspection_Floor"
)

floor_mat.diffuse_color = (
    0.10,
    0.10,
    0.10,
    1.0
)

floor.data.materials.append(
    floor_mat
)


# ------------------------------------------------------------
# LIGHTS
# ------------------------------------------------------------

def area_light(
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


area_light(
    (-9, -9, 13),
    (0, 0, 5),
    1600,
    7,
    (1.0, 0.78, 0.55),
)

area_light(
    (8, -4, 11),
    (0, 0, 5),
    1200,
    7,
    (0.70, 0.82, 1.0),
)


# ------------------------------------------------------------
# CAMERA
# ------------------------------------------------------------

bpy.ops.object.camera_add(
    location=(15, -20, 11)
)

camera = bpy.context.active_object

camera.name = "PBR_Test_Camera"

direction = (
    mathutils.Vector(
        (0, 0, 5)
    )
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
# WORLD / RENDER
# ------------------------------------------------------------

world = bpy.context.scene.world

world.use_nodes = True

background = world.node_tree.nodes.get(
    "Background"
)

background.inputs[
    "Strength"
].default_value = 0.35


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
    exist_ok=True
)

bpy.ops.wm.save_as_mainfile(
    filepath=OUTPUT
)

print("")
print("==============================================")
print(" AGED HUMAN MASONRY PBR TEST CREATED")
print("==============================================")
print(OUTPUT)
print("==============================================")
