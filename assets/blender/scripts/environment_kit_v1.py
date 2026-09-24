import bpy
import math
import os
import random
from mathutils import Vector

# ============================================================
# ENFLESHED
# LOWER LAYER ENVIRONMENT KIT V1
# Destruction-ready modular prototype kit
# ============================================================

random.seed(22)

OUTPUT_DIR = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated"
)
OUTPUT_BLEND = os.path.join(
    OUTPUT_DIR,
    "lower_layer_environment_kit_v1.blend"
)

# ------------------------------------------------------------
# SCALE
# ------------------------------------------------------------
# For this prototype:
# 1 Blender unit = 1 Roblox stud conceptually.
#
# We will verify actual Roblox import scale before committing
# the entire asset pipeline to this assumption.
# ------------------------------------------------------------

WALL_HEIGHT = 16.0
WALL_THICKNESS = 2.0

# ============================================================
# CLEAN SCENE
# ============================================================

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

for datablocks in (
    bpy.data.meshes,
    bpy.data.curves,
    bpy.data.materials,
    bpy.data.cameras,
    bpy.data.lights,
):
    pass


# ============================================================
# COLLECTIONS
# ============================================================

def make_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


walls_col = make_collection("WALLS")
openings_col = make_collection("OPENINGS")
structure_col = make_collection("STRUCTURE")
floors_col = make_collection("FLOORS")
details_col = make_collection("DETAILS")
destruction_col = make_collection("DESTRUCTION")
reference_col = make_collection("MATERIALS_REFERENCE")


# ============================================================
# MATERIALS
# ============================================================

