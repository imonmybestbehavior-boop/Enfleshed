import bpy
import math
import os
import random
from mathutils import Vector

random.seed(917)

OUT = os.path.expanduser(
    "~/Projects/Enfleshed/assets/blender/generated/lower_layer_test_street_v2.blend"
)

# ============================================================
# ENFLESHED — LOWER LAYER TEST STREET V2
#
# DESIGN TARGET:
# Dense, ancient, accreted human habitation.
# NOT a clean alley between buildings.
#
# Priorities:
# - broken sightlines
# - irregular street width
# - offset/crooked route
# - aggressive upper-floor overhangs
# - stacked construction generations
# - overhead habitation
# - bridges/catwalks/pipes
# - alley branch
# - interior passage
# - compression/release
# ============================================================


# ============================================================
# CLEAN
# ============================================================

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)


# ============================================================
# COLLECTIONS
# ============================================================

def make_collection(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


GROUND = make_collection("01_GROUND")
BUILDINGS = make_collection("02_BUILDINGS")
ADDITIONS = make_collection("03_GENERATIONAL_ADDITIONS")
OVERHEAD = make_collection("04_OVERHEAD")
TRAVERSAL = make_collection("05_TRAVERSAL")
DETAILS = make_collection("06_DETAILS")
DAMAGE = make_collection("07_DAMAGE")
ANCIENT_COL = make_collection("08_ANCIENT")
DISPLAY = make_collection("99_DISPLAY")


# ============================================================
# MATERIALS
# ============================================================

def mat(name, color, metallic=0.0, roughness=0.8):
    m = bpy.data.materials.new(name=name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True

    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness

    return m


STONE = mat(
    "Aged_Masonry",
    (0.16, 0.135, 0.11),
    0,
    0.93
)

STONE_DARK = mat(
    "Old_Masonry_Dark",
    (0.09, 0.078, 0.067),
    0,
    0.95
)

PLASTER = mat(
    "Dirty_Plaster",
    (0.28, 0.235, 0.19),
    0,
    0.94
)

PLASTER_DARK = mat(
    "Old_Plaster_Dark",
    (0.16, 0.14, 0.12),
    0,
    0.96
)

IRON = mat(
    "Blackened_Iron",
    (0.04, 0.038, 0.035),
    0.78,
    0.56
)

PATCH = mat(
    "Old_Patch_Metal",
    (0.115, 0.095, 0.075),
    0.58,
    0.73
)

RED = mat(
    "Faded_Military_Red",
    (0.24, 0.03, 0.022),
    0.15,
    0.80
)

WOOD = mat(
    "Aged_Timber",
    (0.095, 0.052, 0.027),
    0,
    0.92
)

STREET = mat(
    "Street_Stone",
    (0.07, 0.064, 0.056),
    0,
    0.97
)

GRIME = mat(
    "Ground_Grime",
    (0.04, 0.032, 0.025),
    0,
    1
)

ANCIENT = mat(
    "Ancient_Megastructure",
    (0.015, 0.017, 0.020),
    0.34,
    0.48
)

LAMP = mat(
    "Lamp_Glass",
    (0.55, 0.28, 0.07),
    0,
    0.32
)


# ============================================================
# HELPERS
# ============================================================

def relocate(obj, collection):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)


def box(
    name,
    loc,
    size,
    collection,
    material,
    bevel=0.08,
    rot=(0, 0, 0)
):
    bpy.ops.mesh.primitive_cube_add(
        location=loc,
        rotation=rot
    )

    o = bpy.context.object
    o.name = name
    o.scale = (
        size[0] / 2,
        size[1] / 2,
        size[2] / 2
    )

    bpy.ops.object.transform_apply(
        location=False,
        rotation=False,
        scale=True
    )

    relocate(o, collection)

    if material:
        o.data.materials.append(material)

    if bevel:
        b = o.modifiers.new("EdgeWear", "BEVEL")
        b.width = bevel
        b.segments = 2

    return o


def cylinder(
    name,
    loc,
    radius,
    depth,
    collection,
    material,
    vertices=12,
    rot=(0, 0, 0)
):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=loc,
        rotation=rot
    )

    o = bpy.context.object
    o.name = name
    relocate(o, collection)
    o.data.materials.append(material)

    return o


