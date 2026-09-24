import bpy
import math
import os
from mathutils import Vector

# ============================================================
# ENFLESHED - LOWER LAYER KIT V1
# Generates:
#   ENV_AncientArch_A
#   ENV_RetrofitWall_A
#   ENV_Catwalk_A
#
# First-pass blockout based on approved Lower Layer visual language.
# ============================================================

OUTPUT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/LowerLayerKit_V1.blend"
)

# ------------------------------------------------------------
# RESET
# ------------------------------------------------------------

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

for collection in list(bpy.data.collections):
    if collection.name != "Collection":
        bpy.data.collections.remove(collection)

# ------------------------------------------------------------
# COLLECTIONS
# ------------------------------------------------------------

def get_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


ancient_col = get_collection("KIT_AncientStructure")
human_col = get_collection("KIT_HumanRetrofit")
reference_col = get_collection("KIT_Reference")


def move_to_collection(obj, collection):
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)


# ------------------------------------------------------------
# MATERIALS
# ------------------------------------------------------------

def create_material(name, color, metallic=0.0, roughness=0.7):
    mat = bpy.data.materials.new(name=name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True

    bsdf = mat.node_tree.nodes.get("Principled BSDF")

    if bsdf:
        if bsdf.inputs.get("Base Color"):
            bsdf.inputs["Base Color"].default_value = (*color, 1.0)

        if bsdf.inputs.get("Metallic"):
            bsdf.inputs["Metallic"].default_value = metallic

        if bsdf.inputs.get("Roughness"):
            bsdf.inputs["Roughness"].default_value = roughness

    return mat


MAT_ANCIENT = create_material(
    "MAT_AncientMetal",
    (0.17, 0.19, 0.20),
    metallic=0.72,
    roughness=0.48,
)

MAT_STONE = create_material(
    "MAT_LowerLayerMasonry",
    (0.24, 0.22, 0.19),
    metallic=0.0,
    roughness=0.88,
)

MAT_IRON = create_material(
    "MAT_WornHumanIron",
    (0.16, 0.13, 0.11),
    metallic=0.68,
    roughness=0.62,
)

MAT_RED = create_material(
    "MAT_MilitaryRed",
    (0.32, 0.045, 0.035),
    metallic=0.0,
    roughness=0.78,
)

MAT_REFERENCE = create_material(
    "MAT_HumanReference",
    (0.55, 0.52, 0.45),
    metallic=0.0,
    roughness=0.8,
)


# ------------------------------------------------------------
# BASIC BUILDING HELPERS
# ------------------------------------------------------------

def cube(name, location, dimensions, material, collection, rotation=(0, 0, 0), bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(
        location=location,
        rotation=rotation,
    )

    obj = bpy.context.active_object
    obj.name = name

    obj.dimensions = dimensions

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    if material:
        obj.data.materials.append(material)

    if bevel > 0:
        mod = obj.modifiers.new(
            name="EdgeBevel",
            type="BEVEL",
        )
        mod.width = bevel
        mod.segments = 2

    move_to_collection(obj, collection)

    return obj


def cylinder(name, location, radius, depth, material, collection, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=16,
        radius=radius,
        depth=depth,
        location=location,
        rotation=rotation,
    )

    obj = bpy.context.active_object
    obj.name = name

    if material:
        obj.data.materials.append(material)

    bevel = obj.modifiers.new(
        name="EdgeBevel",
        type="BEVEL",
    )
    bevel.width = 0.06
    bevel.segments = 2

    move_to_collection(obj, collection)

    return obj


def beam_between(name, start, end, thickness, depth, material, collection):
    p1 = Vector(start)
    p2 = Vector(end)

    delta = p2 - p1
    midpoint = (p1 + p2) / 2

    length = delta.length

    angle = math.atan2(
        delta.z,
        delta.x,
    )

    return cube(
        name,
        midpoint,
        (length, depth, thickness),
        material,
        collection,
        rotation=(0, -angle, 0),
        bevel=0.05,
    )


# ------------------------------------------------------------
# ANCIENT ARCH
# ------------------------------------------------------------

def create_ancient_arch(origin_x=-30):
    prefix = "ENV_AncientArch_A"

    radius = 10.0
    pillar_height = 14.0
    pillar_width = 3.8
    depth = 5.0
    arch_thickness = 2.6

    # Massive pillars
    for side in (-1, 1):
        x = origin_x + side * radius

        cube(
            f"{prefix}_Pillar_{side}",
            (x, 0, pillar_height / 2),
            (pillar_width, depth, pillar_height),
            MAT_ANCIENT,
            ancient_col,
            bevel=0.22,
        )

        # Heavy buttress behind each pillar
        cube(
            f"{prefix}_Buttress_{side}",
            (x, 1.8, pillar_height / 2.3),
            (6.0, 2.0, pillar_height * 0.72),
            MAT_ANCIENT,
            ancient_col,
            bevel=0.18,
        )

    # Main segmented arch rib
    segments = 20
    arc_length = math.pi * radius
    segment_length = (arc_length / segments) * 1.18

    for i in range(segments):
        theta = math.pi * (i + 0.5) / segments

        x = origin_x + radius * math.cos(theta)
        z = pillar_height + radius * math.sin(theta)

        tangent_angle = theta + math.pi / 2

        cube(
            f"{prefix}_Rib_{i:02d}",
            (x, 0, z),
            (segment_length, depth, arch_thickness),
            MAT_ANCIENT,
            ancient_col,
            rotation=(0, -tangent_angle, 0),
            bevel=0.16,
        )

    # Smaller inner structural rib
    inner_radius = 7.7
    inner_segments = 18
    inner_arc_length = math.pi * inner_radius
    inner_segment_length = (inner_arc_length / inner_segments) * 1.2

    for i in range(inner_segments):
        theta = math.pi * (i + 0.5) / inner_segments

        x = origin_x + inner_radius * math.cos(theta)
        z = pillar_height + inner_radius * math.sin(theta)

        tangent_angle = theta + math.pi / 2

        cube(
            f"{prefix}_InnerRib_{i:02d}",
            (x, -2.0, z),
            (inner_segment_length, 0.8, 0.7),
            MAT_ANCIENT,
            ancient_col,
            rotation=(0, -tangent_angle, 0),
            bevel=0.08,
        )

    # Alien-looking structural seam
    cube(
        f"{prefix}_Seam",
        (origin_x, -2.55, 7),
        (1.1, 0.25, 9.5),
        MAT_ANCIENT,
        ancient_col,
        bevel=0.05,
    )


# ------------------------------------------------------------
# HUMAN RETROFIT WALL
# ------------------------------------------------------------

def create_retrofit_wall(origin_x=0):
    prefix = "ENV_RetrofitWall_A"

    # Base wall
    cube(
        f"{prefix}_Base",
        (origin_x, 0, 8),
        (16, 2.0, 16),
        MAT_STONE,
        human_col,
        bevel=0.10,
    )

    # Uneven repair slabs
    patches = [
        (-5.2, -1.08, 11.2, 3.2, 0.22, 4.0),
        (3.8, -1.09, 4.2, 4.8, 0.24, 3.3),
        (1.2, -1.10, 12.5, 5.0, 0.20, 2.6),
    ]

    for i, p in enumerate(patches):
        x, y, z, w, d, h = p

        cube(
            f"{prefix}_Patch_{i}",
            (origin_x + x, y, z),
            (w, d, h),
            MAT_STONE,
            human_col,
            bevel=0.04,
        )

    # Heavy vertical iron braces
    for x_offset in (-6.3, 0, 6.3):
        cube(
            f"{prefix}_VerticalBrace_{x_offset}",
            (origin_x + x_offset, -1.32, 8),
            (0.65, 0.55, 15),
            MAT_IRON,
            human_col,
            bevel=0.07,
        )

    # Horizontal reinforcement
    for z in (4.0, 9.0, 14.0):
        cube(
            f"{prefix}_HorizontalBrace_{z}",
            (origin_x, -1.35, z),
            (15.2, 0.48, 0.55),
            MAT_IRON,
            human_col,
            bevel=0.06,
        )

    # Diagonal repair braces
    beam_between(
        f"{prefix}_DiagonalBrace_L",
        (origin_x - 7, -1.55, 1.0),
        (origin_x - 1.2, -1.55, 8.5),
        0.48,
        0.45,
        MAT_IRON,
        human_col,
    )

    beam_between(
        f"{prefix}_DiagonalBrace_R",
        (origin_x + 7, -1.55, 1.0),
        (origin_x + 2.0, -1.55, 8.0),
        0.48,
        0.45,
        MAT_IRON,
        human_col,
    )

    # Utility pipes
    for x_offset in (-4.2, 4.7):
        cylinder(
            f"{prefix}_Pipe_{x_offset}",
            (origin_x + x_offset, -1.65, 8.0),
            0.32,
            13.0,
            MAT_IRON,
            human_col,
        )

    # Military banner
    cube(
        f"{prefix}_Banner",
        (origin_x + 2.3, -1.72, 10.0),
        (2.8, 0.10, 6.4),
        MAT_RED,
        human_col,
        bevel=0.02,
    )


# ------------------------------------------------------------
# HUMAN CATWALK
# ------------------------------------------------------------

def create_catwalk(origin_x=27):
    prefix = "ENV_Catwalk_A"

    length = 18.0
    width = 5.5
    deck_z = 5.5

    # Main deck
    cube(
        f"{prefix}_Deck",
        (origin_x, 0, deck_z),
        (length, width, 0.55),
        MAT_IRON,
        human_col,
        bevel=0.06,
    )

    # Under-deck support beams
    for y in (-2.25, 2.25):
        cube(
            f"{prefix}_UnderBeam_{y}",
            (origin_x, y, deck_z - 0.55),
            (length, 0.45, 0.65),
            MAT_IRON,
            human_col,
            bevel=0.05,
        )

    # Rail posts
    post_spacing = 3.0
    count = int(length / post_spacing)

    for side_y in (-width / 2, width / 2):
        for i in range(count + 1):
            x = origin_x - length / 2 + i * post_spacing

            cube(
                f"{prefix}_RailPost_{side_y}_{i}",
                (x, side_y, deck_z + 1.55),
                (0.25, 0.25, 2.8),
                MAT_IRON,
                human_col,
                bevel=0.04,
            )

        # Horizontal handrail
        cube(
            f"{prefix}_HandRail_{side_y}",
            (origin_x, side_y, deck_z + 2.75),
            (length, 0.22, 0.22),
            MAT_IRON,
            human_col,
            bevel=0.03,
        )

        # Mid rail
        cube(
            f"{prefix}_MidRail_{side_y}",
            (origin_x, side_y, deck_z + 1.65),
            (length, 0.18, 0.18),
            MAT_IRON,
            human_col,
            bevel=0.03,
        )

    # Structural diagonal braces beneath
    beam_between(
        f"{prefix}_Brace_L",
        (origin_x - 8.5, -2.0, deck_z - 0.5),
        (origin_x - 4.5, -2.0, 0.5),
        0.42,
        0.38,
        MAT_IRON,
        human_col,
    )

    beam_between(
        f"{prefix}_Brace_R",
        (origin_x + 8.5, -2.0, deck_z - 0.5),
        (origin_x + 4.5, -2.0, 0.5),
        0.42,
        0.38,
        MAT_IRON,
        human_col,
    )

    # Small military banner
    cube(
        f"{prefix}_Banner",
        (origin_x + 5.5, width / 2 + 0.10, deck_z + 0.8),
        (2.0, 0.08, 2.8),
        MAT_RED,
        human_col,
        bevel=0.01,
    )


# ------------------------------------------------------------
# HUMAN SCALE REFERENCE
# ------------------------------------------------------------

def create_human_reference():
    # Approximate 6-unit tall placeholder figure.
    cube(
        "REF_HumanScale_Body",
        (-17, -5, 3.0),
        (1.5, 1.0, 6.0),
        MAT_REFERENCE,
        reference_col,
        bevel=0.25,
    )

    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16,
        ring_count=8,
        radius=0.65,
        location=(-17, -5, 6.55),
    )

    head = bpy.context.active_object
    head.name = "REF_HumanScale_Head"
    head.data.materials.append(MAT_REFERENCE)

    move_to_collection(head, reference_col)


# ------------------------------------------------------------
# SIMPLE FLOOR
# ------------------------------------------------------------

cube(
    "REF_Floor",
    (0, 0, -0.5),
    (78, 18, 1),
    MAT_STONE,
    reference_col,
    bevel=0.02,
)


# ------------------------------------------------------------
# GENERATE KIT
# ------------------------------------------------------------

create_ancient_arch()
create_retrofit_wall()
create_catwalk()
create_human_reference()


# ------------------------------------------------------------
# WORLD SETTINGS
# ------------------------------------------------------------

bpy.context.scene.world.color = (0.025, 0.025, 0.03)

# Save
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT)

print("")
print("===================================================")
print("ENFLESHED LOWER LAYER KIT V1 GENERATED")
print(OUTPUT)
print("")
print("Contains:")
print("  - Ancient structural arch")
print("  - Human retrofit wall")
print("  - Human catwalk")
print("  - Reusable materials")
print("  - Human scale reference")
print("===================================================")
