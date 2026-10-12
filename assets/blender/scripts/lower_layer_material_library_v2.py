import bpy
import math
import mathutils
import os

# ============================================================
# ENFLESHED — LOWER LAYER MATERIAL LIBRARY V2
# Blender 5.2
#
# Goals:
# - Preserve V1 palette
# - Give each material a more distinct physical character
# - Improve inspection lighting
# - Add readable labels
# - Keep everything procedural for rapid iteration
# ============================================================

ROOT = os.path.expanduser("~/Projects/Enfleshed")
OUTPUT = os.path.join(
    ROOT,
    "assets/blender/generated/lower_layer_material_library_v2.blend"
)

# ------------------------------------------------------------
# CLEAN SCENE
# ------------------------------------------------------------

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

for material in list(bpy.data.materials):
    bpy.data.materials.remove(material)


# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------

def hex_rgba(value):
    value = value.lstrip("#")
    return (
        int(value[0:2], 16) / 255.0,
        int(value[2:4], 16) / 255.0,
        int(value[4:6], 16) / 255.0,
        1.0,
    )


def material_base(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True

    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    output = nodes.new("ShaderNodeOutputMaterial")
    output.location = (900, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (620, 0)

    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    return mat, nodes, links, bsdf


def noise(nodes, scale, detail=5.0, roughness=0.65, loc=(-700, 0)):
    n = nodes.new("ShaderNodeTexNoise")
    n.location = loc
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = roughness
    return n


def ramp(nodes, entries, loc=(-300, 100)):
    r = nodes.new("ShaderNodeValToRGB")
    r.location = loc

    cr = r.color_ramp

    while len(cr.elements) > 2:
        cr.elements.remove(cr.elements[-1])

    cr.elements[0].position = entries[0][0]
    cr.elements[0].color = entries[0][1]

    cr.elements[1].position = entries[-1][0]
    cr.elements[1].color = entries[-1][1]

    for position, color in entries[1:-1]:
        element = cr.elements.new(position)
        element.color = color

    return r


def bump_from(nodes, links, source, bsdf, strength, distance):
    bump = nodes.new("ShaderNodeBump")
    bump.location = (350, -220)
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = distance

    links.new(source, bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    return bump


def generic_material(
    name,
    colors,
    scale,
    detail,
    roughness,
    bump_strength,
    bump_distance,
    metallic=0.0,
):
    mat, nodes, links, bsdf = material_base(name)

    n = noise(nodes, scale, detail, 0.68, (-720, 80))

    r = ramp(
        nodes,
        [
            (0.18, colors[0]),
            (0.50, colors[1]),
            (0.82, colors[2]),
        ],
        (-300, 120),
    )

    links.new(n.outputs["Fac"], r.inputs["Fac"])
    links.new(r.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic

    bump_from(
        nodes,
        links,
        n.outputs["Fac"],
        bsdf,
        bump_strength,
        bump_distance,
    )

    return mat


# ------------------------------------------------------------
# 01 — ANCIENT DARK STONE
# Large mineral forms, subtle broad variation + fine grain
# ------------------------------------------------------------

def ancient_dark_stone():
    mat, nodes, links, bsdf = material_base("LL_Ancient_Dark_Stone_V2")

    broad = noise(nodes, 1.7, 7.0, 0.72, (-850, 160))
    fine = noise(nodes, 17.0, 6.0, 0.72, (-850, -170))

    mix = nodes.new("ShaderNodeMixRGB")
    mix.location = (-520, 50)
    mix.blend_type = "MULTIPLY"
    mix.inputs["Fac"].default_value = 0.32

    links.new(broad.outputs["Fac"], mix.inputs[1])
    links.new(fine.outputs["Fac"], mix.inputs[2])

    color = ramp(
        nodes,
        [
            (0.12, hex_rgba("#0c1012")),
            (0.43, hex_rgba("#20272a")),
            (0.72, hex_rgba("#353d3f")),
            (0.92, hex_rgba("#4a5050")),
        ],
        (-190, 120),
    )

    links.new(mix.outputs["Color"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.91

    bump_from(nodes, links, fine.outputs["Fac"], bsdf, 0.30, 0.12)

    return mat


# ------------------------------------------------------------
# 02 — AGED MASONRY
# Coarse porous mineral material
# ------------------------------------------------------------

def aged_masonry():
    mat, nodes, links, bsdf = material_base("LL_Aged_Masonry_V2")

    coarse = noise(nodes, 5.5, 9.0, 0.82, (-800, 100))
    pores = noise(nodes, 31.0, 4.0, 0.76, (-800, -220))

    color = ramp(
        nodes,
        [
            (0.16, hex_rgba("#29251f")),
            (0.40, hex_rgba("#494238")),
            (0.68, hex_rgba("#675e50")),
            (0.88, hex_rgba("#887d6b")),
        ],
        (-320, 130),
    )

    links.new(coarse.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.96

    bump_from(nodes, links, pores.outputs["Fac"], bsdf, 0.48, 0.16)

    return mat


# ------------------------------------------------------------
# 03 — WORN PLASTER
# Fine surface with broad dirty/chipped discoloration
# ------------------------------------------------------------

def worn_plaster():
    mat, nodes, links, bsdf = material_base("LL_Worn_Plaster_V2")

    stains = noise(nodes, 2.3, 5.0, 0.78, (-820, 120))
    grain = noise(nodes, 38.0, 3.0, 0.65, (-820, -210))

    color = ramp(
        nodes,
        [
            (0.15, hex_rgba("#39372f")),
            (0.38, hex_rgba("#666157")),
            (0.68, hex_rgba("#8b8578")),
            (0.88, hex_rgba("#aaa293")),
        ],
        (-300, 120),
    )

    links.new(stains.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.88

    bump_from(nodes, links, grain.outputs["Fac"], bsdf, 0.16, 0.035)

    return mat


# ------------------------------------------------------------
# 04 — BLACKENED IRON
# Dark metal with fine surface damage
# ------------------------------------------------------------

def blackened_iron():
    mat, nodes, links, bsdf = material_base("LL_Blackened_Iron_V2")

    damage = noise(nodes, 15.0, 7.0, 0.60, (-760, 90))

    color = ramp(
        nodes,
        [
            (0.12, hex_rgba("#050708")),
            (0.47, hex_rgba("#111516")),
            (0.74, hex_rgba("#252a29")),
            (0.93, hex_rgba("#3a3d38")),
        ],
        (-280, 120),
    )

    links.new(damage.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Metallic"].default_value = 0.92
    bsdf.inputs["Roughness"].default_value = 0.50

    bump_from(nodes, links, damage.outputs["Fac"], bsdf, 0.11, 0.025)

    return mat


# ------------------------------------------------------------
# 05 — RUSTED PATCH METAL
# Patchy oxidation rather than uniform orange
# ------------------------------------------------------------

def rusted_patch_metal():
    mat, nodes, links, bsdf = material_base("LL_Rusted_Patch_Metal_V2")

    rust = noise(nodes, 3.4, 10.0, 0.82, (-820, 100))
    fine = noise(nodes, 24.0, 5.0, 0.75, (-820, -220))

    color = ramp(
        nodes,
        [
            (0.12, hex_rgba("#111313")),
            (0.40, hex_rgba("#292421")),
            (0.52, hex_rgba("#53301f")),
            (0.70, hex_rgba("#8a4827")),
            (0.90, hex_rgba("#b36b37")),
        ],
        (-310, 130),
    )

    links.new(rust.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    metal_ramp = ramp(
        nodes,
        [
            (0.30, (0.85, 0.85, 0.85, 1.0)),
            (0.62, (0.28, 0.28, 0.28, 1.0)),
            (0.82, (0.05, 0.05, 0.05, 1.0)),
        ],
        (80, -30),
    )

    links.new(rust.outputs["Fac"], metal_ramp.inputs["Fac"])
    links.new(metal_ramp.outputs["Color"], bsdf.inputs["Metallic"])

    bsdf.inputs["Roughness"].default_value = 0.69

    bump_from(nodes, links, fine.outputs["Fac"], bsdf, 0.30, 0.07)

    return mat


# ------------------------------------------------------------
# 06 — WORN TIMBER
# Directional grain
# ------------------------------------------------------------

def worn_timber():
    mat, nodes, links, bsdf = material_base("LL_Worn_Timber_V2")

    texcoord = nodes.new("ShaderNodeTexCoord")
    texcoord.location = (-1050, 50)

    mapping = nodes.new("ShaderNodeMapping")
    mapping.location = (-850, 50)

    # Stretch noise to form grain.
    mapping.inputs["Scale"].default_value = (1.0, 7.0, 1.0)

    links.new(texcoord.outputs["Generated"], mapping.inputs["Vector"])

    grain = noise(nodes, 4.2, 7.0, 0.72, (-630, 70))
    links.new(mapping.outputs["Vector"], grain.inputs["Vector"])

    color = ramp(
        nodes,
        [
            (0.13, hex_rgba("#17100c")),
            (0.38, hex_rgba("#34241a")),
            (0.62, hex_rgba("#59402d")),
            (0.86, hex_rgba("#806148")),
        ],
        (-240, 130),
    )

    links.new(grain.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.84

    bump_from(nodes, links, grain.outputs["Fac"], bsdf, 0.24, 0.055)

    return mat


# ------------------------------------------------------------
# 07 — STREET STONE
# Dirty, worn traffic surface
# ------------------------------------------------------------

def street_stone():
    mat, nodes, links, bsdf = material_base("LL_Street_Stone_V2")

    wear = noise(nodes, 4.2, 8.0, 0.76, (-800, 100))
    grain = noise(nodes, 25.0, 4.0, 0.70, (-800, -210))

    color = ramp(
        nodes,
        [
            (0.12, hex_rgba("#161816")),
            (0.40, hex_rgba("#30322e")),
            (0.70, hex_rgba("#4b4b43")),
            (0.90, hex_rgba("#666359")),
        ],
        (-300, 120),
    )

    links.new(wear.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    rough = ramp(
        nodes,
        [
            (0.15, (0.65, 0.65, 0.65, 1.0)),
            (0.80, (0.94, 0.94, 0.94, 1.0)),
        ],
        (70, -40),
    )

    links.new(wear.outputs["Fac"], rough.inputs["Fac"])
    links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])

    bump_from(nodes, links, grain.outputs["Fac"], bsdf, 0.28, 0.065)

    return mat


# ------------------------------------------------------------
# 08 — FADED MILITARY RED
# Old institutional paint
# ------------------------------------------------------------

def military_red():
    mat, nodes, links, bsdf = material_base("LL_Faded_Military_Red_V2")

    wear = noise(nodes, 5.0, 8.0, 0.75, (-800, 90))
    fine = noise(nodes, 29.0, 4.0, 0.70, (-800, -210))

    color = ramp(
        nodes,
        [
            (0.10, hex_rgba("#24100f")),
            (0.38, hex_rgba("#4d1c1b")),
            (0.66, hex_rgba("#722d29")),
            (0.88, hex_rgba("#994b40")),
        ],
        (-300, 120),
    )

    links.new(wear.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.78

    bump_from(nodes, links, fine.outputs["Fac"], bsdf, 0.12, 0.025)

    return mat


# ------------------------------------------------------------
# 09 — SOOT / GRIME
# Near-black oily dirt
# ------------------------------------------------------------

def soot_grime():
    return generic_material(
        "LL_Soot_Grime_V2",
        (
            hex_rgba("#020202"),
            hex_rgba("#0c0b09"),
            hex_rgba("#28231b"),
        ),
        7.5,
        9.0,
        0.93,
        0.14,
        0.025,
    )


# ------------------------------------------------------------
# 10 — FRACTURE MASONRY
# Bright raw broken core
# ------------------------------------------------------------

def fracture_masonry():
    mat, nodes, links, bsdf = material_base("LL_Fracture_Masonry_V2")

    coarse = noise(nodes, 10.0, 9.0, 0.84, (-800, 90))
    grain = noise(nodes, 38.0, 5.0, 0.78, (-800, -210))

    color = ramp(
        nodes,
        [
            (0.12, hex_rgba("#48443b")),
            (0.37, hex_rgba("#756d5e")),
            (0.67, hex_rgba("#9c927e")),
            (0.89, hex_rgba("#c2b8a2")),
        ],
        (-300, 120),
    )

    links.new(coarse.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Roughness"].default_value = 0.98

    bump_from(nodes, links, grain.outputs["Fac"], bsdf, 0.58, 0.13)

    return mat


# ------------------------------------------------------------
# 11 — FRACTURE METAL
# Raw torn metal interior
# ------------------------------------------------------------

def fracture_metal():
    mat, nodes, links, bsdf = material_base("LL_Fracture_Metal_V2")

    damage = noise(nodes, 20.0, 5.0, 0.67, (-780, 80))

    color = ramp(
        nodes,
        [
            (0.12, hex_rgba("#272723")),
            (0.43, hex_rgba("#595950")),
            (0.72, hex_rgba("#8d8c80")),
            (0.91, hex_rgba("#c0bbae")),
        ],
        (-290, 120),
    )

    links.new(damage.outputs["Fac"], color.inputs["Fac"])
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    bsdf.inputs["Metallic"].default_value = 0.96
    bsdf.inputs["Roughness"].default_value = 0.39

    bump_from(nodes, links, damage.outputs["Fac"], bsdf, 0.16, 0.025)

    return mat


# ------------------------------------------------------------
# CREATE MATERIALS
# ------------------------------------------------------------

materials = [
    ("ANCIENT DARK STONE", ancient_dark_stone()),
    ("AGED MASONRY", aged_masonry()),
    ("WORN PLASTER", worn_plaster()),
    ("BLACKENED IRON", blackened_iron()),
    ("RUSTED PATCH METAL", rusted_patch_metal()),
    ("WORN TIMBER", worn_timber()),
    ("STREET STONE", street_stone()),
    ("FADED MILITARY RED", military_red()),
    ("SOOT / GRIME", soot_grime()),
    ("FRACTURE MASONRY", fracture_masonry()),
    ("FRACTURE METAL", fracture_metal()),
]


# ------------------------------------------------------------
# PREVIEW STUDIO
# ------------------------------------------------------------

preview_collection = bpy.data.collections.new("MATERIAL_PREVIEWS")
bpy.context.scene.collection.children.link(preview_collection)


def move_to_collection(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)


def preview_block(name, material, location):
    bpy.ops.mesh.primitive_cube_add(
        location=location,
        scale=(3.1, 3.1, 3.1),
    )

    obj = bpy.context.active_object
    obj.name = "PREVIEW_" + name.replace(" ", "_").replace("/", "_")
    obj.data.materials.append(material)

    bevel = obj.modifiers.new("Small_Edge_Bevel", "BEVEL")
    bevel.width = 0.12
    bevel.segments = 3

    move_to_collection(obj, preview_collection)

    return obj


def create_label(text, location):
    bpy.ops.object.text_add(
        location=location,
        rotation=(math.radians(90), 0, 0),
    )

    obj = bpy.context.active_object
    obj.name = "LABEL_" + text.replace(" ", "_").replace("/", "_")
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.size = 0.72
    obj.data.extrude = 0.012

    mat = bpy.data.materials.get("Label_Material")

    if mat is None:
        mat = bpy.data.materials.new("Label_Material")
        mat.diffuse_color = (0.82, 0.82, 0.78, 1.0)

    obj.data.materials.append(mat)

    return obj


columns = 4
spacing_x = 8.2
spacing_y = 10.0

positions = []

for index, (label, material) in enumerate(materials):
    row = index // columns
    col = index % columns

    x = (col - 1.5) * spacing_x
    y = -row * spacing_y
    z = 3.1

    positions.append((x, y, z))

    preview_block(label, material, (x, y, z))

    create_label(
        label,
        (x, y - 3.9, 0.035),
    )


# ------------------------------------------------------------
# GROUND
# ------------------------------------------------------------

bpy.ops.mesh.primitive_plane_add(
    size=75,
    location=(0, -10, 0),
)

ground = bpy.context.active_object
ground.name = "Inspection_Ground"

ground_mat = bpy.data.materials.new("Inspection_Ground_Material")
ground_mat.diffuse_color = (0.12, 0.12, 0.115, 1.0)
ground.data.materials.append(ground_mat)


# ------------------------------------------------------------
# INSPECTION LIGHTING
# Deliberately brighter and more neutral than game lighting
# ------------------------------------------------------------

world = bpy.context.scene.world
world.color = (0.055, 0.055, 0.055)


def area_light(name, location, energy, size, color, target):
    bpy.ops.object.light_add(
        type="AREA",
        location=location,
    )

    light = bpy.context.active_object
    light.name = name
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = size
    light.data.color = color

    direction = mathutils.Vector(target) - light.location
    light.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    return light


area_light(
    "Neutral_Key",
    (-15, -12, 24),
    2600,
    13,
    (1.0, 0.92, 0.82),
    (0, -10, 2),
)

area_light(
    "Neutral_Fill",
    (17, -4, 18),
    1900,
    14,
    (0.76, 0.86, 1.0),
    (0, -10, 2),
)

area_light(
    "Front_Fill",
    (0, -35, 13),
    1400,
    15,
    (1.0, 0.96, 0.90),
    (0, -10, 2),
)

area_light(
    "Top_Light",
    (0, -10, 30),
    1800,
    18,
    (1.0, 1.0, 1.0),
    (0, -10, 0),
)


# ------------------------------------------------------------
# CAMERA
# ------------------------------------------------------------

bpy.ops.object.camera_add(
    location=(31, -43, 30),
)

camera = bpy.context.active_object
camera.name = "Material_Inspection_Camera"

direction = mathutils.Vector((0, -10, 2.5)) - camera.location
camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 52

bpy.context.scene.camera = camera


# ------------------------------------------------------------
# RENDER SETTINGS
# ------------------------------------------------------------

scene = bpy.context.scene

# Correct Blender 5.2 Eevee identifier
scene.render.engine = "BLENDER_EEVEE"

scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100

scene.render.image_settings.file_format = "PNG"

scene.render.filepath = os.path.join(
    ROOT,
    "assets/blender/generated/lower_layer_material_library_v2_preview.png"
)

try:
    scene.view_settings.look = "AgX - Medium High Contrast"
except Exception:
    pass


# ------------------------------------------------------------
# SAVE
# ------------------------------------------------------------

os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)

bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)

print("")
print("==============================================")
print(" ENFLESHED LOWER LAYER MATERIAL LIBRARY V2")
print("==============================================")

for label, material in materials:
    print("CREATED:", material.name)

print("")
print("SAVED:")
print(OUTPUT)
print("==============================================")