def point_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat(
        "-Z",
        "Y"
    ).to_euler()


# ============================================================
# STREET SEGMENTS
# ============================================================

# Instead of one straight road, construct overlapping,
# slightly rotated street sections.

street_segments = [
    (-58, -1.0, 35, 15, 0),
    (-28, 0.0, 31, 15, 2),
    (0, 2.2, 30, 14, -3),
    (27, -0.5, 30, 16, -5),
    (54, -4.0, 31, 15, 3),
]

for i, (x, y, length, width, angle) in enumerate(street_segments):
    box(
        f"STREET_SEGMENT_{i}",
        (x, y, -0.45),
        (length, width, 0.9),
        GROUND,
        STREET,
        0.03,
        rot=(0, 0, math.radians(angle))
    )


# ============================================================
# SMALL COURTYARD
# ============================================================

box(
    "COURTYARD_FLOOR",
    (16, 0.5, -0.43),
    (22, 23, 0.86),
    GROUND,
    STREET,
    0.03,
    rot=(0, 0, math.radians(-3))
)


# ============================================================
# BUILDING CREATOR
# ============================================================

def building(
    name,
    x,
    y,
    width,
    depth,
    height,
    material,
    angle=0
):
    return box(
        name,
        (x, y, height / 2),
        (width, depth, height),
        BUILDINGS,
        material,
        0.16,
        rot=(0, 0, math.radians(angle))
    )


# ============================================================
# IRREGULAR BUILDING MASSES
# ============================================================

# LEFT / NORTH SIDE
left_buildings = [
    (-66, 12.5, 18, 16, 48, 1),
    (-48, 11.0, 17, 18, 64, -2),
    (-31, 13.8, 18, 18, 45, 4),
    (-12, 12.0, 19, 17, 72, -3),
    (7, 14.5, 18, 20, 52, 3),
    (28, 11.0, 21, 17, 68, -6),
    (48, 8.5, 20, 18, 55, 5),
    (67, 10.5, 19, 20, 78, -2),
]

# RIGHT / SOUTH SIDE
right_buildings = [
    (-67, -11.5, 17, 17, 58, -2),
    (-49, -13.5, 19, 18, 44, 3),
    (-30, -10.0, 18, 18, 68, -4),
    (-11, -14.0, 20, 19, 50, 5),
    (9, -11.0, 18, 17, 75, -2),
    (29, -13.5, 21, 20, 54, 4),
    (51, -10.0, 21, 18, 70, -5),
    (70, -13.0, 18, 20, 60, 2),
]


materials = [
    STONE,
    PLASTER,
    STONE_DARK,
    PLASTER_DARK
]


for i, data in enumerate(left_buildings):
    x, y, w, d, h, angle = data

    building(
        f"LEFT_BASE_{i}",
        x,
        y,
        w,
        d,
        h,
        materials[i % len(materials)],
        angle
    )


for i, data in enumerate(right_buildings):
    x, y, w, d, h, angle = data

    building(
        f"RIGHT_BASE_{i}",
        x,
        y,
        w,
        d,
        h,
        materials[(i + 1) % len(materials)],
        angle
    )


# ============================================================
# GENERATIONAL ADDITIONS
# ============================================================

# These deliberately do not align perfectly with their bases.