def make_material(name, color, metallic=0.0, roughness=0.7):
    mat = bpy.data.materials.new(name=name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True

    bsdf = mat.node_tree.nodes.get("Principled BSDF")

    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness

    return mat


MAT_MASONRY = make_material(
    "MAT_Aged_Masonry",
    (0.22, 0.20, 0.18),
    metallic=0.0,
    roughness=0.88,
)

MAT_PLASTER = make_material(
    "MAT_Dirty_Plaster",
    (0.36, 0.33, 0.28),
    metallic=0.0,
    roughness=0.92,
)

MAT_IRON = make_material(
    "MAT_Dark_Iron",
    (0.075, 0.07, 0.065),
    metallic=0.72,
    roughness=0.55,
)

MAT_PATCH = make_material(
    "MAT_Patch_Metal",
    (0.16, 0.14, 0.12),
    metallic=0.60,
    roughness=0.67,
)

MAT_RED = make_material(
    "MAT_Military_Red",
    (0.27, 0.045, 0.035),
    metallic=0.18,
    roughness=0.72,
)

MAT_ANCIENT = make_material(
    "MAT_Ancient_Dark",
    (0.035, 0.032, 0.03),
    metallic=0.30,
    roughness=0.48,
)


# ============================================================
# OBJECT HELPERS
# ============================================================

def move_to_collection(obj, collection):
    for col in list(obj.users_collection):
        col.objects.unlink(obj)

    collection.objects.link(obj)


def bevel_object(obj, amount=0.15, segments=2):
    bevel = obj.modifiers.new(name="Edge_Bevel", type="BEVEL")
    bevel.width = amount
    bevel.segments = segments


def add_box(
    name,
    location,
    scale,
    collection,
    material,
    bevel=0.10,
):
    bpy.ops.mesh.primitive_cube_add(location=location)

    obj = bpy.context.object
    obj.name = name

    obj.scale = (
        scale[0] / 2,
        scale[1] / 2,
        scale[2] / 2,
    )

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    move_to_collection(obj, collection)

    if material:
        obj.data.materials.append(material)

    if bevel > 0:
        bevel_object(obj, bevel)

    return obj


def add_rotated_box(
    name,
    location,
    scale,
    rotation,
    collection,
    material,
    bevel=0.10,
):
    obj = add_box(
        name,
        location,
        scale,
        collection,
        material,
        bevel,
    )

    obj.rotation_euler = rotation
    return obj


def create_empty(name, location, collection):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "CUBE"
    obj.empty_display_size = 1.0
    obj.location = location
    collection.objects.link(obj)
    return obj


# ============================================================
# WALL CONSTRUCTION
# ============================================================

def create_wall(
    name,
    length,
    x,
    y,
    reinforced=False,
    patched=False,
):
    parent = create_empty(
        name,
        (x, y, WALL_HEIGHT / 2),
        walls_col,
    )

    wall = add_box(
        f"{name}_Masonry",
        (x, y, WALL_HEIGHT / 2),
        (length, WALL_THICKNESS, WALL_HEIGHT),
        walls_col,
        MAT_MASONRY,
        bevel=0.18,
    )
    wall.parent = parent

    # recessed/raised inner human facing
    facing = add_box(
        f"{name}_Facing",
        (x, y - 1.04, WALL_HEIGHT / 2),
        (length - 0.7, 0.16, WALL_HEIGHT - 0.8),
        walls_col,
        MAT_PLASTER,
        bevel=0.05,
    )
    facing.parent = parent

    # bottom reinforcement strip
    lower = add_box(
        f"{name}_LowerReinforcement",
        (x, y - 1.16, 1.25),
        (length, 0.25, 2.5),
        walls_col,
        MAT_IRON,
        bevel=0.06,
    )
    lower.parent = parent

    # vertical structural edge plates
    for sx in (-1, 1):
        edge = add_box(
            f"{name}_Edge_{sx}",
            (
                x + sx * (length / 2 - 0.35),
                y - 1.18,
                WALL_HEIGHT / 2,
            ),
            (0.55, 0.30, WALL_HEIGHT - 0.5),
            walls_col,
            MAT_IRON,
            bevel=0.06,
        )
        edge.parent = parent

    if reinforced:
        brace1 = add_rotated_box(
            f"{name}_Brace_A",
            (x, y - 1.34, WALL_HEIGHT / 2),
            (0.42, 0.34, length * 0.82),
            (0, math.radians(42), 0),
            walls_col,
            MAT_IRON,
            bevel=0.05,
        )
        brace1.parent = parent

        brace2 = add_rotated_box(
            f"{name}_Brace_B",
            (x, y - 1.36, WALL_HEIGHT / 2),
            (0.42, 0.34, length * 0.82),
            (0, math.radians(-42), 0),
            walls_col,
            MAT_IRON,
            bevel=0.05,
        )
        brace2.parent = parent

    if patched:
        patches = [
            (-length * 0.22, 5.1, 2.7, 3.3, -5),
            (length * 0.18, 9.7, 3.4, 2.2, 4),
            (length * 0.31, 3.0, 2.0, 2.8, -2),
        ]

        for i, (px, pz, pw, ph, angle) in enumerate(patches):
            plate = add_box(
                f"{name}_Patch_{i}",
                (x + px, y - 1.37, pz),
                (pw, 0.18, ph),
                walls_col,
                MAT_PATCH if i != 1 else MAT_RED,
                bevel=0.04,
            )
            plate.rotation_euler[1] = math.radians(angle)
            plate.parent = parent

    return parent


# ============================================================
# DAMAGED WALL
# ============================================================

def create_damaged_wall(name, length, x, y):
    parent = create_empty(
        name,
        (x, y, WALL_HEIGHT / 2),
        walls_col,
    )

    # Main wall assembled from irregular blocks rather than
    # one perfect rectangle.
    segments = [
        (-length * 0.36, 3.8, length * 0.27, 7.6),
        (-length * 0.38, 11.5, length * 0.23, 7.0),
        (-length * 0.08, 12.3, length * 0.22, 7.4),
        (length * 0.25, 11.8, length * 0.28, 8.4),
        (length * 0.38, 4.0, length * 0.20, 8.0),
    ]

    for i, (sx, sz, sw, sh) in enumerate(segments):
        block = add_box(
            f"{name}_Section_{i}",
            (x + sx, y, sz),
            (sw, WALL_THICKNESS, sh),
            walls_col,
            MAT_MASONRY,
            bevel=0.16,
        )

        block.rotation_euler[1] = math.radians(
            random.uniform(-2.5, 2.5)
        )
        block.parent = parent

    # Exposed reinforcement near damaged region
    for i, rx in enumerate((-1.5, 0.0, 1.4)):
        bar = add_box(
            f"{name}_ExposedBar_{i}",
            (x + rx, y - 1.08, 4.1 + i * 0.35),
            (0.16, 0.16, 5.0),
            walls_col,
            MAT_IRON,
            bevel=0.02,
        )
        bar.rotation_euler[1] = math.radians(
            random.uniform(-9, 9)
        )
        bar.parent = parent

    return parent


# ============================================================
# BREACHED WALL
# ============================================================

def create_breached_wall(name, length, x, y):
    parent = create_empty(
        name,
        (x, y, WALL_HEIGHT / 2),
        walls_col,
    )

    breach_width = min(6.0, length * 0.42)

    side_width = (length - breach_width) / 2

    # left remaining wall
    left = add_box(
        f"{name}_Left",
        (
            x - breach_width / 2 - side_width / 2,
            y,
            WALL_HEIGHT / 2,
        ),
        (side_width, WALL_THICKNESS, WALL_HEIGHT),
        walls_col,
        MAT_MASONRY,
        bevel=0.18,
    )
    left.parent = parent

    # right remaining wall
    right = add_box(
        f"{name}_Right",
        (
            x + breach_width / 2 + side_width / 2,
            y,
            WALL_HEIGHT / 2,
        ),
        (side_width, WALL_THICKNESS, WALL_HEIGHT),
        walls_col,
        MAT_MASONRY,
        bevel=0.18,
    )
    right.parent = parent

    # broken upper bridge of material
    upper = add_box(
        f"{name}_UpperBroken",
        (x, y, 13.8),
        (breach_width + 1.2, WALL_THICKNESS, 4.4),
        walls_col,
        MAT_MASONRY,
        bevel=0.20,
    )
    upper.rotation_euler[1] = math.radians(2.5)
    upper.parent = parent

    # jagged-ish side chunks
    for i, side in enumerate((-1, 1)):
        for j in range(3):
            chunk = add_box(
                f"{name}_BrokenEdge_{i}_{j}",
                (
                    x + side * (breach_width / 2 + 0.25),
                    y,
                    2.2 + j * 3.0,
                ),
                (
                    random.uniform(0.7, 1.5),
                    WALL_THICKNESS,
                    random.uniform(1.5, 2.8),
                ),
                walls_col,
                MAT_MASONRY,
                bevel=0.12,
            )
            chunk.rotation_euler[1] = math.radians(
                random.uniform(-18, 18)
            )
            chunk.parent = parent

    # exposed reinforcement
    for i, rx in enumerate((-2.4, -1.8, 1.8, 2.4)):
        bar = add_box(
            f"{name}_ExposedRebar_{i}",
            (x + rx, y - 1.08, 8.2),
            (0.15, 0.15, 4.8),
            walls_col,
            MAT_IRON,
            bevel=0.02,
        )
        bar.rotation_euler[1] = math.radians(
            random.uniform(-15, 15)
        )
        bar.parent = parent

    return parent


# ============================================================
# DOORWAY MODULE
# ============================================================

def create_doorway(name, x, y):
    parent = create_empty(
        name,
        (x, y, WALL_HEIGHT / 2),
        openings_col,
    )

    width = 16.0
    door_width = 6.0
    door_height = 10.0

    side_width = (width - door_width) / 2

    for side in (-1, 1):
        pillar = add_box(
            f"{name}_Wall_{side}",
            (
                x + side * (door_width / 2 + side_width / 2),
                y,
                WALL_HEIGHT / 2,
            ),
            (side_width, WALL_THICKNESS, WALL_HEIGHT),
            openings_col,
            MAT_MASONRY,
            bevel=0.18,
        )
        pillar.parent = parent

    header_height = WALL_HEIGHT - door_height

    header = add_box(
        f"{name}_Header",
        (
            x,
            y,
            door_height + header_height / 2,
        ),
        (door_width, WALL_THICKNESS, header_height),
        openings_col,
        MAT_MASONRY,
        bevel=0.18,
    )
    header.parent = parent

    # heavy iron door frame
    for side in (-1, 1):
        frame = add_box(
            f"{name}_FrameSide_{side}",
            (
                x + side * (door_width / 2 + 0.18),
                y - 1.15,
                door_height / 2,
            ),
            (0.38, 0.30, door_height),
            openings_col,
            MAT_IRON,
            bevel=0.05,
        )
        frame.parent = parent

    topframe = add_box(
        f"{name}_FrameTop",
        (x, y - 1.15, door_height),
        (door_width + 0.75, 0.30, 0.40),
        openings_col,
        MAT_IRON,
        bevel=0.05,
    )
    topframe.parent = parent

    return parent


# ============================================================
# WINDOW WALL
# ============================================================

def create_window_wall(name, x, y):
    parent = create_empty(
        name,
        (x, y, WALL_HEIGHT / 2),
        openings_col,
    )

    width = 16.0
    window_width = 5.0
    window_height = 4.5
    sill_height = 5.0

    side_width = (width - window_width) / 2

    for side in (-1, 1):
        section = add_box(
            f"{name}_Side_{side}",
            (
                x + side * (window_width / 2 + side_width / 2),
                y,
                WALL_HEIGHT / 2,
            ),
            (side_width, WALL_THICKNESS, WALL_HEIGHT),
            openings_col,
            MAT_MASONRY,
            bevel=0.16,
        )
        section.parent = parent

    bottom = add_box(
        f"{name}_Bottom",
        (x, y, sill_height / 2),
        (window_width, WALL_THICKNESS, sill_height),
        openings_col,
        MAT_MASONRY,
        bevel=0.16,
    )
    bottom.parent = parent

    upper_start = sill_height + window_height
    upper_height = WALL_HEIGHT - upper_start

    top = add_box(
        f"{name}_Top",
        (
            x,
            y,
            upper_start + upper_height / 2,
        ),
        (window_width, WALL_THICKNESS, upper_height),
        openings_col,
        MAT_MASONRY,
        bevel=0.16,
    )
    top.parent = parent

    # crude reinforced window bars
    for i in (-1, 0, 1):
        bar = add_box(
            f"{name}_Bar_{i}",
            (
                x + i * 1.3,
                y - 1.15,
                sill_height + window_height / 2,
            ),
            (0.16, 0.20, window_height),
            openings_col,
            MAT_IRON,
            bevel=0.02,
        )
        bar.parent = parent

    return parent


# ============================================================
# STRUCTURAL PIECES
# ============================================================

def create_column(name, x, y, heavy=False):
    width = 4.5 if heavy else 2.5
    depth = 4.5 if heavy else 2.5
    height = 20.0 if heavy else 16.0

    parent = create_empty(
        name,
        (x, y, height / 2),
        structure_col,
    )

    core = add_box(
        f"{name}_Core",
        (x, y, height / 2),
        (width, depth, height),
        structure_col,
        MAT_MASONRY,
        bevel=0.22,
    )
    core.parent = parent

    # metal foot
    base = add_box(
        f"{name}_Base",
        (x, y, 0.7),
        (width + 0.8, depth + 0.8, 1.4),
        structure_col,
        MAT_IRON,
        bevel=0.08,
    )
    base.parent = parent

    # crude reinforcement bands
    for z in (4.0, 10.0, 15.0):
        if z >= height:
            continue

        band = add_box(
            f"{name}_Band_{int(z)}",
            (x, y, z),
            (width + 0.28, depth + 0.28, 0.35),
            structure_col,
            MAT_IRON,
            bevel=0.04,
        )
        band.parent = parent

    return parent


def create_beam(name, x, y):
    parent = create_empty(
        name,
        (x, y, 2.0),
        structure_col,
    )

    beam = add_box(
        f"{name}_Main",
        (x, y, 2.0),
        (16.0, 2.0, 3.0),
        structure_col,
        MAT_IRON,
        bevel=0.12,
    )
    beam.parent = parent

    return parent


def create_brace(name, x, y):
    parent = create_empty(
        name,
        (x, y, 5.0),
        structure_col,
    )

    a = add_rotated_box(
        f"{name}_A",
        (x, y, 5.0),
        (0.65, 1.0, 11.0),
        (0, math.radians(43), 0),
        structure_col,
        MAT_IRON,
        bevel=0.06,
    )
    a.parent = parent

    b = add_rotated_box(
        f"{name}_B",
        (x, y, 5.0),
        (0.65, 1.0, 11.0),
        (0, math.radians(-43), 0),
        structure_col,
        MAT_IRON,
        bevel=0.06,
    )
    b.parent = parent

    return parent


# ============================================================
# FLOOR MODULES
# ============================================================

def create_floor(name, x, y, damaged=False):
    parent = create_empty(
        name,
        (x, y, 0),
        floors_col,
    )

    if not damaged:
        slab = add_box(
            f"{name}_Slab",
            (x, y, 0),
            (16.0, 16.0, 1.2),
            floors_col,
            MAT_MASONRY,
            bevel=0.12,
        )
        slab.parent = parent

        # reinforcement strips
        for offset in (-6.0, 6.0):
            strip = add_box(
                f"{name}_Strip_{offset}",
                (x + offset, y, -0.68),
                (0.45, 16.0, 0.30),
                floors_col,
                MAT_IRON,
                bevel=0.03,
            )
            strip.parent = parent

    else:
        # damaged floor built from surviving sections around a hole
        sections = [
            (-5.5, 0, 5.0, 16.0),
            (5.5, 0, 5.0, 16.0),
            (0, -5.5, 6.0, 5.0),
            (0, 5.5, 6.0, 5.0),
        ]

        for i, (ox, oy, sx, sy) in enumerate(sections):
            slab = add_box(
                f"{name}_Section_{i}",
                (x + ox, y + oy, 0),
                (sx, sy, 1.2),
                floors_col,
                MAT_MASONRY,
                bevel=0.12,
            )
            slab.rotation_euler[2] = math.radians(
                random.uniform(-1.5, 1.5)
            )
            slab.parent = parent

    return parent


# ============================================================
# DETAIL PIECES
# ============================================================

def create_repair_plate(name, x, y):
    parent = create_empty(
        name,
        (x, y, 2),
        details_col,
    )

    plate = add_box(
        f"{name}_Plate",
        (x, y, 2),
        (5.0, 0.35, 4.0),
        details_col,
        MAT_PATCH,
        bevel=0.08,
    )
    plate.parent = parent

    # bolt heads
    for bx in (-2.0, 2.0):
        for bz in (0.7, 3.3):
            bpy.ops.mesh.primitive_cylinder_add(
                vertices=8,
                radius=0.12,
                depth=0.16,
                location=(x + bx, y - 0.24, bz),
                rotation=(math.radians(90), 0, 0),
            )

            bolt = bpy.context.object
            bolt.name = f"{name}_Bolt"
            move_to_collection(bolt, details_col)
            bolt.data.materials.append(MAT_IRON)
            bolt.parent = parent

    return parent


def create_lower_reinforcement(name, x, y):
    parent = create_empty(
        name,
        (x, y, 1.5),
        details_col,
    )

    plate = add_box(
        f"{name}_Main",
        (x, y, 1.5),
        (16.0, 0.45, 3.0),
        details_col,
        MAT_IRON,
        bevel=0.07,
    )
    plate.parent = parent

    return parent


# ============================================================
# DEBRIS / BREACH CHUNKS
# ============================================================

def create_breach_chunk(name, x, y, size):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=1,
        radius=1.0,
        location=(x, y, size[2] / 2),
    )

    obj = bpy.context.object
    obj.name = name

    obj.scale = (
        size[0] / 2,
        size[1] / 2,
        size[2] / 2,
    )

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True,
    )

    obj.rotation_euler = (
        random.uniform(-0.4, 0.4),
        random.uniform(-0.4, 0.4),
        random.uniform(-0.4, 0.4),
    )

    move_to_collection(obj, destruction_col)
    obj.data.materials.append(MAT_MASONRY)

    bevel_object(obj, 0.08)

    return obj