addition_specs = [
    (-50, 7.5, 29, 15, 11, 15, PLASTER),
    (-29, 9.0, 24, 12, 13, 12, PATCH),
    (-10, 7.0, 34, 16, 12, 14, PLASTER),
    (9, 9.0, 27, 13, 15, 12, STONE),
    (30, 6.0, 36, 17, 11, 15, PLASTER_DARK),
    (50, 4.0, 28, 14, 13, 13, PATCH),

    (-52, -8.0, 24, 14, 12, 13, PLASTER),
    (-31, -6.5, 35, 15, 13, 14, PATCH),
    (-11, -9.0, 26, 13, 12, 13, PLASTER),
    (10, -7.0, 37, 16, 12, 15, STONE),
    (31, -8.0, 29, 14, 13, 12, PATCH),
    (52, -5.0, 38, 17, 12, 14, PLASTER_DARK),
]

for i, (
    x, y, z,
    w, d, h,
    material
) in enumerate(addition_specs):

    box(
        f"GENERATION_ADDITION_{i}",
        (x, y, z + h / 2),
        (w, d, h),
        ADDITIONS,
        material,
        0.12,
        rot=(
            0,
            0,
            math.radians(
                random.uniform(-5, 5)
            )
        )
    )


# ============================================================
# STREET-LEVEL PROJECTIONS
# ============================================================

# Push some architecture physically into the route.

projections = [
    (-39, 6.8, 8, 7, 5, 16),
    (-3, -6.5, 8, 8, 6, 14),
    (37, 5.5, 7, 8, 6, 18),
    (58, -6.0, 7, 7, 5, 15),
]

for i, (x, y, z, w, d, h) in enumerate(projections):
    box(
        f"STREET_PROJECTION_{i}",
        (x, y, z),
        (w, d, h),
        ADDITIONS,
        PLASTER if i % 2 else STONE,
        0.13,
        rot=(
            0,
            0,
            math.radians(
                random.uniform(-4, 4)
            )
        )
    )


# ============================================================
# FACADE DETAIL
# ============================================================

def facade_detail(
    prefix,
    x,
    y,
    height,
    facing,
    width=14
):
    fy = y + facing * 0.20

    # structural verticals
    for sx in (-1, 1):
        box(
            prefix + "_VERT",
            (
                x + sx * (width / 2 - 0.6),
                fy,
                height / 2
            ),
            (0.55, 0.42, height),
            DETAILS,
            IRON,
            0.035
        )

    # horizontal generation bands
    for z in range(15, int(height), 16):
        box(
            prefix + "_BAND",
            (x, fy, z),
            (width, 0.35, 0.5),
            DETAILS,
            PATCH if z % 32 else IRON,
            0.025
        )

    # windows
    for z in range(8, int(height - 5), 16):
        offsets = (-width * 0.24, width * 0.23)

        for j, dx in enumerate(offsets):
            # dark recess
            box(
                prefix + "_WINDOW_RECESS",
                (
                    x + dx,
                    fy + facing * 0.08,
                    z
                ),
                (3.4, 0.18, 3.5),
                DETAILS,
                ANCIENT,
                0.01
            )

            # bars
            for bx in (-0.9, 0, 0.9):
                box(
                    prefix + "_WINDOW_BAR",
                    (
                        x + dx + bx,
                        fy + facing * 0.18,
                        z
                    ),
                    (0.12, 0.12, 3.5),
                    DETAILS,
                    IRON,
                    0.01
                )

    # ground door
    box(
        prefix + "_DOOR",
        (
            x - width * 0.18,
            fy + facing * 0.12,
            4.5
        ),
        (5.0, 0.28, 9),
        DETAILS,
        WOOD,
        0.035
    )

    # patch
    box(
        prefix + "_PATCH",
        (
            x + width * 0.26,
            fy + facing * 0.24,
            6.0
        ),
        (3.5, 0.18, 4.5),
        DETAILS,
        RED if random.random() < 0.3 else PATCH,
        0.025,
        rot=(
            0,
            math.radians(
                random.uniform(-5, 5)
            ),
            0
        )
    )


for i, data in enumerate(left_buildings):
    x, y, w, d, h, angle = data

    facade_detail(
        f"LEFT_DETAIL_{i}",
        x,
        y - d / 2 - 0.1,
        min(h, 52),
        -1,
        min(w, 16)
    )


for i, data in enumerate(right_buildings):
    x, y, w, d, h, angle = data

    facade_detail(
        f"RIGHT_DETAIL_{i}",
        x,
        y + d / 2 + 0.1,
        min(h, 52),
        1,
        min(w, 16)
    )


# ============================================================
# AGGRESSIVE OVERHANGS
# ============================================================

overhangs = [
    (-57, 0, 19, 15, 24, 8),
    (-20, 1, 26, 18, 26, 10),
    (17, 0, 20, 17, 25, 9),
    (48, -1, 29, 19, 26, 11),
]

for i, (x, y, z, w, d, h) in enumerate(overhangs):
    box(
        f"OVERHANG_ROOM_{i}",
        (x, y, z + h / 2),
        (w, d, h),
        OVERHEAD,
        PLASTER_DARK if i % 2 else PLASTER,
        0.13,
        rot=(
            0,
            0,
            math.radians(
                random.uniform(-3, 3)
            )
        )
    )

    box(
        f"OVERHANG_UNDERSIDE_{i}",
        (x, y, z),
        (w + 1, d + 1, 0.65),
        OVERHEAD,
        IRON,
        0.04
    )


# ============================================================
# HANGING SIDE ROOMS
# ============================================================

side_rooms = [
    (-43, 7, 15),
    (-8, -7, 17),
    (28, 7, 14),
    (61, -7, 18),
]

for i, (x, y, z) in enumerate(side_rooms):
    box(
        f"HANGING_ROOM_{i}",
        (x, y, z + 5),
        (10, 8, 10),
        OVERHEAD,
        PLASTER if i % 2 else STONE,
        0.12
    )

    # support braces
    for sx in (-1, 1):
        box(
            f"HANGING_SUPPORT_{i}",
            (
                x + sx * 3.5,
                y,
                z - 1
            ),
            (0.5, 0.5, 9),
            OVERHEAD,
            IRON,
            0.035,
            rot=(
                0,
                math.radians(sx * 34),
                0
            )
        )


# ============================================================
# OVERHEAD BRIDGES
# ============================================================

bridges = [
    (-38, 24),
    (-2, 34),
    (33, 27),
    (61, 39),
]

for i, (x, z) in enumerate(bridges):
    box(
        f"BRIDGE_{i}",
        (x, 0, z),
        (10, 28, 2.2),
        OVERHEAD,
        IRON if i % 2 else STONE_DARK,
        0.08,
        rot=(
            0,
            0,
            math.radians(
                random.uniform(-4, 4)
            )
        )
    )

    # side rail / structural edge
    for sy in (-1, 1):
        box(
            f"BRIDGE_EDGE_{i}",
            (
                x,
                sy * 13.2,
                z + 1.8
            ),
            (10, 0.35, 2.4),
            OVERHEAD,
            IRON,
            0.025
        )


# ============================================================
# UPPER CITY MASSES
# ============================================================

# Dense enough to make the street feel buried.

for side in (-1, 1):
    for i, x in enumerate(
        (-65, -48, -30, -12, 7, 26, 45, 64)
    ):
        base_z = random.uniform(52, 72)
        h = random.uniform(55, 95)
        w = random.uniform(17, 25)
        d = random.uniform(18, 28)

        y = side * random.uniform(14, 20)

        box(
            f"UPPER_CITY_{side}_{i}",
            (
                x + random.uniform(-2, 2),
                y,
                base_z + h / 2
            ),
            (w, d, h),
            OVERHEAD,
            random.choice(
                (STONE, STONE_DARK, PLASTER_DARK)
            ),
            0.15,
            rot=(
                0,
                0,
                math.radians(
                    random.uniform(-4, 4)
                )
            )
        )

        # smaller later addition
        if i % 2 == 0:
            box(
                f"UPPER_ADDITION_{side}_{i}",
                (
                    x + random.uniform(-4, 4),
                    y - side * random.uniform(1, 4),
                    base_z + h + 12
                ),
                (
                    w * 0.65,
                    d * 0.70,
                    24
                ),
                OVERHEAD,
                PATCH,
                0.10
            )