# ============================================================
# BUILD KIT DISPLAY
# ============================================================

# Walls row
create_wall("Wall_8", 8, -52, 0)
create_wall("Wall_16", 16, -38, 0)
create_wall("Wall_32", 32, -12, 0)

create_wall(
    "Wall_Reinforced",
    16,
    18,
    0,
    reinforced=True,
)

create_wall(
    "Wall_Patched",
    16,
    38,
    0,
    patched=True,
)

create_damaged_wall(
    "Wall_Damaged",
    16,
    58,
    0,
)

create_breached_wall(
    "Wall_Breached",
    16,
    78,
    0,
)

# Openings row
create_doorway(
    "Doorway_16",
    -42,
    28,
)

create_window_wall(
    "WindowWall_16",
    -20,
    28,
)

# Structure row
create_column(
    "Column",
    4,
    28,
    heavy=False,
)

create_column(
    "HeavyColumn",
    14,
    28,
    heavy=True,
)

create_beam(
    "HorizontalBeam",
    32,
    28,
)

create_brace(
    "MetalBrace",
    52,
    28,
)

# Floors row
create_floor(
    "Floor_16",
    -30,
    55,
    damaged=False,
)

create_floor(
    "Floor_Damaged_16",
    -5,
    55,
    damaged=True,
)