# ============================================================
# HIGH OVERHEAD ROOMS / BRIDGES
# ============================================================

high_crossings = [
    (-52, 65),
    (-24, 78),
    (5, 60),
    (29, 84),
    (55, 70),
]

for i, (x, z) in enumerate(high_crossings):
    box(
        f"HIGH_CROSSING_{i}",
        (x, 0, z),
        (
            random.uniform(12, 19),
            random.uniform(30, 38),
            random.uniform(5, 10)
        ),
        OVERHEAD,
        PLASTER_DARK if i % 2 else STONE_DARK,
        0.10,
        rot=(
            0,
            0,
            math.radians(
                random.uniform(-5, 5)
            )
        )
    )


# ============================================================
# CATWALK NETWORK
# ============================================================

catwalk_specs = [
    (-56, -8, 15, 22),
    (-24, 8, 18, 19),
    (8, -8, 14, 24),
    (39, 8, 21, 23),
]

for i, (x, y, z, length) in enumerate(catwalk_specs):
    box(
        f"CATWALK_{i}",
        (x, y, z),
        (length, 4.2, 0.55),
        TRAVERSAL,
        IRON,
        0.035
    )

    for sy in (-1, 1):
        box(
            f"CATWALK_RAIL_{i}",
            (
                x,
                y + sy * 1.95,
                z + 2
            ),
            (length, 0.15, 0.15),
            TRAVERSAL,
            IRON,
            0.01
        )

        for dx in range(
            int(x - length / 2 + 1),
            int(x + length / 2),
            4
        ):
            box(
                f"CATWALK_POST_{i}",
                (
                    dx,
                    y + sy * 1.95,
                    z + 1
                ),
                (0.13, 0.13, 2),
                TRAVERSAL,
                IRON,
                0.01
            )


# ============================================================
# ALLEY BRANCH
# ============================================================

# Narrow ~7 stud branch disappearing north.

ALLEY_X = 34

box(
    "ALLEY_FLOOR",
    (ALLEY_X, 23, -0.4),
    (7, 38, 0.8),
    GROUND,
    STREET,
    0.025,
    rot=(0, 0, math.radians(2))
)

# Alley walls crowd it.
box(
    "ALLEY_WALL_LEFT",
    (ALLEY_X - 5.5, 24, 22),
    (4, 40, 44),
    BUILDINGS,
    STONE_DARK,
    0.13
)

box(
    "ALLEY_WALL_RIGHT",
    (ALLEY_X + 5.5, 24, 27),
    (4, 42, 54),
    BUILDINGS,
    PLASTER_DARK,
    0.13
)

# Low overhead habitation across alley.
box(
    "ALLEY_LOW_ROOM",
    (ALLEY_X, 27, 18),
    (14, 10, 8),
    OVERHEAD,
    PLASTER,
    0.11
)

box(
    "ALLEY_LOW_ROOM_BOTTOM",
    (ALLEY_X, 27, 13.8),
    (15, 11, 0.5),
    OVERHEAD,
    IRON,
    0.03
)


# ============================================================
# INTERIOR THROUGH-PASSAGE
# ============================================================

# Visually reads as a route disappearing through a building.

PASSAGE_X = -15

box(
    "PASSAGE_LEFT_WALL",
    (
        PASSAGE_X - 5,
        -8,
        6
    ),
    (4, 11, 12),
    BUILDINGS,
    STONE,
    0.12
)

box(
    "PASSAGE_RIGHT_WALL",
    (
        PASSAGE_X + 5,
        -8,
        6
    ),
    (4, 11, 12),
    BUILDINGS,
    STONE,
    0.12
)

box(
    "PASSAGE_HEADER",
    (
        PASSAGE_X,
        -8,
        13
    ),
    (14, 11, 5),
    BUILDINGS,
    STONE_DARK,
    0.12
)

box(
    "PASSAGE_FLOOR",
    (
        PASSAGE_X,
        -14,
        -0.35
    ),
    (7, 20, 0.7),
    GROUND,
    STREET,
    0.02
)


# ============================================================
# STAIR / ELEVATED SHORTCUT
# ============================================================

for i in range(13):
    box(
        f"STAIR_{i}",
        (
            5 + i * 0.65,
            8.0,
            i * 0.52
        ),
        (6, 1.0, 0.52),
        TRAVERSAL,
        STONE,
        0.03
    )

box(
    "ELEVATED_ROUTE",
    (23, 8, 7),
    (27, 5, 0.65),
    TRAVERSAL,
    IRON,
    0.035
)


# ============================================================
# UTILITY PIPES
# ============================================================

# Cross-street pipes.
for i, (x, z) in enumerate(
    (
        (-45, 17),
        (-18, 23),
        (22, 16),
        (46, 25)
    )
):
    cylinder(
        f"CROSS_PIPE_{i}",
        (x, 0, z),
        0.45 if i % 2 else 0.70,
        27,
        DETAILS,
        IRON,
        12,
        rot=(
            math.radians(90),
            0,
            0
        )
    )


# Long side utility pipes.
for side in (-1, 1):
    for z in (11, 14):
        cylinder(
            "LONG_PIPE",
            (
                0,
                side * 8.2,
                z
            ),
            0.32,
            125,
            DETAILS,
            IRON,
            10,
            rot=(
                0,
                math.radians(90),
                0
            )
        )


# ============================================================
# HANGING UTILITY DROPS
# ============================================================

for i in range(22):
    x = random.uniform(-68, 68)
    y = random.choice((-7.5, 7.5))
    z = random.uniform(15, 30)

    box(
        f"UTILITY_DROP_{i}",
        (x, y, z),
        (
            0.12,
            0.12,
            random.uniform(5, 12)
        ),
        DETAILS,
        IRON,
        0.01,
        rot=(
            math.radians(
                random.uniform(-5, 5)
            ),
            0,
            math.radians(
                random.uniform(-7, 7)
            )
        )
    )


# ============================================================
# REPAIR PLATES
# ============================================================

for i in range(18):
    side = random.choice((-1, 1))
    x = random.uniform(-65, 67)
    y = side * random.uniform(7.2, 9.5)
    z = random.uniform(3, 16)

    box(
        f"REPAIR_PLATE_{i}",
        (x, y, z),
        (
            random.uniform(2, 5),
            0.18,
            random.uniform(2, 5)
        ),
        DETAILS,
        RED if random.random() < 0.16 else PATCH,
        0.02,
        rot=(
            0,
            math.radians(
                random.uniform(-7, 7)
            ),
            0
        )
    )


# ============================================================
# BREACHED SECTION
# ============================================================

BX = 56
BY = 7.5

box(
    "BREACH_LEFT",
    (BX - 5, BY, 7),
    (4, 2, 14),
    DAMAGE,
    STONE,
    0.13
)

box(
    "BREACH_RIGHT",
    (BX + 5, BY, 7),
    (4, 2, 14),
    DAMAGE,
    STONE,
    0.13
)

box(
    "BREACH_TOP",
    (BX, BY, 13),
    (7, 2, 3),
    DAMAGE,
    STONE,
    0.12,
    rot=(
        0,
        math.radians(4),
        0
    )
)

for i in range(6):
    box(
        f"BREACH_REBAR_{i}",
        (
            BX + random.uniform(-3, 3),
            BY - 1.1,
            random.uniform(4, 10)
        ),
        (
            0.13,
            0.13,
            random.uniform(2, 5)
        ),
        DAMAGE,
        IRON,
        0.01,
        rot=(
            math.radians(
                random.uniform(-8, 8)
            ),
            math.radians(
                random.uniform(-15, 15)
            ),
            0
        )
    )