# Details
create_repair_plate(
    "RepairPlate",
    20,
    55,
)

create_lower_reinforcement(
    "LowerWallReinforcement",
    38,
    55,
)

# Destruction chunks
create_breach_chunk(
    "BreachChunk_Large",
    58,
    55,
    (4.5, 3.0, 3.5),
)

create_breach_chunk(
    "BreachChunk_Medium",
    66,
    55,
    (2.8, 2.2, 2.2),
)

create_breach_chunk(
    "BreachChunk_Small",
    72,
    55,
    (1.6, 1.3, 1.4),
)


# ============================================================
# MATERIAL REFERENCE BLOCKS
# ============================================================

materials = [
    MAT_MASONRY,
    MAT_PLASTER,
    MAT_IRON,
    MAT_PATCH,
    MAT_RED,
    MAT_ANCIENT,
]

for i, mat in enumerate(materials):
    ref = add_box(
        f"MaterialReference_{mat.name}",
        (-48 + i * 6, 78, 2),
        (4, 4, 4),
        reference_col,
        mat,
        bevel=0.18,
    )


# ============================================================
# GROUND DISPLAY PLATFORM
# ============================================================

display_ground = add_box(
    "DISPLAY_GROUND",
    (12, 28, -1.4),
    (150, 105, 1.5),
    reference_col,
    MAT_ANCIENT,
    bevel=0.15,
)