# rubble
for i in range(18):
    box(
        f"RUBBLE_{i}",
        (
            BX + random.uniform(-5, 5),
            random.uniform(2.5, 7),
            random.uniform(0.2, 0.6)
        ),
        (
            random.uniform(0.5, 1.8),
            random.uniform(0.5, 1.5),
            random.uniform(0.4, 1.2)
        ),
        DAMAGE,
        STONE if i % 4 else PATCH,
        0.03,
        rot=(
            random.uniform(-0.4, 0.4),
            random.uniform(-0.4, 0.4),
            random.uniform(-0.8, 0.8)
        )
    )


# ============================================================
# STREET CLUTTER — LARGE ONLY
# ============================================================

# Not decorating our way out of geometry.
# Just enough structural clutter to test silhouette.

for i in range(8):
    x = random.uniform(-60, 60)
    side = random.choice((-1, 1))

    box(
        f"STORAGE_CRATE_{i}",
        (
            x,
            side * random.uniform(5.5, 6.5),
            1
        ),
        (
            random.uniform(1.5, 2.5),
            random.uniform(1.5, 2.5),
            random.uniform(1.5, 2.5)
        ),
        DETAILS,
        WOOD,
        0.04
    )


# ============================================================
# LAMPS
# ============================================================

lamp_positions = [
    (-58, 1),
    (-39, -1),
    (-20, 1),
    (2, -1),
    (25, 1),
    (45, -1),
    (63, 1),
]

for i, (x, side) in enumerate(lamp_positions):
    y = side * 7.2

    box(
        f"LAMP_ARM_{i}",
        (
            x,
            y - side * 0.7,
            10
        ),
        (0.3, 2.2, 0.3),
        DETAILS,
        IRON,
        0.02
    )

    box(
        f"LAMP_BODY_{i}",
        (
            x,
            y - side * 1.5,
            9.5
        ),
        (1, 1, 1.5),
        DETAILS,
        IRON,
        0.04
    )

    box(
        f"LAMP_GLASS_{i}",
        (
            x,
            y - side * 1.5,
            9.35
        ),
        (0.65, 0.65, 0.65),
        DETAILS,
        LAMP,
        0.025
    )

    bpy.ops.object.light_add(
        type="POINT",
        location=(
            x,
            y - side * 1.5,
            9.2
        )
    )

    light = bpy.context.object
    light.name = f"Preview_Lamp_{i}"
    light.data.energy = 100
    light.data.shadow_soft_size = 1.8
    light.data.color = (
        1.0,
        0.50,
        0.18
    )


# ============================================================
# GROUND GRIME
# ============================================================

for i in range(35):
    box(
        f"GROUND_GRIME_{i}",
        (
            random.uniform(-68, 68),
            random.uniform(-6, 6),
            0.025
        ),
        (
            random.uniform(1, 5),
            random.uniform(0.4, 1.8),
            0.025
        ),
        DETAILS,
        GRIME,
        0,
        rot=(
            0,
            0,
            random.uniform(0, math.pi)
        )
    )


# ============================================================
# ANCIENT MEGASTRUCTURE
# ============================================================

# Vast supports beyond the human construction.

for side in (-1, 1):
    box(
        f"ANCIENT_SIDE_MASS_{side}",
        (
            0,
            side * 58,
            110
        ),
        (170, 38, 220),
        ANCIENT_COL,
        ANCIENT,
        0.45
    )


# Giant ribs crossing far above.
ancient_ribs = [
    (-45, 175, -4),
    (10, 195, 3),
    (58, 168, -5)
]

for i, (x, z, angle) in enumerate(ancient_ribs):
    box(
        f"ANCIENT_RIB_{i}",
        (x, 0, z),
        (34, 145, 20),
        ANCIENT_COL,
        ANCIENT,
        0.5,
        rot=(
            math.radians(2),
            0,
            math.radians(angle)
        )
    )


# ============================================================
# SIGHTLINE BREAKERS
# ============================================================

# Important: prevent player from seeing cleanly end-to-end.

box(
    "MID_STREET_OFFSET_MASS",
    (19, 6.0, 11),
    (10, 9, 22),
    BUILDINGS,
    STONE_DARK,
    0.14,
    rot=(
        0,
        0,
        math.radians(-8)
    )
)

box(
    "FAR_ROUTE_TURN_MASS",
    (73, -2, 18),
    (8, 34, 36),
    BUILDINGS,
    STONE,
    0.16,
    rot=(
        0,
        0,
        math.radians(8)
    )
)


# ============================================================
# HUMAN SCALE REFERENCE
# ============================================================

cylinder(
    "PLAYER_BODY",
    (-61, -1, 3),
    0.65,
    4.4,
    DISPLAY,
    RED,
    12
)

bpy.ops.mesh.primitive_uv_sphere_add(
    segments=16,
    ring_count=8,
    radius=0.85,
    location=(-61, -1, 5.6)
)

head = bpy.context.object
head.name = "PLAYER_HEAD"
relocate(head, DISPLAY)
head.data.materials.append(RED)


# ============================================================
# WORLD
# ============================================================

world = bpy.context.scene.world
world.use_nodes = True

bg = world.node_tree.nodes.get("Background")

if bg:
    bg.inputs["Color"].default_value = (
        0.006,
        0.008,
        0.011,
        1
    )
    bg.inputs["Strength"].default_value = 0.18


# ============================================================
# PREVIEW LIGHTING
# ============================================================

bpy.ops.object.light_add(
    type="AREA",
    location=(-10, 0, 125)
)

ambient = bpy.context.object
ambient.name = "Preview_Upper_Ambient"
ambient.data.energy = 1800
ambient.data.size = 65


bpy.ops.object.light_add(
    type="AREA",
    location=(-65, -25, 35)
)

entrance_light = bpy.context.object
entrance_light.name = "Preview_Entrance_Fill"
entrance_light.data.energy = 1100
entrance_light.data.size = 28

point_at(
    entrance_light,
    (-20, 0, 9)
)


# ============================================================
# CAMERAS
# ============================================================

# Player-height entrance view.
bpy.ops.object.camera_add(
    location=(-64, -1.5, 6.3)
)

cam1 = bpy.context.object
cam1.name = "CAMERA_STREET_ENTRANCE"
cam1.data.lens = 31

point_at(
    cam1,
    (12, 1.5, 8)
)


# Mid-street camera for evaluating enclosure.
bpy.ops.object.camera_add(
    location=(-12, 1.0, 6.3)
)

cam2 = bpy.context.object
cam2.name = "CAMERA_MID_STREET"
cam2.data.lens = 30

point_at(
    cam2,
    (48, -2, 9)
)


# Alley camera.
bpy.ops.object.camera_add(
    location=(34, 8, 6.0)
)

cam3 = bpy.context.object
cam3.name = "CAMERA_ALLEY"
cam3.data.lens = 30

point_at(
    cam3,
    (34, 40, 7)
)


# Elevated overview.
bpy.ops.object.camera_add(
    location=(-100, -115, 105)
)

overview = bpy.context.object
overview.name = "CAMERA_OVERVIEW"
overview.data.lens = 45

point_at(
    overview,
    (0, 0, 35)
)


bpy.context.scene.camera = cam1


# ============================================================
# SAVE
# ============================================================

os.makedirs(
    os.path.dirname(OUT),
    exist_ok=True
)

bpy.ops.object.select_all(action="DESELECT")

bpy.ops.wm.save_as_mainfile(
    filepath=OUT
)

print("")
print("=" * 72)
print("ENFLESHED LOWER LAYER TEST STREET V2 GENERATED")
print(OUT)
print("")
print("CHECK THESE CAMERAS:")
print("CAMERA_STREET_ENTRANCE")
print("CAMERA_MID_STREET")
print("CAMERA_ALLEY")
print("CAMERA_OVERVIEW")
print("=" * 72)