# ============================================================
# LABELS
# ============================================================

def add_label(text, location, size=1.4):
    curve = bpy.data.curves.new(
        type="FONT",
        name=f"Label_{text}",
    )

    curve.body = text
    curve.align_x = "CENTER"
    curve.size = size
    curve.extrude = 0.025

    obj = bpy.data.objects.new(
        f"Label_{text}",
        curve,
    )

    obj.location = location
    obj.rotation_euler = (
        math.radians(90),
        0,
        0,
    )

    reference_col.objects.link(obj)

    curve.materials.append(MAT_PLASTER)

    return obj


add_label(
    "WALL MODULES",
    (10, -8, 0.1),
    1.8,
)

add_label(
    "OPENINGS + STRUCTURE",
    (5, 19, 0.1),
    1.8,
)

add_label(
    "FLOORS + DETAILS + DESTRUCTION",
    (15, 45, 0.1),
    1.6,
)

add_label(
    "MATERIAL REFERENCES",
    (-33, 70, 0.1),
    1.5,
)


# ============================================================
# CAMERA
# ============================================================

bpy.ops.object.camera_add(
    location=(120, -155, 105),
)

camera = bpy.context.object
camera.name = "Kit_Preview_Camera"

bpy.context.scene.camera = camera


def point_camera_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


point_camera_at(camera, (10, 28, 6))


# ============================================================
# LIGHTING
# ============================================================

bpy.ops.object.light_add(
    type="AREA",
    location=(10, -30, 85),
)

key = bpy.context.object
key.name = "Preview_Key"
key.data.energy = 2800
key.data.shape = "DISK"
key.data.size = 45

point_camera_at(key, (10, 25, 0))


bpy.ops.object.light_add(
    type="AREA",
    location=(-70, 30, 40),
)

fill = bpy.context.object
fill.name = "Preview_Fill"
fill.data.energy = 1500
fill.data.size = 35

point_camera_at(fill, (5, 30, 4))


bpy.ops.object.light_add(
    type="AREA",
    location=(90, 60, 50),
)

rim = bpy.context.object
rim.name = "Preview_Rim"
rim.data.energy = 1900
rim.data.size = 30

point_camera_at(rim, (25, 30, 7))


# ============================================================
# WORLD
# ============================================================

world = bpy.context.scene.world

world.color = (0.018, 0.018, 0.018)

if world.use_nodes:
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (
            0.018,
            0.020,
            0.024,
            1,
        )
        bg.inputs["Strength"].default_value = 0.35


# ============================================================
# VIEW / SAVE
# ============================================================

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Select nothing
bpy.ops.object.select_all(action="DESELECT")

# Save
bpy.ops.wm.save_as_mainfile(
    filepath=OUTPUT_BLEND
)

print("=" * 60)
print("ENFLESHED ENVIRONMENT KIT V1 GENERATED")
print(OUTPUT_BLEND)
print("=" * 60)
